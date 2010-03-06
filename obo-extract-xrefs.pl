#!/usr/bin/perl -w
use strict;
my $id;
while(<>) {
    if (/^id:\s+(\S+)/) {
        $id = $1;
    }
    elsif (/^(xref|xref_analog):\s+(.*)/) {
        my $v = $2;
        print "$id\t$v\n";
    }
}
