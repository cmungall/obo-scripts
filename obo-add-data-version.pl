#!/usr/bin/perl -w

use strict;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
}

my @t = localtime(time);
my $dv = sprintf("%04s-%02s-%02s",$t[5]+1900,$t[4]+1,$t[3]+1);
my $added = 0;
while (<>) {
    
    if (!$added) {
        if (/^format-version:/) {
        }
        elsif (/^(\S+):/) {
            # add this AFTER format-version
            # see: http://www.geneontology.org/GO.format.obo-1_4.shtml "tag ordering"
            print "data-version: $dv\n";
            $added = 1;
        }
    }

    print $_;
    
}

exit 0;

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn OBO-FILE

Adds data-version tag
EOM
}

