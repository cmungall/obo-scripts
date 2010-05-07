#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $regexp = '';
my $noheader;
my $negate;
my $count;
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
    if ($opt eq '-v' || $opt eq '--neg') {
        $negate = 1;
    }
}


$/ = "\n\n";

my %done = ();
my @flagged = ();
my %referenced;
my $n = 0;
if (!@ARGV) {
    @ARGV=('-');
}
my $n_xps = 0;
while (@ARGV) {
    my $f = pop @ARGV;
    if ($f eq '-') {
        *F=*STDIN;
    }
    else {
        open(F,$f) || die $f;
    }
    my $hdr = 0;
    my $stanza_type;
    while(<F>) {
        my $id;
	if (/^\[(\+)\]/) {
	    $stanza_type = lc($1);
	}
        if (/id:\s*(\S+)/) {
            $id = $1;
            if ($done{$id} && /\nid/) {
                flag("$id present twice",$_);
            }
            $done{$id} = 1
        }
        my @lines = split(/\n/,$_);
        my @xps = grep {/^intersection_of:/} @lines;
        if (@xps) {
            if (@xps == 1) {
                flag("single_xp: @xps",$_); 
            }
            my @genii = ();
            foreach (@xps) {
                s/\s*\!.*//;
                my @parts = split(' ',$_);
                shift @parts;
		foreach (@parts) {
		    $referenced{$_} = 1;
		}
                if (@parts == 1) {
                    push(@genii, $parts[0]);
                }
            }
            if (@genii < 1) {
                flag("single_genus: @genii", $_);
            }
            elsif (@genii > 1) {
                flag("multiple_genus: @genii", $_)
		    unless $stanza_type = 'typedef';
            }
            else {
                if ($id eq $genii[0]) {
                    flag("id $id = genus", $_);
                }
                # ok
            }
            $n_xps++;
        }
    }
}

foreach (keys %done) {
    if (/^_:/) {
	if ($referenced{$_}) {
	    flag("unreferenced anon class", $_);
	}
    }
}

print STDERR "n_xps: $n_xps\n";

exit(scalar(@flagged));

sub flag {
    my $err = shift;
    my $stanza = shift;
    print STDERR "FLAG: $err\n$stanza\n\n";
    push(@flagged, $err);
    return;
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn OBO-FILE [OBO-FILE2...]

performs syntactic check on intersection_of definitions

Example:

$sn mammalian_phenotype_xp.obo

EOM
}

