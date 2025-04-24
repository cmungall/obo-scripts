#!/usr/bin/perl -w

use strict;
use FileHandle;
my $outdir = "terms";
my $cmd;
my $dry_run = 0;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '-d' || $opt eq '--outdir') {
        $outdir = shift @ARGV;
    }
    if ($opt eq '-n' || $opt eq '--dry-run') {
        $dry_run = 1;
    }
}
`mkdir -p $outdir`;
my $id;
my $stanza = "";
my @alt_ids = ();
my $fn = shift @ARGV;
# ensure ids are sorted
my @ids = sort @ARGV;

my %new_stanza_map = ();

foreach my $id (@ids) {
    my $path = get_path($id);
    open(F, $path) || die "no such file $path";
    my $stanza = "";
    while(<F>) {
        chomp;
        $stanza .= "$_\n";
    }
    close(F);
    if ($stanza =~ /id: (\S+)/) {
        # check id matches
        if ($1 ne $id) {
            die "id mismatch $1 ne $id";
        }
    }
    else {
        die "no id found in $path";
    }
    $new_stanza_map{$id} = $stanza;
}

open(W, ">$fn.tmp") || die "cannot write tp $fn.tmp";

my %stanza_map = ();
my %stanza_type_map = (); # To track stanza type (Term or Typedef)
$/ = "\n\n";
open(F, $fn) || die "cannot open $fn";
while(<F>) {
    if ($_ =~ /id: (\S+)/) {
        my $id = $1;
        $stanza_map{$id} = $_;
        
        # Determine stanza type
        if ($_ =~ /\[(\w+)\]/) {
            $stanza_type_map{$id} = $1;
        }
        else {
            # Default to Term if type not specified
            $stanza_type_map{$id} = "Term";
        }
    }
    else {
        print W $_;
    }
}
close(F);

# combine old and new stanzas
foreach my $id (sort keys %new_stanza_map) {
    $stanza_map{$id} = $new_stanza_map{$id};
    
    # Update stanza type for new stanzas
    if ($new_stanza_map{$id} =~ /\[(\w+)\]/) {
        $stanza_type_map{$id} = $1;
    }
    else {
        # Default to Term if type not specified
        $stanza_type_map{$id} = "Term";
    }
}

# Sort ids by stanza type (Term first, then Typedef) and then alphabetically within each type
my @sorted_ids = sort {
    # First compare stanza types (Term comes before Typedef)
    my $type_compare = ($stanza_type_map{$a} eq "Typedef") <=> ($stanza_type_map{$b} eq "Typedef");
    
    # If same type, sort alphabetically by ID
    return $type_compare || $a cmp $b;
} keys %stanza_map;

foreach my $id (@sorted_ids) {
    print W $stanza_map{$id};
}
close(W);

if ($dry_run) {
    print "dry run, no changes made\n";
}
else {
    `mv $fn.tmp $fn`;
    # clear out @ids from $outdir
    foreach my $id (@ids) {
        my $path = get_path($id);
        unlink $path;
    }
}

sub get_path {
    my ($id) = @_;
    my $fn = "$id";
    $fn =~ s@:@_@;
    return "$outdir/$fn.obo"
    
}

sub w {
    my ($id, $stanza) = @_;
    my $path = get_path($id);
    open(F, ">$path") || die($path);
    print F $stanza;
    close(F)
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [-s chunksize] [-x COMMAND \;] OBO-FILES

Splits obo file into stanzas

Example:

$sn -d terms chebi.obo 

EOM
}

