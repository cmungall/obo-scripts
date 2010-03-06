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
my $id;
my %nh = ();
while (<>) {
    chomp;
    if (/^id:\s+(\S+)/) {
        $id = $1;
    }
    elsif (/^name:\s+(.*)/) {
        $nh{$id} = $1;
    }
}
open(F,$lastf);
while(<F>) {
    chomp;
    foreach my $tag (keys %tag_h) {
        if (/^$tag:\s+(.*)/) {
            my @vals = split(' ',$1);
            my @cmts = map { $nh{$_} } (grep { $nh{$_} } @vals);
            if (@cmts) {
		my $v = "@vals";
		if ($check) {
		    if (/!\s+(.*)\s*/) {
			if ("@cmts" ne $1) {
			    print STDERR "different: \"$1\" != \"@cmts\"\n";
			}
		    }
		}
		if ($replace) {
		    $v =~ s/\s*\!.*//;
		}
                $_ = "$tag: $v ! @cmts";
            }
            else {
                print STDERR "No label for: @vals\n";
            }
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

