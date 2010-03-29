use Test::More;
use Test::Exception;

use strict;
use warnings;

my @tests = (
	[['update_foo', {bar => 'baz'}], qr/pass an empty hashref to update all rows/i, 'update_foo'],
	[['delete_foo'], qr/pass an empty hashref to delete all rows/i, 'delete_foo'],

	[['bind'], qr/value not specified/i, 'bind'],
);

plan tests => (2 + scalar @tests);

use_ok('Acoustics::Database');

my $ac = Acoustics::Database->new({
	phrasebook => 't/database/phrase_basic.txt',
	db         => '',
});

isa_ok($ac, 'Acoustics::Database');

for my $line (@tests) {
	throws_ok(
		sub {$ac->_get_sql_bind_query(@{$line->[0]})},
		$line->[1], $line->[2],
	);
}
