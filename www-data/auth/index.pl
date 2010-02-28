#!/usr/bin/perl

use CGI::Simple;
use CGI::Carp 'fatalsToBrowser';

use lib '../../lib';
use Acoustics;
use Acoustics::Web;

my $req;
my $running_under_fastcgi = not scalar keys %ENV;
if ($running_under_fastcgi) {
	require FCGI;
	$req = FCGI::Request();
	$req->Accept() >= 0 or exit 1;
}

do {
	my $acoustics = Acoustics->new({config_file => '../../conf/acoustics.ini'});
	my $web       = Acoustics::Web->new({
		acoustics => $acoustics,
		cgi       => CGI::Simple->new,
	});

	$web->authenticate;

	# finish FastCGI if needed and auto-reload ourselves if we were modified
	$req->Finish if $running_under_fastcgi;
	exit if -M $ENV{SCRIPT_FILENAME} < 0;

	$acoustics->db->disconnect;
} while ($running_under_fastcgi && $req->Accept() >= 0);
