#!/usr/bin/perl -w

use strict;
my $headerfile;
my $noheader;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '--headerfile') {
        $headerfile = shift @ARGV;
    }
    if ($opt eq '--noheader') {
        $noheader = 1;
    }
}

print_obo_header();

foreach (@ARGV) {
    catfile($_);
}

exit 0;

sub catfile {
    my $f=shift;
    my $include=shift;
    my $ok = open(F,$f);
    if (!$ok)  {
        warn("no such file: $f\n");
        return;
    }
    unless ($include) {
        while (<F>) {
            last if /^\s*$/;
        }
    }
    while (<F>) {
        print;
    }
    close(F);
    #print `cat $f`;
    #print "\n";
}

sub print_obo_header {
    if ($noheader) {
        return;
    }
    if ($headerfile) {
        catfile($headerfile,1);
        print "\n";
        return;
    }
    print <<EOM;
format-version: 1.2
date: 23:09:2005 14:37
saved-by: obo-cat.pl
default-namespace: none

EOM

}
