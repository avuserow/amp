#! /bin/sh

#/usr/bin/perl /afs/acm.uiuc.edu/project/acoustics/bin/player-remote.pl ${1+"$@"}
/usr/bin/k5start -t -f /etc/soda.keytab -K 120 tunez /usr/bin/perl /afs/acm.uiuc.edu/project/acoustics/bin/player-remote.pl ${1+"$@"}
