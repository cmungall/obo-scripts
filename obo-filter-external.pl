#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $negate = 0;
my $typedef = 1;
my $show_header = 1;
my $idspace;
my $verbose;
my $xp2rel;
my $filter_dangling = 1;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '--xp2rel') {
        $xp2rel = 1; # now the default
    }
    elsif ($opt eq '--typedef') {
        $typedef = 1; # now the default
    }
    elsif ($opt eq '--no-typedef') {
        $typedef = 0;
    }
    elsif ($opt eq '--idspace') {
        $idspace = shift @ARGV;
    }
    elsif ($opt eq '--no-header') {
        $show_header = 0;
    }
    elsif ($opt eq '--verbose' || $opt eq '-v') {
        $verbose = 1;
    }
    elsif ($opt eq '-n' || $opt eq '--negate') {
        $negate = 1;
    }
    elsif ($opt eq '-t' || $opt eq '--tag') {
        $tag_h{shift @ARGV} = 1;
    }
    elsif ($opt eq '-') {
    }
    else {
        die "$opt";
    }
}
#if (!@ARGV) {
#    print usage();
#    exit 1;
#}

my %id2ns = ();

my @all_lines = ();
while (<>) {
    chomp;
    my $id;
    if (/^id:\s+(\S+)/) {
	$id = $1;
	$id2ns{"$id"} = 1;
	print STDERR "id: $id\n";
    }
    push(@all_lines,$_);
}

my @lines = ();
foreach (@all_lines) {
    chomp;

    if (!$idspace) {
	if (/^id:\s+(\S+):(\S+)/) {
	    $idspace = $1;
	}
    }
    push(@lines, $_);
    if (/^\s*$/) {
	export();
    }
}
export();
exit 0;

sub export {
    my $nox = 0;
    my @extra_rels = ();

    foreach (@lines) {
	my $orig = $_;
	s/\s*\!.*$//;
	s/\s+$//;
	my $fullx;
	my $x;
	if (/^intersection_of:\s+(\S+)\s+(\S+):(\S+)$/) {
	    $fullx = "$2:$3";
	    $x = $2;
	    push(@extra_rels, "relationship: $1 $2:$3");
	}
	elsif (/^intersection_of:\s+(\S+):(\S+)$/) {
	    $fullx = "$1:$2";
	    $x = $1;
	}

	if ($fullx && $fullx =~ /\^/) {
	    $fullx = '';
	}

	if (!$filter_dangling && $x && $x ne $idspace) {
	    $nox = 1;
	}
	if ($filter_dangling && $fullx && !$id2ns{$fullx}) {
	    $nox = 1;
	    if ($verbose) {
		print STDERR "dropping whole stanza, no $fullx\n";
	    }
	}
	$_ = $orig;
    }

    foreach (@lines) {
	my $orig = $_;
	s/\s*\!.*$//;
	s/\s+$//;
	my $filter = 0;
	my $x;
	my $fullx;
	if (/^disjoint_from:\s+(\S+):(\S+)$/) {
	    $x = $1;
	    $fullx = "$1:$2";
	}
#	elsif (/^relationship:\s+(\S+):(\S+)$/) {
#	    $x = $1;
#	    $fullx = "$1:$2";
#	}
	elsif (/^relationship:\s+(\S+)\s+(\S+):(\S+)$/) {
	    $x = $2;
	    $fullx = "$2:$3";
	}

	if (!$filter_dangling && $x && $x ne $idspace) {
	    $filter = 1;
	}
	if ($filter_dangling && $fullx && !$id2ns{$fullx}) {
	    $filter = 1;
	}
	if (/^intersection_of/) {
	    if ($nox) {
		$filter = 1;
	    }
	    else {
		print "$_\n" foreach @extra_rels;
		@extra_rels = ();
	    }
	}
	if ($verbose && $filter) {
	    print STDERR "Filtering: $orig [full: $fullx]\n";
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
$sn [-t tag]* [--no-header] FILE [FILE...]

strips all tags except selected

Example:

$sn  -t id -t xref gene_ontology.obo

EOM
}

