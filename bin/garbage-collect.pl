#!/usr/bin/env perl

use strict;
use warnings;
use lib ($0 =~ m{(.+)/})[0] . '/../lib';
use Log::Log4perl ':easy';
use Acoustics;

my $acoustics = Acoustics->new({
	config_file => ($0 =~ m{(.+)/})[0] . '/../lib/acoustics.ini',
});

die "Usage: $0 dir1 dir2 ..." unless @ARGV;

for my $path (@ARGV) {
	for my $song ($acoustics->get_song({path => {-like => "$path%"}})) {
		unless (-e $song->{path}) {
			WARN "Removing $song->{path} from the database";
			$acoustics->delete_song({path => $song->{path}});
		}
	}
}
