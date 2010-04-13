use Test::More tests => 3;

use strict;
use warnings;

use Acoustics;
use Acoustics::Queue::TimeSlice;

my $ac = Acoustics->new;
# specify the queue engine manually
$ac->{queue} = Acoustics::Queue::TimeSlice->new({acoustics => $ac});

# make a random player id
$ac->{player_id} = 'timeslice.t:' . rand();

# simulate round-robin for two voters
{
	# get some fake songs
	my @songs = $ac->test(create_fake_songs => 4);

	# rig the song lengths
	my $i = 1;
	for my $song (@songs) {
		$song->{length} = 10 * $i++ ** 2; # 10, 40, 90, 160
		$ac->query('update_songs', $song, {song_id => $song->{song_id}});
	}

	my @voters = map {$_ . rand()} qw(test1_ test2_);

	$ac->vote($_->{song_id}, $voters[0]) for @songs[0, 1];
	$_->{who} = [$voters[0]] for @songs[0, 1]; # add in the who
	$ac->vote($_->{song_id}, $voters[1]) for @songs[2, 3];
	$_->{who} = [$voters[1]] for @songs[2, 3]; # add in the who

	$ac->test('cmp_songs',
		[$ac->get_playlist], [@songs[0,2,1,3]], 'simple timeslice queue');

	# serialize/deserialize test
	my $hint = $ac->queue->serialize;

	my $new_ac = Acoustics->new;
	$new_ac->queue->deserialize($hint);

	# specify the queue engine manually
	$new_ac->{queue} = Acoustics::Queue::TimeSlice->new({acoustics => $new_ac});
	$new_ac->{player_id} = $ac->player_id;

	$new_ac->test('cmp_songs',
		[$new_ac->get_playlist], [@songs[0,2,1,3]],
		'timeslice serialize/deserialize');

	# now "play" the first song and see if it is still correct
	$ac->queue->song_start($songs[0]);
	$ac->queue->song_stop($songs[0]);
	$ac->query(delete_votes => {song_id => $songs[0]{song_id}});
	my @queue = $ac->get_playlist;
	$ac->test('cmp_songs',
		[$ac->get_playlist], [@songs[2,1,3]], 'simple timeslice queue 2');
}
