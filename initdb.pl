#!/usr/bin/env perl

use strict;
use warnings;
use DBI;

my $db = DBI->connect("DBI:SQLite:./acoustics.db","","",{RaiseError=>1, AutoCommit=>1});

$db->do("DROP TABLE IF EXISTS songs");
$db->do("DROP TABLE IF EXISTS votes");

$db->do("CREATE TABLE songs (song_id INTEGER PRIMARY KEY AUTOINCREMENT, path VARCHAR, artist VARCHAR, album VARCHAR, title VARCHAR, length INTEGER)");
$db->do("CREATE TABLE votes (song id INTEGER, who VARCHAR, player_id VARCHAR, time DATETIME)");

