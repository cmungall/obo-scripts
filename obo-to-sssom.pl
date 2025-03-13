#!/usr/bin/perl -w
use strict;
my $id;
my $name;
my @cols = qw(subject_id subject_label predicate_id object_id mapping_justification);
print join("\t", @cols);
print "\n";
while(<>) {
    chomp;
    if (/^id:\s+(\S+)/) {
        $id = $1;
        $name = "";
    }
    elsif (/^name:\s+(.*)/) {
        $name = $1;
    }
    elsif (/^xref:\s+(.*)/) {
        my $v = $1;
        my $p = "oio:hasDbXref";
        if ($v =~ m@(\S+)\s+\{(.*)\}@) {
            $v = $1;
            my $q = $2;
            if ($q =~ m@source="(\S+)"@) {
                $p = $1;
            }
        }
        print "$id\t$name\t$p\t$v\tsemapv:ManualMappingCuration\n";
    }
}
