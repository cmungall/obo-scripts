#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $verbose = 0;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq -'v' || $opt eq '--verbose') {
        $verbose = 1;
    }
}
if (!@ARGV) {
    print usage();
    exit 0;
}

my $id;
my @lines = @_;
my %relh = ();
while (<>) {
    s/\s+$//;
    if (/^id:\s+(\S+)/) {
        $id = $1;
    }
    elsif (/^relationship:\s+(\S+)\s+(\S+)/) {
	$relh{$id}->{$1}->{$2} = 1;
    }

    push(@lines,$_);
}

my $n = 0;
my %fixedh = ();
my @adds = ();
foreach (@lines) {
    my $orig = $_;
    s/\s*\!.*//;
    if (/^id:\s+(\S+)/) {
        $id = $1;
    }
    if (/^intersection_of:\s+(\S+)\s+(\S+)/) {
	if (!$relh{$id}->{$1}->{$2}) {
	    $_ = $orig;
	    s/intersection_of/relationship/;
	    push(@adds, $_);
	}
	else {
	    if ($verbose) {
		print STDERR "Already have corresponding relationship for: $_\n";
	    }
	}
    }
    else {
	# relationship tags should be added immediately after intersection_of tags
	while (my $add = shift @adds) {
	    print "$add\n";
	    $n++;
	    $fixedh{$id}++;
	    if ($verbose) {
		printf STDERR "Inserted[%d]: $add\n", scalar($fixedh{$id});
	    }
	}
    }

    print "$orig\n";
    
}

printf STDERR "Added $n new relationships in %d terms based on xp defs\n", scalar(keys %fixedh);

exit 0;

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [-v] OBO-FILE

Add (redundant) relationship tags for intersection_of
differentiae. This is useful in cases where we might want to remove
all intersection_of tags before presentation to basic tools.

  If the script encounters the following:

[Term]
id: GO:0035085
name: cilium axoneme
namespace: cellular_component
def: "The bundle of microtubules and associated proteins that forms the core of cilia in eukaryotic cells and is responsible for their movements." [GOC:bf, ISBN:0198547684]
is_a: GO:0005930 ! axoneme
is_a: GO:0044441 ! cilium part
intersection_of: GO:0005930 ! axoneme
intersection_of: part_of GO:0005929 ! cilium

  It will add a line

relationship: part_of GO:0005929 ! cilium

  This is technically completely redundant, but useful to materialize in the file.

  If the script encounters the following:

[Term]
id: GO:0034350
name: regulation of glial cell apoptosis
namespace: biological_process
def: "Any process that modulates the frequency, rate, or extent of glial cell apoptosis." [GOC:mah]
is_a: GO:0042981 ! regulation of apoptosis
intersection_of: GO:0065007 ! biological regulation
intersection_of: regulates GO:0034349 ! glial cell apoptosis
relationship: regulates GO:0034349 ! glial cell apoptosis

 It will do nothing, as the redundant relationship is already there.

See also:

https://sourceforge.net/tracker/?func=detail&aid=2305635&group_id=36855&atid=418260

https://sourceforge.net/tracker/index.php?func=detail&aid=2305594&group_id=36855&atid=418257

EOM
}

