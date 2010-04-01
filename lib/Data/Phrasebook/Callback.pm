package Data::Phrasebook::Callback;

use strict;
use warnings;
use base qw(Data::Phrasebook::Generic Data::Phrasebook::Debug);
use Carp qw(croak);

our $VERSION = '0.01';

=head1 NAME

Data::Phrasebook::Callback - Phrasebook Model with callbacks

=head1 SYNOPSIS

    use Data::Phrasebook;

    my $book = Data::Phrasebook->new(
        class => 'Callback',
        file  => 'phrasebook.txt',
    );

    my $phrase = $book->fetch(
        $keyword,
        {
            this => 'that',
            other => sub {...},
            more => [sub {...}, $arg1, $arg2, ...],
        }
    );

=head1 DESCRIPTION

This module implements a phrasebook that can have code references for the
values. All scalar values are passed through as usual.

=head1 METHODS

=head2 fetch($keyword, \%mapping, \&default)

Fetches the given phrase from the book, and applies the mapping to it.

C<\%mapping> is a key-value pair of replacements. The key must be a simple
scalar. The value depends on the type: Scalars are substituted directly.  Code
references are executed and then the return value is substituted. All other
values are rejected at present.

C<\&default> is a code reference which is executed if no valid entry in
C<\%mapping> is specified. If this is not specified, then we C<croak> if we find
an entry not found in C<\%mapping>.

Both C<\&default> and any code references in C<\%mapping> are passed the key
found as their first and only argument.

=cut

sub fetch {
	my $self = shift;
	my ($id, $args, $default) = @_;

	$self->store(3,"->fetch IN - @_")	if($self->debug);

	croak "Default code is not a code reference." if $default && ref $default ne
	'CODE';
	my $map = $self->data($id);
	croak "No mapping for '$id'" unless($map);
	my $delim_RE = $self->delimiters;
	croak "Mapping for '$id' not a string." if ref $map;

	if($self->debug) {
		$self->store(4,"->fetch delimiters=[$delim_RE]");
		$self->store(4,"->fetch args=[".$self->dumper($args)."]");
	}

	$map =~ s{$delim_RE}[
		if (ref $args->{$1} eq 'CODE') {
			$args->{$1}->($1);
		} elsif (ref $args->{$1}) {
			croak "Unsupported reference type given for '$1'";
		} elsif (defined $args->{$1}) {
			$args->{$1};
		} elsif ($default) {
			my $val = $default->($1);
			defined $val ? $val : ''
		} else {
			croak "No value given for '$1'";
		}
	]egx;

	return $map;
}

=head1 SEE ALSO

L<Data::Phrasebook>,
L<Data::Phrasebook::Generic>,
L<Data::Phrasebook::Plain>

=head1 AUTHOR

  Adrian Kreher <avuserow@cpan.org>

  This module is largely based off of L<Data::Phrasebook::Plain>,
  written by:

  Original author: Iain Campbell Truskett (16.07.1979 - 29.12.2003)
  Maintainer: Barbie <barbie@cpan.org> since January 2004.
  for Miss Barbell Productions <http://www.missbarbell.co.uk>.

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2003 Iain Truskett.
  Copyright (C) 2004-2007 Barbie for Miss Barbell Productions.
  Copyright (C) 2010 Adrian Kreher.

  This library is free software; you can redistribute it and/or modify
  it under the same terms as Perl itself.

The full text of the licenses can be found in the F<Artistic> and
F<COPYING> files included with this module, or in L<perlartistic> and
L<perlgpl> in Perl 5.8.1 or later.

=cut
1;
