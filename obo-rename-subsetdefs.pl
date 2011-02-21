#!/usr/bin/perl -w

use strict;
my $fix_whitespace = 0;
my %ssmap = ();
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '-w' || $opt eq '--fix-whitespace') {
        $fix_whitespace = 1;
    }
    elsif ($opt eq '-') {
    }
    else {
        die "$opt";
    }
}

my $n = 0;
while (<>) {
    chomp;
    if (/^subsetdef:\s+(.*)\s+\"(.*)\"/) {
        my $n = $2;
        my $ss = $1;
        $ss =~ s/\s+$//;
        if ($ss =~ /\s/) {
            if ($fix_whitespace) {
                my $v = $ss;
                $v =~ s/\s+/_/g;
                $ssmap{$ss} = $v;
            }
            else {
                warn "consider using --fix-whitespace";
            }
        }
        if ($ssmap{$ss}) {
            my $v = $ssmap{$ss};
            #s/$ss/$v/e;
            $_ = "subsetdef: $v \"$n\"";
        }
    }
    if (/^subset:\s+(.*)/) {
        my $ss = $1;
        $ss =~ s/\s*\!.*//;
        $ss =~ s/\s+$//;
        if ($ssmap{$ss}) {
            my $v = $ssmap{$ss};
            s/$ss/$v/x;
            $_ = "subset: $v";
            #print STDERR "F: $v // $_\n";
            $n++;
        }
        
    }
    print "$_\n";
}
print STDERR "fixes: $n\n";

exit 0;

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [-t tag]* [--no-header] FILE [FILE...]

strips all tags except selected

Example:

$sn  -t id -t xref gene_ontology.obo

EOM
}

