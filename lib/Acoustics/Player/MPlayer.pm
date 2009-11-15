package Acoustics::Player::MPlayer;

use strict;
use warnings;

use Log::Log4perl ':easy';

sub start {
	my $class     = shift;
	my $acoustics = shift;

	my $pid = fork;
	if ($pid) {
		return;
	} elsif ($pid == 0) {
		daemonize();
		system('/home/ak10/projects/acoustics/bin/player.pl');
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

1;
