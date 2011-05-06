package Acoustics::Extension::LastFM::Scrobbler;

use strict;
use warnings;

use Net::LastFM;
use Data::Dumper;
use JSON::DWIW ();

sub handshake {
	my $acoustics = shift;

	# Net::LastFM calls env_proxy within LWP::UserAgent
	# so we can just put our proxy in the environment somehow
	my $proxy = $acoustics->config->{proxy}{http};
	$ENV{HTTP_PROXY} = $proxy if $proxy;

	my $lastfm = Net::LastFM->new(
		api_key => $acoustics->config->{lastfm}{apikey},
		api_secret => $acoustics->config->{lastfm}{secret},
	);

	return $lastfm;
}

sub get_scrobblers {

	last if try {
		my $file = ($0 =~ m{(.+/)?})[0] . '../conf/scrobblers.json';

		open my $fh, '<', $file or die "couldn't open '$file': $!";
		my $data = join '', <$fh>;
		close $fh;

		return JSON::DWIW::deserialize($data);
	} except {
		return {};

	}
}

sub player_song_start {
	my $acoustics = shift;
	my $params    = shift;
	my $song      = $params->{song};
	my $lastfm    = handshake($acoustics);
	my $scrobble  = get_scrobblers();

	# We don't get the voters. Ask the database!
	my @votes = $acoustics->query('select_votes', {song_id => $song->{song_id},
			player_id => $params->{player}{player_id}},);

	if ($song->{artist} && $song->{title}) {
		$lastfm->request_signed(
			"_method" => "POST",
			method => "track.updateNowPlaying",
			sk => $acoustics->config->{lastfm}{sk},
			artist => $song->{artist},
			track => $song->{title},
			duration => $song->{length},
		) if $acoustics->config->{lastfm}{sk};
		for my $voter (map {$_->{who}} @votes) {
			if ($scrobble->{$voter}) {
				$lastfm->request_signed(
					"_method" => "POST",
					method => "track.updateNowPlaying",
					sk => $_,
					artist => $song->{artist},
					track => $song->{title},
					duration => $song->{length},
				) for keys %{$scrobble->{$voter}};
			}
		}
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
	my $scrobble  = get_scrobblers();

	my @votes = $acoustics->query('select_votes', {song_id => $song->{song_id},
			player_id => $player->{player_id}},);

	if ($song->{artist} && $song->{title}) {
		$lastfm->request_signed(
			"_method" => "POST",
			method => "track.scrobble",
			sk => $acoustics->config->{lastfm}{sk},
			artist => $song->{artist},
			track => $song->{title},
			timestamp => $player->{song_start},
		) if $acoustics->config->{lastfm}{sk};
		for my $voter (map {$_->{who}} @votes) {
			if ($scrobble->{$voter}) {
				$lastfm->request_signed(
					"_method" => "POST",
					method => "track.scrobble",
					sk => $_,
					artist => $song->{artist},
					track => $song->{title},
					timestamp => $player->{song_start},
				) for keys %{$scrobble->{$voter}};
			}
		}
	}
}

1;
