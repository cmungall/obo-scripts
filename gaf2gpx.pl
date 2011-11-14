#!/usr/bin/perl
# simple script to convert legacy GAF2.0 files into GPx format
#
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
use GOBO::AnnotationFormats qw(get_file_format get_gaf_spec get_gpi_spec get_gpad_spec transform can_transform);

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
		unshift @gaf_line, "";
		my $id;
		if (defined $gaf_line[ $gaf->{by_col}{gp_form_id} ] && $gaf_line[ $gaf->{by_col}{gp_form_id} ] =~ /\w/)
		{	## this is a spliceform
			my ($db, $key) = split(/:/, $gaf_line[ $gaf->{by_col}{gp_form_id} ], 2);

			$metadata->{parent_gp_id}{ $gaf_line[ $gaf->{by_col}{gp_form_id} ] } = $gaf_line[ $gaf->{by_col}{db} ] . ":" . $gaf_line[ $gaf->{by_col}{db_object_id} ];
			$id = $gaf_line[ $gaf->{by_col}{gp_form_id} ];

			$logger->info("$id: this is a spliceform!");

		}
		else
		{	$id = $gaf_line[ $gaf->{by_col}{db} ] . ":" . $gaf_line[ $gaf->{by_col}{db_object_id} ];
		}

		## process the GPI data
		if (! $metadata->{by_id}{ $id })
		{	#my @gpi_line = ( ('') x ((scalar keys %{$gpi->{by_col}}) + 1) );
			my @gpi_line;
			$logger->info("getting GPI data for $id");

			foreach my $col (keys %{$gpi->{by_col}})
			{	$logger->info("GPI: looking at $col...");
				## do we have this data?
				if ($gaf->{by_col}{ $col })
				{	$gpi_line[ $gpi->{by_col}{ $col } ] = $gaf_line[ $gaf->{by_col}{ $col } ] || '';
				}
				elsif (can_transform($col))
				{	## the data needs to be transformed
					$gpi_line[ $gpi->{by_col}{ $col } ] = transform( $col,
						id => $id,
						logger => $logger,
						gaf_data => [ @gaf_line ],
					) || '';
				}
				else
				{	$errs->{gpi}{unknown_col}{$col}++;
					$logger->error("GPI: Don't know what to do with $col data!!");
					$gpi_line[ $gpi->{by_col}{ $col } ] = '';
				}
			}
			shift @gpi_line;
			$metadata->{by_id}{$id} = \@gpi_line;
			$logger->info("$id gpi_line: " . join(", ", @gpi_line));
		}

		my @gpad_line;
#		my @gpad_line = ( ('') x ((scalar keys %{$gpad->{by_col}}) + 1) );
		## gather the data
		foreach my $col (keys %{$gpad->{by_col}})
		{	#$logger->info("looking at $col...");
			## do we have this data?
			if ($gaf->{by_col}{ $col })
			{	$gpad_line[ $gpad->{by_col}{ $col } ] = $gaf_line[ $gaf->{by_col}{ $col } ] || '';
			}
			elsif (can_transform($col))
			{	## the data needs to be transformed
				$gpad_line[ $gpad->{by_col}{ $col } ] = transform( $col,
					id => $id,
					logger => $logger,
					gaf_data => [ @gaf_line ],
				) || '';
			}
			else
			{	$errs->{gpad}{unknown_col}{$col}++;
#				$logger->error("GPAD: Don't know what to do with $col data!!");
				$gpad_line[ $gpad->{by_col}{ $col } ] = '';
			}
		}

		shift @gpad_line;
		#$logger->info("gpad_line: " . join("]\t[", @gpad_line));

		print GPAD join("\t", @gpad_line) . "\n";
	}

	$logger->info("metadata: " . Dumper($metadata));
	# dump the gpi file
	foreach my $id (sort keys %{$metadata->{by_id}}) {
		my ($db, $key) = split(/:/, $id, 2);
		print GPI join("\t", @{$metadata->{by_id}{$id}}) . "\n";
	}

	# our work here is done...
	close GAF;
	close GPAD;
	close GPI;

	$logger->error( Dumper($errs) );
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
