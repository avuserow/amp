use Test::More tests => 3;

use strict;
use warnings;

use Acoustics;
use Acoustics::Queue::RoundRobin;

my $ac = Acoustics->new;
# specify the queue engine manually
$ac->{queue} = Acoustics::Queue::RoundRobin->new({acoustics => $ac});

# make a random player id
$ac->{player_id} = 'roundrobin.t:' . rand();

# simulate round-robin for two voters
{
	# get some fake songs
	my @songs = $ac->test(create_fake_songs => 4);

	my @voters = map {$_ . rand()} qw(test1_ test2_);

	$ac->vote($_->{song_id}, $voters[0]) for @songs[0, 1];
	$ac->vote($_->{song_id}, $voters[1]) for @songs[2, 3];

	$ac->test('cmp_songs',
		[$ac->get_playlist], [@songs[0,2,1,3]], 'simple roundrobin queue');

	# serialize/deserialize test
	my $hint = $ac->queue->serialize;

	my $new_ac = Acoustics->new;
	$new_ac->queue->deserialize($hint);

	# specify the queue engine manually
	$new_ac->{queue} = Acoustics::Queue::RoundRobin->new({acoustics => $new_ac});
	$new_ac->{player_id} = $ac->player_id;

	$new_ac->test('cmp_songs',
		[$new_ac->get_playlist], [@songs[0,2,1,3]], 'serialize/deserialize');

	# now "play" the first song and see if it is still correct
	$ac->queue->song_stop;
	$ac->query(delete_votes => {song_id => $songs[0]{song_id}});
	my @queue = $ac->get_playlist;
	$ac->test('cmp_songs',
		[$ac->get_playlist], [@songs[2,1,3]], 'simple roundrobin queue');
}
