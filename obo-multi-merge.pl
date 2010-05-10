#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $noheader;
my $mapf;
my %prec= ();
while ($ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '-m' || $opt eq '--map-file') {
        $mapf = shift @ARGV;
    }
    if ($opt eq '-p' || $opt eq '--prec') {
	my $a = shift @ARGV;
	my $b = shift @ARGV;
        $prec{$a}->{$b} = 1;
    }
    if ($opt eq '--noheader') {
        $noheader = 1;
    }
}

if (!$mapf) {
    $mapf = shift @ARGV;
}

my %maph = ();
open(F,$mapf) || die $mapf;
while(<F>) {
    chomp;
    my ($src,$tgt) = split(/\t/,$_);
    $src =~ s/\-.*//;
    $tgt =~ s/\-.*//;
    my ($src_db) = ($src =~ /^(\w+):/);
    my ($tgt_db) = ($tgt =~ /^(\w+):/);
    if ($prec{$tgt_db}->{$src_db}) {
	$maph{$tgt} = $src;
    }
    else {
	$maph{$src} = $tgt;
    }
}

my %KEEP = 
    (is_a=>1,
     relationship=>1,
     synonym=>1);
my @lines = ();
my $id;
my %tvh = ();
while (<>) {
    push(@lines, $_);
    chomp;
    if (/^id:\s*(\S+)/) {
	$id = $1;
    }
    else {
	if (/(\S+):\s*(.*)/) {
	    my ($t,$v) = ($1,$2);
	    if ($KEEP{$t}) {
		#print STDERR "TV: $t=$v\n";
		push(@{$tvh{$id}},[$t,$v]);
	    }
	}
    }
}

# inverse map
my %rmaph = ();
foreach my $k (keys %maph) {
    #print STDERR "RMAP: '$maph{$k}' << '$k'\n";
    push(@{$rmaph{$maph{$k}}}, $k);
}

my $elim;
my @out = ();
my $n = 0;
while ($_ = shift @lines) {
    chomp;
    if (/^\[/) {
	$elim = 0;
    }
    next if $elim;
    push(@out, $_);
    if (/^id:\s*(\S+)/) {
	$id = $1;
	if ($maph{$id}) {
	    #print STDERR "elim: $id\n";
	    $n++;
	    while (@out) {
		my $last = pop @out;
		if ($last =~ /^\[/) {
		    last;
		}
		if ($last =~ /^\s*$/) {
		    last;
		}
	    }
	    $elim = 1;
	    next;
	}
	print STDERR "ID: '$id'\n";
	foreach my $alt_id (@{$rmaph{$id}}) {
	    print STDERR "merged: $alt_id --> $id\n";
	    push(@out, "alt_id: $alt_id");
	    foreach my $tv (@{$tvh{$alt_id}}) {
		push(@out, "$tv->[0]: $tv->[1]");
	    }
	}
    }
}

foreach (@out) {
    print "$_\n";
}

print STDERR "DONE: $n\n";

exit(0);


sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [ OBO-FILE [OBO-FILE2...]

Merges multiple classes based on equivalence mapping file

Example:
 
$sn -p HP MP equiv.txt mammalian_phenotype.obo human_phenotype.obo

equiv.txt is a list of pairs, src-> tgt, where src is merged into tgt
(i.e. tgt has precedence)

 -p SRC TGT
    merge all SRC into TGT
    

EOM
}

