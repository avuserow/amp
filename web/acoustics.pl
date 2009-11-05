#!/usr/bin/env perl
#
use strict; 
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DBI;
use Time::Format qw(%time);
require "vote.pl";

my $db = DBI->connect("DBI:SQLite:../acoustics.db","","",{RaiseError=>1, AutoCommit=>1});
my $select = $db->prepare("SELECT * FROM songs ORDER BY artist,album,track ASC");

my $cgi = CGI->new;

if($cgi->param("mode") eq "vote")
{
    vote($db, $cgi->param("song_id"));
    print $cgi->redirect("acoustics.pl");
    exit;
}

$select->execute();

my @rows = @{$select->fetchall_arrayref({})};

print $cgi->header;
print "<html><head><title>Acoustics - Music Library</title></head><body>";

print "<table>";

my @order = qw(artist album track title);
print "<tr>";
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
