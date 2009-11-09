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

my $template = Template->new({INCLUDE_PATH => 'www-data'});
my $file = "main.tpl";
my $mode = $cgi->param('mode') || 'library';

# FIXME: don't literally use $mode
my $vars = {mode => "$mode.tpl"};

if($mode eq "vote")
{
    $acoustics->vote($cgi->param("song_id"));
    print $cgi->redirect("acoustics.pl");
    exit;
}
elsif($mode eq "auth")
{
    print $cgi->header;
    $template->process($file, $vars);
}
else
{
    my @rows = $acoustics->get_song({}, [qw(artist album track)]);
    $vars->{playlist} = \@rows;
    $vars->{mode} = "playlist.tpl";

    print $cgi->header;
    $template->process($file, $vars);

}
