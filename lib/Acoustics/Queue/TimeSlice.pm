package Acoustics::Queue::TimeSlice;

use strict;
use warnings;

use List::Util 'reduce';
use List::MoreUtils 'uniq';
use Mouse;

extends 'Acoustics::Queue', 'Mouse::Object';
has 'acoustics' => (is => 'ro', isa => 'Acoustics');
has 'debt'      => (is => 'rw', isa => 'HashRef[Int]', default => sub {{}});

sub list {
	my $self      = shift;
	my $acoustics = $self->acoustics;

	my %votes = $acoustics->get_songs_by_votes;

	my %debt = %{$self->debt};
	my @who  = uniq map {@{$_->{who}}} values %votes;

	$debt{$_} ||= 0 for @who;

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
			$debt{$a} + $next_songs{$a}{length} <
			$debt{$b} + $next_songs{$b}{length} ? $a : $b
		} @who;

		# use up this vote and remove it from the votes hash
		my $song = delete $votes{$next_songs{$best_choice}{song_id}};
		push @playlist, $song;

		# give everyone else with remaining votes 1/nth of this song's length
		$debt{$_} += $song->{length} / @{$song->{who}} for @{$song->{who}};
		@who = uniq map {@{$_->{who}}} values %votes;
	}

	return @playlist;
}

sub song_stop {
	my $self = shift;
	my $song = shift;

	for (@{$song->{who}}) {
		$self->debt->{$_} ||= 0;
		$self->debt->{$_} += $song->{length} / @{$song->{who}};
	}
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
