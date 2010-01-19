#!/usr/bin/env perl

use strict;
use warnings;
use lib ($0 =~ m{(.+)/})[0] . '/../lib';
use Log::Log4perl ':easy';
use Acoustics;

my $acoustics = Acoustics->new({
	config_file => ($0 =~ m{(.+)/})[0] . '/../conf/acoustics.ini',
});

die "Usage: $0 path1 path2 ..." unless @ARGV;

for my $path (@ARGV) {
	for my $song ($acoustics->get_song({path => {-like => "$path%"}})) {
		my $state = $song->{online};
		$song->{online} = -e $song->{path} ? 1 : 0;
		if ($song->{online} != $state) {
			if ($song->{online}) {
				WARN "Setting $song->{path} online";
			} else {
				ERROR "Setting $song->{path} offline";
			}
			$acoustics->update_song($song, {path => $song->{path}});
		} else {
			#INFO "Ignoring $song->{path}";
		}
	}
}
