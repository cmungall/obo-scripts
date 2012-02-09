#!/usr/bin/perl
# simple script to convert legacy GAF2.0 files into GPx format
#
#!/usr/bin/perl -w

=head1 NAME

gpx2gaf.pl

=head1 SYNOPSIS

 gpx2gaf.pl --gpad /path/to/gpad_file.gpad --gpi /path/to/gpi_file.gpi --ontology /path/to/ontology_file.obo --gaf /path/for/output_file.gaf

=head1 DESCRIPTION

Converts GPAD and GPI files into a GAF 2.0 file

=head2 Input parameters

=head3 Required

=over

=item -i | --input | --gaf /path/to/file_name

input GAF output file

=item --gpad /path/to/file_name

output annotation file, GPAD format

=item --gpi /path/to/file_name

output gene product info file, GPI format

=back

=head3 Optional switches

=over

=item -l || --log

Saves all errors to a log file; otherwise, errors are printed out to STDERR

=item -h || --help

This useful guide to what's going on!

=item -v || --verbose

prints various messages during the execution of the script

=back

=cut

use strict;
use warnings;
use Data::Dumper;

my $bin_dir;
my $dist_dir;

BEGIN {
	use Cwd;
	use File::Basename;
	$bin_dir = dirname(__FILE__);
	$bin_dir = Cwd::abs_path($bin_dir);
	($dist_dir = $bin_dir) =~ s/bin\/?$//;
}

use lib ($dist_dir, $bin_dir);

use GOBO::Logger;
use GOBO::AnnotationFormats qw(get_file_format get_gaf_spec get_gpi_spec get_gpad_spec transform can_transform write_errors);

my $logger;

my $gaf = get_gaf_spec();
my $gpi = get_gpi_spec();
my $gpad = get_gpad_spec();

run_script(\@ARGV);

exit(0);

sub run_script {

	my $options = parse_options(@_);
	$logger->info("Parsed options. Starting script!");

	## process 'n' print!
	process_gaf($options);

}

sub process_gaf {
	my $opt = shift;

	my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0, 1, 2, 3, 4, 5];
	my $timestamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year + 1900, $month + 1, $day, $hour, $min, $sec);

	# open all files
	open (GAF, "<" . $opt->{gaf}) or $logger->logdie("Unable to open " . $opt->{gaf} ." for reading: $!");

	open (GPAD, "> " . $opt->{gpad}) or $logger->logdie("Unable to open " . $opt->{gpad} . ": $!");
	open (GPI, "> " . $opt->{gpi}) or $logger->logdie("Unable to open " . $opt->{gpi} . ": $!");

	if ($opt->{'log'})
	{	open (my $log_fh, "> " . $opt->{'log'}) or $logger->logdie("Unable to open " . $opt->{gpi} . ": $!");
		$opt->{log_fh} = $log_fh;
	}

	print GPAD "!gpad-version: " . $gpad->{version}{major} . $gpad->{version}{minor} ."\n"
	. "!file generated at $timestamp from " . $opt->{gaf} . " by " . scr_name() . "\n!\n"
	.  "!columns:\n"
	.  "!" . join("\t", @{$gpad->{in_order}}) . "\n"
	.  "!\n";

	print GPI "!gpi-version: ". $gpi->{version}{major} . $gpi->{version}{minor} ."\n"
	.  "!file generated at $timestamp from " . $opt->{gaf} . " by " . scr_name() . "\n!\n"
	.  "!columns:\n"
	.  "!" . join("\t", @{$gpi->{in_order}}) . "\n"
	.  "!\n";

	my $metadata;
	my $errs;

	while(<GAF>) {
		next unless /\w/;
		if (/^!/) {
			# ignore the file format tag
			next if /^!\s*gaf-version:\s*((\d)(\.(\d))?)/;
			# pass all other comments through unchanged
			print GPAD;
			next;
		};

		# tokenise line
		chomp;
		my @gaf_line = split("\t", $_);
		## add sth to the beginning of the array so that the cols are correct
		unshift @gaf_line, "";

		my $id;
		my $parent;
		if (defined $gaf_line[ $gaf->{by_col}{gp_object_form_id} ] && $gaf_line[ $gaf->{by_col}{gp_object_form_id} ] =~ /\w/)
		{	## this is a spliceform
			if ($gaf_line[ $gaf->{by_col}{gp_object_form_id} ] =~ /[\|;, ]/)
			{	$logger->error("Found pipe in gp form id col " . $gaf_line[ $gaf->{by_col}{gp_object_form_id} ] . "! Skipping line.");
				next;
			}
			my ($db, $key) = split(/:/, $gaf_line[ $gaf->{by_col}{gp_object_form_id} ], 2);
			$parent = $gaf_line[ $gaf->{by_col}{db} ] . ":" . $gaf_line[ $gaf->{by_col}{db_object_id} ];

			## store this info in terms of parent and child relations
			$metadata->{parent_gp_id}{ $gaf_line[ $gaf->{by_col}{gp_object_form_id} ] }{$parent}++;
			$metadata->{child_gp_id}{ $parent }{ $gaf_line[ $gaf->{by_col}{gp_object_form_id} ] }++;

			$id = $gaf_line[ $gaf->{by_col}{gp_object_form_id} ];

			$logger->info("$id: this is a spliceform!");

			## do we want to save the data about the canon form?
			## no data about the parent
			if (! $metadata->{by_id}{$parent})
			{	## save this line
				@{$metadata->{parent_gaf_line}{$parent}} = map { $_ } @gaf_line;
			}

		}
		else
		{	$id = $gaf_line[ $gaf->{by_col}{db} ] . ":" . $gaf_line[ $gaf->{by_col}{db_object_id} ];
		}

		## process the GPI data
		if (! $metadata->{by_id}{ $id } )
		{	#my @gpi_line = ( ('') x ((scalar keys %{$gpi->{by_col}}) + 1) );

			my @gpi_line;
			my @parent_gpi_line;
#			$logger->info("getting GPI data for $id");
			foreach my $col (keys %{$gpi->{by_col}})
			{	## do we have this data?
				if ($gaf->{by_col}{ $col })
				{	$gpi_line[ $gpi->{by_col}{ $col } ] = $gaf_line[ $gaf->{by_col}{ $col } ] || '';

				}
				elsif (can_transform($col))
				{	## the data needs to be transformed
					$gpi_line[ $gpi->{by_col}{ $col } ] = transform( $col,
						id => $id,
						errs => \$errs,
						gaf_data => [ @gaf_line ],
					) || '';
				}
				else
				{	$errs->{gaf}{unknown_gpi_col}{$col}++;
					$gpi_line[ $gpi->{by_col}{ $col } ] = '';
				}
			}
			$metadata->{by_id}{$id} = \@gpi_line;
		}

		my @gpad_line;
#		my @gpad_line = ( ('') x ((scalar keys %{$gpad->{by_col}}) + 1) );
		## gather the data
		foreach my $col (keys %{$gpad->{by_col}})
		{	## do we have this data?
			if ($gaf->{by_col}{ $col })
			{	$gpad_line[ $gpad->{by_col}{ $col } ] = $gaf_line[ $gaf->{by_col}{ $col } ] || '';
			}
			elsif (can_transform($col))
			{	## the data needs to be transformed
				$gpad_line[ $gpad->{by_col}{ $col } ] = transform( $col,
					id => $id,
					errs => \$errs,
					gaf_data => [ @gaf_line ],
				#	logger => $logger,
				) || '';
			}
			else
			{	$errs->{gaf}{unknown_gpad_col}{$col}++;
				$gpad_line[ $gpad->{by_col}{ $col } ] = '';
			}
		}

		shift @gpad_line;
		#$logger->info("gpad_line: " . join("]\t[", @gpad_line));

		if (! $errs->{line_err})
		{	print GPAD join("\t", @gpad_line) . "\n";
		}
		else
		{	delete $errs->{line_err};
		}
	}

	close GAF;
	close GPAD;

	foreach my $child (keys %{$metadata->{parent_gp_id}})
	{	if (scalar keys %{$metadata->{parent_gp_id}{$child}} > 1)
		{	$logger->error("$child has " . (scalar keys %{$metadata->{parent_gp_id}{$child}}) . " parents!");
			## should we go back and alter which parent is used?
		}
	}

	# dump the gpi file
	## check on the parent IDs. If we didn't get info on them, we should copy
	## it from their children
	foreach my $parent (keys %{$metadata->{child_gp_id}})
	{	if (! $metadata->{by_id}{$parent})
		{	## create the data from the saved GAF line
			if (! $metadata->{parent_gaf_line}{$parent})
			{	$logger->error("No info for $parent! This should not have happened!");
				next;
			}

			my @parent_gaf_line;
			my @parent_gpi_line;
			foreach (@{$metadata->{parent_gaf_line}{$parent}})
			{	push @parent_gaf_line, $_;
			}
			$parent_gaf_line[ $gaf->{by_col}{gp_object_form_id} ] = '';

			foreach my $col (keys %{$gpi->{by_col}})
			{	## do we have this data?
				if ($gaf->{by_col}{ $col })
				{	$parent_gpi_line[ $gpi->{by_col}{ $col } ] = $parent_gaf_line[ $gaf->{by_col}{ $col } ] || '';
				}
				elsif (can_transform($col))
				{	## the data needs to be transformed
					$parent_gpi_line[ $gpi->{by_col}{ $col } ] = transform( $col,
						id => $parent,
						errs => \$errs,
						gaf_data => [ @parent_gaf_line ],
					) || '';
				}
				else
				{	$errs->{gaf}{unknown_gpi_col}{$col}++;
					$parent_gpi_line[ $gpi->{by_col}{ $col } ] = '';
				}
			}
			$metadata->{by_id}{ $parent } = \@parent_gpi_line;
		}
	}

	foreach my $id (sort keys %{$metadata->{by_id}})
	{	print GPI join("\t", @{$metadata->{by_id}{$id}}[1..$#{$metadata->{by_id}{$id}}]) . "\n";
	}

	# our work here is done...
	close GPI;

	if ($errs)
	{	write_errors( errs => $errs, options => $opt, logger => $logger );
	}

	if ($opt->{'log'})
	{	close $opt->{log_fh};
	}
}

# parse the options from the command line
sub parse_options {
	my ($args) = @_;
	my $errs;
	my $opt;
	while (@$args && $args->[0] =~ /^\-/) {
		my $o = shift @$args;
		if ($o eq '-i' || $o eq '--input' || $o eq '--gaf') {
			if (@$args && $args->[0] !~ /^\-/)
			{	$opt->{gaf} = shift @$args;
			}
		}
		elsif ($o eq '--gpi') {
			if (@$args && $args->[0] !~ /^\-/)
			{	$opt->{gpi} = shift @$args;
			}
		}
		elsif ($o eq '--gpad') {
			if (@$args && $args->[0] !~ /^\-/)
			{	$opt->{gpad} = shift @$args;
			}
		}
		elsif ($o eq '-l' || $o eq '--log') {
			if (@$args && $args->[0] !~ /^\-/)
			{	$opt->{'log'} = shift @$args;
			}
		}
		elsif ($o eq '-h' || $o eq '--help') {
			system("perldoc", $0);
			exit(0);
		}
		elsif ($o eq '-v' || $o eq '--verbose') {
			$opt->{verbose} = 1;
		}
		elsif ($o eq '--galaxy') {
			$opt->{galaxy} = 1;
		}
		else {
			push @$errs, "Ignored nonexistent option $o";
		}
	}

	return check_options($opt, $errs);
}




# process the input params
sub check_options {
	my ($opt, $errs) = @_;

	if (!$opt)
	{	GOBO::Logger::init_with_config( 'standard' );
		$logger = GOBO::Logger::get_logger();
		$logger->logdie("Error: please ensure you have specified a GAF input file and GPAD and GPI output files.\nThe help documentation can be accessed using the command\n\t" . scr_name() . " --help");
	}

	if (! $opt->{verbose})
	{	$opt->{verbose} = $ENV{GO_VERBOSE} || 0;
	}

	if ($opt->{galaxy})
	{	GOBO::Logger::init_with_config( 'galaxy' );
		#GOBO::Logger::init_with_config( 'verbose' );
		$logger = GOBO::Logger::get_logger();
	}
	elsif ($opt->{verbose} || $ENV{DEBUG})
	{	GOBO::Logger::init_with_config( 'verbose' );
		$logger = GOBO::Logger::get_logger();
	}
	else
	{	GOBO::Logger::init_with_config( 'standard' );
		$logger = GOBO::Logger::get_logger();
	}

	$logger->debug("args: " . Dumper($opt));

	if ($errs && @$errs)
	{	foreach (@$errs)
		{	$logger->error($_);
		}
	}
	undef $errs;

	foreach my $g qw(gpad gpi)
	{	if (!$opt->{$g})
		{	## no input
			push @$errs, "specify a " . $g . " format output file using --" . $g . " /path/to/file";
		}
		elsif ($opt->{$g} !~ /\.$g/i && ! $opt->{galaxy})
		{	$logger->info("Appending $g to " . $g . " file name");
			$opt->{$g} .= ".$g";
			$logger->info("file name: " . $opt->{$g});
		}
	}

	if ($opt->{galaxy} && ! $opt->{'log'})
	{	## we need a log file if we're in Galaxy mode
		push @$errs, "specify a log file if using the script in Galaxy mode";
	}

	if (! $opt->{gaf})
	{	## no input
		push @$errs, "specify a GAF format input file using -i /path/to/file";
	}
	else
	{	## check the file is ok
		if (! -e $opt->{gaf})
		{	push @$errs, "the file " . $opt->{gaf} . " could not be found.";
		}
		elsif (! -r $opt->{gaf} || -z $opt->{gaf})
		{	push @$errs, "the file " . $opt->{gaf} . " could not be read.";
		}
		my ($format, $major, $minor) = get_file_format($opt->{gaf});

		$logger->info("get_file_formats: format: " . ( $format||"undef") . "; major: " . ( $major||"undef") . "; minor: " . ($minor||"undef") ."\nData from spec: major: " . $gaf->{version}{major} . "; minor: " . $gaf->{version}{minor});

		if (! defined($format) || $format ne 'gaf' || $major ne $gaf->{version}{major} || $minor ne $gaf->{version}{minor})
		{	# push @$errs, $opt->{gaf} . " is not in GAF v" . $gaf->{version}{major} . $gaf->{version}{minor} . " format!";
		}
	}

	## end processing
	if ($errs && @$errs)
	{	$logger->logdie("Please correct the following parameters to run the script:\n" . ( join("\n", map { " - " . $_ } @$errs ) ) . "\nThe help documentation can be accessed with the command\n\t" . scr_name() . " --help");
	}

	return $opt;
}

## script name, minus path
sub scr_name {
	my $n = $0;
	$n =~ s/^.*\///;
	return $n;
}
