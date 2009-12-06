#!/usr/bin/perl

use FCGI;
use CGI::Simple;
use CGI::Carp 'fatalsToBrowser';
use CGI::Session;

my $req = FCGI::Request();

while ($req->Accept() >= 0) {
	my($user) = $ENV{REMOTE_USER} =~ /([^@]+)\@/;

	my $session = CGI::Session->new;
	$session->param(who => $user);
	$session->flush;

	print $session->header(-status => 302, -location => '/acoustics');
}
