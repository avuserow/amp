#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use lib ($0 =~ m{(.+)/})[0] . '/../lib';
use Acoustics;
use File::Find::Rule ();
use List::MoreUtils qw(uniq);
use Log::Log4perl ':easy';
use Cwd qw(abs_path);
use Unicode::Normalize;
use Asdf;

my $acoustics = Acoustics->new({
	config_file => ($0 =~ m{(.+)/})[0] . '/../lib/acoustics.ini',
});

#get list of unique filenames from paths passed on command line
my @files = uniq(map {abs_path($_)} File::Find::Rule->file()->in(@ARGV));

#pass filenames through tagreader
open my $pipe, '-|:encoding(UTF-8)', ($0 =~ m{(.+)/})[0] . '/tagreader', @files or die "couldn't open tagreader: $!";
my $data = join '', <$pipe>;
close $pipe;

#split apart data, insert to database
my @datas = split /---/, $data;

binmode STDOUT, ':utf8';
for my $item (@datas) {
	my %hash = map {(split /:/, $_, 2)} split /\n/, $item;

	next unless $hash{length};

	my $title = $hash{title};
	my $title_casefolded = NFKD(to_casefold(NFKD(to_casefold(NFD($title)))));
	if ($title ne $title_casefolded) {
		printf("%x ", $_) for map ord, split //, $title;
		print "\n";
		printf("%x ", $_) for map ord, split //, $title_casefolded;
		print "\n";
		print "$title -> $title_casefolded\n";
		last;
	}
}
