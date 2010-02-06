package Acoustics::Player::MPlayer;

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
		open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
		open STDOUT, '>/dev/null'
			or die "Can't write to /dev/null: $!";
		setsid                  or die "Can't start a new session: $!";
		#open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
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

sub volume {
	my $class     = shift;
	my $acoustics = shift;
	my $volume    = shift;

	if ($volume !~ /^\d+$/) {
		ERROR "volume must be a number, not something like '$volume'";
		return;
	}

	$acoustics->update_player({volume => $volume});
	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	$class->send_signal($acoustics, 'USR1');
}

sub send_signal {
	my $class     = shift;
	my $acoustics = shift;
	my $signal    = shift;
	my($player)   = $acoustics->get_player({player_id => $acoustics->player_id});

	my $success   = kill $signal => $player->{local_id};

	if ($success) {
		INFO "Sent $signal to $player->{local_id}";
	} else {
		ERROR "Sending $signal to $player->{local_id} failed: $!";
	}

	return $success;
}

sub start_player {
	my $acoustics = shift;

#	$acoustics->remove_player;
	$acoustics->add_player({
		local_id => $$,
		volume   => -1,
	});

	local $SIG{TERM} = local $SIG{INT} = sub {
		WARN "Exiting player $$";
		$acoustics->remove_player;
		exit;
	};
	local $SIG{HUP}  = 'IGNORE';
	local $SIG{CHLD} = 'IGNORE';
	local $SIG{USR1} = 'IGNORE';
	local $SIG{USR2} = 'IGNORE';

	$acoustics->plugin_call('player', 'start_player'); # load the plugins

	$acoustics->get_current_song; # populate the playlist

	while (1) {
		player_loop($acoustics);
	}
}

sub player_loop {
	my $acoustics = shift;
	my $song = $acoustics->get_current_song;
	($song)  = $acoustics->get_song({online => 1}, $acoustics->rand, 1) unless $song;

	my $song_start_time = time;
	my $skipped         = 0;
	if(-e $song->{path})
	{
		$acoustics->queue->song_start($song);
		my $queue_hint = $acoustics->queue->serialize;
		$acoustics->update_player({
			song_id    => $song->{song_id},
			song_start => $song_start_time,
			queue_hint => scalar JSON::DWIW->new->to_json($queue_hint),
		});
		INFO "Playing '$song->{path}'";
		INFO "$song->{title} by $song->{artist} from $song->{album}";

		my($player) = $acoustics->get_player({
			player_id => $acoustics->player_id,
		});
		$player->{volume} ||= -1;

		# General plan: open both input and output of the mplayer process
		# then continually read from input so we know it's still running
		# and handle SIGHUP. don't use waitpid because it blocks SIGHUP.
		my $pid = open2(my $child_out, my $child_in,
			'mplayer', '-slave', '-quiet',
			'-af' => 'volnorm=2:0.10',
			#'-volume' => $player->{volume},
			$song->{path})
			or LOGDIE "couldn't open mplayer: $!";

		# when we get SIGHUP, ask mplayer to quit
		local $SIG{HUP} = sub {
			WARN "skipping song: $song->{path}!";
			print $child_in "quit\n";
			$acoustics->delete_vote({song_id => $song->{song_id}});
			$skipped = 1;
			return;
		};

		local $SIG{USR1} = sub {
			WARN "changing volume to $player->{volume}";
			my($player) = $acoustics->get_player({
				player_id => $acoustics->player_id,
			});
			$player->{volume}  = 100 if $player->{volume} > 100;
			$player->{volume} *= .7;
			print $child_in "volume $player->{volume} 1\n";
			print $child_in "get_volume\n";
		};

		local $SIG{__DIE__} = local $SIG{TERM} = local $SIG{INT} = sub {
			WARN "Exiting player $$";
			print $child_in "quit\n";
			$acoustics->remove_player;
			exit;
		};

		$acoustics->plugin_call('player', 'start_song', $player, $song);

		# loop until mplayer ends
		while (<$child_out>) {}

		close $child_out; close $child_in;

		my $event = $skipped ? 'skip_song' : 'stop_song';
		$acoustics->plugin_call('player', $event, $player, $song);
	}
	else
	{
		ERROR "Song '$song->{path}' is invalid, (not yet) deleting";
		#$acoustics->delete_song({song_id => $song->{song_id}});
	}

	# Get the votes and log them. Use undef if Acoustics itself chose it.
	my @votes = $acoustics->get_votes_for_song($song->{song_id});
	@votes    = (undef) unless @votes;
	for my $vote ($acoustics->get_votes_for_song($song->{song_id})) {
		$acoustics->add_playhistory({
			song_id   => $song->{song_id},
			who       => $vote->{who},
			time      => $song_start_time,
			player_id => $acoustics->player_id,
		});
	}

	# Go to the next voter, and remove votes for this song
	$acoustics->queue->song_stop($song);
	$acoustics->delete_vote({song_id => $song->{song_id}});
}

1;
