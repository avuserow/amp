package Acoustics::Web;

use warnings;
use strict;

use Log::Log4perl ':easy';
use Time::HiRes 'sleep';
use Moose;
use Module::Load 'load';
use List::Util 'shuffle';
use LWP::Simple;

has 'psgi_env'  => (is => 'ro', isa => 'HashRef');
has 'acoustics' => (is => 'ro', isa => 'Acoustics');
has 'cgi'       => (is => 'ro', isa => 'Object');

# this parameter is filled in in the BUILD sub below
has 'auth' => (
	is  => 'ro',
	isa => 'Acoustics::Web::Auth',
	handles => {
		authenticate => 'authenticate',
		is_admin     => 'is_admin',
		who          => 'whoami',
	},
);

# Code that is called to convert a boolean to whatever you want
# defaults to using double negation, resulting in 1 or ''
has 'boolean_callback' => (
	is  => 'rw',
	isa => 'CodeRef',
	# I heard you liked subs, so I put a sub in your sub
	# so you can execute while you execute.
	default => sub {sub {
		return $_[0] ? 1 : 0;
	}},
);

=head1 NAME

Acoustics::Web - handle web requests

=head1 SYNOPSIS

This module handles web requests. It's designed to be indepedent of web server
and should run with regular CGI, FastCGI, mod_perl, or similar, so long as we
can get an object that looks like L<CGI> or L<CGI::Simple>.

All of the (public) methods return two values: an array reference of values to
pass to CGI's header method, and a Perl data structure to encode using
L<JSON::DWIW> or whatever module you like to send data back. The array reference
may be C<[]> instead if we don't care about the headers.

    # give me a Acoustics object and a CGI object
    my $web = Acoustics::Web::JSON->new({
        acoustics => $acoustics,
        cgi       => $cgi,
    });

    # then call a method on me.
    my($code, $data) = $web->random;
    my($code, $data) = $web->stop;
    # etc

=head1 CONSTRUCTOR

new({acoustics => $acoustics, cgi => $cgi})

Takes an Acoustics object, a CGI (or compatible) object, and returns an
Acoustics::Web object. Both are required to be present when calling C<new>.

Additionally, you may pass a coderef as a C<boolean_callback> parameter. This
code will be called when a boolean should be returned. This is useful for
outputting to JSON and returning a real true or false value. By default, it uses
double-negation on the value.

=cut

sub BUILD {
	my $self = shift;

	my $auth_module = $self->acoustics->config->{webauth}{module};
	load $auth_module;

	$self->{auth} = $auth_module->new({
		psgi_env  => $self->psgi_env,
		acoustics => $self->acoustics,
		cgi       => $self->cgi,
	});

	$self->acoustics->select_player($self->auth->player_id);
}

=head1 METHODS THAT RETURN THE PLAYER STATE OBJECT

The following methods return the player state object. They usually change the
player state.

=head2 status

Just returns the player state. All of the Player State Object methods end up
calling this.

=cut

sub status {
	my $self = shift;
	my $acoustics = $self->acoustics;
	my $data = {};
	my $player = $acoustics->query(
		'select_players', {player_id => $acoustics->player_id},
	);
	$data->{player} = $player;

	# FIXME: there should be a better way to do this
	my $hint = JSON::DWIW->new->from_json($player->{queue_hint} || '');
	$acoustics->queue->deserialize($hint);
	$data->{playlist}    = [$acoustics->get_playlist()];
	$data->{now_playing} = $acoustics->query(
		'select_songs', {song_id => $player->{song_id}},
	);

	$data->{players} = [split /\s*,\s*/, $self->acoustics->config->{_}{players}];
	$data->{selected_player} = $self->acoustics->player_id;

	if ($data->{now_playing}) {
		$data->{now_playing}{who} = [map {$_->{who}} $acoustics->query('select_votes', {song_id => $player->{song_id}})];
		$data->{now_playing}{now} = time;
	}

	$data->{who} = $self->who;
	$data->{can_skip} = $self->boolean_callback->($self->can_skip);
	$data->{is_admin} = $self->boolean_callback->($self->is_admin);
	return [], $data;
}

sub can_skip {
	my $self = shift;
	my $acoustics = $self->acoustics;
	my $who = $self->who || '';
	my $player = $acoustics->query(
		'select_players', {player_id => $acoustics->player_id},
	);
	my @voters = map {$_->{who}} $acoustics->query('select_votes', {song_id => $player->{song_id}});
	my $voted = grep {$who eq $_} @voters;

	return 0 unless $who;
	return 1 if $self->is_admin;
	return 1 if $voted && @voters == 1;
	return 1 if @voters == 0;
	return 0;
}

=head2 get_details

Retrieve details for the song specified by the C<song_id> parameter.

=cut

sub get_details {
	my $self = shift;
	my(@song_ids) = $self->cgi->param('song_id');
	return bad_request('No songs specified.') unless @song_ids;
	my $song = 0+(shift @song_ids);
	my $acoustics = $self->acoustics;
	my $details = {};
	$details->{song} = $acoustics->query('select_songs', {song_id => $song});
	if ($details->{song}) {
		$details->{song}{who} = [map {$_->{who}} $acoustics->query('select_votes', {song_id => $song})];
	}
	return [], $details;
}

=head2 vote

Votes for all the songs specified by the C<song_id> parameter(s).

=cut

sub vote {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	my(@song_ids) = $self->cgi->param('song_id');
	return bad_request('No songs specified.') unless @song_ids;

	$self->acoustics->vote(0+$_, $self->who) for @song_ids;
	$self->status;
}

=head2 unvote

Removes votes for the song or songs specified by the C<song_id> parameter.

=cut

sub unvote {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	for my $id ($self->cgi->param('song_id')) {
		$self->acoustics->query('delete_votes', {
			song_id => 0+$id,
			who     => $self->who,
		});
	}

	$self->status;
}

=head2 purge

Purges all votes by a given user. If this user is not an admin, it purges their
votes.

=cut

sub purge {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	my $purge_user = $self->cgi->param('who');
	$purge_user    = $self->who unless $self->is_admin;

	$self->acoustics->query('delete_votes', {who => $purge_user});

	$self->status;
}

=head2 start

Turns on the player. Sleeps for 0.25 seconds before checking on the player
state.

=cut

sub start {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	INFO("start requested by " . $self->who);
	$self->acoustics->rpc('start');

	sleep 0.25;

	$self->status;
}

=head2 stop

Turns off the player. Sleeps for 0.25 seconds before checking on the player
state.

=cut

sub stop {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	INFO("stop requested by " . $self->who);
	$self->acoustics->rpc('stop');

	sleep 0.25;

	$self->status;
}

=head2 zap

removes the specified player from the database by force. sleeps for 0.25 seconds
before checking on the player state

=cut

sub zap {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	my $zap_player = $self->cgi->param('value');
	INFO("zap requested by " . $self->who . " for player " . $zap_player);
	$self->acoustics->rpc('zap',$zap_player);
	
	sleep 0.25;

	$self->status;
}

=head2 skip

Attempts to skip the current song. Sleeps for 0.25 seconds before checking on
the player state.

=cut

sub skip {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;
	return access_denied('You cannot skip this song.') unless $self->can_skip;

	INFO("skip requested by " . $self->who);
	$self->acoustics->rpc('skip');

	sleep 0.25;

	$self->status;
}

=head2 volume

Changes the volume of the player to the value specified by C<value>, which is a
percentage.

=cut

sub volume {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	my $vol = $self->cgi->param('value');
	return bad_request('No volume specified.') unless defined $vol;
	INFO("volume change requested by " . $self->who . " to " . $vol);
	$self->acoustics->rpc('volume', $vol);
	$self->status;
}

=head2 change_player

Moves you to a different player specified by C<player_id>.

=cut

sub change_player {
	my $self = shift;

	my $player = $self->cgi->param('player_id');
	$self->acoustics->select_player($player);

	$self->auth->player_id($self->acoustics->player_id);
	return $self->status;
}

=head2 shuffle_votes

Shuffles all of your votes.

=cut

sub shuffle_votes {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	my @votes = shuffle($self->acoustics->query(
			'select_votes', {who => $self->who},
	));
	my $pri = 0;
	for my $vote (@votes) {
		$vote->{priority} = $pri;
		$self->acoustics->query('update_votes', $vote, {
			who => $self->who, song_id => $vote->{song_id},
		});
		$pri++;
	}

	$self->status;
}

=head2 vote_to_top

Brings a vote to the top of your queue.

=cut

sub vote_to_top {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	my $song_id = $self->cgi->param('song_id');
	return bad_request('No song specified.') unless $song_id;

	my $vote_where = {who => $self->who, song_id => $song_id};

	my $minvote = $self->acoustics->query(
		'select_votes', {who => $self->who}, 'priority', 1,
	);
	my $vote = $self->acoustics->query('select_votes', $vote_where);
	$vote->{priority} = $minvote->{priority} - 1;
	$self->acoustics->query('update_votes', $vote, $vote_where);

	$self->status;
}

=head2 reorder_queue

Reorders the songs that the current user has in the queue into the order
provided.

=cut

sub reorder_queue {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	my @order = $self->cgi->param('song_id');

	my %songmap = map {$_->{song_id} => $_}
		$self->acoustics->query('select_votes', {who => $self->who});

	my @songs;
	for my $song_id (@order) {
		push @songs, delete $songmap{$song_id};
	}
	push @songs, values %songmap;

	for my $i (0 .. $#songs) {
		$songs[$i]{priority} = $i;
		$self->acoustics->query('update_votes', $songs[$i],
			{song_id => $songs[$i]{song_id}, player_id => $songs[$i]{player_id},
				who => $songs[$i]{who}});
	}

	return $self->status;
}

=head1 METHODS THAT FIND SONGS

Many methods find and return an array of songs.

=head2 random

Returns C<amount> or 20 random songs.

=cut

sub random {
	my $self   = shift;
	my $amount = $self->cgi->param('amount') || 20;
	my $seed = $self->cgi->param('seed') || int(rand(2147483647));
	return [], [$self->acoustics->get_random_song($amount, $seed)];
}

=head2 recent

Returns the C<amount> or 50 most recently added songs.

=cut

sub recent {
	my $self   = shift;
	my $amount = $self->cgi->param('amount') || 50;
	return [], [$self->acoustics->query(
		'select_songs', {}, {'-DESC' => 'song_id'}, $amount,
	)];
}

=head2 byuser

Returns the songs voter X has voted for.

=cut

sub byvoter {
	my $self  = shift;
	my $other = $self->cgi->param('voter') || "";
	my @votes = $self->acoustics->query(
		'select_votes', {who => $other}, 'priority',
	);
	my (@songs) = map {
		$self->acoustics->query('select_songs', {song_id => $_->{song_id}})
	} @votes;
	return [], [@songs];
}

=head2 history

Returns the C<amount> or 50 most recently played songs.

=cut

sub history {
	my $self   = shift;
	my $amount = $self->cgi->param('amount') || 50;
	my $voter  = $self->cgi->param('who') || '';
	my @history;
	for my $song ($self->acoustics->get_history($amount, $voter)) {
		if ($history[-1] && $song->{song_id} == $history[-1]{song_id} && $history[-1]{time} == $song->{time}) {
			push @{$history[-1]{who}}, $song->{who};
		} else {
			$song->{who} = [$song->{who}];
			push @history, $song;
		}
	}
	return [], \@history;
}

=head2 select
=head2 search

These methods search the C<field> column for the C<value> specified. C<search>
does a wildcard match using SQL's LIKE, where C<select> does not.

=cut

sub select {
	my $self = shift;
	_search_or_select($self, 'select');
}

sub search {
	my $self = shift;
	if ($self->cgi->param('query')) {
		$self->_newsearch;
	} else {
		_search_or_select($self, 'search');
	}
}

sub _search_or_select {
	my $self  = shift;
	my $mode  = shift;
	my $field = $self->cgi->param('field');
	my $value = $self->cgi->param('value');

	my $where;
	my $value_clause = $value;
	if ($mode eq 'search') {
		$value =~ s/^\s+//g;
		$value =~ s/\s+$//g;
		$value =~ s/\s+/ /g;
		$value_clause = {-like => "%$value%"};
	}
	if ($field eq 'any') {
		$where = {-or => [map {$_ => $value_clause} qw(artist album title path)]};
	} else {
		$where = {$field => $value_clause};
	}

	$where->{online} = 1;
	
	my @results = $self->acoustics->query('select_songs', $where, [qw(artist album track)]);

	@results = $self->acoustics->dedupe(@results);

	return [], \@results;
}

=head2 _newsearch

Takes in a JSON structure and searches for things. Examples:

=over 4

=item * songs where artist is foo and album is bar

    ["artist", "==", "foo", "AND", "album", "==", "bar"]

=item * songs where artist is foo or artist is bar and album is not baz

    ["artist", "==", "foo", "OR", ["artist", "==", "bar", "album", "!=",
    "baz"]]

=back

Basically, specify a "group". This group contains either one value (a
subgroup), or three values (field, operator, and value). Then the group either
ends or has a joining operator, and the initial values repeat.

Operators, which may be prefaced with a ! to negate it: == for equals and ~~
for contains.

Joining operators are C<AND> and C<OR>.

=cut

sub _newsearch {
	my $self = shift;
	my $query = $self->acoustics->from_json($self->cgi->param('query'));

	my($where, @bind) = _newsearch_parse_query($query);

	my $sth = $self->acoustics->db->prepare('SELECT * FROM songs WHERE online = 1 AND ' . $where);
	$sth->execute(@bind);
	my @results = @{$sth->fetchall_arrayref({})};

	return [], \@results;
}

sub _newsearch_parse_query {
	my $query = shift;
	use Data::Dumper;
	die Dumper($query);
	ref $query eq 'ARRAY'
		or die '_newsearch_parse_query: outer level must be arrayref';

	return if @$query == 0; # empty useless group

	# well, this is awkward
	my $bool;
	$bool = uc shift @$query;
	if ($bool eq 'AND') {
		$bool = ' AND ';
	} elsif ($bool eq 'OR') {
		$bool = ' OR ';
	} else {
		die "_newsearch_parse_query: unknown boolean $bool";
	}


	my @sql;
	my @bind_vars;

	while (@$query > 0) {
		if (ref $query->[0]) {
			# found a subgroup; recurse
			my $subgroup = shift @$query;
			my($sql, @bind) = _newsearch_parse_query($subgroup);
			push @sql, "($sql)";
			push @bind_vars, @bind;
		} else {
			# we can get into some odd situations where we don't get the right
			# number of items, so let's sanity check here
			if (@$query < 2) {
				die '_newsearch_parse_query: not enough key/value pairs found';
			}

			my $field = shift @$query;
			not ref $field or die '_newsearch_parse_query: field expected where ' .
				(ref $field) . ' found';
			$field =~ /^\w+$/
				or die '_newsearch_parse_query: field contains invalid characters';

			my $value = shift @$query;
			if (not defined $value) {
				push @sql, "$field IS NOT NULL";
			} elsif (ref $value eq 'HASH') {
				# XXX: needs to be more well thought out here
				if ($value->{"!="}) {
					push @sql, "$field != ?";
					push @bind_vars, $value->{"!="};
				} elsif ($value->{"~~"}) {
					push @sql, "$field LIKE ?";
					my $val = $value->{"~~"};
					push @bind_vars, "%$val%";
				}
			} else {
				not ref $value or die '_newsearch_parse_query: value expected where ' .
					(ref $value) . ' found';

				push @sql, "$field = ?";
				push @bind_vars, $value;
			}
		}
	}

	my $sql = join $bool, @sql;

	return $sql, @bind_vars;
}

=head2 playlist_contents

Takes a parameter (C<playlist_id>) and returns the songs in it.

=cut

sub playlist_contents {
	my $self = shift;
	my $plid = $self->cgi->param('playlist_id');

	return bad_request('No playlist_id specified.') unless $plid;

	return [], [$self->acoustics->query(
		'get_playlist_contents', {playlist_id => $plid},
	)];
}

=head2 add_to_playlist

Adds all the songs (specified by the C<song_id> parameter(s)) to the given
playlist (specified by C<playlist_id>).

=cut

sub add_to_playlist {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	my $plid = $self->cgi->param('playlist_id');
	return bad_request('No playlist specified.') unless $plid;

	my(@song_ids) = $self->cgi->param('song_id');
	return bad_request('No songs specified.') unless @song_ids;

	my $priority = $self->acoustics->query(
		'get_max_playlist_priority', {playlist_id => $plid},
	);
	$priority = $priority ? $priority->{'max(priority)'} : 0;
	$priority++;

	for my $song_id (@song_ids) {
		my $song = $self->acoustics->query('select_playlist_contents',
			{playlist_id => $plid, song_id => $song_id}
		);
		unless ($song) {
			$self->acoustics->query('insert_playlist_contents',
				{
					playlist_id => $plid,
					song_id     => 0+$song_id,
					priority    => $priority++,
				},
			);
		}
	}
	$self->playlist_contents;
}

=head2 remove_from_playlist

Removes one or more songs (specified by C<song_id> parameters) from the given
playlist (specified by C<playlist_id>).

=cut

sub remove_from_playlist {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	my $plid = $self->cgi->param('playlist_id');
	return bad_request('No playlist specified.') unless $plid;

	my(@song_ids) = $self->cgi->param('song_id');
	return bad_request('No songs specified.') unless @song_ids;

	for my $song_id (@song_ids) {
		my $song = $self->acoustics->query('select_playlist_contents',
			{playlist_id => $plid, song_id => $song_id}
		);
		if ($song) {
			$self->acoustics->query('delete_playlist_contents',
				{playlist_id => $plid, song_id => 0+$song_id},
			);
		}
	}
	$self->playlist_contents;
}

=head1 OTHER METHODS

These methods (currently just browse) do not return the player state or an
arrayref of songs.

=head2 browse

Returns an array reference of artists or albums, as specified by the C<field>
parameter.

=cut

sub browse {
	my $self  = shift;
	my $field = $self->cgi->param('field');
	return [], [] if $field ne 'artist' && $field ne 'album';
	return [], [map {$_->{$field}} $self->acoustics->query(
		'get_songs_by_column', {}, {column => $field},
	)];
}

=head2 create_playlist

Creates a playlist with the given title (C<title> parameter).

=cut

sub create_playlist {
	my $self  = shift;
	my $title = $self->cgi->param('title');

	return access_denied('You must log in.') unless $self->who;

	# require that the title contains at least one printable nonspace character
	if(!$title || $title =~ /[^[:print:]]/ || $title !~ /\S/) {
		return bad_request('Invalid title');
	}

	$self->acoustics->query('insert_playlists', {
		who   => $self->who,
		title => $title,
	});

	# rebind some parameters for when we chain to the next routine
	$self->cgi->param('who', $self->who);
	$self->cgi->delete('title');
	$self->playlists;
}

=head2 delete_playlist

Permanently removes the specified playlist (using the C<playlist_id> parameter).

=cut

sub delete_playlist {
	my $self = shift;
	my $plid = $self->cgi->param('playlist_id');

	return access_denied('You must log in.') unless $self->who;

	$self->acoustics->query('delete_playlists',
		{who => $self->who, playlist_id => $plid},
	);

	# rebind some parameters for when we chain to the next routine
	$self->cgi->param('who', $self->who);
	$self->playlists;
}

=head2 playlists

Returns a list of all the playlists, optionally with a C<who> parameter
(case-insensitive match) or a C<title> (case-insensitive, substring match).

=cut

sub playlists {
	my $self  = shift;
	my $who   = $self->cgi->param('who') || '';
	my $title = $self->cgi->param('title') || '';

	my $where = {};
	$where->{who}   = {-like => $who} if $who;
	$where->{title} = {-like => "%$title%"} if $title;

	return [], [$self->acoustics->query('select_playlists', $where)];
}

=head2 rename_playlist

Renames a given playlist

=cut

sub rename_playlist {
	my $self = shift;
	my $id = $self->cgi->param('id') || '';
	my $new = $self->cgi->param('new') || '';
	if($new eq '' || $id eq '')
	{
		return;
	}

	my $where = {};
	$where->{playlist_id} = {$id};
	
	my $set = {};
	$set->{title} = $new;
	return [], [$self->acoustics->query('update_playlists', $set, $where)];

}

=head2 resource

Emit HTML, Javascript, or CSS content.

=cut

sub resource {
	my $self = shift;
	my $filename = $self->cgi->param('file') || 'index.html';
	my($type) = $filename =~ /\.(html|css|js|png|jpg)$/;

	return access_denied("Access Denied") if $filename =~ m{^/} || $filename =~ m{\.\.};
	return access_denied("Access Denied") if $filename =~ m{[^/\.\w-]};
	return bad_request("Invalid Filetype") unless $type;

	open my $fh, '<', "www-data/$filename" or die "Could not open '$filename': $!";
	my $data = join '', <$fh>;
	close $fh;

	my $content_type;
	if ($type =~ /html|css|js/) {
		$content_type = "text/$type";
		my $api_url = 'json.psgi';
		my $content_url = 'json.psgi?mode=resource;file=';
		$data =~ s/\[%\s* api_url \s*%\]/$api_url/gx;
		$data =~ s/\[%\s* wwwdata_url \s*%\]/$content_url/gx;
	} else {
		$content_type = "image/$type";
	}

	return [-type => $content_type], $data;
}

=head1 ERROR FUNCTIONS

These are to be called as functions, not methods, for internal use only.

=head2 access_denied($msg)

Returns a 403 error with the text in C<$msg>. For use when a given action
requires the user to be logged in or to be an admin.

=cut

sub access_denied {
	my $msg = shift;
	return [-status => '403 Forbidden'], $msg;
}

=head2 bad_request($msg)

Returns a 400 error with the text in C<$msg>. Indicates that the given command
is nonsensical (for example, a required argument was missing).

=cut

sub bad_request {
	my $msg = shift;
	return [-status => '400 Bad Request'], $msg;
}

=head1 SEE ALSO

L<Acoustics>

The description of the JSON API, which is a thin wrapper around this module:
L<http://wiki.github.com/avuserow/amp/json-api>

=cut

sub stats
{
	my $self = shift;
	my $who = $self->cgi->param('who');
	my $acoustics = $self->acoustics;
	my $db = $acoustics->db;
	my $results = {};
	
	my $totalsongs = $db->prepare("SELECT count(*) from songs");
	$totalsongs->execute();
	$results->{total_songs} = ($db->selectrow_array($totalsongs))[0];

	if($who) 
	{
		my $topartists = $db->prepare('select artist,count(songs.artist) as count from songs,history where songs.song_id = history.song_id and history.who = ? group by artist order by count(songs.artist) desc limit 10;');
		$topartists->execute($who);
		$results->{top_artists} = ($topartists->fetchall_arrayref({}))
	}
	else
	{
			my $topartists = $db->prepare('select artist,count(songs.artist) as count from songs,history where songs.song_id = history.song_id group by artist order by count(songs.artist) desc limit 10;');
		$topartists->execute();
		$results->{top_artists} = ($topartists->fetchall_arrayref({}));
	}

	return [], $results;
}

=head2 art

Return album art image for the requested song.

=cut

sub art
{
	my $self = shift;
	my $artist = $self->cgi->param("artist");
	my $album  = $self->cgi->param("album");
	my $title  = $self->cgi->param("title");
	my $set    = $self->cgi->param("set");
	my $size   = 128;
	if ($self->cgi->param("size")) {
		$size = int($self->cgi->param("size"));
	}

	# It's okay if an argument is blank, for the most part.
	if (!$artist) { $artist = ""; }
	if (!$album)  { $album  = ""; }
	if (!$title)  { $title  = ""; }
	my $ret    = {};

	# Fix issues with albumless tracks
	if (length $album < 1) {
		$album = $title . "__" . $artist;
	}

	# This is a request to set to a specific URL.
	if ($set && $set eq "yes") {
		return access_denied('You must log in.') unless $self->who;
		my $url = $self->cgi->param("image");
		my $image = get $url;
		INFO("adding art cache for " . $title . ": " . $url);
		$self->acoustics->query('delete_art_cache', {artist => $artist, album => $album, title => $title});
		$self->acoustics->query('insert_art_cache', {artist => $artist, album => $album, title => $title, image => $image, url => $url });
		return [], {};
	}

	# Check the database first.
	my @queries = (
		{artist => $artist, album => $album, title => $title},
		{artist => $artist, album => $album},
		{album => $album},
	);

	my @results;

	# Try some queries until we get results.
	while (!@results && @queries) {
		@results = $self->acoustics->query('select_art_cache', shift @queries);
	}

	# We have a result from the database, dump that and bale.
	if (@results) {
		unless (length $results[0]->{image} > 10) {
			# We found something, but we only have a URL stored for some reason.
			# This could be because a plugin added it but didn't store the result.
			$results[0]->{image} = get $results[0]->{url};
			INFO("updating art cache for " . $results[0]->{title});
			$self->acoustics->query('delete_art_cache', {artist => $artist, album => $album, title => $title});
			$self->acoustics->query('insert_art_cache', {artist => $artist, album => $album, title => $title, image => $results[0]->{image}, url => $results[0]->{url} });
		}
		return [-type => "image/png"], $results[0]->{image};
	}

	# XXX: Extension hooks should be added here to
	#      pull from LastFM / Amazon / whatever

	# Fall back to local icon.
	my $last_try = "www-data/icons/cd_case.png";
	if ($size < 100) {
		$last_try = "www-data/icons/cd_case_small.png";
	} else {
		$last_try = "www-data/icons/cd_case.png";
	}
	open IMAGE, $last_try;
	local $/;
	$ret->{image} = <IMAGE>;
	close IMAGE;


	# TODO: We should probably use Perl's GD bindings to resize
	#       the result image to the requested size. I'm not
	#       entirely sure whether I want to, though - klange

	return [-type => "image/png"], $ret->{image};
}

sub album_search
{
	my $self  = shift;
	my $album = $self->cgi->param('album') || '';

	my $sth = $self->acoustics->db->prepare('SELECT album FROM songs WHERE album LIKE ? OR artist LIKE ? GROUP BY album');
	$sth->execute("%$album%", "%$album%");
	my @results = @{$sth->fetchall_arrayref({})};

	return [], \@results;
}


1;
