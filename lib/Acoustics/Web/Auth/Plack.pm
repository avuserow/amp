package Acoustics::Web::Auth::Plack;

use strict;
use warnings;

use Moose;
use Plack::Session;

extends 'Acoustics::Web::Auth';

has 'acoustics' => (is => 'ro', isa => 'Acoustics');
has 'cgi'       => (is => 'ro', isa => 'Object');
has 'psgi_env'  => (is => 'ro', isa => 'HashRef');

sub authenticate {
	my $self = shift;
	my $session = Plack::Session->new($self->psgi_env);
}

sub player_id {
	my $self  = shift;
	my $value = shift;
	my $session = Plack::Session->new($self->psgi_env);
	if ($value) {
		return $session->set('player_id', $value);
	} else {
		return $session->get('player_id');
	}

}

sub whoami {
	my $self = shift;
	my $session = Plack::Session->new($self->psgi_env);
	return $session->id;
}

sub is_admin {
	return 1;
}

1;
