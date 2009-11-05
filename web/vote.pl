#!/usr/bin/env perl

use strict;
use warnings;

sub vote #vote($db, $song_id)
{
    my $db = shift;
    my $song_id = shift;

    my $insert = $db->prepare("INSERT INTO votes (song_id, time) VALUES(?, ?)");

    $insert->execute($song_id, time);
}

1;
