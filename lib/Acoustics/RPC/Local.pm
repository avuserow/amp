package Acoustics::RPC::Local;

use strict;
use warnings;

use Log::Log4perl ':easy';

sub start {
	my $self      = shift;
	my $acoustics = shift;

	$acoustics->player('start', 1);
}

sub skip {
	my $self      = shift;
	my $acoustics = shift;

	$acoustics->player('skip');
}

sub stop {
	my $self      = shift;
	my $acoustics = shift;

	$acoustics->player('stop');
}

sub pause {
	my $self      = shift;
	my $acoustics = shift;

	$acoustics->player('pause');
}

sub volume {
	my $self      = shift;
	my $acoustics = shift;
	my $volume    = shift;

	$acoustics->player('volume', $volume);
}

sub zap {
	my $self = shift;
	my $acoustics = shift;
	my $zap_player = shift;

	$acoustics->player('zap',$zap_player);
}

1;
