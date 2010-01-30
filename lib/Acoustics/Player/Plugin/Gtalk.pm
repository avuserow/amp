package Acoustics::Player::Plugin::Gtalk;

# http://digitalpbk.blogspot.com/2009/02/perl-change-google-talk-status.html
use strict;
use warnings;
use Net::XMPP;
use Data::Dumper;
use Log::Log4perl ':easy';
our %creds;

sub start_player {
    my $acoustics = shift;
    $creds{user} = $acoustics->config->{gtalk}{user};
    $creds{pass} = $acoustics->config->{gtalk}{pass};
}

sub start_song {
    my $acoustics = shift;
    my $player    = shift;
    my $song      = shift;
    my $status    = 'Listening to: ' . $song->{title} . 'by' . $song->{artist}
      if ( $song->{artist} && $song->{title} );
    &set_status($status);
}
sub stop_song { &set_status("") }

sub set_status {
    my $status         = shift;
    my $username       = $creds{user};
    my $password       = $creds{pass};
    my $hostname       = 'talk.google.com';
    my $port           = 5222;
    my $componentname  = 'gmail.com';
    my $connectiontype = 'tcpip';
    my $tls            = 1;
    my $Con            = new Net::XMPP::Client( debuglevel => 1 );
    WARN "it never gets past the connect!";
    return;
    my $con_status = $Con->Connect(
        hostname       => $hostname,
        port           => $port,
        componentname  => $componentname,
        connectiontype => $connectiontype,
        tls            => $tls,
        timeout        => 10
    );
    my $sid = $Con->{SESSION}->{id};
    $Con->{STREAM}->{SIDS}->{$sid}->{hostname} = $componentname;
    my @result = $Con->AuthSend(
        username => $username,
        password => $password,
        resource => "neuron"
    );
    $Con->Send(
"<iq type='get' to='gmail.com'><query xmlns='http://jabber.org/protocol/disco#info'></query></iq>"
    );
    return unless defined( $Con->Process() );
    my $iq = $Con->SendAndReceiveWithID(
"<iq type='get' to='$username\@gmail.com' id='ss-1'><query xmlns='google:shared-status' version='2'></query></iq>"
    );
    ##Change status
    $Con->Send(
        "<iq type='set' to='$username\@gmail.com' id='ss-2'>
        <query xmlns='google:shared-status' version='2'>
        <status>$status</status>
        <show>default</status>
        </query></iq>"
    );
    return unless defined( $Con->Process() );
    $Con->Disconnect();
    return;
}

1;
