package Acoustics::Test;

use strict;
use warnings;

$SIG{__DIE__} = sub {require Carp; Carp::confess(@_)};

=head1 NAME

Acoustics::Test - a collection of routines for testing Acoustics

=head1 SYNOPSIS

This module provides several methods useful for testing Acoustics, most of which
have to do with adding fake data to the database.

=cut

=head2 create_fake_songs($ac, $num)

Creates C<$num> fake songs, inserts them into the database, and returns them.
Title, artist, album, length, and path are all randomly specified.

The songs are reloaded to get the song_id, since you probably care about it most
of the time.

=cut

sub create_fake_songs {
	my $acoustics = shift;
	my $count     = shift;

	my @songs = map {
		{
			length => 1 + int(rand(600)),
			title  => _random_string(12),
			artist => _random_string(12),
			album  => _random_string(12),
			path   => '/' . _random_string(12),
		}
	} 1 .. $count;

	$acoustics->query('insert_songs', $_) for @songs;

	# get the song_ids, since we frequently only care about that
	return map {$acoustics->query('select_songs', {path => $_->{path}})} @songs;
}

=head2 _random_string($num)

Returns a random string of C<$num> characters [A-Za-z0-9].

=cut

my @randchars = ('A' .. 'Z', 'a' .. 'z', 0 .. 9);
sub _random_string {
	my $num   = shift;
	return join '', map {$randchars[rand @randchars]} 1 .. $num;
}

=head2 cmp_songs($ac, \@got, \@expected, $reason)

Simple wrapper around L<Test::More>'s C<is_deeply> that compares on song_ids
only.

=cut

sub cmp_songs {
	my $self = shift;
	my $got  = shift;
	my $exp  = shift;
	my $desc = shift;

	use Test::More;
	is_deeply(
		[map {$_->{song_id}} @$got],
		[map {$_->{song_id}} @$exp],
		$desc || 'automatic cmp_songs :(',
	);
}

=head1 SEE ALSO

L<Acoustics>

=cut

1;
