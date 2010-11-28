package Acoustics::GarbageCollect;

use strict;
use warnings;

use Acoustics;
use Acoustics::Scanner 'file_to_info';
use File::Find::Rule ();
use List::MoreUtils qw(uniq);
use Log::Log4perl ':easy';
use Cwd qw(abs_path);

sub prune {
	my @files = @_;
	die "Usage: $0 path1 path2 ..." unless @files;

	my $acoustics = Acoustics->new({
		config_file => ($0 =~ m{(.+)/})[0] . '/../conf/acoustics.ini',
	});

	for my $path (@files) {
		for my $song ($acoustics->query('select_songs', {path => {-like => "$path%"}})) {
			my $state = $song->{online};
			$song->{online} = -e $song->{path} ? 1 : 0;
			if ($song->{online} != $state) {
				if ($song->{online}) {
					WARN "Setting $song->{path} online";
				} else {
					ERROR "Setting $song->{path} offline";
				}
				$acoustics->query('update_songs', $song, {path => $song->{path}});
			}
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
