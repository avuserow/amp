#!/usr/bin/env perl
#
use strict;
use warnings;
use DBI;

my $db = DBI->connect("DBI:SQLite:../acoustics.db","","",{RaiseError=>1, AutoCommit=>1});
my $select = $db->prepare("SELECT song_id FROM votes GROUP BY song_id ORDER BY count(song_id) DESC");
my $song = $db->prepare("SELECT * FROM songs WHERE song_id=?");
my $random = $db->prepare("SELECT * FROM songs ORDER BY RANDOM() LIMIT 1");
my $delete = $db->prepare("DELETE FROM votes WHERE song_id=?");

#while(1)
{
	$select->execute();
	my @rows = @{$select->fetchall_arrayref({})};
	my $song_id;
	my %data;

	if(@rows) #we have rows
	{
		$song_id = $rows[0]{song_id};
		$song->execute($song_id);
		%data = %{$song->fetchrow_hashref()};
	}
	else #random
	{
		$random->execute();
		%data = %{$random->fetchrow_hashref()};
	}

	$delete->execute($data{song_id});
	#TODO: update player table
	system("vlc", "-Irc", $data{path}, "vlc://quit");
}
