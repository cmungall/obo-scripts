#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $negate = 0;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '--neg') {
        $negate = 1;
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

my $id;
my %sh = ();
my @lines = ();
while (<>) {
    push(@lines,$_);
    chomp;
    if (/^id:\s+(\S+)/) {
        $id = $1;
    }
    elsif (/^name:\s+(.*)/) {
        $sh{$id}->{lc($1)} = $1;
    }
    elsif (/^synonym:\s+\"(.*)\"\s\w+\s+\[/) {
	my $s = $1;
	my $cs = $sh{$id}->{lc($s)};


	if ($cs) {
	    die if $cs eq "1";
	    # synonym clash - choose best
	    my $best = bestsyn($cs,$s);

	    print STDERR "BEST = $best [from \"$cs\" and \"$s\"]\n";
	    $s = $best;
	    #if ($cs gt $s) {
	#	print STDERR "Deprecating \"$s\" for \"$cs\"\n";
#		$s = $cs;
#	    }
#	    else {
#		print STDERR "Replacing \"$cs\" with \"$s\"\n";
#	    }
	}
	$sh{$id}->{lc($s)} = $s;
    }
}

foreach (@lines) {
    chomp;
    my $omit = 0;
    if (/^id:\s+(\S+)/) {
        $id = $1;
    }
    elsif (/^synonym:\s+\"(.*)\"\s\w+\s+\[/) {
	my $s = $1;
	my $cs= $sh{$id}->{lc($s)};
	if ($cs) {
	    if ($cs ne $s) {
		# case insensitive takes priority
		print STDERR "omitting $s [already have $cs]\n";
		$omit = 1;
	    }
	}
    }
    print "$_\n" unless $omit;
}
exit 0;

sub bestsyn {
    my $x = shift;
    my $y = shift;

    my $lc = $x;
    my $uc = $y;
    if ($x lt $y) { # uc lt lc
	$uc = $x;
	$lc = $y;
    }

    my $is_latin_num = ($uc =~ /[CVIX]{2,}/) || ($uc =~ /\[[CVIX]+\]/);
    if ($is_latin_num) {
	    print STDERR "LATIN: $uc\n";
	    return $uc;
	}
    if ($uc =~ /\'/) {
	print STDERR "PROPER: $uc\n";
	return $uc;
    }
    if ($uc !~ /[a-z]/) {
	print STDERR "ACRONYM: $uc\n";
	return $uc;
    }
    return $lc;
	
}

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

