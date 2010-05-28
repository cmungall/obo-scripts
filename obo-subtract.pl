#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $regexp = '';
my $noheader;
my $negate;
my $comment;
my $rmc = 0;

if (!@ARGV) {
    print usage();
    exit 1;
 }
while ($ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '--noheader') {
        $noheader = 1;
    }
    if ($opt eq '--comment') {
        $comment = 1;
    }
    if ($opt eq '--remove-comments') {
        $rmc = 1;
    }
}

my %th = ();
$/ = "\n\n";

my $n = 0;
my $firstf = shift @ARGV;
while (@ARGV) {
    my $f = shift @ARGV;
    if ($f eq '-') {
        *F=*STDIN;
    }
    else {
        open(F,$f) || die $f;
    }
    my $hdr = 0;
    while(<F>) {
        if ($rmc) {
            s/^\!*//g;
            s/\n\!*/\n/g;
        }
	# remove commented out info
	#s/\!.*\n//g;

        if (!$hdr && $_ !~ /^\[/) {
            $hdr = 1;
        }
        else {
            if (/id: (\S+)/) {
                my $id = $1;
                if ($th{$id}) {
                    if ($th{$id} eq $_) {
                        print STDERR "IDENTICAL: $id\n";
                    }
                    else {
                        print STDERR "========================================\nDITCHING:\n\n$_  <<< >>>>\n\nUSING:\n\n$th{$id}";
                    }
                }
                else {
                    $th{$id} = $_;
                }
            }
            else {
                # no ID - this is allowed; e.g. Annotation stanzas
                $th{$_} = $_;                
            }
        }
    }
    close(F);
}
open(F,$firstf) || die $firstf;
my $hdr = 0;
while (<F>) {
    if (!$hdr && $_ !~ /^\[/) {
        print unless $noheader;
        $hdr = 1;
        $noheader = 1; # show max 1 times
    }
    else {
        if (/\nid: (\S+)/) {
            my $id = $1;
            if ($th{$id}) {
                my $diff = diff($_,$th{$id});
                print STDERR "Subtracting $id $diff\n";
                if ($comment) {
                    my @lines = map {"!!   $_"} split(/\n/,$_);
                    print join("\n",@lines),"\n\n";
                }
            }
            else {
                print STDERR "Keeping $id\n";
                print $_;
            }
        }
        else {
            # no ID - this is allowed; e.g. Annotation stanzas
            print $_;
        }
    }
}
close(F);

exit 0;

sub diff {
    my $x = shift;
    my $y = shift;
    
    if ($x eq $y) {
        return "[identical]";
    }
    my $xc = clean($x);
    my $yc = clean($y);
    if ($xc eq $yc) {
        return "[equivalent]";
    }
    return "[DIFFERENT] <<$xc>>  <<$yc>>\nDITCHING:\n$y\nUSING:\n$x\n";
}

sub clean {
    my $x = shift;
    $x =~ s/\!.*//g;
    $x =~ s/\s//g;
    return $x;
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [--noheader] [--comment] OBO-FILE1 OBO-FILE2 [OBO-FILE3...]

Subtracts one obo file from another. Each stanza is treated
as atomic, and identified by its ID. No attempt is made to merge tags
within a stanza.

If you pass in files F1, F2, F3, ... then the result will be F1, with
stanzas from F2 subtracted, then stanzas from F3 subtracted....

i.e. left-associative just like arithmentic subtraction
e.g. passing in 4 files will yield (((F1-F2)-F3)-F4)

If F2 is subtracted from F1, and F2 contains stanzas not mappable to
F1, then these will simply be ignored.

If F2 is subtracted from F1, any stanza in the intersection between F1
and F2 will not be present in the output file. Here stanzas are
compared purely with respect to their id. The report will tell whether
the intersecting stanzas are equivalent, or different.

If --comment is passed, then the duplicate stanzas are commented out rather than removed

A report is written on STDERR

See also: obo-merge-tags.pl

EOM
}

