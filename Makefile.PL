use inc::Module::Install;

name     'Acoustics';
all_from 'lib/Acoustics.pm';
author   q{Adrian Kreher <avuserow@cpan.org>};
license  'perl';

test_requires 'Test::More';

#install_script 'bin/streaming-next-song.sh';
#install_script 'bin/initdb-pgsql.pl';
install_script 'bin/initdb-mysql.pl';
install_script 'bin/k5start-wrapper.sh';
install_script 'bin/acoustics';
install_script 'bin/tagreader';

install_share 'www-data';

auto_install;

makemaker_args(PL_FILES => {'acoustics-tagreader.PL' => 'bin/tagreader'});
WriteAll;
