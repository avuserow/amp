#!/usr/bin/env perl

use strict;
use warnings;
use lib '../lib';
use Acoustics;
use File::Find::Rule ();
use List::MoreUtils qw(uniq);
use Cwd qw(abs_path);

my $acoustics = Acoustics->new({data_source => '../acoustics.db'});

#get list of unique filenames from paths passed on command line
my @files = uniq(map {abs_path($_)} File::Find::Rule->file()->in(@ARGV));

#pass filenames through tagreader
open my $pipe, '-|', './tagreader', @files or die "couldn't open tagreader: $!";
my $data = join '', <$pipe>;
close $pipe;

#split apart data, insert to database
my @datas = split /---/, $data;

$acoustics->begin_work;
for my $item (@datas) {
	my %hash = map {(split /:/, $_, 2)} split /\n/, $item;
	unless($hash{length})
	{
		print "file $hash{path} not music\n";
		next;
	}
	if($acoustics->check_if_song_exists($hash{path}))
	{
		print "file $hash{path} updated\n";
		$acoustics->update_song(\%hash);
	}
	else
	{
		print "file $hash{path} added\n";
		$acoustics->add_song(\%hash);
	}
}
$acoustics->commit;
