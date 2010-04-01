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
$db->do("DROP TABLE IF EXISTS playlists_contents");

$db->do("CREATE TABLE songs (song_id INT UNSIGNED AUTO_INCREMENT, path
    VARCHAR(1024) NOT NULL, artist VARCHAR(256), album VARCHAR(256), title
    VARCHAR(256), length INT UNSIGNED NOT NULL, track INT UNSIGNED, online
    TINYINT(1) UNSIGNED, PRIMARY KEY (song_id))");

$db->do("CREATE TABLE votes (song_id INT UNSIGNED, who VARCHAR(256), player_id
    VARCHAR(256), time INT UNSIGNED, priority INT, UNIQUE(song_id, who))");

$db->do("CREATE TABLE history (song_id INT UNSIGNED, time TIMESTAMP, who
    VARCHAR(256), player_id VARCHAR(256))");

$db->do("CREATE TABLE players (player_id VARCHAR(256), volume INT UNSIGNED,
    song_id INT UNSIGNED, song_start INT UNSIGNED, local_id VARCHAR(256),
    remote_id VARCHAR(256), queue_hint TEXT, PRIMARY KEY(player_id))");

$db->do("CREATE TABLE playlists (who VARCHAR(256) NOT NULL, id INT
    AUTO_INCREMENT PRIMARY KEY, title VARCHAR(256) NOT NULL)");

$db->do("CREATE TABLE playlists_contents (id INT UNSIGNED, song_id INT
    UNSIGNED, priority INT, UNIQUE(id,song_id))");
