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

my $f = pop @ARGV; # file to extract from
my %ref=();
my %names=();
my $name;
while (<>) {
    chomp;
    if (/^name:\s+(.*)/) {
	$name = $1;
    }
    elsif (/^id:\s+(\S+)\s*\!\s*(.+)/) {
	$name = $2;
    }
    elsif (/^(relationship|intersection_of|union_of):\s+(\S+)\s+(\S+)/) {
	count($1,$2);
    }
    elsif (/^(is_a|intersection_of):\s+(\S+)/) {
	count($1);
    }
    else {
    }
}
$/="\n\n";
open(F,$f);
while(<F>) {
    chomp;
    if (/id:\s*(\S+)/ && $ref{$1}) {
	print STDERR "$1 refcount: $ref{$1}\n";
	printf "! %s\n", join('//',@{$names{$1}});
	print "$_\n\n";
    }
}
close(F);
exit 0;

sub count {
    foreach (@_) {
	$ref{$_}++;
	push(@{$names{$_}}, $name);
    }

}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn REFERENCING-FILE1 [REFERENCING-FILE2..] REFERENCED-FILE

extracts from REFERENCED-FILE all stanzas referenced in the other files

EOM
}

