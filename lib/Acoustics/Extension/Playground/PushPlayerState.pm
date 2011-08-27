package Acoustics::Extension::Playground::PushPlayerState;

use strict;
use warnings;

# There is a reason this module is in the playground.
# It is DEFINITELY not ready
# but it shows something cool

use LWP::Simple 'get';

sub notify {
	get("http://localhost:5000/push");
}

sub player_song_start {
	notify();
}

sub player_song_stop {
	notify();
}

sub player_stop {
	notify();
}

sub player_song_skip {
	notify();
}

1;
