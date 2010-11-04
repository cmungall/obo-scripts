#!/usr/bin/perl -w

use strict;
my $verbose;
my $silent = 0;
my $kcol = 0;
my $vcol = 0;
my $filter_unmapped = 0;
my $bin_id;
my $bin_go_terms;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '-s' || $opt eq '--silent') {
        $silent = 1;
    }
    elsif ($opt eq '-v' || $opt eq '--verbose') {
        $verbose = 1;
    }
    elsif ($opt eq '-x' || $opt eq '--filter') {
        $filter_unmapped = 1;
    }
    elsif ($opt eq '-b' || $opt eq '--bin') {
        $filter_unmapped = 1;
        $bin_id = shift @ARGV;
    }
    elsif ($opt eq '--bin-go-terms') {
        $filter_unmapped = 1;
        $bin_go_terms = 1;
    }
    elsif ($opt eq '-k' || $opt eq '--col') {
        $kcol = shift @ARGV;
        if ($kcol =~ /(\d+),(\d+)/) {
            $kcol = $1;
            $vcol = $2;
        }
        else {
            $vcol = $kcol;
        }
    }
}

if (!@ARGV) {
    print usage();
    exit 0;
}

my @mapfiles = (shift @ARGV);

my @inputfiles = @ARGV;

# build map
my %idmap = ();
foreach my $mapfile (@mapfiles) {
    open(F,$mapfile) || die $mapfile;
    while (<F>) {
        chomp;
        next if /^\!/;
        my @vals = split(/\t/,$_);

        # try and guess columns
        if (!$kcol) {
            if (scalar(@vals) == 1) {
                # GUESS: filter
                $kcol = 1;
                $vcol = 1; # filter file
                $filter_unmapped = 1;
            }
            elsif (scalar(@vals) == 2) {
                if ($filter_unmapped) {
                    $kcol = 1;
                    $vcol = 1;
                }
                else {
                    # GUESS: 2 column mapping file
                    $kcol = 1;
                    $vcol = 2;
                }
            }
            else {
                for (my $i=0; $i<scalar(@vals); $i++) {
                    if ($vals[$i] =~ /^(\S+):(\S+)/) {
                        if (!$kcol) {
                            $kcol = $i+1;
                        }
                        elsif (!$vcol) {
                            if (!$filter_unmapped) {
                                $vcol = $i+1;
                            }
                        }
                        else {
                        }
                    }
                }
            }
        } # -- end of guessing

        if (!$vcol) {
            die "cannot guess";
        }
        if (!$kcol) {
            die "cannot guess";
        }

        #print STDERR "$kcol => $vcol\n";
        my $v = (scalar(@vals) < $vcol) ? $vals[$kcol-1] : $vals[$vcol-1];
        push(@{$idmap{$vals[$kcol-1]}}, $v);
    }
    close(F);
}

# now perform mappings on the main file
my $n = 0;
my @hdr = ();
my @out = ();
foreach my $f (@inputfiles) {
    open(F,$f) || die $f;
    while (<F>) {
        chomp;
        my @vals = split(/\t/,$_);
        my $v = $vals[4];
        if (!$v) {
            # probably in header..
            print "$_\n";
        }
        elsif ($idmap{$v}) {
            foreach (@{$idmap{$v}}) {
                $vals[4] = $_;
                print join("\t",@vals)."\n";
            }
        }
        elsif ($filter_unmapped) {
            # no mapping
            if ($bin_id) {
                # put in bin
                $vals[4] = $bin_id;
                print join("\t",@vals)."\n";
            }
            elsif ($bin_go_terms) {
                my $aspect = $vals[8];
                my $bin;
                if ($aspect eq 'P') {
                    $bin = 'GO:0008150';
                }
                elsif ($aspect eq 'F') {
                    $bin = 'GO:0003674';
                }
                elsif ($aspect eq 'C') {
                    $bin = 'GO:0005575';
                }
                else {
                    die "does not appear to be a GO GAF";
                }
                $vals[4] = $bin;
                print join("\t",@vals)."\n";

            }
            else {
                # drop unmapped
            }
        }
        else {
            # no mapping, print original
            print "$_\n";
        }
    }
    close(F);
}


#printf STDERR "Fixed: $n\n";
exit 0;


sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn MAPPING-FILE FILE-TO-MAP [FILE-TO-MAP ...]

maps annotations using a mapping file(s)

This can be used for purposes including mapping to a subset or "slim"

The mapping file is typically two column, tab separated

 COL1: Source GO term
 COL2: Target GO term

No inference is performed when mapping - if you want to use the
relationships in the ontology, then this should be incorporated into
the mapping file.

If an annotation is to a GO term without a mapping, then the
annotation is dropped, unless --bin-go-terms is specified. If this is
specified, then the annotation is mapped up to the relevant root node
in F/P/C depending on the aspect.

MAPPING FILES:

If your mapping file does not conform to the 2-column format above,
you can use the -k option. E.g.

 -k3,4

Uses col3 to read the source GO IDs, and col4 to read the targets

If your mapping file has only one column, it is treated as a filter
file. Any annotation to a term not in this is dropped.

If your file has more than two columns, and the -k opt is not
specified, then the format of the mapping file is guessed.

Lines beginning with ! are ignored


EOM
}

