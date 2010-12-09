#! /bin/sh

if [ "$1" = 'player-start' ]; then
	BGOPT=-b
	ND=--nodaemonize
fi

/usr/bin/k5start $BGOPT -t -f /etc/soda.keytab -K 120 tunez -- /usr/bin/perl /afs/acm.uiuc.edu/project/acoustics/bin/acoustics ${1+"$@"} $ND
