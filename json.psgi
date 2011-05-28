#!/usr/bin/env plackup

use strict;
use warnings;

use lib 'lib';
use Acoustics;
use Acoustics::Web;
use Log::Log4perl ':easy';
use CGI::Simple;
use CGI::Carp 'fatalsToBrowser';
use List::MoreUtils 'none';
use JSON::DWIW ();

return sub {
	my $env       = shift;
	my $q         = CGI::Simple->new($env->{QUERY_STRING});
	my $acoustics = Acoustics->new;
	my $web       = Acoustics::Web->new({
		acoustics        => $acoustics,
		cgi              => $q,
		boolean_callback => sub {$_[0] ? JSON::DWIW::true : JSON::DWIW::false},
	});

	# hide private methods and revert to the default mode
	my $mode = lc($q->param('mode') || '');
	$mode    = 'status' if $mode =~ /^_/ or $mode =~ /[^\w_]/ or $mode eq 'new';
	$mode    = 'status' unless $web->can($mode);

	my($headers, $data) = $web->$mode;

	my %headers = @$headers;

	# If they don't specify a type, assume it is a data structure that we
	# should encode to JSON and change the header accordingly.
	unless ($headers{'-type'}) {
		$headers{'-type'} = 'application/json';
		$data = scalar JSON::DWIW->new({
			pretty            => 1,
			escape_multi_byte => 1,
			bad_char_policy   => 'convert',
		})->to_json($data);
	}

	$acoustics->db->disconnect;

	my $status = 200;
	if ($headers{'-status'}) {
		($status) = $headers{'-status'} =~ /^(\d+)/;
		delete $headers{'-status'};
	}
	return [$status, [%headers], [$data]];
};
