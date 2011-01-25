package Acoustics::Web::Auth::Kerberos;

use strict;
use warnings;

use CGI::Session;
use Memoize;
use Moose;
use List::Util 'first';

extends 'Acoustics::Web::Auth';

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
	my $self = shift;
	return 1 unless $self->acoustics->config->{webauth}{use_pts_admin};
	my $username = whoami();
	return unless $username;

	my $admin_group = $self->acoustics->config->{webauth}{pts_admin_group};
	my (undef, undef, undef, $admins) = getgrnam($admin_group);
	return first {$_ eq $username} split(/ /, $admins);
}

1;
