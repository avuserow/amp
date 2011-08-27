use strict;
use warnings;

my $root;

BEGIN {
	use File::Basename ();
	use File::Spec ();

	$root = File::Basename::dirname(__FILE__);
	$root = File::Spec->rel2abs($root);

	unshift @INC, "$root/../../lib";
}

use PocketIO;

use Plack::App::File;
use Plack::Builder;
use Plack::Middleware::Static;

my $pocketio = PocketIO->new(
	socketio => {transports => [qw(jsonp-polling htmlfile xhr-polling)]},
	handler => sub {
		my $self = shift;
		# do nothing; just push from other places
		$self->on('connect', sub {print "got conn here";});
	}
);

my $amp = require 'json.psgi';

builder {
	mount '/socket.io/socket.io.js' =>
		Plack::App::File->new(file => "$root/public/socket.io.js");

	mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
		Plack::App::File->new(file => "$root/public/WebSocketMain.swf");

	mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
		Plack::App::File->new(file => "$root/public/WebSocketMainInsecure.swf");

	mount '/socket.io' => $pocketio;

	mount '/push' => sub {
		print time, ": telling clients to update\n";
		my $req = Plack::Request->new(shift);
		# Gotta be a better way to do this
		my $sockets = PocketIO::Sockets->new(pool => $pocketio->pool);

		$sockets->emit('check');
		return $req->new_response(200)->finalize;
	};

	# so we don't clutter the main one
	mount '/index2.html' =>
		Plack::App::File->new(file => "$root/index2.html");

	mount '/' => $amp;
};

# vim: set ft=perl:
