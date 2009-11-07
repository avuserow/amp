#!/usr/bin/env perl
#
use warnings;
use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Authen::Krb5::Simple;


my $cgi = CGI->new;
my $user = $cgi->param("user");
my $pass = $cgi->param("pass");

print $cgi->header;

if(!$user or !$pass)
{
    print "missing parameters";
    exit;
}

my $krb = Authen::Krb5::Simple->new();
my $authen = $krb->authenticate($user, $pass);

unless($authen)
{
    print "authorization failed";
}
else
{
    print "authorization successful";
}
