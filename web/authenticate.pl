#!/usr/bin/env perl
#
use warnings;
use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session;
use Authen::Krb5::Simple;


my $cgi = CGI->new;
my $session = new CGI::Session();

my $user = $cgi->param("user");
my $pass = $cgi->param("pass");


if(!$user or !$pass)
{
    print $cgi->header;
    print "missing parameters";
    exit;
}

my $krb = Authen::Krb5::Simple->new();
my $authen = $krb->authenticate($user, $pass);

unless($authen)
{
    print $cgi->header;
    print "authorization failed";
}
else
{
    $session->param('user', $user);
    print $session->header;
    print "authorization successful";
}
