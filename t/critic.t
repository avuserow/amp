#!/usr/bin/perl -w

use strict;

use Test::More;
use Test::Perl::Critic  -profile => 't/perlcriticrc';
use Perl::Critic::Utils 'all_perl_files';

my @files = all_perl_files('lib/Acoustics');
push @files, 'json.pl', all_perl_files('bin');

# We can use this later if test coverage becomes really slow with critic tests
# enabled. This will allow us to not run critic when running under coverage.

if($ENV{'OTHERLDFLAGS'}) {
	plan skip_all => 'Test coverage appears to be enabled.';
} else {
	plan tests => scalar(@files);
}

#plan tests => scalar @files;
critic_ok($_) for @files;
