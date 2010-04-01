use Test::More;

use strict;
use warnings;

my @tests = (
	[['select_foo'], 'select * from foo', 'select_foo'],
	[['select_foo', {}, {'-DESC' => 'asdf'}], 'select * from foo order by asdf desc', 'select_foo with order clause'],
	[['insert_foo', {bar => 'baz'}], 'insert into foo(bar) values(?)', 'insert_foo'],
	[['update_foo', {bar => 'baz'}, {}], 'update foo set bar = ?', 'update_foo'],
	[['delete_foo', {}], 'delete from foo', 'delete_foo'],

	[['simple'], 'select * from simple', 'simple (phrasebook)'],
	[['where'], 'select * from simple', 'where (no clause) (phrasebook)'],
	[['where', {a => 1}], 'select * from simple where (a = ?)', 'where (phrasebook)'],

	[['andwhere'], 'select * from simple where a = 1', 'andwhere (no clause) (phrasebook)'],
	[['andwhere', {b => 2}], 'select * from simple where a = 1 and (b = ?)', 'andwhere (clause) (phrasebook)'],
	[['orwhere'], 'select * from simple where a = 1', 'orwhere (no clause) (phrasebook)'],
	[['orwhere', {b => 2}], 'select * from simple where a = 1 or (b = ?)', 'orwhere (clause) (phrasebook)'],

	[['bind', {}, {}, {type => 'hats'}], 'select * from simple where type = ?', 'bind (phrasebook)'],
	[['bind', {}, {type => 'hats'}], 'select * from simple where type = hats', 'subst (phrasebook)'],
);

plan tests => (2 + scalar @tests);

use_ok('Acoustics::Database');

my $ac = Acoustics::Database->new({
	phrasebook => 't/database/phrase_basic.txt',
	db         => '',
});

isa_ok($ac, 'Acoustics::Database');

for my $line (@tests) {
	my($sql, @bind) = $ac->_get_sql_bind_query(@{$line->[0]});
	is (normalize($sql), normalize($line->[1]), $line->[2]);
}

sub normalize {
	my $str = shift;
	$str =~ s/\s+/ /g;
	$str =~ s/^\s+//g;
	$str =~ s/\s+$//g;
	$str =~ s/(\W)\s+(.)/$1$2/g;
	$str =~ s/(.)\s+(\W)/$1$2/g;
	return lc $str;
}
