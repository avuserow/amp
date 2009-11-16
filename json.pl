#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';
use Acoustics;
use CGI::Simple;
use CGI::Carp 'fatalsToBrowser';
use JSON::DWIW ();
use Time::HiRes 'sleep';

my $acoustics = Acoustics->new({config_file => 'lib/acoustics.ini'});
my $q = CGI::Simple->new;

my $mode = $q->param('mode');
my $data;
if ($mode eq 'random') {
	$data = [$acoustics->get_song({}, 'RANDOM()', 10)];
} elsif ($mode eq 'vote') {
	my $song_id = $q->param('song_id');
	if ($song_id) {
		$acoustics->vote($song_id, 'test');
	}
} elsif ($mode) {
	$acoustics->rpc($mode);
	sleep 0.25;

	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	($data)     = $acoustics->get_song({song_id => $player->{song_id}});
} else {
	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	($data)     = $acoustics->get_song({song_id => $player->{song_id}});
}

print $q->header('application/json');
print JSON::DWIW->to_json($data);
