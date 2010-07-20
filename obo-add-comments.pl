#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $negate = 0;
my $replace = 0;
my $check = 0;
my $expand_relations = 0;
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
    if ($opt eq '--expand-relations') {
        $expand_relations = 1;
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
my $stanza_type;
while (<>) {
    s/\s+$//;
    if (/^\[(\S+)\]/) {
        $stanza_type = lc($1);
    }
    if (/^id:\s+(\S+)/) {
        $id = $1;
    }
    elsif (/^name:\s+(.*)/) {
        if ($stanza_type eq 'typedef' && !$expand_relations) {
        }
        else {
            $nh{$id} = $1;
        }
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
			if (lc("@cmts") ne lc($1)) {
			    print STDERR "different: \"$1\" not the same as \"@cmts\"\n";
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
$sn [-c] [-r] [-t tag]* [REFERENCED FILE...] SOURCE

for all ID references in SOURCE in a specified tag, adds the label after a "!"

using the -c option runs this in CHECK mode

using the -r option replaces existing comments

Example:

$sn -c -t id -t intersection_of human-phenotype-ontology.obo quality.obo fma.obo human-phenotype-ontology_xp.obo

EOM
}

