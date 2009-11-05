#!/usr/bin/env perl

use strict;
use warnings;
use DBI;

my $db = DBI->connect("DBI:SQLite:../acoustics.db","","",{RaiseError=>1, AutoCommit=>1});

$db->do("CREATE TABLE IF NOT EXISTS songs (song_id VARCHAR, path VARCHAR, artist VARCHAR, album VARCHAR, title VARCHAR, length INTEGER)");
$db->do("CREATE TABLE IF NOT EXISTS votes (song_id VARCHAR, who VARCHAR, player_id VARCHAR, time DATETIME)");
$db->do("CREATE TABLE IF NOT EXISTS players (player VARCHAR, volume INTEGER, song_id VARCHAR)");

open my $pipe, '-|', './tagreader', @ARGV or die "couldn't open tagreader: $!";
my $data = join '', <$pipe>;
close $pipe;

my @datas = split /---/, $data;
my $sth = $db->prepare("INSERT INTO songs (path, artist, album, title, length) VALUES (?, ?, ?, ?, ?)");
$db->begin_work();
for my $item (@datas) {
	my %hash = map {(split /:/, $_, 2)} split /\n/, $item;
	$sth->execute((map {$hash{$_}} qw(path artist album title length)));
}
$db->commit();


