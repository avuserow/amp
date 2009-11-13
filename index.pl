#!/usr/bin/env perl
#
use strict; 
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session;
use Time::Format qw(%time);
use Template;
use lib 'lib';
use Acoustics;

my $acoustics = Acoustics->new({data_source => 'acoustics.db'});
my $cgi = CGI->new;
my $session = CGI::Session->new;

my %mode_table = (
    vote => \&vote,
    auth => \&auth,
    library => \&library
);

my $template = Template->new({INCLUDE_PATH => 'www-data'});
my $file = "main.tpl";
my $mode = $cgi->param('mode') || 'library';

my $vars = $mode_table{$mode}->($acoustics, $cgi, $session);

print $cgi->header;
$template->process($file, $vars);

sub vote
{
    my $acoustics = shift;
    my $cgi = shift;
    my $session = shift;

    $acoustics->vote($cgi->param("song_id"));
    print $cgi->redirect("index.pl");
    exit;
}
sub auth
{
    my $acoustics = shift;
    my $cgi = shift;
    my $session = shift;
    
    return {mode => "auth.tpl"};
}
sub library
{
    my $acoustics = shift;
    my $cgi = shift;
    my $session = shift;
    my $vars = {};

    my @rows = $acoustics->get_song({}, [qw(artist album track)]);
    $vars->{playlist} = \@rows;
    $vars->{mode} = "playlist.tpl";
    
    return $vars;
}
