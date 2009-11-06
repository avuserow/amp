#!/usr/bin/env perl
#
use strict; 
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Time::Format qw(%time);
use lib '../lib';
use Acoustics;
require "vote.pl";

my $acoustics = Acoustics->new({data_source => '../acoustics.db'});

my $cgi = CGI->new;

if($cgi->param("mode") eq "vote")
{
    $acoustics->vote($cgi->param("song_id"));
    print $cgi->redirect("acoustics.pl");
    exit;
}

my @rows = $acoustics->get_library;

print $cgi->header;
print "<html><head><title>Acoustics - Music Library</title></head><body>";

print "<table>";

my @order = qw(artist album track title);
print "<tr>";
print "<th>vote</th>";
print "<th>$_</th>" for @order;
print "<th>length</th>";
print "</tr>";

foreach my $row (@rows)
{
    print "<tr>";
    print qq{<td><a href="acoustics.pl?mode=vote;song_id=$row->{song_id}">vote</a></td>};
    print map {"<td>$row->{$_}</td>"} @order;
    print "<td>$time{'mm:ss', $row->{length}}</td>";
    print "</tr>";
}

print "</table>";

print "</body></html>";
