#!/usr/bin/env perl

use strict;
use warnings;
use DBI;

open my $pipe, '-|', './tagreader', @ARGV or die "couldn't open tagreader: $!";
my $data = join '', <$pipe>;
close $pipe;

my @datas = split /---/, $data;
for my $item (@datas) {
	my %hash = map {(split /:/, $_, 2)} split /\n/, $item;
	use Data::Dumper;
	print Dumper(\%hash);
}
