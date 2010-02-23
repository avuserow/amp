package Acoustics::Web::Auth::Kerberos;

use strict;
use warnings;

use CGI::Session;
use Memoize;
use Mouse;
use List::Util 'first';

# XXX: Mouse as of version 0.4501 does not leave Mouse::Object in its
# superclass list, so we manually include it to make Mouse work.
extends 'Mouse::Object', 'Acoustics::Web::Auth';

has 'acoustics' => (is => 'ro', isa => 'Acoustics');
has 'cgi'       => (is => 'ro', isa => 'Object');

sub authenticate {
	my $self = shift;

	my $user = $ENV{REMOTE_USER};
	($user, undef) = split /\@/, $user;

	my $session = CGI::Session->new;
	$session->param(who => $user);
	$session->flush;

	print $session->header(-status => 302, -location => '/acoustics/');
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
	my $self = shift;
	return 1 unless $self->acoustics->config->{webauth}{use_pts_admin};
	my $username = whoami();
	return unless $username;

	my $admin_group = $self->acoustics->config->{webauth}{pts_admin_group};
	my @admins = qx(pts mem $admin_group -noauth);
	shift @admins; # throw away the header line
	s{\s+}{}g for @admins; # remove extra whitespace

	return first {$_ eq $username} @admins;
}

1;
