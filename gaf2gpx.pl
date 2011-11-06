#!/sw/arch/bin/perl
# simple script to convert legacy GAF2.0 files into GPx format
#
use strict;
use warnings;

# hash that maps GO evidence codes to (reference-specific) ECO identifiers
my %ev2eco = (
	IEA	=> {
		'GO_REF:0000002' => 'ECO:0000256',
		'GO_REF:0000003' => 'ECO:0000265',
		'GO_REF:0000004' => 'ECO:0000203',
		'GO_REF:0000019' => 'ECO:0000265',
		'GO_REF:0000020' => 'ECO:0000256',
		'GO_REF:0000023' => 'ECO:0000203',
		'GO_REF:0000035' => 'ECO:0000265',
		default => 'ECO:0000203'
	},
	ND => { default => 'ECO:0000307' },
	EXP => { default => 'ECO:0000269' },
	IDA => { default => 'ECO:0000314' },
	IMP => { default => 'ECO:0000315' },
	IGI => { default => 'ECO:0000316' },
	IEP => { default => 'ECO:0000270' },
	IPI => { default => 'ECO:0000021' },
	TAS => { default => 'ECO:0000304' },
	NAS => { default => 'ECO:0000303' },
	IC => { default => 'ECO:0000305' },
	ISS => {
		'GO_REF:0000011' => 'ECO:0000255',
		'GO_REF:0000012' => 'ECO:0000031',
		'GO_REF:0000018' => 'ECO:0000031',
		'GO_REF:0000027' => 'ECO:0000031',
		default => 'ECO:0000250'
	},
	ISO => { default => 'ECO:0000266' },
	ISA => { default => 'ECO:0000247' },
	ISM => { default => 'ECO:0000255' },
	IGC	=> {
		'GO_REF:0000025' =>	'ECO:0000084',
		default => 'ECO:0000317'
	},
	IBA => { default => 'ECO:0000318' },
	IBD => { default => 'ECO:0000319' },
	IKR => { default => 'ECO:0000320' },
	IRD => { default => 'ECO:0000321' },
	RCA => { default => 'ECO:0000245' },
	IMR => { default => 'ECO:0000320' }
);

# hash containing the default relations for each ontology
my %default_relations = (
	P => 'participates_in',
	F => 'actively_participates_in',
	C => 'part_of'
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

sub process_gaf {
	my $gaf = shift;
	my $suffix = ($gaf =~ /gene_association\.(.+)/) ? $1 : "generic_suffix";

	my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0, 1, 2, 3, 4, 5];
	my $timestamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year + 1900, $month + 1, $day, $hour, $min, $sec);

	# open all files
	open (GAF, "<$gaf") or die "Unable to open $gaf for reading; aborting.\n";

	my $gpa = "gp_association.$suffix";
	open (GPA, ">$gpa") or die "Unable to open $gpa for writing; aborting.\n";
	print GPA "!gpa-version: 1.1\n";
	print GPA "!file generated at $timestamp from $gaf\n!\n";
	print GPA "!columns:\n";
	print GPA "!  # name                  required? cardinality   GAF column\n";
	print GPA "!  1 DB                    required  1              1\n";
	print GPA "!  2 DB_Object_ID          required  1              2\n";
	print GPA "!  3 Qualifier             optional  0 or greater   4\n";
	print GPA "!  4 Relation              required  1 or greater   -\n";
	print GPA "!  5 GO ID                 required  1              5\n";
	print GPA "!  6 DB:Reference(s)       required  1 or greater   6\n";
	print GPA "!  7 Evidence code         required  1              7\n";
	print GPA "!  8 With                  optional  0 or greater   8\n";
	print GPA "!  9 Interacting taxon ID  optional  0 or 1        13\n";
	print GPA "! 10 Date                  required  1             14\n";
	print GPA "! 11 Assigned_by           required  1             15\n";
	print GPA "! 12 Annotation Extension  optional  0 or greater  16\n";
	print GPA "! 13 Spliceform ID         optional  0 or 1        17\n";
	print GPA "!\n";

	my $gpi = "gp_information.$suffix";
	open (GPI, ">$gpi") or die "Unable to open $gpi for writing; aborting.\n";
	print GPI "!gpi-version: 1.0\n";
	print GPI "!file generated at $timestamp from $gaf\n!\n";
	print GPI "!columns:\n";
	print GPI "!  # name                   required? cardinality   GAF column\n";
	print GPI "!  1 DB                     required  1              1\n";
	print GPI "!  2 DB_Subset              optional  0 or 1         -\n";
	print GPI "!  3 DB_Object_ID           required  1              2\n";
	print GPI "!  4 DB_Object_Symbol       required  1              3\n";
	print GPI "!  5 DB_Object_Name         optional  0 or 1        10\n";
	print GPI "!  6 DB_Object_Synonym(s)   optional  0 or greater  11\n";
	print GPI "!  7 DB_Object_Type         required  1             12\n";
	print GPI "!  8 Taxon                  required  1             13\n";
	print GPI "!  9 Annotation_Target_Set  optional  0 or greater   -\n";
	print GPI "! 10 Annotation_Completed   optional  1              -\n";
	print GPI "! 11 Parent_Object_ID       optional  0 or 1         -\n";
	print GPI "!\n";

	my %metadata;

	while(<GAF>) {
		if (/^!/) {
			# ignore the file format tag
			next if (/^!\s*gaf-version:\s*((\d)(\.(\d))?)/);

			# pass all other comments through unchanged
			print GPA;
			next;
		};

		# tokenise line
		chomp;
		next if ($_ eq '');
		my ($db, $db_object_id, $db_object_symbol, $qualifier, $go_id, $reference, $evidence, $with, $aspect, $db_object_name, $db_object_synonym, $db_object_type, $taxon, $date, $assigned_by, $annotation_extension, $gene_product_form_id) = split(/\t/, $_);

		# translate the evidence code into the appropriate ECO identifier
		my $eco_id = $ev2eco{$evidence}{$reference};
		$eco_id = $ev2eco{$evidence}{'default'} if (!defined($eco_id));

		# translate any qualifier into the new qualifier + relation format
		my $qual = '';
		my $relation = '';
		if (defined($qualifier) && $qualifier ne '') {
			if ($qualifier =~ /^NOT(\|(contributes_to|colocalizes_with))?$/i) {
				$qual = 'NOT';
				if (defined($2)) {
					$relation = $2;
				}
			}
			else {
				if ($qualifier =~ /(contributes_to|colocalizes_with)/i) {
					$relation = $1;
				}
			}
		}
		if ($relation ne '') {
			$relation =~ s/contributes_to/contributes_to/i;
			$relation =~ s/colocalizes_with/colocalizes_with/i;
		}
		else {
			$relation = $default_relations{$aspect};
		}

		# extract interacting taxon id (if any)
		my $interacting_taxon = '';
		if ($taxon =~ /(taxon:[0-9]+)\|(taxon:[0-9]+)/) {
			$taxon = $1;
			$interacting_taxon = $2;
		}

		# stash away the gp metadata for later output in the gpi file - given the redundant nature of the data in the gaf, we only store the first occurrence of the metadata for any given gene product
		my $key = "$db:$db_object_id";
		if (!defined($metadata{$key})) {
				$metadata{$key} = [$db, $db_object_id, $db_object_symbol, $db_object_name, $db_object_synonym, $db_object_type, $taxon, ''];
		}
		if (defined($gene_product_form_id) && $gene_product_form_id ne '') {
			# store metadata for isoform
			if (!defined($metadata{$gene_product_form_id})) {
					my ($pre, $suf) = split /:/, $gene_product_form_id, 2;
					$metadata{$gene_product_form_id} = [$pre, $suf, $db_object_symbol, $db_object_name, $db_object_synonym, $db_object_type, $taxon, "$db:$db_object_id"];
			}
		}

		# output the annotation in gpa format
		print GPA "$db\t$db_object_id\t$qual\t$relation\t$go_id\t$reference\t$eco_id\t$with\t$interacting_taxon\t$date\t$assigned_by\t$annotation_extension\t$gene_product_form_id\n";
	}

	# dump the gpi file
	foreach my $key (sort keys %metadata) {
		my @md = @{$metadata{$key}};
		print GPI "$md[0]\t\t$md[1]\t$md[2]\t$md[3]\t$md[4]\t$md[5]\t$md[6]\t\t\t$md[7]\n";
	}

	# our work here is done...
	close GAF;
	close GPA;
	close GPI;
}

if ($#ARGV != 0) {
	print STDERR "Usage: perl ", __FILE__, " <gene_association_file>\n";
}
else {
	my ($gaf) = @ARGV;
	my ($format, $major, $minor) = get_file_format($gaf);
	die "The supplied file ($gaf) is not in GAF 2.0 format; aborting.\n" if (!defined($format) || ($format ne 'gaf' && $major == 2 && $minor == 0));
	process_gaf($gaf);
}
