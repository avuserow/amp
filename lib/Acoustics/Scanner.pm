package Acoustics::Scanner;
require Exporter;
@ISA=qw(Exporter);
@EXPORT_OK = qw(file_to_info);
sub file_to_info {
	my $file = shift;
	#pass filenames through tagreader
	open my $pipe, '-|', ($0 =~ m{(.+/)?})[0] . 'tagreader', $file or die "couldn't open tagreader: $!";
	chomp(my @data = <$pipe>);
	close $pipe;

#split apart data, insert to database
	my %hash = map {(split /:/, $_, 2)} @data;
	$hash{$_} =~ s{^\s*?(.*?)\s*?$}{$1} for (keys %hash); # Remove any nasty whitespace
	delete $hash{bitrate}; # no bitrate field in the database yet
	$hash{online} = 1; # set the online bit
	return %hash;
}
1;
