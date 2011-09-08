package Acoustics::Player;

use strict;
use warnings;

use Moose::Role;

=head2 PLAYER FUNCTIONS

Things the player ought to be able to do:

start - make new player object, begin playing loop; store in DB (current process becomes the player daemon)
stop - stop playing; delete player in DB
skip - skip current song
volume - get/set volume if supported
pause - pause if supported

=cut

use constant COMPONENT => 'player';
$SIG{__DIE__} = sub {
	# we're toast! :(
	require Carp;
	open my $fh, '>>', '/tmp/acoustics-panic.log';
	print $fh Carp::longmess(@_);
	close $fh;
};
requires 'start';
around 'start' => sub {
	my $method = shift;
	my $class = shift;
	my $acoustics = shift;
	my $daemonize = shift;

	$acoustics = $daemonize ? daemonize($acoustics) : disassociate($acoustics);

	$acoustics->query('insert_players', {
		player_id => $acoustics->player_id,
		local_id  => $$,
		volume    => $acoustics->config->{player}{default_volume} || 0,
	});

	$method->($acoustics);

	$acoustics->query('delete_players', {player_id => $acoustics->player_id});
};

requires 'stop';
requires 'skip';

sub zap {
	my $class = shift;
	my $acoustics = shift;
	# TODO: try to stop the player and see if it responds
	$acoustics->query('delete_players', {player_id => $acoustics->player_id});
	return 0;
}

=head2 PLAYER HELPER METHODS / CALLBACKS

Common things that the player wants to have us help with with (helper methods)

daemonize - fork
disassociate - reopen filehandles

get_song_to_play - returns the song to play now and updates database/extensions
finish_song($reason) - handles a song ending either via skip, player stop, or
	natural end of song. updates history, etc

=cut

use POSIX 'setsid';
sub daemonize {
	my $acoustics = shift;
	my $pid = fork;
	if ($pid) {
		exit;
	} elsif ($pid != 0) {
		die "fork failed: $!";
	}

	$acoustics = disassociate($acoustics);
	setsid or die "Can't start a new session: $!";
	return $acoustics;
}

sub disassociate {
	my $acoustics = shift;
	$acoustics = $acoustics->reinit;
	open STDIN, '<', '/dev/null' or die "Can't reopen STDIN as /dev/null: $!";
	open STDOUT, '>', '/dev/null'
		or die "Can't reopen STDOUT as /dev/null: $!";
	open STDERR, '>&', 'STDOUT' or die "Can't dup STDERR to STDOUT: $!";
	#open STDERR, '>>', '/tmp/acoustics-panic.log' or die "Couldn't reopen STDERR: $!";
	return $acoustics;
}

sub get_song_to_play {
	my $acoustics = shift;
	my $song;
	while (!$song) {
		$song = $acoustics->get_current_song;
		$song ||= $acoustics->query('select_songs', {online => 1},
			$acoustics->rand, 1);

		unless (-e $song->{path}) {
			# blah blah blah, set it offline or something if we want
			# loop again
			undef $song;
		}
	}

	return $song;
}

sub begin_song {
	my $acoustics = shift;
	my $song = shift;

	$acoustics->queue->song_start($song);
	my $queue_hint = $acoustics->queue->serialize;
	$acoustics->query('update_players',
		{
			song_id    => $song->{song_id},
			song_start => time,
			queue_hint => scalar $acoustics->to_json($queue_hint),
		},
		{player_id => $acoustics->player_id});

	my $player = $acoustics->query('select_players',
		{player_id => $acoustics->player_id});
	$acoustics->ext_hook(COMPONENT, 'song_start',
		{player => $player, song => $song});
}

sub finish_song {
	my $acoustics = shift;
	my $reason = shift;
	my $song = shift;

	my $player = $acoustics->query('select_players',
		{player_id => $acoustics->player_id});

	# add the votes to the history
	my @votes = $acoustics->query('select_votes',
		{song_id => $song->{song_id}});
	@votes = (undef) unless @votes; # random song
	for my $vote (@votes) {
		$acoustics->query('insert_history', {
			song_id   => $song->{song_id},
			who       => $vote->{who},
			time      => $player->{song_start},
			player_id => $acoustics->player_id,
		});
	}

	# player turned off
	if ($reason eq 'stop') {
		$acoustics->ext_hook(COMPONENT, 'stop',
			{player => $player, song => $song});
		$acoustics->query('delete_players',
			{player_id => $player->{player_id}});
	} else {
		# just a song change

		if ($reason eq 'complete') {
			$acoustics->ext_hook(COMPONENT, 'song_stop',
				{player => $player, song => $song});
		} elsif ($reason eq 'skip') {
			$acoustics->ext_hook(COMPONENT, 'song_skip',
				{player => $player, song => $song});
		} else {
			die "Acoustics::Player::finish_song: invalid reason: $reason";
		}

		$acoustics->queue->song_stop($song);
		$acoustics->query(delete_votes => {song_id => $song->{song_id}});
	}
}

1;
