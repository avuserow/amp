#!/usr/bin/perl

use CGI;
use CGI::Carp 'fatalsToBrowser';
use CGI::Session;

my($user) = $ENV{REMOTE_USER} =~ /([^@]+)\@/;

my $session = CGI::Session->new;
$session->param(who => $user);
$session->flush;

print $session->header(-status => 302, -location => '/acoustics/acoustics.html');
