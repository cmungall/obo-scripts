#!/usr/bin/perl -w

use strict;
my @remarks = ();
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '-r') {
        push(@remarks, shift @ARGV);
    }
}
if (!@ARGV) {
    print usage();
    exit 0;
}
while (@ARGV > 1) {
    my $f = shift @ARGV;
    open(F, $f) || die $f;
    while(<F>) {
        chomp;
        push(@remarks, $_);
    }
    close(F);
}

my $r = 0;
while (<>) {
    
    if (/^remark/) {
        $r = 1;
    }
    else {
        if ($r || /^\s*$/) {
            print "remark: $_\n" foreach @remarks;
            @remarks = ();
            $r=0;
        }
    }
    print;
}
exit 0;

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [-c] [-r] [-t tag]* [REFERENCED FILE...] SOURCE

for all ID references in SOURCE in a specified tag, adds the label after a "!"

using the -c option runs this in CHECK mode

using the -r option replaces existing comments

Example:

$sn -c -t id -t intersection_of human-phenotype-ontology.obo quality.obo fma.obo human-phenotype-ontology_xp.obo

EOM
}

