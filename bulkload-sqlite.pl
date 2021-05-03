#!/usr/bin/perl -w
use strict;
my $bulktable = "bulk$$";
my $db = shift;
my $tn = shift;
run('.separator "\t"');
foreach my $fn (@ARGV) {
    open(F, $fn) || die $fn;
    my $hdr = <F>;
    chomp $hdr;
    my @cols = split(/\t/, $hdr);
    $hdr =~ s@\t@,@g;
    close(F);
    run(".import $fn $bulktable", ".mode tabs");
    run("INSERT INTO $tn( $hdr ) SELECT * FROM $bulktable;");
    run("DELETE FROM $bulktable;");
}
exit 0;

sub run {
    my $cmd = shift;
    my $subcmd = shift;
    if ($subcmd) {
        $subcmd = "-cmd '$subcmd'";
    }
    else {
        $subcmd = '';
    }
    my $sh = "echo '$cmd' | sqlite3 $db $subcmd";
    print STDERR "$sh\n";
    print `$sh`;
    print "\n";
}    
