package Acoustics::RPC::Local;

use strict;
use warnings;

use Log::Log4perl ':easy';

sub start {
	my $self      = shift;
	my $acoustics = shift;

	$acoustics->player->start;
}

sub skip {
	my $self      = shift;
	my $acoustics = shift;

	$acoustics->player->skip;
}

sub stop {
	my $self      = shift;
	my $acoustics = shift;

	$acoustics->player->stop;
}

1;
