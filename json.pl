#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';
use Acoustics;
use Acoustics::Web;
use CGI::Simple '-debug1';
use CGI::Carp 'fatalsToBrowser';
use List::MoreUtils 'none';
use JSON::DWIW ();

# Determine if we are running under FastCGI or not
my $req;
my $running_under_fastcgi = not scalar keys %ENV;
if ($running_under_fastcgi) {
	require FCGI;
	$req = FCGI::Request();
	$req->Accept() >= 0 or exit 1;
}

do {
	my $q         = CGI::Simple->new;
	my $acoustics = Acoustics->new;
	my $web       = Acoustics::Web->new({
		acoustics        => $acoustics,
		cgi              => $q,
		boolean_callback => sub {$_[0] ? JSON::DWIW::true : JSON::DWIW::false},
	});

	# hide private methods and revert to the default mode
	my $mode = lc $q->param('mode') || '';
	$mode    = 'status' if $mode =~ /^_/ or $mode =~ /[^\w_]/ or $mode eq 'new';
	$mode    = 'status' unless $web->can($mode);
	my($headers, $data) = $web->$mode;

	$q->no_cache(1);
	binmode STDOUT, ':utf8';
	print $q->header(
		@$headers,
		-type     => 'application/json',
	);
	print scalar JSON::DWIW->new({
		pretty            => 1,
		escape_multi_byte => 1,
		bad_char_policy   => 'convert',
	})->to_json($data);

	# finish FastCGI if needed and auto-reload ourselves if we were modified
	$req->Finish if $running_under_fastcgi;
	exit if (-M $ENV{SCRIPT_FILENAME}) < 0;

	$acoustics->db->disconnect;
} while ($running_under_fastcgi && $req->Accept() >= 0);
