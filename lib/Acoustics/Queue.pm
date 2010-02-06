package Acoustics::Queue;

# a base class for queues. might be useful someday.

use strict;
use warnings;

sub list {
	die 'list method not implemented in ' . __PACKAGE__ . ' subclass!';
}

sub song_stop {}

sub serialize {}
sub deserialize {}

1;
