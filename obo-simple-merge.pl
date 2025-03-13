#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $regexp = '';
my $noheader;
my $negate;
my $count;
my $rmc;
my $keep_dupes;
my $keep_other;

while ($ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '-c' || $opt eq '--count') {
        $count = 1;
    }
    elsif ($opt eq '--noheader') {
        $noheader = 1;
    }
    elsif ($opt eq '--keep-duplicates') {
        $keep_dupes = 1;
    }
    elsif ($opt eq '--remove-comments') {
        $rmc = 1;
    }
    elsif ($opt eq '--keep-other') {
        $keep_other = 1;
    }
}

my %th = ();
$/ = "\n\n";

my $n = 0;
while (@ARGV) {
    my $f = pop @ARGV;
    if ($f eq '-') {
        *F=*STDIN;
    }
    else {
        open(F,$f) || die $f;
    }
    my $hdr = 0;
    while(<F>) {
        if ($rmc) {
            s/^\!*//;
            s/\n\!*/\n/g;
        }

        if (!$hdr && $_ !~ /^\[/) {
            print unless $noheader || $count;
            $hdr = 1;
            $noheader = 1; # show max 1 times
        }
        else {
            if (/\nid: (\S+)/) {
                my $id = $1;
                #print STDERR "id: $id\n";
                if ($th{$id}) {
                    if ($th{$id} eq $_) {
                        print STDERR "IDENTICAL: $id\n";
                    }
                    else {
                        if (compr($th{$id}) eq compr($_)) {
                            print STDERR "NEAR-IDENTICAL: $id\n";
                        }
                        elsif ($keep_other) {
                            print STDERR "========================================\nDITCHING:\n\n$th{$id}  <<< >>>>\n\nUSING:\n\n$_";
                            $th{$id} = $_;
                        }
                        else {
                            print STDERR "========================================\nDITCHING:\n\n$_  <<< >>>>\n\nUSING:\n\n$th{$id}";
                            if ($keep_dupes) {
                                my $n=1;
                                while ($th{"$id-duplicate-$n"}) {
                                    $n++;
                                }
                                $th{"$id-duplicate-$n"} = $_;
                            }
                        }
                    }
                }
                else {
                    $th{$id} = $_;
                }
            }
            else {
                # no ID - this is allowed; e.g. Annotation stanzas
                $th{$_} = $_;                
            }
        }
    }
}

foreach my $id (sort (keys %th)) {
    #print "! $id\n";
    print $th{$id};
}


exit 0;

sub compr {
    my $s = shift;
    $s =~ s/\s+//g;
    $s;
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [--noheader] [--remove-comments] OBO-FILE1 OBO-FILE2 [OBO-FILE3...]

Merges multiple obo files together. Each stanza is treated as atomic,
and identified by its ID. No attempt is made to merge tags within a
stanza.

The last file specified on the command line has highest precedence.

A report is written on STDERR

See also: obo-merge-tags.pl

EOM
}

