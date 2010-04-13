#!/usr/bin/perl -w

use strict;
use Test::More;

# keep critic from running too slow in coverage
BEGIN {
	if($ENV{'OTHERLDFLAGS'}) {
		plan skip_all => 'Test coverage appears to be enabled.';
		exit;
	}
}

use Test::Perl::Critic  -profile => 't/perlcriticrc';
use Perl::Critic::Utils 'all_perl_files';

my @files = all_perl_files('lib/Acoustics');
push @files, 'json.pl', all_perl_files('bin');
plan tests => scalar(@files);

critic_ok($_) for @files;
