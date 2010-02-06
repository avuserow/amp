package Acoustics::Queue::TimeSlice;

use strict;
use warnings;

use List::Util 'reduce';
use List::MoreUtils 'uniq';
use Mouse;

extends 'Acoustics::Queue', 'Mouse::Object';
has 'acoustics' => (is => 'ro', isa => 'Acoustics');
has 'debt'      => (is => 'rw', isa => 'HashRef[Item]', default => sub {{}});

sub list {
	use integer;
	my $self      = shift;
	my $acoustics = $self->acoustics;

	my %votes = $acoustics->get_songs_by_votes;

	my %debt = %{$self->debt};
	my @who  = uniq map {@{$_->{who}}} values %votes;

	$debt{$_} ||= 0 for @who;

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
			$debt{$a} + $next_songs{$a}{length} <
			$debt{$b} + $next_songs{$b}{length} ? $a : $b
		} @who;

		# use up this vote and remove it from the votes hash
		my $song = delete $votes{$next_songs{$best_choice}{song_id}};
		push @playlist, $song;

		# give everyone else with remaining votes 1/nth of this song's length
		$debt{$_} += ($song->{length} / @{$song->{who}}) for @{$song->{who}};
		@who = uniq map {@{$_->{who}}} values %votes;

		my @payees = grep {$_ ~~ @{$song->{who}}} keys(%debt);
		for (@payees)
		{
			$debt{$_} -= ($song->{length} / @payees);
	}

	}

	return @playlist;
}

sub song_start {
	use integer;
	my $self = shift;
	my $song = shift;

	my $debt = $self->debt;

	for (@{$song->{who}}) {
		$debt->{$_} ||= 0;
		$debt->{$_} += ($song->{length} / @{$song->{who}});
	}
	
	my @who = grep {$_ ~~ @{$song->{who}}} keys(%{$debt});
	for (@who) {
		$debt->{$_} -= ($song->{length} / @who);
	}

	$self->debt($debt);
}

sub song_stop {
	use integer;
	my $self = shift;
	
	my $debt = $self->debt;

	my %votes = $self->acoustics->get_songs_by_votes;
	my %participants = map {$_ => 1} map {@{$_->{who}}} values %votes;

	my $cost =0;

	for(keys(%{$debt}))
	{
		$cost += delete $debt->{$_} unless($participants{$_});
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
