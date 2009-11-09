#!/usr/bin/env perl

use strict;
use warnings;
use lib '../lib';
use Acoustics;
use Log::Log4perl ':easy';

my $acoustics = Acoustics->new({data_source => '../acoustics.db'});

while(1)
{
	my @songs = $acoustics->get_playlist;
	@songs    = $acoustics->get_song({}, 'RANDOM()', 1) unless @songs;
	my %data  = %{$songs[0]};

	$acoustics->delete_vote({song_id => $data{song_id}});

	if(-e $data{path})
	{
		$acoustics->add_playhistory(\%data);
		$acoustics->update_player({song_id => $data{song_id}});
		INFO "Playing '$data{path}'";
		system("vlc", "-Irc", $data{path}, "vlc://quit");
	}
	else
	{
		ERROR "Song '$data{path}' is invalid, deleting";
		$acoustics->delete_song({song_id => $data{song_id}});
	}
	sleep(1);
}
