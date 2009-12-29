package Acoustics::Web::Auth::RemoteUser;

use strict;
use warnings;

use CGI::Session;

sub whoami {
	my $session = CGI::Session->load;
	if ($session->param('who')) {
		return $session->param('who');
	} else {
		return;
	}
}

sub is_admin {
	my $username = whoami();
	return unless $username;
	my @admins = qx(pts mem proj.acoustics -noauth);
	shift @admins;
	s{\s+}{}g for @admins;
	return grep {$_ eq $username} @admins;
}

1;
