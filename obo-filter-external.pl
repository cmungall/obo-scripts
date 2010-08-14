#!/usr/bin/perl -w

use strict;
my $idspace;
my $verbose;
my $filter_dangling = 1; # default
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '--xp2rel') {
	# default
    }
    elsif ($opt eq '--idspace') {
        $idspace = shift @ARGV;
    }
    elsif ($opt eq '--verbose' || $opt eq '-v') {
        $verbose = 1;
    }
    elsif ($opt eq '-') {
    }
    else {
        die "$opt";
    }
}

# ----------------------------------------
# load all lines
# ----------------------------------------

my %id2ns = ();
my @all_lines = ();
while (<>) {
    s/\s+$//;
    chomp;
    my $id;
    if (/^id:\s+(\S+)/) {
	$id = $1;
	$id2ns{"$id"} = 1;
	#print STDERR "id: '$id'\n";
    }
    push(@all_lines,$_);
}

# ----------------------------------------
# process all lines
# ----------------------------------------

my @lines = ();
foreach (@all_lines) {
    chomp;

    if (!$idspace) {
	if (/^id:\s+(\S+):(\S+)/) {
	    $idspace = $1;
	}
    }
    # buffer
    push(@lines, $_);

    # assumes double-newline between stanzas
    if (/^\s*$/) {
	export();
    }
}
export();
exit 0;

# ----------------------------------------
# rewrite stanza
# ----------------------------------------
sub export {
    my $remove_xp_lines = 0;
    my @extra_rels = ();

    # pre-process xps: all xp lines must be treated together
    foreach (@lines) {
	my $orig = $_;
	s/\s*\!.*$//; # remove comments
	s/\s*\{.*$//; # remove qualifiers
	s/\s+$//;

        # check for external references
	my $global_id; # e.g. GO:0000123
	my $id_prefix;     # e.g. GO
	if (/^intersection_of:\s+(\S+)\s+(\S+):(\S+)$/) {
            my $rel = $1;
	    $global_id = "$2:$3";
	    $id_prefix = $2;
	    # if an xp def is dropped, keep rels
	    push(@extra_rels, "relationship: $rel $global_id");
	}
	elsif (/^intersection_of:\s+(\S+):(\S+)$/) {
	    $global_id = "$1:$2";
	    $id_prefix = $1;
	}

	if ($global_id && $global_id =~ /\^/) {
	    $global_id = ''; # anon 
	}

	if ($id_prefix && $id_prefix ne $idspace) {
	    $remove_xp_lines = 1;
	    if ($verbose) {
		print STDERR "dropping all intersection_of tags, $id_prefix != $idspace\n";
	    }
	}
	if ($filter_dangling && $global_id && !$id2ns{$global_id}) {
	    $remove_xp_lines = 1;
	    if ($verbose) {
		print STDERR "dropping all intersection_of tags, $global_id is a dangling ref\n";
	    }
	}
	$_ = $orig;
    }

    # now write all lines apart from filtered ones
    foreach (@lines) {
	my $orig = $_;
	s/\s*\!.*$//;
	s/\s*\{.*$//;
	s/\s+$//;
	my $filter = 0;
	my $id_prefix;
	my $global_id;
	if (/^disjoint_from:\s+(\S+):(\S+)$/) {
	    $id_prefix = $1;
	    $global_id = "$1:$2";
	}
#	elsif (/^relationship:\s+(\S+):(\S+)$/) {
#	    $id_prefix = $1;
#	    $global_id = "$1:$2";
#	}
	elsif (/^relationship:\s+(\S+)\s+(\S+):(\S+)$/) {
	    $id_prefix = $2;
	    $global_id = "$2:$3";
	}
	elsif (/^is_a:\s+(\S+):(\S+)$/) {
	    $id_prefix = $1;
	    $global_id = "$1:$2";
	}

	if ($id_prefix && $id_prefix ne $idspace) {
	    $filter = 1;
	    if ($verbose) {
		print STDERR "Filtering ref to external ($id_prefix): $orig\n";
	    }
	}
	if ($filter_dangling && $global_id && !$id2ns{$global_id}) {
	    $filter = 1;
	    if ($verbose) {
		print STDERR "Filtering dangling ref: $orig\n";
	    }
	}
	if (/^intersection_of/) {
	    if ($remove_xp_lines) {
		$filter = 1;
	    }
	    else {
		print "$_\n" foreach @extra_rels;
		@extra_rels = ();
	    }
	}
	if ($verbose && $filter) {
	    print STDERR "Filtering: $orig [full: $global_id] idspace:$id_prefix\n";
	}
	print "$orig\n" unless $filter;
    }
    @lines = ();
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [--idspace IDSPACE] FILE

strips all tags except selected

Example:

$sn  -t id -t xref gene_ontology.obo

EOM
}

