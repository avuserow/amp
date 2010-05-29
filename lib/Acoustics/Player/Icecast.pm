package Acoustics::Player::Icecast;

use strict;
use warnings;

use Log::Log4perl ':easy';
use IPC::Open2 'open2';
use Module::Load 'load';
use JSON::DWIW ();

sub start {
	my $class     = shift;
	my $acoustics = shift;
	my $daemonize = shift;

	# FIXME: If you daemonize, you end up in / as the pwd
	# and if you don't, your pwd does not change
	# (as well as STD{IN,OUT,ERR} being closed/open)
	if ($daemonize) {
		$acoustics = daemonize($acoustics);
	}
	start_player($acoustics);
}

use POSIX 'setsid';
sub daemonize {
	my $acoustics = shift;

	my $pid = fork;
	if ($pid) {
		exit;
	} elsif ($pid == 0) {
		$acoustics = $acoustics->reinit;
		# The below is probably not needed and makes things more complicated
		# regarding paths
		#chdir '/'               or die "Can't chdir to /: $!";
		open STDIN, '<', '/dev/null' or die "Can't read /dev/null: $!";
		open STDOUT, '>', '/dev/null'
			or die "Can't write to /dev/null: $!";
		setsid                  or die "Can't start a new session: $!";
		#open STDERR, '>&', 'STDOUT' or die "Can't dup stdout: $!";
		return $acoustics;
	} else {
		ERROR "fork failed: $!";
	}
}

sub skip {
	my $class     = shift;
	my $acoustics = shift;
	$class->send_signal($acoustics, 'HUP');
}

sub stop {
	my $class     = shift;
	my $acoustics = shift;
	$class->send_signal($acoustics, 'INT');
}

sub zap {
	my $class = shift;
	my $acoustics = shift;
	my $dead_player_id = shift;
	# Don't do stupid things
	unless ($dead_player_id){
		ERROR "Blank player_id";
	} else {
		# KILL IT WITH FIRE
		$acoustics->query('delete_players', {player_id => $dead_player_id});
		INFO "Zapped $dead_player_id";
	}
}

sub send_signal {
	my $class     = shift;
	my $acoustics = shift;
	my $signal    = shift;
	my $player = $acoustics->query(
		'select_players', {player_id => $acoustics->player_id},
	);

	my $success = kill $signal => $player->{local_id};

	if ($success) {
		INFO "Sent $signal to $player->{local_id}";
	} else {
		ERROR "Sending $signal to $player->{local_id} failed: $!";
	}

	return $success;
}

sub start_player {
	my $acoustics = shift;

	#$acoustics->query('delete_players', {player_id => $acoustics->player_id});
	$acoustics->query('insert_players', {
		player_id => $acoustics->player_id,
		local_id  => $$,
		volume    => -1,
	});

	local $SIG{HUP}  = 'IGNORE';
	local $SIG{CHLD} = 'IGNORE';
	local $SIG{USR1} = 'IGNORE';
	local $SIG{USR2} = 'IGNORE';

	$acoustics->get_current_song; # populate the playlist

	my $pid = open2(my $child_out, my $child_in,
		'ezstream', '-c', $acoustics->config->{player}{ezstreamconfig});

	my $exit = 0;
	local $SIG{__DIE__} = local $SIG{TERM} = local $SIG{INT} = sub {
		WARN "Exiting player $$";
		$exit = 1;
	};

	# routine called when the web interface wants us to skip a song. To do this,
	# we send SIGUSR1 to the stream source.
	local $SIG{HUP} = sub {
		WARN "skipping song!";
		kill USR1 => $pid;
		return;
	};

	# TODO: calling the plugin system in signal handlers sounds like a great way
	# to introduce a race condition. Need to think about how to handle plugins
	# with this, since it does not match the pattern of the typical
	# (MPlayer/VLC) model.

	sleep 1 until $exit;
	kill TERM => $pid;
	$acoustics->query('delete_players', {player_id => $acoustics->player_id});
}

sub song_iterate {
	my $class     = shift;
	my $acoustics = shift;

	# Go to the next voter, and remove votes for this song
	my $player = $acoustics->query('select_players',
		{player_id => $acoustics->player_id});

	if ($player->{song_id}) {
		my $song = $acoustics->query('select_songs',
			{song_id => $player->{song_id}});
		$acoustics->queue->song_stop($song);
		$acoustics->query(delete_votes => {song_id => $song->{song_id}});
	}

	my $song = $acoustics->get_current_song;
	$song = $acoustics->query('select_songs', {online => 1}, $acoustics->rand, 1) unless $song;

	$acoustics->queue->song_start($song);
	my $queue_hint = $acoustics->queue->serialize;
	$acoustics->query('update_players',
		{
			song_id    => $song->{song_id},
			song_start => time,
			queue_hint => scalar JSON::DWIW->new->to_json($queue_hint),
		},
		{player_id => $acoustics->player_id});

	print $song->{path};
}

1;
