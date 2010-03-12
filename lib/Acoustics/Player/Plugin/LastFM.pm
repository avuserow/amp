package Acoustics::Player::Plugin::LastFM;

use strict;
use warnings;

use Net::LastFM::Submission;
use Data::Dumper;
use LWP::UserAgent;
use Log::Log4perl ':easy';

my $submit;

sub start_player {
	my $acoustics = shift;

	my $ua = LWP::UserAgent->new;
	my $proxy = $acoustics->config->{proxy}{http};
	$ua->proxy('http' => $proxy) if $proxy;

	$submit = Net::LastFM::Submission->new(
		user     => $acoustics->config->{lastfm}{user},
		password => $acoustics->config->{lastfm}{pass},
		ua       => $ua,
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
			length => $song->{length},
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
