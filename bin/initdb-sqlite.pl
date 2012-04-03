#!/usr/bin/env perl

use strict;
use warnings;
use lib ($0 =~ m{(.+/)?})[0] . '../lib';
use Acoustics;

my $ac = Acoustics->new({
	config_file => ($0 =~ m{(.+)/})[0] . '/../conf/acoustics.ini',
});
my $db = $ac->db;

$db->do("DROP TABLE IF EXISTS songs");
$db->do("DROP TABLE IF EXISTS votes");
$db->do("DROP TABLE IF EXISTS history");
$db->do("DROP TABLE IF EXISTS players");
$db->do("DROP TABLE IF EXISTS playlists");
$db->do("DROP TABLE IF EXISTS playlist_contents");

$db->do("CREATE TABLE songs (song_id INTEGER PRIMARY KEY AUTOINCREMENT, path
    VARCHAR(1024) NOT NULL, artist VARCHAR(256), albumartist VARCHAR(256), album VARCHAR(256), title
    VARCHAR(256), disc INT, length INT NOT NULL, track INT, online
    TINYINT(1))");

$db->do("CREATE TABLE votes (song_id INT, who VARCHAR(256), player_id
    VARCHAR(256), time INT, priority INT, UNIQUE(song_id, who))");

$db->do("CREATE TABLE history (song_id INT, time TIMESTAMP, who
    VARCHAR(256), player_id VARCHAR(256))");

$db->do("CREATE TABLE players (player_id VARCHAR(256), volume INT,
    song_id INT, song_start INT, local_id VARCHAR(256),
    remote_id VARCHAR(256), queue_hint TEXT, PRIMARY KEY(player_id))");

$db->do("CREATE TABLE playlists (who VARCHAR(256) NOT NULL, playlist_id INTEGER
    PRIMARY KEY AUTOINCREMENT, title VARCHAR(256) NOT NULL)");

$db->do("CREATE TABLE playlist_contents (playlist_id INT, song_id INT,
   priority INT, UNIQUE(playlist_id,song_id))");

