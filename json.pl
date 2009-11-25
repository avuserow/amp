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
	$data = [$acoustics->get_song({}, 'RAND()', 10)];
} elsif ($mode eq 'vote') {
	my $song_id = $q->param('song_id');
	if ($song_id) {
		$acoustics->vote($song_id, $ENV{REMOTE_USER} || "test");
	}
}
elsif ($mode eq 'unvote') {
	my $song_id = $q->param('song_id');
	if ($song_id) {
		$acoustics->delete_vote({
			song_id => $song_id,
			who     => $ENV{REMOTE_USER} || "test",
		});
	} else {
		$acoustics->delete_vote({
			who => $ENV{REMOTE_USER} || "test",
		});
	}
}
elsif($mode eq 'playlist')
{
	$data = [$acoustics->get_playlist()];
}
elsif($mode eq 'browse')
{
	my $field = $q->param('field');
	$data = [$acoustics->browse_songs_by_column($field, $field)];
}
elsif($mode ~~ ['search', 'select']
	&& $q->param('field') ~~ [qw(any artist album title path song_id)]) {

	my $field = $q->param('field');
	my $value = $q->param('value');

	my $where;
	my $value_clause = $value;
	$value_clause    = {-like => "%$value%"} if $mode eq 'search';
	if ($field eq 'any') {
		$where = [map {{$_ => $value_clause}} qw(artist album title path)];
	} else {
		$where = {$field => $value_clause};
	}

	$data = [$acoustics->get_song($where, [qw(artist album track title)])];
}
elsif ($mode eq 'volume') {
	$acoustics->rpc('volume', $q->param('value'));
}
elsif ($mode ~~ [qw(start stop skip)]) {
	$acoustics->rpc($mode);
	sleep 0.25;

	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	($data)     = $acoustics->get_song({song_id => $player->{song_id}});
} else {
	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	($data)     = $acoustics->get_song({song_id => $player->{song_id}});
}

binmode STDOUT, ':utf8';
print $q->header(
	-type     => 'application/json',
);
print JSON::DWIW->to_json($data);
