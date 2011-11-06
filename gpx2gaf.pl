#!/sw/arch/bin/perl
# simple script to convert GPx files into GAF 2.0 format
# note that this may result in data loss, as not everything that can represented in GPx format can be represented in GAF 2.0 format
#
# gpa columns:
#   # name                   required? cardinality   GAF column
#   1 DB                     required  1              1
#   2 DB_Object_ID           required  1              2
#   3 Qualifier              optional  0 or greater   4
#   4 Relation               required  1 or greater   -
#   5 GO ID                  required  1              5
#   6 DB:Reference(s)        required  1 or greater   6
#   7 Evidence code          required  1              7
#   8 With                   optional  0 or greater   8
#   9 Interacting taxon ID   optional  0 or 1        13
#  10 Date                   required  1             14
#  11 Assigned_by            required  1             15
#  12 Annotation Extension   optional  0 or greater  16
#  13 Spliceform ID          optional  0 or 1        17
#
# gpi columns:
#   # name                   required? cardinality   GAF column
#   1 DB                     required  1              1
#   2 DB_Subset              optional  0 or 1         -
#   3 DB_Object_ID           required  1              2
#   4 DB_Object_Symbol       required  1              3
#   5 DB_Object_Name         optional  0 or 1        10
#   6 DB_Object_Synonym(s)   optional  0 or greater  11
#   7 DB_Object_Type         required  1             12
#   8 Taxon                  required  1             13
#   9 Annotation_Target_Set  optional  0 or greater   -
#  10 Annotation_Completed   optional  1              -
#  11 Parent_Object_ID       optional  0 or 1         -
#
use strict;
use warnings;

# hash that maps ECO identifiers to GO evidence codes
my %eco2ev = (
	'ECO:0000314' => 'IDA',
	'ECO:0000316' => 'IGI',
	'ECO:0000315' => 'IMP',
	'ECO:0000021' => 'IPI',
	'ECO:0000031' => 'ISS',
	'ECO:0000084' => 'IGC',
	'ECO:0000317' => 'IGC',
	'ECO:0000203' => 'IEA',
	'ECO:0000319' => 'IBD',
	'ECO:0000321' => 'IRD',
	'ECO:0000320' => 'IKR',
	'ECO:0000245' => 'RCA',
	'ECO:0000247' => 'ISA',
	'ECO:0000250' => 'ISS',
	'ECO:0000255' => 'ISM',
	'ECO:0000256' => 'IEA',
	'ECO:0000265' => 'IEA',
	'ECO:0000266' => 'ISO',
	'ECO:0000269' => 'EXP',
	'ECO:0000270' => 'IEP',
	'ECO:0000303' => 'NAS',
	'ECO:0000304' => 'TAS',
	'ECO:0000305' => 'IC',
	'ECO:0000307' => 'ND',
	'ECO:0000318' => 'IBA',
);

# hash that maps relation to ontology and (where appropriate) the GAF 2.0 equivalent
my %relations = (
# cellular_component
	part_of => { aspect => 'C', gaf_equivalent => '' },
	colocalizes_with => { aspect => 'C', gaf_equivalent => 'colocalizes_with' },
	active_in => { aspect => 'C' },
	transported_by => { aspect => 'C' },
	posttranslationally_modified_in => { aspect => 'C' },
	located_in_other_organism => { aspect => 'C' },
	located_in_host => { aspect => 'C' },
	member_of => { aspect => 'C' },
	intrinsic_to => { aspect => 'C' },
	extrinsic_to => { aspect => 'C' },
	spans => { aspect => 'C' },
	partially_spans => { aspect => 'C' },
# molecular_function
	actively_participates_in => { aspect => 'F',  gaf_equivalent => '' },
	contributes_to => { aspect => 'F', gaf_equivalent => 'contributes_to' },
	functions_in_other_organism => { aspect => 'F' },
	functions_in_host => { aspect => 'F' },
	substrate_of => { aspect => 'F' },
# biological_process
	participates_in => { aspect => 'P', gaf_equivalent => '' }
);

sub get_file_format {
	my $f = shift;
	my ($format, $major, $minor);
	
	open (F, "<$f") or die "Unable to open $f for reading; aborting.\n";
	# loop until we find the first non-blank, non-comment line or a file format tag
	while (<F>) {
		chomp;
		if (/!\s*(gaf|gpa|gpi)-version:\s*((\d)(\.(\d))?)/) {
			$format = $1;
			$major = $3;
			$minor = $5;
			last;
		}
		last if ($_ ne '' && !/^!/);
	}
	close F;
	return ($format, $major, $minor);
}

sub read_gpi {
	my $gpi = shift;
	my %metadata;

	open (GPI, "<$gpi") or die "Unable to open $gpi for reading; aborting.\n";

	while(<GPI>) {
		chomp;
		next if (/^!/ || ($_ eq ''));

		my ($db, $db_subset, $db_object_id, $db_object_symbol, $db_object_name, $db_object_synonym, $db_object_type, $taxon, $annotation_target_set, $annotation_completed, $parent_object_id) = split(/\t/, $_);
		# stash away only those attributes that are supported by the GAF 2.0 format
		$metadata{"$db:$db_object_id"} = [$db, $db_object_id, $db_object_symbol, $db_object_name, $db_object_synonym, $db_object_type, $taxon];
	}
	close GPI;
	return \%metadata;
}

sub process_gpa {
	my ($gpa, $metadata) = @_;
	my $suffix = ($gpa =~ /gp_association\.(.+)/) ? $1 : "generic_suffix";

	my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0, 1, 2, 3, 4, 5];
	my $timestamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year + 1900, $month + 1, $day, $hour, $min, $sec);

	# open all files
	open (GPA, "<$gpa") or die "Unable to open $gpa for reading; aborting.\n";

	my $gaf = "gene_association.$suffix";
	open (GAF, ">$gaf") or die "Unable to open $gaf for writing; aborting.\n";
	print GAF "!gaf-version: 2.0\n";
	print GAF "!file generated at $timestamp from $gpa\n!\n";

	my $log = "gpx2gaf_log.$suffix";
	open (LOG, ">$log") or die "Unable to open $log for writing; aborting.\n";

	my $line_number = 0;
	while (<GPA>) {
		$line_number++;

		if (/^!/) {
			# ignore the file format tag
			next if (/^!\s*gpa-version:\s*((\d)(\.(\d))?)/);

			# pass all other comments through unchanged
			print GAF;
			next;
		};

		# tokenise line
		chomp;
		next if ($_ eq '');
		my ($db, $db_object_id, $qualifier, $relation, $go_id, $reference, $evidence_code, $with, $interacting_taxon, $date, $assigned_by, $annotation_extension, $spliceform_id) = split(/\t/, $_);

		# get the appropriate set of metadata
		my $key = (defined($spliceform_id) && $spliceform_id ne '') ? $spliceform_id : "$db:$db_object_id";
		if (!defined($metadata->{$key})) {
			print LOG "$gpa ($line_number): metadata not found for $key\n";
			next;
		}
		my @md = @{$metadata->{$key}}; # $md[0] = db, $md[1] = db_object_id, $md[2] = db_object_symbol, $md[3] = db_object_name, $md[4] = db_object_synonym, $md[5] = db_object_type, $md[6] = taxon

		# translate ECO id to GO evidence code
		my $ev = $eco2ev{$evidence_code};
		if (!defined($ev)) {
			print LOG "$gpa ($line_number): unsupported/unrecognised evidence code ($evidence_code)\n";
			next;
		}

		# deal with qualifier, relation and aspect
		my ($aspect, $qual);
		foreach my $rel (keys %relations) {
			if ($relation =~ /^$rel$/) {
				$aspect = $relations{$rel}{aspect};
				$qual = $relations{$rel}{gaf_equivalent};
				last;
			}
		}
		if (!defined($aspect)) {
			print LOG "$gpa ($line_number): unsupported/unrecognised relation ($relation)\n";
			next;
		}
		if (!defined($qual)) {
			print LOG "$gpa ($line_number): relation not supported in GAF 2.0 format ($relation)\n";
			next;
		}

		if ($qualifier eq 'NOT') {
			$qual = ($qual eq '') ? $qualifier : "$qualifier|$qual";
		}

		# interacting taxon
		my $tax = (defined($interacting_taxon) && $interacting_taxon ne '') ? "$md[6]|$interacting_taxon" : $md[6];

		# output the annotation in GAF 2.0 format
		print GAF "$db\t$db_object_id\t$md[2]\t$qual\t$go_id\t$reference\t$ev\t$with\t$aspect\t$md[3]\t$md[4]\t$md[5]\t$tax\t$date\t$assigned_by\t$annotation_extension\t$spliceform_id\n";
	}

	# all done
	close GPA;
	close GAF;
	close LOG;
}

if ($#ARGV != 1) {
	print STDERR "Usage: perl ", __FILE__, " <gpa_file> <gpi_file>\n";
}
else {
	my ($gpa, $gpi) = @ARGV;
	my ($format, $major, $minor) = get_file_format($gpa);
	die "$gpa is not in GPA 1.1 format; aborting.\n" if (!defined($format) || ($format ne 'gpa' && $major == 1 && $minor == 1));

	($format, $major, $minor) = get_file_format($gpi);
	die "$gpi is not in GPI 1.0 format; aborting.\n" if (!defined($format) || ($format ne 'gpi' && $major == 1 && $minor == 0));

	process_gpa($gpa, read_gpi($gpi));
}
