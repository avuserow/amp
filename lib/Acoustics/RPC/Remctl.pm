package Acoustics::RPC::Remctl;

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
	my $class = shift;
	my $acoustics = shift;
	my $volume = shift;

	$class->do_call($acoustics, 'volume', $volume);
}

sub do_call {
	my $class     = shift;
	my $acoustics = shift;
	my $action    = shift;

	for (qw(host)) {
		die "Config entry {rpc}{$_} not defined"
			unless $acoustics->config->{rpc}{$_};
	}

	system('kinit', '-kt', '/etc/www.keytab', 'websvc') == 0 or die "bleh";
	system(
		'remctl', '-p', 4373,
		$acoustics->config->{rpc}{host},
		'acoustics',
		$action, @_,
	) == 0 or die "couldn't run remctl: $!,$?,@{[$? >> 8]}";

#	system(
#		'/usr/bin/k5start', '-t', '-f', '/etc/krb5.keytab', '-K', 120,
#		'akreher2',
#		'/usr/bin/remctl',
#		$acoustics->config->{rpc}{host},
#		'acoustics',
#		$action,
#	) == 0 or die "couldn't run remctl: $!,$?,@{[$? >> 8]}";
}

1;
