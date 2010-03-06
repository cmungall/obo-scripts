#!/usr/bin/perl -w

$ENV{CVS_RSH} = 'ssh';
use strict;
my $diffcmd = 'obodiff';
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-d' || $opt eq '--diff') {
        $diffcmd = shift @ARGV;
    }
    elsif ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
}
foreach my $f (@ARGV) {
    my $cmd = "cvs log $f";
    my @lines = split(/\n/,`$cmd`);
    my @revs = ();
    foreach (@lines) {
        if (/^revision\s+(\S+)/) {
            push(@revs,$1);
        }
    }
    my $f1 = $f;
    for (my $i=1; $i<@revs; $i++) {
        my $rev = $revs[$i];
        my $revp = $revs[$i-1];
        my $f2 = $f.$rev;
        runcmd("cvs diff -u -r $revp -r $rev $f > DIFF");
        open(F,"DIFF") || die;
        open(OF,">DIFF2") || die;
        my $line = 0;
        while(<F>) {
            s/Index:\s+($f)/Index: $f1/;
            s/^\-\-\-\s($f)/\-\-\- $f1/;
            s/^\+\+\+\s($f)/\+\+\+ $f1/;
            $line++;
            print OF "$_";
        }
        close(OF);
        close(F);
        runcmd("patch -o $f2 < DIFF2");
        runcmd("$diffcmd $f2 $f1 > obodiff.$f.$rev-$revp.diff");
        $f1=$f2;
    }
}

exit 0;

sub runcmd {
    my @c = @_;
    print STDERR "CMD: @c\n";
    system("@c");
    #system("@c") && die "@c";
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn FILE.OBO

obodiff over history. Must be run from a cvs directory

Example:

  cd cvs/go/ontology
  $sn gene_ontology_edit.obo
EOM
}


