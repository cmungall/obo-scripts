#!/usr/bin/perl -w

use strict;
my %colh = ();

while ($ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '-k' || $opt eq '--key') {
        foreach (split /,/,shift @ARGV) {
            if (/(\d+)\-(\d+)/) {
                foreach ($1..$2) {
                    $colh{$_}=1;
                }
            }
            else {
                $colh{$_}=1;
            }
        }
    }
}
my @cols = keys %colh;

if (@cols) {
    while (<>) {
        chomp;
        my @vals = split(/\t/,$_);
        foreach my $c (@cols) {
            $vals[$c-1] =~ s@http://purl.obolibrary.org/obo/([\w\-^_]+)_(\S+)@$1:$2@g;
        }
        print join("\t",@vals),"\n";
    }
}
else {
    while (<>) {
        s@http://purl.obolibrary.org/obo/([\w\-^_]+)_(\S+)@$1:$2@g;
        print;
    }
}

exit 0;


sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [-k COLNUMS] FILE [FILES]

translates OBO IDs to OBO Foundry style URIs.
E.g. CL:0000540 ==> http://purl.obolibrary.org/obo/CL_0000540

If -k is not specified, the translation operates on the whole file - any file structure can be used.

If -k is specified, a tab delimited file is assumed

E.g.

  $sn -k 2,4,7-10 foo.tab > foo_owl.tab

converts all OBO IDs in cols 2,4,7,8,9 and 10

EOM
}

