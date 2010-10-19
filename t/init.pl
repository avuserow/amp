#!/usr/bin/perl -w

use strict;

use Test::More;

my @modules = qw(Acoustics);

push @modules, map {"Acoustics::$_"} qw(
	Web
	Web::Auth Web::Auth::Kerberos Web::Auth::Simple
	Queue Queue::RoundRobin Queue::TimeSlice
	Player::MPlayer
	RPC::SSH_PrivateKey RPC::Local RPC::Remctl
);

plan tests => 1 + scalar @modules;

use_ok($_) for @modules;

# FIXME: put the delete/create code into the Acoustics object
my $acoustics = Acoustics->new;
isa_ok($acoustics, 'Acoustics');

# FIXME: support postgres/sqlite nicely by
#  - renaming initdb_mysql to initdb
#  - having MySQL/PostgreSQL/SQLite specific phrasebooks (layered-style)
#  - using the phrasebook entries in the Acoustics object
$acoustics->initdb_mysql;
