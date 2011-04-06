#!/usr/bin/perl -w

use strict;
my $idspace;
my $verbose;
my $filter_dangling = 1; # default
my $rel;
my $diffrel = "other_isa";
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '--rel') {
        $rel = shift;
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
# load files
# ----------------------------------------

my ($h1,$b1) = readfile(shift @ARGV);
my ($h2,$b2) = readfile(shift @ARGV);

# ----------------------------------------
# headers
# ----------------------------------------

foreach (@$h1) {
    print "$_\n" unless /^\s*$/;
}
print "subsetdef: unique_term1 \"unique to first ontology in comparison\"\n";
print "subsetdef: unique_term2 \"unique to first ontology in comparison\"\n";

foreach (@$h2) {
    if (/^(synonymtypedef|subsetdef)/) {
        print "$_\n";
    }
}
print "\n";

# ----------------------------------------
# write merged file
# ----------------------------------------

foreach my $k (%$b1) {
    my $v1 = $b1->{$k};
    my $v2 = $b2->{$k};
    foreach my $line (@$v1) {
        print "$line\n";
        if ($line =~ /^id:/) {
            if ($v2) {
                foreach my $line2 (@$v2) {
                    if ($line2 =~ /^is_a:\s*(\S+)(.*)/) {
                        print "relationship: $diffrel $1 $2\n";
                    }
                }
                delete $b2->{$k};
            }
            else {
                print "subset: unique_term1\n";
            }
        }
    }
}

# print any remaining entries from file 2
foreach my $k (%$b2) {
    my $v2 = $b2->{$k};
    foreach my $line (@$v2) {
        print "$line\n";
        if ($line =~ /^id:/) {
            print "subset: unique_term2\n";
        }
    }
}

print "\n[Typedef]\n";
print "id: $diffrel\n";
print "name: $diffrel\n";

exit 0;

# ----------------------------------------
# utils
# ----------------------------------------

sub readfile {
    my $fn = shift;
    my $hdr = 1;
    my $id = 0;
    open(F,$fn) || die $fn;
    my $block = [];
    my %bh = ();
    my @headers = ();

    while (<F>) {
        chomp;
        if (/^\[/) {
            $hdr = 0;
            $id = 0;
            $block = [];
        }
        if ($hdr) {
            push(@headers,$_);
        }
        else {
            if (/^id:\s*(\S+)/) {
                $id = $1;
                $bh{$id} = $block;
            }
            push(@$block,$_);
        }
    }
    close(F);
    return (\@headers,\%bh);
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}

sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [--rel DIFF-RELATION] FILE

Example:

$sn --rel is_a goche.obo chebi.obo > visualize-goche-chebi-diffs.obo

diffs relationships between two files and produces an obo file that
shows the differences in a way that can be visualized in oboedit

TODO:

currently only isa links are diffed

EOM
}

