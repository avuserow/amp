package Acoustics::Extension::LastFM::Scrobbler;

use strict;
use warnings;

use Net::LastFM;
use Data::Dumper;
use LWP::UserAgent;
use Log::Log4perl ':easy';

sub handshake {
	my $acoustics = shift;

#	my $ua = LWP::UserAgent->new;
#	my $proxy = $acoustics->config->{proxy}{http};
#	$ua->proxy('http' => $proxy) if $proxy;

	# TODO: proxy

	my $lastfm = Net::LastFM->new(
		api_key => $acoustics->config->{lastfm}{apikey},
		api_secret => $acoustics->config->{lastfm}{secret},
	);

	return $lastfm;
}

sub player_song_start {
	my $acoustics = shift;
	my $params    = shift;
	my $song      = $params->{song};
	my $lastfm    = handshake($acoustics);

	if ($song->{artist} && $song->{title}) {
		$lastfm->request_signed(
			"_method" => "POST",
			method => "track.updateNowPlaying",
			sk => $acoustics->config->{lastfm}{sk},
			artist => $song->{artist},
			track => $song->{title},
			duration => $song->{length},
		);
	}
}

sub player_song_stop {
	my $acoustics = shift;
	my $params    = shift;
	scrobble_song($acoustics, $params->{player}, $params->{song});
}

sub player_stop {
	my $acoustics = shift;
	my $params    = shift;
	my $song      = $params->{song};
	if (time - $params->{player}{song_start} >= $song->{length} / 2) {
		scrobble_song($acoustics, $params->{player}, $song);
	}
}

sub player_song_skip {
	my $acoustics = shift;
	my $params    = shift;
	my $song      = $params->{song};
	if (time - $params->{player}{song_start} >= $song->{length} / 2) {
		scrobble_song($acoustics, $params->{player}, $song);
	}
}

sub scrobble_song {
	my $acoustics = shift;
	my $player    = shift;
	my $song      = shift;
	my $lastfm    = handshake($acoustics);

	if ($song->{artist} && $song->{title}) {
		$lastfm->request_signed(
			"_method" => "POST",
			method => "track.scrobble",
			sk => $acoustics->config->{lastfm}{sk},
			artist => $song->{artist},
			track => $song->{title},
			timestamp => $player->{song_start},
		);
	}
}

1;
