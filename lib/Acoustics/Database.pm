package Acoustics::Database;

use strict;
use warnings;

use Carp qw(cluck carp confess croak);
use DBI;
use Data::Phrasebook;
use SQL::Abstract;
use Try::Tiny;

use Moose;

has 'phrasebook' => (is => 'rw', isa => 'Str', required => 1);
has 'db'         => (is => 'ro', required => 1);
has 'book'       => (is => 'ro');
has 'abstract'   => (is => 'ro');

=head1 NAME

Acoustics::Database - combination phrasebook/generated SQL abstraction

=head1 SYNOPSIS

An experimental module to have a phrasebook of SQL queries and add in SQL that
was generated at run-time by combining L<Data::Phrasebook::Callback> and
L<SQL::Abstract::Limit>. The goal is to eliminate the repetition of the
phrasebook module while still having the ability to hand-craft powerful queries
when needed.

=head1 CONSTRUCTOR

These objects require the following parameters at construction:

=over 4

=item * db - a database handle from DBI

=item * phrasebook - the filename of the phrasebook to use

=back

The constructor will make a L<Data::Phrasebook::Callback> object as well as a
L<SQL::Abstract::Limit> or L<SQL::Abstract> object.

=cut

sub BUILD {
	my $self = shift;

	my @db_opts = @{$self->{db} || []};
	if (@db_opts != 3) {
		croak '"db" parameter in Acoustics::Database should be the first three'
			. ' arguments to DBI->connect';
	}
	$self->{db} = DBI->connect(@db_opts, {RaiseError => 1, AutoCommit => 1});

	my @parsed = DBI->parse_dsn($db_opts[0]);
	my $db_drive = $parsed[1];

	$self->{book} = Data::Phrasebook->new(
		class => 'Callback',
		file  => $self->phrasebook,
		dict  => ['generic', $db_drive],
	);

	# we'd really like SQL::Abstract::Limit but we'll make do without it if we
	# only have SQL::Abstract
	$self->{abstract} = SQL::Abstract->new;
	try {
		require SQL::Abstract::Limit;
		$self->{abstract} = SQL::Abstract::Limit->new(
			limit_dialect => $self->{db},
		);
	}
}

=head1 METHODS

=head2 query($what, @args)

Runs a query on the database. First, we parse C<$what> and determine what type
of query to run:

=over 4

=item * C<select_foo>

Automatically generates a query in the form of C<SELECT * FROM foo...>. The rest
of C<@args> is interpreted as C<\%where>, C<\@order>, C<$limit>, C<$offset> and
passed directly to L<SQL::Abstract::Limit>'s C<select> function without any
processing.

=item * C<insert_foo>

Automatically generates a query in the form of C<INSERT INTO foo(...)
values(...)>. The remaining C<@args> are passed directly to L<SQL::Abstract>'s
C<insert> function as C<\%fieldvals> or C<\@values> (the data to insert).

=item * C<update_foo>

Automatically generates a query in the form of C<UPDATE foo ...>. The remaining
C<@args> are passed to L<SQL::Abstract>'s C<update> function as C<\%fieldvals>
and C<\%where>. You must pass an empty hashref as C<\%where> if you really want
to update the whole table.

=item * C<delete_foo>

Automatically generates a query in the form of C<DELETE FROM foo...>. The
remaining C<@args> are passed to L<SQL::Abstract>'s C<delete> function as
C<\%where>. You must pass an empty hashref as C<\%where> if you really want to
delete all rows in the table.

=item * anything else

All other queries are looked up in the phrasebook. Now the cool part: the
remaining part of C<@args> are specified as: C<\%where>, C<\%replace>, and
C<\%bind>.

C<\%where> is then passed to L<SQL::Abstract>'s C<where> function. The resulting
clause, if any, is then substituted into the phrasebook as C<where>.

This allows you to write a phrase that looks like this:

    count_hats=SELECT count(*) FROM hats :where

Now, if a C<\%where> clause is passed in, C<:where> is replaced with it.
Otherwise, C<:where> is removed.

You can also write queries like the following:

    count_blue_hats=SELECT count(*) FROM hats WHERE color="blue" :andwhere
    count_red_hats_or=SELECT count(*) FROM hats WHERE color="red" :orwhere

The first query will have its C<:andwhere> parameter replaced by the where
clause, joined by the C<AND> operator. The second query will have the
C<:orwhere> parameter replaced by the where clause, but joined by the C<OR>
operator. This allows you to partially write where clauses and still allow them
to have a parameterized where clause.

The remaining two parameters, C<\%replace> and C<\%bind>, are passed into
L<Data::Phrasebook::SQL>'s C<query> method.

=back

Now, the return value:

If C<wantarray> tells us that we are in void context, we check to see if your
query began with C<select>. If so, we C<die> since you really need to check your
return value and you probably forgot to write some code. Otherwise, we return.

Otherwise, we collect all the values using L<DBI>'s C<fetchall_arrayref({})>. If
you called us in list context, we return the values. If you called us in scalar
context, we check to see how many values we got back, and C<warn> you if we have
more than one value. Otherwise, we're fine with this.

If you do choose to call this function in scalar context, you should be certain
that we are only going to return one value. You are okay if you are using a
limit of 1, a function that never returns more than one row, or otherwise know
that you are fine (such as selecting by the primary unique key).

=cut

sub query {
	my $self = shift;

	my($sql, @bind) = $self->_get_sql_bind_query(@_);

	use Try::Tiny;
	my $sth;
	try {
		$sth = $self->db->prepare($sql);
		$sth->execute(@bind);
	} catch {
		require Data::Dumper;
		die Data::Dumper::Dumper($self->db->errstr, $sql, @bind);
	};

	# determine the return value based on context
	if (!defined wantarray) {
		# void context
		if ($sql =~ /^\s*SELECT/i) {
			confess "SELECT query in void context not allowed\n";
		} else {
			return;
		}
	} else {
		my @values;
		try {
			@values = @{$sth->fetchall_arrayref({})};
		} catch {
			require Data::Dumper;
			confess Data::Dumper::Dumper($self->db->errstr, $sql, @bind);
		};

		# list context
		return @values if wantarray;

		# scalar context
		# TODO: "know" if we are selecting on the primary key or a unique
		# clause so we can throw this error earlier and more predictably
		if (@values > 1) {
			cluck "Multiple values returned when in scalar context";
		}
		return $values[0];
	}
}

sub _get_sql_bind_query {
	my $self = shift;
	my $what = shift;

	my($mode, $table) = $what =~ /^(select|insert|update|delete)_(\w+)$/i;
	$mode ||= '';

	if ($mode eq 'select') {
		return $self->abstract->select($table, '*', @_);
	} elsif ($mode eq 'insert') {
		return $self->abstract->insert($table, @_);
	} elsif ($mode eq 'update') {
		my($fieldvals, $where) = @_;
		die "you must pass an empty hashref to update all rows" unless $where;
		return $self->abstract->update($table, @_);
	} elsif ($mode eq 'delete') {
		my($where) = @_;
		die "you must pass an empty hashref to delete all rows" unless $where;
		return $self->abstract->delete($table, @_);
	} else {
		return $self->_phrasebook_query($what, @_);
	}
}

sub _phrasebook_query {
	my $self    = shift;
	my $what    = shift;
	my $where   = shift;
	my $replace = shift;
	my $bind    = shift;

	# remove out the -limit and -order items
	my $limit = delete $where->{'-limit'};
	my $offset = delete $where->{'-offset'};

	# the where clause that we generate
	my($where_clause, @where_bind) = $self->abstract->where($where);

	# store the binded values here
	my @bind;

	# handle the where, andwhere, and orwhere cases
	$replace->{where} = sub {
		push @bind, @where_bind;
		return $where_clause;
	};

	$replace->{andwhere} = sub {
		push @bind, @where_bind;
		my $where = $where_clause;
		$where =~ s/^\s+WHERE/ AND/i;
		return $where;
	};

	$replace->{orwhere} = sub {
		push @bind, @where_bind;
		my $where = $where_clause;
		$where =~ s/^\s+WHERE/ OR/i;
		return $where;
	};

	if ($self->abstract->isa('SQL::Abstract::Limit')) {
		my($limit_clause, @limit_bind) = $self->abstract->where({}, [], $limit, $offset);
		$replace->{limitoffset} = sub {
			push @bind, @limit_bind;
			return $limit_clause;
		};
	} else {
		die "SQL::Abstract::Limit not available -- limitoffset not available" if $limit || $offset;
		$replace->{limitoffset} = sub {
			die "SQL::Abstract::Limit not available -- limitoffset not available";
		};
	}

	# Use the default to handle any binded values
	my $default = sub {
		my $key = shift;
		if (exists $bind->{$key}) {
			push @bind, $bind->{$key};
			return '?';
		} else {
			die "value not specified: $key";
		}
	};

	# use the phrasebook to fill in the values
	my $sql = $self->book->fetch($what, $replace, $default);
	return ($sql, @bind);
}

1;
