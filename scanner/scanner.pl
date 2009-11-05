#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use File::Find::Rule ();
use List::MoreUtils qw(uniq);
use Cwd qw(abs_path);

#database creation, move later
my $db = DBI->connect("DBI:SQLite:../acoustics.db","","",{RaiseError=>1, AutoCommit=>1});

#get list of unique filenames from paths passed on command line
my @files = uniq(map {abs_path($_)} File::Find::Rule->file()->in(@ARGV));

#pass filenames through tagreader
open my $pipe, '-|', './tagreader', @files or die "couldn't open tagreader: $!";
my $data = join '', <$pipe>;
close $pipe;

#split apart data, insert to database
my @datas = split /---/, $data;
my $insert = $db->prepare("INSERT INTO songs (path, artist, album, title, length, track) VALUES (?, ?, ?, ?, ?, ?)");
my $update = $db->prepare("UPDATE songs SET artist=?,album=?,title=?,length=?,track=? WHERE path=?");

$db->begin_work();
for my $item (@datas) {
	my %hash = map {(split /:/, $_, 2)} split /\n/, $item;
	unless($hash{length})
	{
		print "file $hash{path} not music\n";
		next;
	}
	my @count = $db->selectrow_array("SELECT count(*) FROM songs WHERE path=?", undef, $hash{path});
	if($count[0] == 0)
	{
		print "file $hash{path} added\n";
		$insert->execute((map {$hash{$_}} qw(path artist album title length track)));
	}
	else
	{
		print "file $hash{path} updated\n";
		$update->execute((map {$hash{$_}} qw(artist album title length track path)));
	}
}
$db->commit();


