use Unicode::UCD 'casefold';

sub to_casefold {
	my $string = shift;
	return join '', map {codepoint_to_string($_)} map ord, split //, $string;
}

sub codepoint_to_string {
	my $codepoint = shift;
	my $folded = casefold($codepoint);

	use Data::Dumper;
	if ($folded) {print Dumper($codepoint, chr $codepoint,$folded);}

	if (exists $folded{full}) {
		return '' unless $folded{full};
		return join '', map chr, split / /, $folded{full};
	} elsif (exists $folded{simple}) {
		return '' unless $folded{simple};
		return chr $folded{simple};
	} else {
		return chr $codepoint;
	}
}

1;
