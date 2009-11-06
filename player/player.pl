#!/usr/bin/env perl

use strict;
use warnings;
use lib '../lib';
use Acoustics;

my $acoustics = Acoustics->new({data_source => '../acoustics.db'});

while(1)
{
	my @songs = $acoustics->get_playlist;
	my %data  = %{$songs[0]};

	$acoustics->delete_vote($data{song_id});

	if(-e $data{path})
	{
		$acoustics->add_playhistory(\%data);
		#TODO: update player table
		print "okay! playing $data{path} now!\n";
		system("vlc", "-Irc", $data{path}, "vlc://quit");
	}
	else
	{
		$acoustics->delete_song($data{song_id});
	}
	sleep(1);
}
