package Acoustics::Scanner;

use strict;
use warnings;

use Acoustics;
use File::Find::Rule ();
use List::MoreUtils qw(uniq);
use Log::Log4perl ':easy';
use Cwd qw(abs_path);

sub file_to_info {
	my $file = shift;
	# pass filenames through tagreader.
	open my $pipe, '-|', ($0 =~ m{(.+/)?})[0] . 'tagreader', $file
		or die "couldn't open tagreader: $!";
	chomp(my @data = <$pipe>);
	close $pipe;

	# split apart data, insert to database.
	my %hash = map {(split /:/, $_, 2)} @data;
	for my $key (keys %hash) {
		$hash{$key} =~ s/^\s+//;
		$hash{$key} =~ s/\s+$//;
	}
	%hash = map {$_ => $hash{$_}} qw(path artist album title disc length track);
	$hash{online} = 1; # set the online bit
	return %hash;
}

sub scan {
	my @args = @_;
	my $acoustics = Acoustics->new({
		config_file => ($0 =~ m{(.+)/})[0] . '/../conf/acoustics.ini',
	});

	my $prefix = $acoustics->config->{scanner}{require_prefix};
	for my $filename (map {abs_path($_)} @args) {
		if ($prefix && index($filename, $prefix) != 0) {
			LOGDIE "Your path ($filename) must begin with $prefix";
		}
	}

	# get list of unique filenames from paths passed on command line.
	my @files = uniq(map {abs_path($_)} File::Find::Rule->file()->in(@args));

	for my $file (@files) {
		my %hash = file_to_info($file);
		unless($hash{length}) {
			WARN "file $hash{path} not music";
			next;
		}
		if($acoustics->query('select_songs', {path => $hash{path}}, [], 1)) {
			INFO "file $hash{path} updated";
			my $path = delete $hash{path};
			$acoustics->query('update_songs', \%hash, {path => $path});
		} else {
			INFO "file $hash{path} added";
			$acoustics->query('insert_songs', \%hash);
		}
	}
}

1;

__END__

=head1 NAME

Acoustics::Scanner - add/update files to the Acoustics database

=head1 SYNOPSIS

    acoustics scan file1 file2 ...

Adds and/or updates the given files or directories recursively.

Use C<acoustics gc ...> to prune non-existent/broken files.

=head1 DESCRIPTION

Acoustics keeps a database of songs and their various attributes. This module
contains the code to add and update the database.

=head1 FUNCTIONS

None of these are exported.

=head2 scan(@files)

Scans the list of given files, adding them if they don't exist or updating the
records if they do exist.

=head2 file_to_info($filename)

Retrieves the information from the given file and returns a hash containing the
values that the database wants.

Our 'tagreader' binary does the heavy-lifting of reading the tags, and relies on
taglib.

=head1 SEE ALSO

L<acoustics>, command line frontend

L<Acoustics>, main Acoustics module

=head1 COPYRIGHT & AUTHORS

The Acoustics Team. See L<Acoustics>.

=cut
