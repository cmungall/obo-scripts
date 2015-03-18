#!/usr/bin/perl

my $f = shift @ARGV;
my $tgt = shift @ARGV;
open(F,$f) || die $f;
while(<F>) {
    if (/^ontology:\s*(\S+)/) {
        $ont = $1;
    }
    push(@lines,$_);
}
close(F);
if (!$ont) {
    $ont = $tgt;
    if (!$ont) {
        if ($f =~ /([\w+\-]+)\.obo/) {
            $ont = $1;
        }
        else {
            die $f;
        }
    }
    unshift(@lines, "ontology: $ont\n");
    open (F, ">$f") || die $f;
    foreach (@lines) {
        print F $_;
    }
    close(F);

}
