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

1;
