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
		daemonize();
		$acoustics = $acoustics->reinit;
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

	$acoustics->add_player({local_id => $$});

	$SIG{TERM} = $SIG{INT} = sub {
		WARN "Exiting player $$";
		$acoustics->remove_player;
		exit;
	};
	$SIG{HUP}  = 'IGNORE';
	$SIG{CHLD} = 'IGNORE';

	while (1) {
		player_loop($acoustics);
	}
}

sub player_loop {
	my $acoustics = shift;
	my @songs = $acoustics->get_playlist;
	@songs    = $acoustics->get_song({}, 'RAND()', 1) unless @songs;
	my %data  = %{$songs[0]};

	$acoustics->delete_vote({song_id => $data{song_id}});

	if(-e $data{path})
	{
		$acoustics->add_playhistory(\%data);
		$acoustics->update_player({song_id => $data{song_id}});
		INFO "Playing '$data{path}'";
		INFO "$data{title} by $data{artist} from $data{album}";

		# General plan: open both input and output of the mplayer process
		# then continually read from input so we know it's still running
		# and handle SIGHUP. don't use waitpid because it blocks SIGHUP.
		my $pid = open2(my $child_out, my $child_in,
			'mplayer', '-slave', '-quiet', $data{path})
			or LOGDIE "couldn't open mplayer: $!";

		# when we get SIGHUP, ask mplayer to quit
		local $SIG{HUP} = sub {
			WARN "skipping song: $data{path}!";
			print $child_in "quit\n";
		};

		local $SIG{TERM} = $SIG{INT} = sub {
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
}

1;
