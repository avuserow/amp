#! /bin/sh

#/usr/bin/perl /afs/acm.uiuc.edu/project/acoustics/bin/player-remote.pl ${1+"$@"}

if [ $1 = 'start' ]; then
	BGOPT=-b
fi

/usr/bin/k5start $BGOPT -t -f /etc/soda.keytab -K 120 tunez -- /usr/bin/perl /afs/acm.uiuc.edu/project/acoustics/bin/player-remote.pl ${1+"$@"} --nodaemonize
