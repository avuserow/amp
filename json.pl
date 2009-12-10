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

	# FIXME: there should be a better way to do this
	$data->{playlist}     = [$acoustics->get_playlist()];
	($data->{nowPlaying}) = $acoustics->get_song({song_id => $player->{song_id}});
	$data->{nowPlaying}{who} = [map {$_->{who}} $acoustics->get_votes_for_song($player->{song_id})];

	$data->{who} = Acoustics::Web::Auth::RemoteUser->whoami;
	$data->{canSkip} = can_skip($acoustics) ? JSON::DWIW::true : JSON::DWIW::false;
	return $data;
}

sub can_skip {
	my $acoustics = shift;

	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	my $player_count = scalar $acoustics->get_votes_for_song($player->{song_id});

	return Acoustics::Web::Auth::RemoteUser->whoami && $player_count == 0;
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
	} 
	elsif($mode eq 'history')
	{
		my $amount = $q->param('amount') || 25;
		$data = [$acoustics->get_history($amount)];
	}
	elsif ($mode eq 'vote') {

		my $song_id = $q->param('song_id');
		if ($song_id && $who) {
			$acoustics->vote($song_id, $who);
		}
		$data = generate_player_state($acoustics);
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
		$data = generate_player_state($acoustics);
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
	elsif ($mode eq 'votes')
	{
		my $song_id = $q->param('song_id');
		if($song_id)
		{
			$data = [$acoustics->get_votes_for_song($song_id)];
		}
		else
		{
			$data = generate_player_state($acoustics);
		}
	}
	elsif ($mode eq 'volume') {
		my $vol = $q->param('value');
		$acoustics->rpc('volume', $vol) if $who;
		$data = generate_player_state($acoustics);
	}
	elsif ($mode =~ /^(start|stop|skip)$/) {
		# FIXME: there should be a better way to do this
		if ($mode eq 'skip') {
			if (can_skip($acoustics))
			{
				$acoustics->rpc($mode) if $who;
			}
		} else {
			$acoustics->rpc($mode) if $who;
		}
		sleep 0.25;

		$data = generate_player_state($acoustics);
	} else {
		$data = generate_player_state($acoustics);
	}

	binmode STDOUT, ':utf8';
	$q->no_cache(1);
	print $q->header(
		-type     => 'application/json',
	);
	print JSON::DWIW->new({
		pretty            => 1,
		escape_multi_byte => 1,
		bad_char_policy   => 'convert',
	})->to_json($data);

	$req->Finish();
	exit if -M $ENV{SCRIPT_FILENAME} < 0; # Autorestart
}
