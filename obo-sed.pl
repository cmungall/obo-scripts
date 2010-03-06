#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $regexp = '';
my $noheader;
my $negate;
my $count;
my $del = "\n\n";
while ($ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '-r' || $opt eq '--regexp') {
        $regexp = shift @ARGV;
    }
    if ($opt eq '-c' || $opt eq '--count') {
        $count = 1;
    }
    if ($opt eq '--noheader') {
        $noheader = 1;
    }
    if ($opt eq '--windowscr') {
        $del = "\r\n\r\n";
    }
    if ($opt eq '-v' || $opt eq '--neg') {
        $negate = 1;
    }
}
my $sed = shift;
my $repl = eval "sub {$sed}";


my $n = 0;
if (!@ARGV) {
    @ARGV=('-');
}
my $n_stanzas = 0;
while (@ARGV) {
    my $f = pop @ARGV;
    #$/ = "\n\n";
    #$/ = "^\[";
    if ($f eq '-') {
        *F=*STDIN;
    }
    else {
        open(F,$f) || die $f;
    }
    my $hdr = 0;
    my $s = '';
    while(<F>) {
        $s .= $_;
    }
    my @toks = split(/$del/,$s);
    foreach (@toks) {
        $n_stanzas++;
        if (!$hdr && $_ !~ /^\[/) {
            print unless $noheader || $count;
            $hdr = 1;
        }
        else {
            if (!$regexp || /$regexp/) {            
                #$repl->($_);
                &$repl;
            }
            $n++;
            if (!$count) {
                print;
                print $del;
            }
        }
    }
}
if ($count) {
    print "$n\n";
}
print STDERR "num: $n_stanzas\n";

exit 0;

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [--noheader] [--neg] [--r REGULAR-EXPRESSION] SED-EXPRESSION OBO-FILE

search an replace stanzas from obo files

Example:

$sn -r 'namespace: molecular_function' 's/ activity//' go.obo

EOM
}

