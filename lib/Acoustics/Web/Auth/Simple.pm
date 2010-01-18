package Acoustics::Web::Auth::Simple;

use strict;
use warnings;

use CGI::Session;
use Memoize;
use Mouse;

# XXX: Mouse as of version 0.4501 does not leave Mouse::Object in its
# superclass list, so we manually include it to make Mouse work.
extends 'Mouse::Object', 'Acoustics::Web::Auth';

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

	print $session->header(-status => 302, -location => '/acoustics');
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
