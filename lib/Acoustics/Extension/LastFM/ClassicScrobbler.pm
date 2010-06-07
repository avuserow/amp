package Acoustics::Extension::LastFM::ClassicScrobbler;

use strict;
use warnings;

use Net::LastFM::Submission;
use Data::Dumper;
use LWP::UserAgent;
use Log::Log4perl ':easy';

sub handshake {
	my $acoustics = shift;

	my $ua = LWP::UserAgent->new;
	my $proxy = $acoustics->config->{proxy}{http};
	$ua->proxy('http' => $proxy) if $proxy;

	my $submit = Net::LastFM::Submission->new(
		user     => $acoustics->config->{lastfm}{user},
		password => $acoustics->config->{lastfm}{pass},
		ua       => $ua,
	);
	my $status = $submit->handshake;
	die Dumper($status) unless $status->{status} eq 'OK';

	return $submit;
}

sub player_song_start {
	my $acoustics = shift;
	my $params    = shift;
	my $song      = $params->{song};
	my $submit    = handshake($acoustics);

	if ($song->{artist} && $song->{title}) {
		my $status = $submit->now_playing(
			artist => $song->{artist},
			title  => $song->{title},
			length => $song->{length},
		);
		die Dumper($status) unless $status->{status} eq 'OK';
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
	my $submit    = handshake($acoustics);

	if ($song->{artist} && $song->{title}) {
		my $status = $submit->submit(
			artist => $song->{artist},
			title  => $song->{title},
			time   => $player->{song_start},
		);
		die Dumper($status) unless $status->{status} eq 'OK';
	}
}

1;
