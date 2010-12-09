package Acoustics::Web::Auth::Simple;

use strict;
use warnings;

use CGI::Session;
use Memoize;
use Moose;

extends 'Acoustics::Web::Auth';

has 'acoustics' => (is => 'ro', isa => 'Acoustics');
has 'cgi'       => (is => 'ro', isa => 'Object');

sub authenticate {
	my $self = shift;

	my $field = $self->acoustics->config->{webauth}{field};
	my $user  = '???';
	if ($field eq 'random') {
		# generate a random large number
		$user = int rand(~1);
	} elsif ($field eq 'time') {
		$user = time;
	} else {
		# otherwise, pick from %ENV
		$user = $ENV{$field} if $ENV{$field};
	}

	my $session = CGI::Session->new;
	$session->param(who => $user);
	$session->flush;

	print $session->header(-status => 302, -location => $self->acoustics->config->{_}{webroot});
}

sub player_id {
	my $self  = shift;
	my $value = shift;

	my $session = CGI::Session->load;

	if ($value) {
		$session->param(player_id => $value);
		$session->flush;
	} else {
		return $session->param('player_id') || '';
	}
}

sub whoami {
	my $session = CGI::Session->load;
	if ($session->param('who')) {
		return $session->param('who');
	} else {
		return;
	}
}

sub is_admin {
	return 1;
}

1;
