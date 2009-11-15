package Acoustics::Player::MPlayer;

use strict;
use warnings;

use Log::Log4perl ':easy';
Log::Log4perl->easy_init($INFO);

sub skip {
	my $acoustics = shift;
	my($player)   = $acoustics->get_player({player_id => $acoustics->player_id});

	my $success = kill HUP => $player->{local_id};

	if ($success) {
		INFO "Skipped song $player->{song_id}";
	} else {
		ERROR "Skipping song failed: $!";
	}
}

sub stop {
	my $acoustics = shift;
	my($player)   = $acoustics->get_player({player_id => $acoustics->player_id});

	my $success = kill INT => $player->{local_id};

	if ($success) {
		INFO "Stopping player $player->{local_id}";
	} else {
		ERROR "Stopping player failed: $!";
	}
}

1;
