#!/usr/bin/env perl

use strict;
use warnings;
use lib ($0 =~ m{(.+/)?})[0] . '../lib';
use Acoustics;
use Acoustics::Scanner qw(file_to_info);
use File::Find::Rule ();
use List::MoreUtils qw(uniq);
use Log::Log4perl ':easy';
use Cwd qw(abs_path);

my $acoustics = Acoustics->new({
	config_file => ($0 =~ m{(.+)/})[0] . '/../conf/acoustics.ini',
});

my $prefix = $acoustics->config->{scanner}{require_prefix};
for my $filename (map {abs_path($_)} @ARGV) {
	if ($prefix && index($filename, $prefix) != 0) {
		LOGDIE "Your path ($filename) must begin with $prefix";
	}
}

#get list of unique filenames from paths passed on command line
my @files = uniq(map {abs_path($_)} File::Find::Rule->file()->in(@ARGV));

for my $file (@files) {
	my %hash = &file_to_info($file);
	unless($hash{length})
	{
		WARN "file $hash{path} not music";
		next;
	}
	if($acoustics->query('select_songs', {path => $hash{path}}, [], 1))
	{
		INFO "file $hash{path} updated";
		my $path = delete $hash{path};
		$acoustics->query('update_songs', \%hash, {path => $path});
	}
	else
	{
		INFO "file $hash{path} added";
		$acoustics->query('insert_songs', \%hash);
	}
}
