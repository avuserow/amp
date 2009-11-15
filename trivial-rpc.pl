#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';
use Acoustics;
use CGI::Simple;
use CGI::Carp 'fatalsToBrowser';

my $acoustics = Acoustics->new({config_file => 'lib/acoustics.ini'});
my $q = CGI::Simple->new;

my $mode = $q->param('mode');
if ($mode) {
	$acoustics->rpc($mode);
	print $q->redirect('trivial-rpc.pl');
} else {
	my($player) = $acoustics->get_player({player_id => $acoustics->player_id});
	my($data)   = $acoustics->get_song({song_id => $player->{song_id}});
	print $q->header;
	print <<EOH;
	<html>
	<head>
	</head>
	<body>
	Now playing on $player->{player_id}:
	<br />$data->{title} by $data->{artist} from $data->{album}
		<ul>
		<li><a href="?mode=start">start</a></li>
		<li><a href="?mode=skip">skip</a></li>
		<li><a href="?mode=stop">stop</a></li>
		</ul>
	</body>
</html>
EOH
}
