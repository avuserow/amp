package Acoustics;

use strict;
use warnings;

use Acoustics::Database;
use Mouse;
use Module::Load 'load';
use DBI;
use Log::Log4perl;
use Date::Parse 'str2time';
use Config::Tiny;
use Try::Tiny;

has 'db' => (is => 'ro', isa => 'DBI', handles => [qw(begin_work commit)]);
has 'config' => (is => 'ro', isa => 'Config::Tiny');
has 'querybook' => (is => 'ro', handles => ['query']);
has 'config_file' => (is => 'ro', isa => 'Str');
has 'player_id' => (is => 'ro', isa => 'Str', default => 'default player');
has 'queue' => (is => 'ro', isa => 'Acoustics::Queue');

# Logger configuration:
# - Print out all INFO and above messages to the screen
# - Write out all WARN and above messages to a logfile
my $log4perl_conf = q(
log4perl.logger = INFO, Screen, Logfile
log4perl.logger.Acoustics.Web = INFO, Weblogfile

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

# INFO to Weblogfile
log4perl.appender.Weblogfile          = Log::Log4perl::Appender::File
log4perl.appender.Weblogfile.Filter   = MatchInfo
log4perl.appender.Weblogfile.filename = /tmp/acoustics.log
log4perl.appender.Weblogfile.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Weblogfile.layout.ConversionPattern = %p %d %F{1} %L> %m %n
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
	$self->{querybook} = Acoustics::Database->new(
		db => $self->{db},
		phrasebook => 'queries.txt',
	);

	my $queue_class = $self->config->{player}{queue} || 'RoundRobin';
	$queue_class    = 'Acoustics::Queue::' . $queue_class;
	load $queue_class;
	$self->{queue} = $queue_class->new({acoustics => $self});
}

# MySQL fails hard on selecting a random song. see:
# http://www.paperplanes.de/2008/4/24/mysql_nonos_order_by_rand.html
sub get_random_song {
	my $self  = shift;
	my $count = shift;
	return $self->query(
		'get_random_songs', {-limit => $count}, {random => $self->rand},
	);
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
		my $priority = delete $row->{priority};
		$votes{$row->{song_id}} ||= $row;
		$votes{$row->{song_id}}{priority}{$who} = $priority;
		push @{$votes{$row->{song_id}}{who}}, $who;
	}

	return %votes;
}

sub get_playlist {
	my $self = shift;
	my @playlist = $self->queue->list;

	my $player = $self->query('select_players', {player_id => $self->player_id});
	$player->{song_id} ||= 0;
	return grep {$player->{song_id} != $_->{song_id}} @playlist;
}

sub get_current_song {
	my $self = shift;
	my @playlist = $self->queue->list;
	return $playlist[0] if @playlist;
	return;
}

sub get_history {
	my $self   = shift;
	my $amount = shift;
	my $voter  = shift;

	my %where;
	$where{who} = $voter if $voter;
	my @times = $self->query(
		'get_time_from_history', {%where, -limit => $amount},
	);
	if (@times) {
		return $self->query(
			'get_history', \%where, {},
			{%where, time => $times[-1]{time}, player_id => $self->player_id},
		);
	}

	return;
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

sub dedupe
{
	my $self = shift;
	my @input = grep {$_->{title} ne ""} @_;

	my %songs = map { 
		join(' ', uc(join '', ($_->{title} =~ /\S+/g)),
		uc(join '', ($_->{artist} =~ /\S+/g)),
		uc(join '', ($_->{album} =~ /\S+/g)))
		=> $_
	} @input;


	return sort {$a->{album} cmp $b->{album}} (sort {$a->{track} <=> $b->{track}} (values %songs));
}

1;
