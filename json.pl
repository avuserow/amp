#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';
use Acoustics;
use Acoustics::Web::Auth::RemoteUser;
use FCGI;
use CGI::Simple;
use CGI::Carp 'fatalsToBrowser';
use JSON::DWIW ();
use Time::HiRes 'sleep';

sub generate_player_state {
	my $acoustics = shift;
	my $data = {};
	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	$data->{player} = $player;

	my($song) = $acoustics->get_song({song_id => $player->{song_id}});
	$data->{nowPlaying} = $song;
	$data->{playlist}   = [$acoustics->get_playlist()];
	$data->{who}        = Acoustics::Web::Auth::RemoteUser->whoami;
	return $data;
}

my $req = FCGI::Request();

while ($req->Accept() >= 0) {
	my $q = CGI::Simple->new;
	my $acoustics = Acoustics->new({config_file => 'lib/acoustics.ini'});

	my $who = Acoustics::Web::Auth::RemoteUser->whoami;

	my $mode = $q->param('mode') || '';
	my $data;

	if ($mode eq 'random') {
		my $amount = $q->param('amount') || 20;
		$data = [$acoustics->get_song({}, 'RAND()', $amount)];
	} elsif ($mode eq 'recent') {
		my $amount = $q->param('amount') || 50;
		$data = [$acoustics->get_song({}, {'-DESC' => 'song_id'}, $amount)];
	} elsif ($mode eq 'vote') {

		my $song_id = $q->param('song_id');
		if ($song_id && $who) {
			$acoustics->vote($song_id, $who);
		}
	}
	elsif ($mode eq 'unvote') {
		my $song_id = $q->param('song_id');
		if ($song_id && $who) {
			$acoustics->delete_vote({
				song_id => $song_id,
				who     => $who,
			});
		} elsif($who) {
			$acoustics->delete_vote({who => $who});
		}
	}
	elsif($mode eq 'browse')
	{
		my $field = $q->param('field');
		$data = [$acoustics->browse_songs_by_column($field, $field)];
	}
	elsif(($mode eq 'search' || $mode eq 'select')
		&& $q->param('field') =~ /^(any|artist|album|title|path|song_id)$/) {

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
		$data = generate_player_state($acoustics);
	}
	elsif ($mode =~ /^(start|stop|skip)$/) {
		$acoustics->rpc($mode);
		sleep 0.25;

		$data = generate_player_state($acoustics);
	} else {
		$data = generate_player_state($acoustics);
	}

	binmode STDOUT, ':utf8';
	print $q->header(
		-type     => 'application/json',
	);
	print JSON::DWIW->to_json($data);
}
