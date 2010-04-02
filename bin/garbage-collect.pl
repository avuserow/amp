#!/usr/bin/env perl

use strict;
use warnings;
use lib ($0 =~ m{(.+/)?})[0] . '../lib';
use Log::Log4perl ':easy';
use Acoustics;
use Acoustics::Scanner qw(file_to_info);
use File::Glob qw(:globally :nocase);
use List::Util qw(first);

my $acoustics = Acoustics->new({
		config_file => ($0 =~ m{(.+)/})[0] . '/../conf/acoustics.ini',
	});

die "Usage: $0 path1 path2 ..." unless @ARGV;

for my $path (@ARGV) {
	for my $song ($acoustics->query('select_songs', {path => {-like => "$path%"}})) {
		my $state = $song->{online};
		$song->{online} = -e $song->{path} ? 1 : 0;
		# Check if song was reencoded
#		unless ($song->{online}) {
#			my $sans_filetype = $song->{path};
#			$sans_filetype =~ s{\..*$}{};
#			my @possibles = glob("$sans_filetype.*");
#			my @scanned = ();
#			(@scanned) = &file_to_info($_) for @possibles;
#			my $new = first {defined($_->{length})} @scanned;
#			if ($new) {
#				$song->{online} = 1;
#				$acoustics->update_song($song,{path=>$new->{path}});
#			}
#		}
		if ($song->{online} != $state) {
			if ($song->{online}) {
				WARN "Setting $song->{path} online";
			} else {
				ERROR "Setting $song->{path} offline";
			}
			$acoustics->query('update_songs', $song, {path => $song->{path}},);
		}
	}
}
