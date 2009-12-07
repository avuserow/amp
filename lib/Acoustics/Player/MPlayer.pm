package Acoustics::Player::MPlayer;

use strict;
use warnings;

use Log::Log4perl ':easy';
use IPC::Open2 'open2';

sub start {
	my $class     = shift;
	my $acoustics = shift;


	my $pid = fork;
	if ($pid) {
		return;
	} elsif ($pid == 0) {
		$acoustics = $acoustics->reinit;
		daemonize();
		start_player($acoustics);
	} else {
		ERROR "fork failed: $!";
	}
}
use POSIX 'setsid';

sub daemonize {
	chdir '/'               or die "Can't chdir to /: $!";
	open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
	open STDOUT, '>/dev/null'
							or die "Can't write to /dev/null: $!";
	setsid                  or die "Can't start a new session: $!";
	open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
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

	if($volume > 100)
	{
		$volume = 100;
	}

	$volume *= .7;

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

	$acoustics->remove_player;
	$acoustics->add_player({
		local_id => $$,
		volume   => 50,
	});

	$SIG{TERM} = $SIG{INT} = sub {
		WARN "Exiting player $$";
		$acoustics->remove_player;
		exit;
	};
	$SIG{HUP}  = 'IGNORE';
	$SIG{CHLD} = 'IGNORE';
	$SIG{USR1} = 'IGNORE';
	$SIG{USR2} = 'IGNORE';

	while (1) {
		player_loop($acoustics);
	}
}

sub player_loop {
	my $acoustics = shift;
	my $song = $acoustics->get_current_song;
	($song)  = $acoustics->get_song({}, 'RAND()', 1) unless $song;
	my %data = %$song;

	if(-e $data{path})
	{
		$acoustics->add_playhistory(\%data);
		$acoustics->update_player({song_id => $data{song_id}});
		INFO "Playing '$data{path}'";
		INFO "$data{title} by $data{artist} from $data{album}";

		my($player) = $acoustics->get_player({
			player_id => $acoustics->player_id,
		});

		# General plan: open both input and output of the mplayer process
		# then continually read from input so we know it's still running
		# and handle SIGHUP. don't use waitpid because it blocks SIGHUP.
		my $pid = open2(my $child_out, my $child_in,
			'mplayer', '-slave', '-quiet', '-af' => 'volnorm=2:0.25', # volnorm=2:0.25 does multipass volume normalization with 0.25 amplitude adjustment
			$data{path})
			or LOGDIE "couldn't open mplayer: $!";

		# when we get SIGHUP, ask mplayer to quit
		local $SIG{HUP} = sub {
			WARN "skipping song: $data{path}!";
			print $child_in "quit\n";
			return;
		};

		local $SIG{USR1} = sub {
			WARN "changing volume";
			my($player) = $acoustics->get_player({
				player_id => $acoustics->player_id,
			});
			print $child_in "volume $player->{volume} 1\n";
			print $child_in "get_volume\n";
		};

		local $SIG{__DIE__} = local $SIG{TERM} = local $SIG{INT} = sub {
			WARN "Exiting player $$";
			print $child_in "quit\n";
			$acoustics->remove_player;
			exit;
		};

		# loop until mplayer ends
		while (<$child_out>) {}

		close $child_out; close $child_in;
	}
	else
	{
		ERROR "Song '$data{path}' is invalid, deleting";
		$acoustics->delete_song({song_id => $data{song_id}});
	}

	push @{$acoustics->voter_order}, shift @{$acoustics->voter_order};
	$acoustics->delete_vote({song_id => $data{song_id}});
}

1;
