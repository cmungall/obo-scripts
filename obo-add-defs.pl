#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $negate = 0;
my $replace = 0;
my $check = 0;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '--neg') {
        $negate = 1;
    }
    if ($opt eq '-r' || $opt eq '--replace') {
        $replace = 1;
    }
    if ($opt eq '-c' || $opt eq '--check') {
        $check = 1;
    }
    if ($opt eq '-t' || $opt eq '--tag') {
        $tag_h{shift @ARGV} = 1;
    }
}
if (!%tag_h) {
    $tag_h{'xref'} = 1;
}
if (!@ARGV) {
    print usage();
    exit 0;
}
my $lastf = pop @ARGV;
my %defmap = ();
while (<>) {
    chomp;
    my ($k,$v) = split(/\t/,$_);
    $defmap{$k} = $v;
}

my $id;
open(F,$lastf);
while(<F>) {
    chomp;
    if (/^id:\s+(\S+)/) {
        $id = $1;
    }
    if ($defmap{$id}) {
	if (/^def:\s".*"\s+(\[.*\])\s*/) {
	    printf('def: "%s" %s%s', $defmap{$id}, $1, "\n");
	    next;
	}
    }
    print "$_\n";
}
exit 0;

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [-t tag]* BASE-FILE FILE-TO-MERGE1 [FILE-TO-MERGE2...]

merges in tags to base file

Example:

$sn  referenced_file1.obo [referenced_file2.obo ...] source_file.obo

EOM
}

