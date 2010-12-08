#!/usr/bin/perl -w

=head1 NAME

obo-def-differ.pl.pl - compare term defs between two OBO files

=head1 SYNOPSIS

 obo-def-differ.pl.pl --file_1 old_gene_ontology.obo --file_2 gene_ontology.obo
 -o results.txt

=head1 DESCRIPTION

Compares the defs in two OBO files and records the differences between them

=head2 Input parameters

=head3 Required

=over

=item -f1 || --file_1 /path/to/file_name

"old" ontology file

=item -f2 || --file_2 /path/to/file_2_name

"new" ontology file

=item -o || --output /path/to/file_name

output file for results

=back

=head3 Optional switches

=over

=item -v || --verbose

prints various messages

=back

=cut

use strict;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

run_script(\@ARGV);

exit(0);

sub run_script {

	my $options = parse_options(@_);

	# check verbosity
	if (! defined $options->{verbose})
	{	$options->{verbose} = $ENV{GO_VERBOSE} || 0;
	}

	## OK, looks like we're going to have to compare the files.

	print STDERR "Parsed options. Now starting script...\n" if $options->{verbose};

	my $data;

	open(OUT, ">" . $options->{'output'}) or die("Could not create " . $options->{output} . ": $!");

	open(FH, "<" . $options->{'f1'}) or die("Could not open " . $options->{'f1'} . "! $!");
	my @arr;
	# remove and parse the header
	{	local $/ = "\n[";
		@arr = split("\n", <FH> );
	#	$data->{$f}{header} = tag_val_arr_to_hash( \@arr );
	#	print STDERR "Parsed $f header; starting body\n" if $options->{verbose};
		my @lines;
		{	local $/ = "\n[";
			while (<FH>)
			{	if (/^(\S+)\]\s*.*?^id:\s*(\S+)/sm)
				{	# extract the interesting data
					if ($1 eq "Term")
					{	my $h;
						map {
							if (/(.*?): ?(.+)/)
							{	$h->{$1} = $2;
							}
						} grep { /^(id|name|def|is_obsolete):/ } split("\n", $_);
						if ($h->{def})
						{	## clip off the def xrefs
							if ($h->{def} =~ /^\"(.*)\"\s*(\[.*)/)
							{	$h->{def} = $1;
							}
							else
							{	warn "Could not parse def for " . $h->{id};
							}
						}
						$data->{f1}{ $h->{id} } = $h;
					}
				}
			}
		}
	}
	close(FH);

	print STDERR "Parsed " . $options->{f1} . "\n" if $options->{verbose};

	open(FH, "<" . $options->{'f2'}) or die("Could not open " . $options->{'f2'} . "! $!");
	# remove and parse the header
	{	local $/ = "\n[";
		@arr = split("\n", <FH> );
	#	$data->{$f}{header} = tag_val_arr_to_hash( \@arr );
	#	print STDERR "Parsed $f header; starting body\n" if $options->{verbose};
		my @lines;
		{	local $/ = "\n[";
			while (<FH>)
			{	if (/^(\S+)\]\s*.*?^id:\s*(\S+)/sm)
				{	# extract the interesting data
					if ($1 eq "Term")
					{	my $h;
						map {
							if (/(.*?): ?(.+)/)
							{	$h->{$1} = $2;
							}
						} grep { /^(id|name|def|is_obsolete):/ } split("\n", $_);

						if ($h->{def})
						{	## clip off the def xrefs
							if ($h->{def} =~ /^\"(.*)\"\s*(\[.*)/)
							{	$h->{def} = $1;
							}
							else
							{	warn "Could not parse def for " . $h->{id};
							}
						}

						if ($data->{f1}{ $h->{id} })
						{	## existing term
							if ($data->{f1}{$h->{id}}{def} && $h->{def} && $h->{def} ne $data->{f1}{ $h->{id} }{def})
							{	if ($h->{is_obsolete} && $h->{def} eq "OBSOLETE. " . $data->{f1}{$h->{id}}{def})
								{	## term has been obsoleted. Don't show.
								}
								else
								{	$data->{changed}{$h->{id}}++;
									$data->{f2}{$h->{id}} = $h;
								}
							}
						}
					}
				}
			}
		}
	}
	close(FH);

	print STDERR "Parsed " . $options->{f2} . "\nGathering results for printing...\n" if $options->{verbose};

#	print STDERR "data: " . Dumper($data) . "\n";
	if ($data->{changed})
	{	foreach my $id (sort keys %{$data->{changed}})
		{	print OUT "$id : " . $data->{f2}{$id}{name} . "\n";
			if ($data->{f1}{$id}{name} ne $data->{f2}{$id}{name})
			{	print OUT "   was " . $data->{f1}{$id}{name} . "\n";
			}
			print OUT "OLD: " . $data->{f1}{$id}{def} . "\nNEW: " . $data->{f2}{$id}{def} . "\n\n";
		}
	}
	close OUT;
}

# parse the options from the command line
sub parse_options {
	my $args = shift;

	my $opt;

	while (@$args && $args->[0] =~ /^\-/) {
		my $o = shift @$args;
		if ($o eq '-f1' || $o eq '--file_1' || $o eq '--file_one') {
			if (@$args && $args->[0] !~ /^\-/)
			{	$opt->{f1} = shift @$args;
			}
		}
		elsif ($o eq '-f2' || $o eq '--file_2' || $o eq '--file_two') {
			if (@$args && $args->[0] !~ /^\-/)
			{	$opt->{f2} = shift @$args;
			}
		}
		elsif ($o eq '-o' || $o eq '--output') {
			if (@$args && $args->[0] !~ /^\-/)
			{	$opt->{output} = shift @$args;
			}
		}
		elsif ($o eq '-h' || $o eq '--help') {
			system("perldoc", $0);
			exit(0);
		}
		elsif ($o eq '-v' || $o eq '--verbose') {
			$opt->{verbose} = 1;
		}
		else {
			die_msg( "Error: no such option: $o" );
		}
	}
	return check_options($opt);
}


# process the input params
sub check_options {
	my $opt = shift;
	my $errs;

	if (!$opt)
	{	die_msg( "Error: please ensure you have specified two input files, a subset, and an output file." );
	}

	foreach my $f qw(f1 f2)
	{	if (!$opt->{$f})
		{	push @$errs, "specify an input file using -$f /path/to/<file_name>";
		}
		elsif (! -e $opt->{$f})
		{	push @$errs, "the file " . $opt->{$f} . " could not be found.\n";
		}
		elsif (! -r $opt->{$f} || -z $opt->{$f})
		{	push @$errs, "the file " . $opt->{$f} . " could not be read.\n";
		}
	}

	if (!$opt->{output})
	{	push @$errs, "specify an output file using -o /path/to/<file_name>";
	}

	if ($errs && @$errs)
	{	die_msg( "Error: please correct the following parameters to run the script:\n" . ( join("\n", map { " - " . $_ } @$errs ) ) );
	}

	## quick 'diff' check of whether the files are identical or not
	my $cmd = "diff -w -q -i '" . $opt->{f1} . "' '" . $opt->{f2} . "'";

	my $status = `$cmd`;
	die "The two files specified appear to be identical!" if ! $status;

	if ($ENV{DEBUG})
	{	$opt->{verbose} = 1;
	}

	return $opt;
}

sub die_msg {
	my $msg =  shift || "";
	die join("\n", $msg, "The help documentation can be accessed with the command:\nobo-def-differ.pl --help\n");
}

=head1 AUTHOR

Amelia Ireland

=head1 SEE ALSO

L<GOBO::Graph>, L<GOBO::InferenceEngine>, L<GOBO::Doc::FAQ>

=cut
