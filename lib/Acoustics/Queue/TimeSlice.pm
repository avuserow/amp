package Acoustics::Queue::TimeSlice;

use strict;
use warnings;

use List::Util 'reduce';
use List::MoreUtils 'uniq';
use Mouse;
use v5.010;

extends 'Acoustics::Queue', 'Mouse::Object';
has 'acoustics' => (is => 'ro', isa => 'Acoustics');
has 'debt'      => (is => 'rw', isa => 'HashRef[Item]', default => sub {{}});

sub list {
	my $self      = shift;
	my $acoustics = $self->acoustics;

	my %votes = $acoustics->get_songs_by_votes;

	# remove the current song
	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	delete $votes{$player->{song_id}};

	# get a copy of the current debt and a list of the voters
	my %debt = %{$self->debt};
	my @who  = uniq map {@{$_->{who}}} values %votes;

	# add 0 debts for anyone not present to avoid warnings
	$debt{$_} ||= 0 for @who;

	# debug if we're running the player
	if ($0 =~ /player-remote\.pl/) {
		use Data::Dumper;
		print Dumper(\%debt);
		print "\n";
	}
	my @playlist;
	while (keys %votes) {
		# find the next song for every voter by priority
		my %next_songs;
		for my $who (@who) {
			$next_songs{$who} = reduce {
				$a->{priority} < $b->{priority} ? $a : $b
			} grep {$who ~~ $_->{who}} values %votes;
		}


		# now find the person that will have the most credit left over after
		# we play their next song
		my $best_choice = reduce {
				$debt{$a} < $debt{$b} ? $a : $b
		} @who;
		

		# use up this vote and remove it from the votes hash
		my $song = delete $votes{$next_songs{$best_choice}{song_id}};
		push @playlist, $song;

		@who = uniq map {@{$_->{who}}} values %votes;
		# give everyone else with remaining votes 1/nth of this song's length
		#
		if(@{$song->{who}} != @who)
		{
			$debt{$_} += int($song->{length} / @{$song->{who}}) for @{$song->{who}};

			my @payees = grep {not $_ ~~ @{$song->{who}}} @who;
			for (@payees)
			{
				$debt{$_} -= int($song->{length} / @payees);
			}
		}

	}

	return @playlist;
}

sub song_start {
	my $self = shift;
	my $song = shift;

	my $debt = $self->debt;

	my @voters = $self->acoustics->get_voters_by_time;

	return if @voters == @{$song->{who} || []};

	for (@{$song->{who}}) {
		$debt->{$_} ||= 0;
		$debt->{$_} += ($song->{length} / @{$song->{who}});
	}

	my @who = grep {not $_ ~~ @{$song->{who}}} @voters;
	for (@who) {
		$debt->{$_} -= int($song->{length} / @who);
	}

	$self->debt($debt);
}

sub song_stop {
	my $self = shift;
	my $song = shift;
	my $debt = $self->debt;

	my %votes = $self->acoustics->get_songs_by_votes;
	my %participants = map {$_ => 1} map {@{$_->{who}}} values %votes;

	my $cost =0;

	for(keys(%{$debt}))
	{
		unless($participants{$_}){
			if (abs($debt->{$_}) < $song->{length}){
				$cost += delete $debt->{$_};
			}
			else {
				$cost += $song->{length};
				$debt->{$_} += $song->{length} * ($debt->{$_} > 0 ? -1 : 1);
			}
		}
	}

	my $size = keys %{$debt};
	for(keys(%{$debt}))
	{
		$debt->{$_} += $cost / $size;
	}

	$self->debt($debt);
}

sub serialize {
	my $self = shift;
	return $self->debt;
}

sub deserialize {
	my $self = shift;
	my $data = shift;

	if (ref $data eq 'HASH') {
		$self->debt($data);
	}
}

1;
