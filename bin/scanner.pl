#!/usr/bin/env perl

use strict;
use warnings;
use lib ($0 =~ m{(.+)/})[0] . '/../lib';
use Acoustics;
use File::Find::Rule ();
use List::MoreUtils qw(uniq);
use Log::Log4perl ':easy';
use Cwd qw(abs_path);

my $acoustics = Acoustics->new({
	data_source => ($0 =~ m{(.+)/})[0] . '/../acoustics.db',
});

#get list of unique filenames from paths passed on command line
my @files = uniq(map {abs_path($_)} File::Find::Rule->file()->in(@ARGV));

#pass filenames through tagreader
open my $pipe, '-|', ($0 =~ m{(.+)/})[0] . '/tagreader', @files or die "couldn't open tagreader: $!";
my $data = join '', <$pipe>;
close $pipe;

#split apart data, insert to database
my @datas = split /---/, $data;

$acoustics->begin_work;
for my $item (@datas) {
	my %hash = map {(split /:/, $_, 2)} split /\n/, $item;
	delete $hash{bitrate}; # no bitrate field in the database yet
	unless($hash{length})
	{
		WARN "file $hash{path} not music";
		next;
	}
	if($acoustics->check_if_song_exists($hash{path}))
	{
		INFO "file $hash{path} updated";
		my $path = delete $hash{path};
		$acoustics->update_song(\%hash, {path => $path});
	}
	else
	{
		INFO "file $hash{path} added";
		$acoustics->add_song(\%hash);
	}
}
$acoustics->commit;
