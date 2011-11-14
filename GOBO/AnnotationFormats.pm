package GOBO::AnnotationFormats;

use strict;
use warnings;
use Data::Dumper;
use base 'Exporter';
our @EXPORT = qw(get_file_format get_gpi_spec get_gaf_spec get_gpad_spec transform can_transform);

=head2 GPI fields

Content	 Required?	 Cardinality	 Example
DB	 required	 1	 UniProtKB
DB Object ID	 required	 1	 P12345
DB Object Symbol	 required	 1	 PHO3
DB Object Name	 optional	 0 or 1	 Toll-like receptor 4
DB Object Synonym	 optional	 0+, pipe-separated	 hToll|Tollbooth
DB Object Type	 required	 1	 protein
Taxon	 required	 1	 taxon:9606
Parent GP ID	 optional	 0 or 1
External GP xrefs	 optional	 0+, pipe-separated	 UniProtKB:P12345

=cut

my $gpi = {
	version => {
		major => '1',
		minor => '.0',
	},
	by_col => {
		db => 1,
		db_gp_form_id => 2,
		db_object_symbol => 3,
		db_object_name => 4,
		db_object_synonym => 5,
		db_object_type => 6,
		taxon => 7,
		parent_gp_id => 8,
		gp_xrefs => 9,
	},
	in_order => [
	qw( db
		db_gp_form_id
		db_object_symbol
		db_object_name
		db_object_synonym
		db_object_type
		taxon
		parent_gp_id
		gp_xrefs )
	],
};

sub get_gpi_spec {
	return $gpi;
}

=head2 GPAD fields

Content	 Required?	 Cardinality	 Example
DB	 required	 1	 UniProtKB
DB Object ID	 required	 1	 P12345
Relationship	 required	 1	NOT part of
GO ID	 required	 1	 GO:0003993
Reference(s)	 required	 1 or greater	 PMID:2676709
Evidence Code ID	 required	 1	ECO:0000315
With (or) From	 optional	 0 or greater	 GO:0000346
Interacting taxon	 optional	 0 or 1	 9606
Date	 required	 1	 20090118
Assigned By	 required	 1	 SGD
Annotation XP	 optional	 0 or greater	part_of(CL:0000576)

=cut
my $gpad = {
	version => {
		major => '1',
		minor => '.0',
	},
	by_col => {
		db => 1,
		db_gp_form_id => 2,
		relationship => 3,
		go_id => 4,
		reference => 5,
		eco_id => 6,
		with_from => 7,
		interacting_taxon => 8,
		date => 9,
		assigned_by => 10,
		annotation_xp => 11,
	},
	in_order => [
	qw( db
		db_gp_form_id
		relationship
		go_id
		reference
		eco_id
		with_from
		interacting_taxon
		date
		assigned_by
		annotation_xp )
	],
};

sub get_gpad_spec {
	return $gpad;
}

=head2 GAF 2.0 fields

Column	 Content	 Required?	 Cardinality	 Example
1	DB	 required	 1	 UniProtKB
2	DB Object ID	 required	 1	 P12345
3	DB Object Symbol	 required	 1	 PHO3
4	Qualifier	 optional	 0 or greater	NOT
5	GO ID	 required	 1	 GO:0003993
6	DB:Reference (|DB:Reference)	 required	 1 or greater	 PMID:2676709
7	Evidence Code	 required	 1	IMP
8	With (or) From	 optional	 0 or greater	 GO:0000346
9	Aspect	 required	 1	 F
10	DB Object Name	 optional	 0 or 1	 Toll-like receptor 4
11	DB Object Synonym (|Synonym)	 optional	 0 or greater	 hToll|Tollbooth
12	DB Object Type	 required	 1	 protein
13	Taxon(|taxon)	 required	 1 or 2	 taxon:9606
14	Date	 required	 1	 20090118
15	Assigned By	 required	 1	 SGD
16	Annotation Extension	 optional	 0 or greater	part_of(CL:0000576)
17	Gene Product Form ID	 optional	 0 or 1	 UniProtKB:P12345-2

=cut

my $gaf = {
	version => {
		major => '2',
		minor => '.0',
	},
	by_col => {
		db => 1,
		db_object_id => 2,
		db_object_symbol => 3,
		qualifier => 4,
		go_id => 5,
		reference => 6,
		evidence_code => 7,
		with_from => 8,
		aspect => 9,
		db_object_name => 10,
		db_object_synonym => 11,
		db_object_type => 12,
		taxon_int_taxon => 13,
		date => 14,
		assigned_by => 15,
		annotation_xp => 16,
		gp_form_id => 17,
	},
	in_order => [
	qw( db
		db_object_id
		db_object_symbol
		qualifier
		go_id
		reference
		evidence_code
		with_from
		aspect
		db_object_name
		db_object_synonym
		db_object_type
		taxon_int_taxon
		date
		assigned_by
		annotation_xp
		gp_form_id )
	],
};

sub get_gaf_spec {
	return $gaf;
}


sub get_file_format {
	my $f = shift;
	my ($format, $major, $minor);

	open (F, "< $f") or die "Unable to open $f for reading: $!";
	# loop until we find the first non-blank, non-comment line or a file format tag
	while (<F>) {
		next unless /\w/;
		if (/!\s*(gaf|gpad|gpi)-version:\s*((\d)(\.(\d))?)/) {
#			print STDERR "Found $_!\n";
			$format = $1;
			$major = $3;
			$minor = $4 || '.0';  ## hack due to Perl's stupidity with zeroes.
			last;
		}
		last if $_ !~ /^!/;
	}
	close F;
	return ($format, $major, $minor);
}

## Stuff for the conversion of GPAD + GPI => GAF 2.0
# hash that maps ECO identifiers to GO evidence codes
my $eco2ev = {
	'ECO:0000021' => 'IPI',
	'ECO:0000031' => 'ISS',
	'ECO:0000084' => 'IGC',
	'ECO:0000203' => 'IEA',
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
	'ECO:0000314' => 'IDA',
	'ECO:0000315' => 'IMP',
	'ECO:0000316' => 'IGI',
	'ECO:0000317' => 'IGC',
	'ECO:0000318' => 'IBA',
	'ECO:0000319' => 'IBD',
	'ECO:0000320' => 'IKR',
	'ECO:0000321' => 'IRD',
};


# hash that maps relation to ontology and (where appropriate) the GAF 2.0 equivalent
my $rln2qual = {
	contributes_to => 'contributes_to',
	colocalizes_with => 'colocalizes_with',
	'not' => 'NOT',
};

# hash that maps GO evidence codes to (reference-specific) ECO identifiers
my $ev2eco = {
	IEA => {
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
	IGC => {
		'GO_REF:0000025' =>	'ECO:0000084',
		default => 'ECO:0000317'
	},
	IBA => { default => 'ECO:0000318' },
	IBD => { default => 'ECO:0000319' },
	IKR => { default => 'ECO:0000320' },
	IRD => { default => 'ECO:0000321' },
	RCA => { default => 'ECO:0000245' },
	IMR => { default => 'ECO:0000320' }
};

# hash containing the default relations for each ontology
my $aspect2rln = {
	P => 'actively_participates_in',
	F => 'actively_participates_in',
	C => 'part_of',
	default => 'annotated_to',
};

my $qual_order = [
	'NOT',
	'colocalizes_with',
	'contributes_to',
];

# hash that maps relation to ontology and (where appropriate) the GAF 2.0 equivalent
my $relations = {
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
#	actively_participates_in => { aspect => 'F',  gaf_equivalent => '' },
	contributes_to => { aspect => 'F', gaf_equivalent => 'contributes_to' },
	functions_in_other_organism => { aspect => 'F' },
	functions_in_host => { aspect => 'F' },
	substrate_of => { aspect => 'F' },
# biological_process
#	actively_participates_in => { aspect => 'P', gaf_equivalent => '' }
};

my $transforms = {
	## GPAD int taxon + GPI taxon => GAF taxon int taxon
	'taxon_int_taxon' => sub {
		my %args = (@_);
		## concatenate gpi taxon and gpad int_taxon
		if ($args{gpad_data}->[ $gpad->{by_col}{interacting_taxon} ] ne "")
		{	#print STDERR "gpad data, interacting taxon: " . $args{gpad_data}->[ $gpad->{by_col}{interacting_taxon} ] . "\n";
			return join('|', map { "taxon:$_" } ($args{gpi_data}->[ $gpi->{by_col}{taxon} ], $args{gpad_data}->[ $gpad->{by_col}{interacting_taxon} ]) );
		}
		else
		{	return "taxon:" . $args{gpi_data}->[ $gpi->{by_col}{taxon} ];
		}
	},
	'aspect' => sub {
		my %args = (@_);
		## find out the term and get the ontology data
		## could also add something here to get this data from the relationship

		if (defined $args{ontology}->{ $args{gpad_data}->[$gpad->{by_col}{go_id}] })
		{	return $args{ontology}->{ $args{gpad_data}->[$gpad->{by_col}{go_id}] };
		}
		else
		{	$args{logger}->error("No namespace for " . $args{gpad_data}->[$gpad->{by_col}{go_id}]);
			return "";
		}
	},
	'evidence_code' => sub {
		my %args = (@_);
		## check our ECO ID and find what it translates into
		if ( $eco2ev->{ $args{gpad_data}->[ $gpad->{by_col}{eco_id} ] })
		{	return $eco2ev->{ $args{gpad_data}->[ $gpad->{by_col}{eco_id} ]};
		}
		else
		{	$args{logger}->error("No mapping for " . $args{gpad_data}->[ $gpad->{by_col}{eco_id} ]);
			return "";
		}
	},
	'qualifier' => sub {
		my %args = (@_);
		## check our relations and see how many we can translate back into GAF 2.0 language
		my @rlns = split(/[ \|]/, $args{gpad_data}->[ $gpad->{by_col}{relationship} ]);
		my $qual;
		foreach (@rlns)
		{	if ($rln2qual->{$_})
			{	push @$qual, $rln2qual->{$_};
			}
		}

		if ($qual && @$qual)
		{	return join('|', @$qual);
		}
		return '';
	},
	'gp_form_id' => sub {
		my %args = (@_);
		if ($args{parent} =~ /\w/)
		{	## get the by_child_id data
#			print STDERR "id: $args{id}; by_child_id data: " . Dumper($args{metadata}->{by_child_id}{ $args{id} });
#			print STDERR "gpi data: " . Dumper($args{gpi_data}) . "Looking at cols " . $gpi->{by_col}{db} . " and " . $gpi->{by_col}{db_gp_form_id}. "\n";
			return $args{id};
		}
		return;
	},
	'db_object_id' => sub {
		my %args = (@_);
		##
		if ($args{parent} =~ /\w/)
		{	## put in the parent id
			my ($db, $ref) = split /:/, $args{parent}, 2;
			return $ref;
		}
		else
		{	return $args{gpi_data}->[ $gpi->{by_col}{db_gp_form_id} ];
		}
	},

	## GAF => GPAD + GPI
	'taxon' => sub {
		my %args = (@_);
		## split up the taxon and interacting taxon
		my @taxa = map { s/taxon://g; $_ } split(/\|/, $args{gaf_data}->[ $gaf->{by_col}{taxon_int_taxon} ]);
#		print STDERR "taxa: " . Dumper(\@taxa);
		return $taxa[0];
	},
	'interacting_taxon' => sub {
		my %args = (@_);
		## split up the taxon and interacting taxon
		my @taxa = map { s/taxon://g; $_ } split(/\|/, $args{gaf_data}->[ $gaf->{by_col}{taxon_int_taxon} ]);
#		print STDERR "taxa: " . Dumper(\@taxa);
		return $taxa[1] || '';
	},
	'eco_id' => sub {
		my %args = (@_);
		my $ev = $args{gaf_data}->[ $gaf->{by_col}{evidence_code} ];
		my $ref = $args{gaf_data}->[ $gaf->{by_col}{reference} ];

#		print STDERR "ev: " . ($ev||"undef") . "; ref: " . ($ref||"undef") . "\n";
		# translate the evidence code into the appropriate ECO identifier
		return $ev2eco->{$ev}{$ref} || $ev2eco->{$ev}{'default'};
	},
	'relationship' => sub {
		my %args = (@_);
		my @quals = split(/\|/, $args{gaf_data}->[ $gaf->{by_col}{qualifier} ]);
		my @rlns;
		if (@quals)
		{	## need to sort these!!
			foreach my $q (@$qual_order)
			{	if (grep { /^$q$/i } @quals)
				{	push @rlns, $q;
					last if scalar @quals == 1;
				}
			}
		}

		## get the term aspect and add the relationship
		if (! $aspect2rln->{ $args{gaf_data}->[ $gaf->{by_col}{aspect} ] })
		{	$args{logger}->error("Invalid aspect: " . $args{gaf_data}->[ $gaf->{by_col}{aspect} ]);
			push @rlns, $aspect2rln->{ 'default' };
		}
		else
		{	push @rlns, $aspect2rln->{ $args{gaf_data}->[ $gaf->{by_col}{aspect} ] };
		}
		return join('|', @rlns);
	},
	'parent_gp_id' => sub {
		my %args = (@_);
		if ($args{gaf_data}->[ $gaf->{by_col}{gp_form_id} ])
		{	## this is a spliceform
			return $args{gaf_data}->[ $gaf->{by_col}{db} ].":".$args{gaf_data}->[ $gaf->{by_col}{db_object_id} ];
		}
		return '';
	},
	'db_gp_form_id' => sub {
		my %args = (@_);
		if ($args{gaf_data}->[ $gaf->{by_col}{gp_form_id} ])
		{	## remove the db, return
			my ($db, $key) = split /:/, $args{gaf_data}->[ $gaf->{by_col}{gp_form_id} ], 2;
			if ($key)
			{	return $key;
			}
		}
		return $args{gaf_data}->[ $gaf->{by_col}{db_object_id} ];
	},
};

sub transform {
	my $tfm = shift;
	if (! $transforms->{$tfm})
	{	warn "$tfm: no such transform!";
		return;
	}
	return $transforms->{$tfm}(@_);
}

sub can_transform {
	my $tfm = shift;

#	print STDERR "possible transforms: " . join(", ", keys %$transforms) . "\n\n";
	return 1 if $transforms->{$tfm};
	return;
}

1;
