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
	$data->{playlist}      = [$acoustics->get_playlist()];
	($data->{now_playing}) = $acoustics->get_song({song_id => $player->{song_id}});

	if ($data->{now_playing}) {
		$data->{now_playing}{who} = [map {$_->{who}} $acoustics->get_votes_for_song($player->{song_id})];
	}

	$data->{who} = Acoustics::Web::Auth::RemoteUser->whoami;
	$data->{can_skip} = can_skip($acoustics) ? JSON::DWIW::true : JSON::DWIW::false;
	$data->{is_admin} = Acoustics::Web::Auth::RemoteUser->is_admin ? JSON::DWIW::true : JSON::DWIW::false;
	return $data;
}

sub can_skip {
	my $acoustics = shift;
	my $who = Acoustics::Web::Auth::RemoteUser->whoami;
	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	my @voters = map {$_->{who}} $acoustics->get_votes_for_song($player->{song_id});
	my $voter_count = scalar @voters;
	my $voted = grep {$who eq $_} @voters;
	return 0 unless ($who);
	return 1 if (Acoustics::Web::Auth::RemoteUser->is_admin);
	return 1 if ($voted && $voter_count == 1);
	return 1 if ($voter_count == 0);
	return 0;
}

sub access_denied {
	my $q   = shift;
	my $msg = shift;

	print $q->header(-status => '403 Forbidden');
	print $msg;
	next REQUEST_LOOP;
}

sub bad_request {
	my $q   = shift;
	my $msg = shift;

	print $q->header(-status => '400 Bad Request');
	print $msg;
	next REQUEST_LOOP;
}

my $req = FCGI::Request();

REQUEST_LOOP: while ($req->Accept() >= 0) {
	my $q = CGI::Simple->new;
	$q->no_cache(1);
	binmode STDOUT, ':utf8';

	my $acoustics = Acoustics->new({config_file => 'conf/acoustics.ini'});

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
		my @history;
		for my $song ($acoustics->get_history($amount)) {
			if ($history[-1] && $history[-1]{time} == $song->{time}) {
				push @{$history[-1]{who}}, $song->{who};
			} else {
				$song->{who} = [$song->{who}];
				push @history, $song;
			}
		}
		$data = \@history;
	}
	elsif ($mode eq 'vote') {
		access_denied($q, 'You must log in.') unless $who;

		my(@song_ids) = $q->param('song_id');
		bad_request($q, 'No songs specified.') unless @song_ids;

		$acoustics->vote($_, $who) for @song_ids;
		$data = generate_player_state($acoustics);
	}
	elsif ($mode eq 'unvote') {
		access_denied($q, 'You must log in.') unless $who;
		my(@song_ids) = $q->param('song_id');
		my $purge_user = $q->param('purge');
		if (@song_ids && $song_ids[0]) {
			$acoustics->delete_vote({
				song_id => $_,
				who     => $who,
			}) for @song_ids;
		} elsif (Acoustics::Web::Auth::RemoteUser->is_admin && $purge_user) {
			$acoustics->delete_vote({who => $purge_user});
		} else {
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
	elsif ($mode eq 'volume') {
		access_denied($q, 'You must log in.') unless $who;
		my $vol = $q->param('value');
		bad_request($q, 'No songs specified.') unless $vol;
		$acoustics->rpc('volume', $vol);
		$data = generate_player_state($acoustics);
	}
	elsif ($mode =~ /^(start|stop|skip)$/) {
		access_denied($q, 'You must log in.') unless $who;

		if ($mode eq 'skip') {
			$acoustics->rpc($mode) if can_skip($acoustics);
		} else {
			$acoustics->rpc($mode);
		}
		sleep 0.25;

		$data = generate_player_state($acoustics);
	} else {
		$data = generate_player_state($acoustics);
	}

	print $q->header(
		-type     => 'application/json',
	);
	print JSON::DWIW->new({
		pretty            => 1,
		escape_multi_byte => 1,
		bad_char_policy   => 'convert',
	})->to_json($data);
} continue {
	$req->Finish();
	exit if -M $ENV{SCRIPT_FILENAME} < 0; # Autorestart
}
