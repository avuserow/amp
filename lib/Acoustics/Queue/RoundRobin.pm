package Acoustics::Queue::RoundRobin;

use strict;
use warnings;

use List::Util 'first';
use List::MoreUtils 'uniq';
use Mouse;

extends 'Acoustics::Queue', 'Mouse::Object';
has 'acoustics'   => (is => 'ro', isa => 'Acoustics');
has 'voter_order' => (is => 'rw', isa => 'Maybe[ArrayRef[Str]]', default => sub {[]});

sub _build_voter_order {
	my $self  = shift;
	my @votes = @_;
	my @who   = $self->acoustics->get_voters_by_time;
	my @order = @{$self->voter_order};

	# see if we need to build the order from the database or just fix it up
	if (@order == 0) {
		# get it from the database
		# first, see if we have a hint to load
		$self->voter_order(\@who);
		return @who;
	} else {
		# add any voters that we don't have listed to the end of the queue
		for my $who (@who) {
			push @order, $who unless first {$_ eq $who} @order;
		}

		# remove extra voters from the list
		my %lookup = map {$_ => 1} @who;
		return grep {$lookup{$_}} @order;
	}
}

sub list {
	my $self      = shift;
	my $acoustics = $self->acoustics;

	my %votes = $acoustics->get_songs_by_votes;
	my @voter_order = $self->_build_voter_order;

	# round-robin between voters, removing them from the temporary voter list
	# when all their songs are added to the playlist
	my @songs;
	while (@voter_order) {
		# pick the first voter
		my $voter = shift @voter_order;

		# find all songs matching this voter and sort by number of voters
		my @candidates = grep {
			grep {$_ eq $voter} @{$_->{who}}
		} values %votes;
		@candidates = reverse sort {@{$a->{who}} <=> @{$b->{who}}} reverse sort {$a->{priority}{$voter} <=> $b->{priority}{$voter}} @candidates;

		# if this user has no more stored votes, ignore them
		next unless @candidates;

		# grab the first candidate, remove it from the hash of votes
		push @songs, delete $votes{$candidates[0]{song_id}};

		# re-add the voter to the list since they probably have more songs
		push @voter_order, $voter;
	}

	return @songs;
}

sub song_stop {
	my $self  = shift;
	my @order = @{$self->voter_order};

	push @order, shift @order;
	$self->voter_order(\@order);
}

sub serialize {
	my $self = shift;
	return $self->voter_order;
}

sub deserialize {
	my $self = shift;
	my $data = shift;

	$self->voter_order($data) if ref $data eq 'ARRAY';
}

1;
