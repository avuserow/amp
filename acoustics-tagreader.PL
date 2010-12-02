#!/usr/bin/perl

use strict;
use warnings;

use Cwd 'cwd';

my $URL = 'https://github.com/avuserow/taglib/tarball/master';
my $TAGLIB_VERSION = '1.6.3';
sub build_it {
	# TODO: don't rely on the shell

	my $WORKDIR = '/tmp/acoustics-' . $$;
	my $ACOUSTICSDIR = cwd();

	mkdir($WORKDIR) or die "could not mkdir '$WORKDIR': $!";

	system("curl -L -o - $URL | tar -xz") == 0
		or die "could not download/extract taglib: $!";
	my $DOWNLOADED_DIR = glob('avuserow-taglib-*/taglib-' . $TAGLIB_VERSION);
	system('cp', '-r', $DOWNLOADED_DIR, $WORKDIR) == 0
		or die "could not copy taglib source to '$WORKDIR': $!";
	system('cp', 'bin/tagreader.cpp', $WORKDIR) == 0
		or die "could not copy tagreader source to '$WORKDIR': $!";

	my $TAGLIB_DIR = "$WORKDIR/taglib-$TAGLIB_VERSION";
	chdir($TAGLIB_DIR) or die "could not chdir to '$TAGLIB_DIR': $!";

	system('./configure', '--prefix' => $WORKDIR, '--disable-shared',
		'--enable-static', '--enable-mp4', '--enable-asf') == 0
		or die "taglib configure failed: $!";

	system('make', '-j') == 0 or die "taglib make failed: $!";
	system('make', 'install') == 0 or die "taglib make install failed: $!";

	chdir($WORKDIR) or die "could not chdir to '$WORKDIR': $!";
	my @COMPILE_FLAGS = split /\s+/, `bin/taglib-config --cflags --libs`;

	if (@COMPILE_FLAGS == 0) {
		die "could not get flags from $WORKDIR/bin/taglib-config: $!";
	}

	push @COMPILE_FLAGS, '-lz', '-O2';
	system('g++', '-o' => 'tagreader', 'tagreader.cpp', @COMPILE_FLAGS) == 0
		or die "could not build tagreader binary: $!";

	system('cp', 'tagreader', "$ACOUSTICSDIR/bin") == 0
		or die "could not copy tagreader binary back to '$ACOUSTICSDIR/bin': $!";

	chdir($ACOUSTICSDIR) or die "could not chdir back to '$ACOUSTICSDIR': $!";

	# clean up
	for my $dir ($DOWNLOADED_DIR, $WORKDIR) {
		system('rm', '-rf', $dir) == 0
			or warn "could not clean up '$dir': $!, continuing anyway";
	}
}

build_it();
#chdir 'bin';
#
#system('./build-tagreader.sh') == 0 or die "build-tagreader failed :(";
#chdir '..';
