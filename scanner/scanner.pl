#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use File::Find::Rule ();
use List::MoreUtils qw(uniq);
use Cwd qw(abs_path);

#database creation, move later
my $db = DBI->connect("DBI:SQLite:../acoustics.db","","",{RaiseError=>1, AutoCommit=>1});

$db->do("CREATE TABLE IF NOT EXISTS songs (song_id VARCHAR, path VARCHAR, artist VARCHAR, album VARCHAR, title VARCHAR, length INTEGER)");
$db->do("CREATE TABLE IF NOT EXISTS votes (song_id VARCHAR, who VARCHAR, player_id VARCHAR, time DATETIME)");
$db->do("CREATE TABLE IF NOT EXISTS players (player VARCHAR, volume INTEGER, song_id VARCHAR)");

#get list of unique filenames from paths passed on command line
my @files = uniq(map {abs_path($_)} File::Find::Rule->file()->in(@ARGV));

#pass filenames through tagreader
open my $pipe, '-|', './tagreader', @files or die "couldn't open tagreader: $!";
my $data = join '', <$pipe>;
close $pipe;

#split apart data, insert to database
my @datas = split /---/, $data;
my $sth = $db->prepare("INSERT INTO songs (path, artist, album, title, length) VALUES (?, ?, ?, ?, ?)");
$db->begin_work();
for my $item (@datas) {
	my %hash = map {(split /:/, $_, 2)} split /\n/, $item;
	unless($hash{length})
	{
		print "file $hash{path} not music\n";
		next;
	}
	print "file $hash{path} processed\n";
	$sth->execute((map {$hash{$_}} qw(path artist album title length)));
}
$db->commit();


