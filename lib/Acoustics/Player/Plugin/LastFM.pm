package Acoustics::Player::Plugin::LastFM;

use strict;
use warnings;

use Net::LastFM::Submission;
use Data::Dumper;
use Log::Log4perl ':easy';

my $submit;

sub start_player {
	my $acoustics = shift;

	$submit = Net::LastFM::Submission->new(
		user     => $acoustics->config->{lastfm}{user},
		password => $acoustics->config->{lastfm}{pass},
	);
	my $status = $submit->handshake;
	ERROR Dumper($status) unless $status->{status} eq 'OK';
}

sub start_song {
	my $acoustics = shift;
	my $player    = shift;
	my $song      = shift;

	if ($song->{artist} && $song->{title}) {
		my $status = $submit->now_playing(
			artist => $song->{artist},
			title  => $song->{title},
		);
		ERROR Dumper($status) unless $status->{status} eq 'OK';
	}
}

sub stop_song {
	my $acoustics = shift;
	my $player    = shift;
	my $song      = shift;

	if ($song->{artist} && $song->{title}) {
		my $status = $submit->submit(
			artist => $song->{artist},
			title  => $song->{title},
			time   => $player->{song_start},
		);
		ERROR Dumper($status) unless $status->{status} eq 'OK';
	}
}

1;
