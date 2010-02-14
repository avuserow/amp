#!/usr/bin/perl -w

use strict;

use Test::More;

my @modules = qw(Acoustics);

push @modules, map {"Acoustics::$_"} qw(
	Web
	Web::Auth Web::Auth::Kerberos Web::Auth::Simple
	Queue Queue::RoundRobin Queue::TimeSlice
	Player::MPlayer
	Player::Plugin::LastFM
	RPC::SSH_PrivateKey RPC::Local RPC::Remctl
);

plan tests => scalar @modules;

use_ok($_) for @modules;
