#!/usr/bin/perl -w

use strict;
use FileHandle;
my $chunksize = 10000;
my $cmd;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '-s' || $opt eq '--chunksize') {
        $chunksize = shift @ARGV;
    }
    if ($opt eq '-x' || $opt eq '--iterate') {
        while (@ARGV) {
            my $next = shift @ARGV;
            if ($next eq ';') {
                last;
            }
            $cmd.= "$next ";
        }
        if (!@ARGV) {
            die "-x must end with \; I got:\n$cmd";
        }
    }
}
while (@ARGV) {
    chunk(shift @ARGV);
}
exit 0;

sub chunk {
    my $f = shift;
    my $in_header = 1;
    my $hdr = '';
    my $n = 0;
    my $oh;
    my $ih = FileHandle->new($f) || die $f;
    while(<$ih>) {
        if (/^\[/) {
            if ($n % $chunksize == 0) {
                my $chunkid = int($n/$chunksize);
                $oh->close if $oh;
                $oh = outhandle($f,$chunkid+1);
                print $oh $hdr;
            }
            $n++;
            $in_header = 0;
            print $oh $_;
        }
        else {
            if ($in_header) {
                $hdr .= $_;
            }
            else {
                print $oh $_;
            }
        }
    }

    $ih->close;
    $oh->close;
}

sub outhandle {
    my ($f,$id) = @_;
    if ($cmd) {
        my $oh = FileHandle->new("|$cmd") || die $cmd;
        return $oh;
    }
    else {
        my $orig = $f;
        $f =~ s/\.obo/.chunk-$id\.obo/;
        die if $f eq $orig;
        my $oh = FileHandle->new(">$f") || die $f;
        return $oh;
    }
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [-s chunksize] [-x COMMAND \;] OBO-FILES

Splits obo file into chunks. the main reason to do this is
pre-processing before passing to memory intensive applications

-s --chunksize : number of stanzas per file/command. default 10000
-x --iterate : command to iterate over each chunk

Example:

$sn -c 1000 chebi.obo 

--breaks chebi into files of size 1000

$sn -x obo-grep.pl -r calcium - \; chebi.obo 

--iterates through chebi running obo-grep on each chunk

EOM
}

