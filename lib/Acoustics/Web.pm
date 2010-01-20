package Acoustics::Web;

use warnings;
use strict;

use Time::HiRes 'sleep';
use Mouse;
use Module::Load 'load';
use List::Util 'shuffle';

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
		acoustics => $self->acoustics,
		cgi       => $self->cgi,
	});
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
	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	$data->{player} = $player;

	# FIXME: there should be a better way to do this
	$data->{playlist}      = [$acoustics->get_playlist()];
	($data->{now_playing}) = $acoustics->get_song({song_id => $player->{song_id}});

	if ($data->{now_playing}) {
		$data->{now_playing}{who} = [map {$_->{who}} $acoustics->get_votes_for_song($player->{song_id})];
	}

	$data->{who} = $self->who;
	$data->{can_skip} = $self->boolean_callback->($self->can_skip);
	$data->{is_admin} = $self->boolean_callback->($self->is_admin);
	return [], $data;
}

sub can_skip {
	my $self = shift;
	my $acoustics = $self->acoustics;
	my $who = $self->who;
	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	my @voters = map {$_->{who}} $acoustics->get_votes_for_song($player->{song_id});
	my $voted = grep {$who eq $_} @voters;

	return 0 unless $who;
	return 1 if $self->is_admin;
	return 1 if $voted && @voters == 1;
	return 1 if @voters == 0;
	return 0;
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

	my(@song_ids) = $self->cgi->param('song_id');
	my $purge_user = $self->cgi->param('purge');

	if (@song_ids && $song_ids[0]) {
		$self->acoustics->delete_vote({
			song_id => 0+$_,
			who     => $self->who,
		}) for @song_ids;
	} elsif ($self->is_admin && $purge_user) {
		$self->acoustics->delete_vote({who => $purge_user});
	} else {
		$self->acoustics->delete_vote({who => $self->who});
	}
	$self->status;
}

=head2 start

Turns on the player. Sleeps for 0.25 seconds before checking on the player
state.

=cut

sub start {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

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

	$self->acoustics->rpc('stop');

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
	return bad_request('No volume specified.') unless $vol;
	$self->acoustics->rpc('volume', $vol);
	$self->status;
}

=head2 shuffle_votes

Shuffles all of your votes.

=cut

sub shuffle_votes {
	my $self = shift;
	return access_denied('You must log in.') unless $self->who;

	my @votes = shuffle($self->acoustics->get_vote({who => $self->who}));
	my $pri = 0;
	for my $vote (@votes) {
		$vote->{priority} = $pri;
		$self->acoustics->update_vote($vote, {
			who => $self->who, song_id => $vote->{song_id},
		});
		$pri++;
	}

	$self->status;
}

=head1 METHODS THAT FIND SONGS

Many methods find and return an array of songs.

=head2 random

Returns C<amount> or 20 random songs.

=cut

sub random {
	my $self   = shift;
	my $amount = $self->cgi->param('amount') || 20;
	return [], [$self->acoustics->get_song({}, 'RAND()', $amount)];
}

=head2 recent

Returns the C<amount> or 50 most recently added songs.

=cut

sub recent {
	my $self   = shift;
	my $amount = $self->cgi->param('amount') || 50;
	return [], [$self->acoustics->get_song({}, {'-DESC' => 'song_id'}, $amount)];
}

=head2 history

Returns the C<amount> or 50 most recently played songs.

=cut

sub history {
	my $self   = shift;
	my $amount = $self->cgi->param('amount') || 50;
	my @history;
	for my $song ($self->acoustics->get_history($amount)) {
		if ($history[-1] && $history[-1]{time} == $song->{time}) {
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
	_search_or_select($self, 'search');
}

sub _search_or_select {
	my $self  = shift;
	my $mode  = shift;
	my $field = $self->cgi->param('field');
	my $value = $self->cgi->param('value');

	my $where;
	my $value_clause = $value;
	$value_clause    = {-like => "%$value%"} if $mode eq 'search';
	if ($field eq 'any') {
		$where = {-or => [map {$_ => $value_clause} qw(artist album title path)]};
	} else {
		$where = {$field => $value_clause};
	}

	$where->{online} = 1;

	return [], [$self->acoustics->get_song($where, [qw(artist album track title)])];
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
	return [], [$self->acoustics->browse_songs_by_column($field, $field)];
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

1;
