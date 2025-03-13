#!/usr/bin/perl -w
use strict;
my $id;
print "id\txref\tpred\n";
while(<>) {    
    if (/^id:\s+(\S+)/) {
        $id = $1;
    }
    elsif (/^xref:\s+(.*)/) {
        my $v = $1;
        if ($v =~ m@(\S+)\s+\{(.*)\}@) {
            $v = $1;
            my $q = $2;
            my $p = "";
            if ($q =~ m@source="(\S+)"@) {
                $p = $1;
            }
            print "$id\t$v\t$p\n";
        }
        else {
            print "$id\t$v\t\n";
        }
    }
}
