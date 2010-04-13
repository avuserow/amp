export PERL5OPT = -Ilib
export ACOUSTICS_CONFIG_FILE = conf/acoustics_test.ini

# this gets set when we're run under 'cover -test'
# so it's pretty reliable as a sign to add this flag
ifdef OTHERLDFLAGS
	export HARNESS_PERL_SWITCHES=-MDevel::Cover=-ignore,.,-select,Acoustics
endif

test:
	prove t/init.pl
	prove -s -r -j 3 t/
	chmod -R 755 cover_db
