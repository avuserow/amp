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
	my $volume = int(shift);

	$class->do_call($acoustics, 'volume', $volume);
}

sub zap {
	my $class = shift;
	my $acoustics = shift;
	my $zap_player = shift;

	$class->do_call($acoustics, 'zap', $zap_player);
}

sub do_call {
	my $class     = shift;
	my $acoustics = shift;
	my $action    = shift;

	for (qw(host)) {
		die "Config entry {player.@{[$acoustics->player_id]}}{$_} not defined"
			unless $acoustics->config->{player}{$_};
	}

	system('kinit', '-kt', '/etc/www.keytab', 'websvc') == 0 or die "bleh";
	system(
		'remctl', '-p', 4373,
		$acoustics->config->{player}{host},
		'acoustics',
		$acoustics->player_id, $action, @_,
	) == 0 or die "couldn't run remctl: $!,$?,@{[$? >> 8]}";
}

1;
