#!/usr/bin/perl -w

use strict;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
}

my $passed_header = 0;
while (<>) {
    if (/^\[/) {
        $passed_header = 1;
    }
    next unless $passed_header;
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
$sn OBO-FILE

does what it says on the tin
EOM
}

