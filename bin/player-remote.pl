#!/usr/bin/env perl

use strict;
use warnings;
use lib ($0 =~ m{(.+)/})[0] . '/../lib';
use Acoustics;

my $command = shift;

my $acoustics = Acoustics->new({
	config_file => ($0 =~ m{(.+)/})[0] . '/../lib/acoustics.ini',
});

print "command: $command @ARGV\n";
if($command eq 'update')
{
 my ($path) = $0 =~ m{(.+)/};
	system("$path/scanner.pl", @ARGV);
}
else
{
 $acoustics->player($command, @ARGV);
}
