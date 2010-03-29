package Acoustics;

use strict;
use warnings;

use Acoustics::Database;
use SQL::Abstract::Limit;
use Mouse;
use Module::Load 'load';
use DBI;
use Log::Log4perl;
use Date::Parse 'str2time';
use Config::Tiny;
use Try::Tiny;

has 'db' => (is => 'ro', isa => 'DBI', handles => [qw(begin_work commit)]);
has 'config' => (is => 'ro', isa => 'Config::Tiny');
has 'abstract' => (is => 'ro', isa => 'SQL::Abstract');
has 'querybook' => (is => 'ro', handles => ['query']);
has 'config_file' => (is => 'ro', isa => 'Str');
has 'player_id' => (is => 'ro', isa => 'Str', default => 'default player');
has 'queue' => (is => 'ro', isa => 'Acoustics::Queue');

# Logger configuration:
# - Print out all INFO and above messages to the screen
# - Write out all WARN and above messages to a logfile
my $log4perl_conf = q(
log4perl.logger = INFO, Screen, Logfile
log4perl.logger.Acoustics.Web = INFO, Logfile

# INFO messages
log4perl.filter.MatchInfo = Log::Log4perl::Filter::LevelRange
log4perl.filter.MatchInfo.LevelMin      = INFO
log4perl.filter.MatchInfo.AcceptOnMatch = true

# Error messages
log4perl.filter.MatchError = Log::Log4perl::Filter::LevelRange
log4perl.filter.MatchError.LevelMin      = WARN
log4perl.filter.MatchError.AcceptOnMatch = true

# INFO to Screen
log4perl.appender.Screen        = Log::Log4perl::Appender::ScreenColoredLevels
log4perl.appender.Screen.Filter = MatchInfo
log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %p %d %F{1} %L> %m %n

# ERROR to Logfile
log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.Filter   = MatchError
log4perl.appender.Logfile.filename = /tmp/acoustics.log
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = %p %d %F{1} %L> %m %n
);
Log::Log4perl::init(\$log4perl_conf);
my $logger = Log::Log4perl::get_logger;

sub BUILD {
	my $self = shift;

	$self->{config} = Config::Tiny->read($self->config_file)
		or die "couldn't read config: \"" . $self->config_file . '"';

	$self->{db} = DBI->connect(
		$self->config->{database}{data_source},
		$self->config->{database}{user}, $self->config->{database}{pass},
		{RaiseError => 1, AutoCommit => 1},
	);
	$self->{abstract} = SQL::Abstract::Limit->new({limit_dialect => $self->db});
	$self->{querybook} = Acoustics::Database->new(
		db => $self->{db},
		phrasebook => 'queries.txt',
	);

	my $queue_class = $self->config->{player}{queue} || 'RoundRobin';
	$queue_class    = 'Acoustics::Queue::' . $queue_class;
	load $queue_class;
	$self->{queue} = $queue_class->new({acoustics => $self});
}

sub check_if_song_exists {
	my $self = shift;
	my $path = shift;

	my @rows = $self->db->selectrow_array(
		'SELECT count(*) FROM songs WHERE path = ?',
		undef, $path,
	);

	return $rows[0];
}

sub add_song {
	my $self = shift;
	my $data = shift;

	my($sql, @values) = $self->abstract->insert('songs', $data);
	my $sth = $self->db->prepare($sql);
	$sth->execute(@values);
}

sub update_song {
	my $self  = shift;
	my $data  = shift;
	my $where = shift;

	my($sql, @values) = $self->abstract->update('songs', $data, $where);
	my $sth = $self->db->prepare($sql);
	$sth->execute(@values);
}

sub get_song {
	my $self   = shift;
	my $where  = shift;
	my $order  = shift;
	my $limit  = shift;
	my $offset = shift;

	my($sql, @values) = $self->abstract->select(
		'songs', '*', $where, $order, $limit, $offset,
	);
	my $sth = $self->db->prepare($sql);
	$sth->execute(@values);

	return @{$sth->fetchall_arrayref({})};
}

# MySQL fails hard on selecting a random song. see:
# http://www.paperplanes.de/2008/4/24/mysql_nonos_order_by_rand.html
sub get_random_song {
	my $self  = shift;
	my $count = shift;
	my $random = $self->rand;
	my $sth = $self->db->prepare("SELECT * FROM (SELECT song_id FROM songs ORDER BY $random LIMIT ?) AS random_songs JOIN songs ON songs.song_id = random_songs.song_id");
	$sth->execute($count);

	return @{$sth->fetchall_arrayref({})};
}

sub browse_songs_by_column {
	my $self   = shift;
	my $col    = shift;
	my $order  = shift;
	my $limit  = shift;
	my $offset = shift;

	# SQL injection.
	if ($col =~ /\W/) {
		$logger->error("SQL injection attempt with column '$col'");
		return;
	}

	my($sql, @values) = $self->abstract->select(
		'songs', "DISTINCT $col", {online => 1}, $order, $limit, $offset,
	);
	my $sth = $self->db->prepare($sql);
	$sth->execute(@values);

	return map {$_->[0]} @{$sth->fetchall_arrayref([$col])};
}

sub get_votes_for_song {
	my $self = shift;
	my $song_id = shift;

	my $select_votes = $self->db->prepare(
			'SELECT who FROM votes WHERE song_id=?');
	
	$select_votes->execute($song_id);

	return @{$select_votes->fetchall_arrayref({})};
}

sub get_voters_by_time {
	my $self = shift;
	return @{$self->db->selectcol_arrayref(
		'SELECT who FROM votes WHERE player_id = ?
		GROUP BY who ORDER BY MIN(time)',
		undef, $self->player_id,
	)};
}

sub get_songs_by_votes {
	my $self = shift;

	# Make a hash mapping voters to all the songs they have voted for
	my $select_votes = $self->db->prepare('
		SELECT votes.song_id, votes.time, votes.who, votes.priority,
		songs.artist, songs.album, songs.title, songs.length, songs.path,
		songs.track FROM votes INNER JOIN songs ON votes.song_id =
		songs.song_id WHERE votes.player_id = ?
	');
	$select_votes->execute($self->player_id);

	my %votes;
	while (my $row = $select_votes->fetchrow_hashref()) {
		my $who = delete $row->{who}; # remove the who, save it
		$row->{time} = str2time($row->{time});
		$votes{$row->{song_id}} ||= $row;
		push @{$votes{$row->{song_id}}{who}}, $who; # re-add the voter
	}

	return %votes;
}

sub get_playlist {
	my $self = shift;
	my @playlist = $self->queue->list;

	my($player) = $self->get_player({player_id => $self->player_id});
	$player->{song_id} ||= 0;
	return grep {$player->{song_id} != $_->{song_id}} @playlist;
}

sub get_current_song {
	my $self = shift;
	my @playlist = $self->queue->list;
	if (@playlist) {
		return $playlist[0];
	}
	return;
}

sub add_playhistory {
	my $self = shift;
	my $data = shift;

	my($sql, @values) = $self->abstract->insert('history', $data);
	my $sth = $self->db->prepare($sql);
	$sth->execute(@values);
}

sub get_history
{
	my $self = shift;
	my $amount = shift;
	my $voter  = shift;

	my $sth;
	if ($voter) {
		$sth = $self->db->prepare('SELECT time FROM history WHERE who = ? GROUP BY time ORDER BY time DESC LIMIT ?');
		$sth->execute($voter, $amount);
	} else {
		$sth = $self->db->prepare('SELECT time FROM history GROUP BY time ORDER BY time DESC LIMIT ?');
		$sth->execute($amount);
	}
	$_ = (@{$sth->fetchall_arrayref({})})[-1];
	my $final_time = (defined($_) ? $_->{time} : undef);
	$sth->finish;

	my $select_history;
	if ($voter) {
		$select_history = $self->db->prepare('SELECT history.who, history.time,
			songs.* FROM history INNER JOIN songs ON history.song_id =
			songs.song_id WHERE history.time >= ? AND history.player_id = ? AND
			history.who = ? ORDER BY history.time DESC');
		$select_history->execute($final_time, $self->player_id, $voter);
	} else {
		$select_history = $self->db->prepare('SELECT history.who, history.time,
			songs.* FROM history INNER JOIN songs ON history.song_id =
			songs.song_id WHERE history.time >= ? AND history.player_id = ?
			ORDER BY history.time DESC');
		$select_history->execute($final_time, $self->player_id);
	}

	return (defined($final_time) ? @{$select_history->fetchall_arrayref({})} : () );
}

sub vote {
	my $self = shift;
	my $song_id = shift;
	my $who = shift;

	my $sth = $self->db->prepare('SELECT max(priority) FROM votes WHERE who = ?
			AND player_id = ?');
	$sth->execute($who, $self->player_id);
	my($maxpri) = $sth->fetchrow_array() || 0;
	$sth = $self->db->prepare('SELECT count(*) FROM votes WHERE who = ?
			AND player_id = ?');
	$sth->execute($who, $self->player_id);
	my($num_votes) = $sth->fetchrow_array() || 0;
	# Cap # of votes per voter
	my $maxvotes = $self->config->{player}{max_votes};
	$maxvotes = 0 if $maxvotes < 0;
	if ($num_votes < $maxvotes || !$maxvotes){
		$sth = $self->db->prepare(
			'INSERT IGNORE INTO votes (song_id, time, player_id, who, priority)
			VALUES (?, now(), ?, ?, ?)'
		);
		$sth->execute($song_id, $self->player_id, $who, $maxpri + 1);
	}
}

sub update_vote {
	my $self  = shift;
	my $data  = shift;
	my $where = shift;

	my($sql, @values) = $self->abstract->update(
		'votes', $data, $where,
	);
	my $sth = $self->db->prepare($sql);
	$sth->execute(@values);
}

sub add_player {
	my $self = shift;
	my $data = shift;
	$data  ||= {};
	$data->{player_id} = $self->player_id;

	my($sql, @values) = $self->abstract->insert('players', $data);
	my $sth  = $self->db->prepare($sql);

	$sth->execute(@values);
}

sub update_player {
	my $self = shift;
	my $data = shift;

	my($sql, @values) = $self->abstract->update(
		'players', $data, {player_id => $self->player_id},
	);
	my $sth = $self->db->prepare($sql);
	$sth->execute(@values);
}

sub remove_player {
	my $self = shift;
	my $sth  = $self->db->prepare('DELETE FROM players WHERE player_id = ?');

	$sth->execute($self->player_id);
}

sub get_player {
	my $self  = shift;
	my $where = shift;

	my($sql, @values) = $self->abstract->select('players', '*', $where);
	my $sth = $self->db->prepare($sql);
	$sth->execute(@values);

	return @{$sth->fetchall_arrayref({})};
}

sub player {
	my $self = shift;
	my $act  = shift;

	my $player_class = $self->config->{player}{module};
	load $player_class;

	$player_class->$act($self, @_);
}

sub rpc {
	my $self = shift;
	my $act  = shift;

	my $rpc_class = $self->config->{rpc}{module};
	load $rpc_class;

	$rpc_class->$act($self, @_);
}

sub plugin_call {
	my $self      = shift;
	my $component = shift;
	my $message   = shift;
	my @args      = @_;

	die 'component must be "player" currently!' if $component ne 'player';
	die 'no message sent' unless $message;

	my @plugins = split /\s*,\s*/, $self->config->{$component}{plugins};
	for my $plugin (@plugins) {
		next if !$plugin || $plugin =~ /[^\w:]/; # ignore invalid string
		$component = ucfirst $component;
		my $class  = "Acoustics::$component\::Plugin::$plugin";
		try {
			load $class;
			my $method = $class->can($message);
			$method->($self, @args) if $method;
		} catch {
			$logger->error("Plugin '$class' is broken: $_");
			# remove the plugin to supress a large number of errors
			$self->config->{$component}{plugins} =~ s/$plugin//;
		};
	}
}

sub reinit {
	my $self = shift;

	return Acoustics->new({config_file => $self->config_file});
}
# Mysql has RAND, everyone else has RANDOM
# TODO: Make this a stored procedure
sub rand {
	my $self = shift;
	my $db = $self->config->{database}{data_source};
	if ($db =~ m{^dbi:mysql}i) {
		return "RAND()";
	}
	elsif ($db =~ m{^dbi:(pg|sqlite)}i) {
		return "RANDOM()";
	}
	# A propable default. Hack if yours is different
	else {
		return "RANDOM()";
	}
}
1;
