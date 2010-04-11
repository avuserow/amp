package Acoustics::RPC::SSH_PrivateKey;

use strict;
use warnings;

use Log::Log4perl ':easy';

sub start {
	my $class     = shift;
	my $acoustics = shift;

	$class->do_call($acoustics, 'start');
}

sub skip {
	my $class     = shift;
	my $acoustics = shift;

	$class->do_call($acoustics, 'skip');
}

sub stop {
	my $class     = shift;
	my $acoustics = shift;

	$class->do_call($acoustics, 'stop');
}

sub volume {
	my $class     = shift;
	my $acoustics = shift;
	my $volume    = shift;

	$class->do_call($acoustics, 'volume', $volume);
}

sub zap {
	my $class = shift;
	my $acoustics = shift;
	my $zap_player = shift;
	
	$class->do_call($acoustics,'zap',$zap_player);
}

sub do_call {
	my $class     = shift;
	my $acoustics = shift;
	my $action    = shift;

	for (qw(user private_key host player_remote)) {
		die "Config entry {rpc}{$_} not defined"
			unless $acoustics->config->{rpc}{$_};
	}

	system(
		'ssh',
		-l => $acoustics->config->{rpc}{user},
		-i => $acoustics->config->{rpc}{private_key},
		-o => 'StrictHostKeyChecking=no',
		-o => 'GSSAPIAuthentication=no',
		$acoustics->config->{rpc}{host},
		$acoustics->config->{rpc}{player_remote},
		$action, @_,
	) == 0 or die "couldn't run ssh: $!,$?,@{[$? >> 8]}";
}

1;
