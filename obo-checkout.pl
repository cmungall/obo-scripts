#!/usr/bin/perl -w

use strict;
use FileHandle;
my $outdir = "terms";
my $cmd;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '-d' || $opt eq '--outdir') {
        $outdir = shift @ARGV;
    }
}
`mkdir -p $outdir`;
my $id;
my $stanza = "";
my @alt_ids = ();
my $fn = shift @ARGV;
my @ids = @ARGV;
my %idmap = map {$_ => 1} @ids;
my $num_ids = scalar(@ids);

my $n = 0;
print "Reading $fn\n";
open(F, $fn) || die "no such file $fn";
while(<F>) {
    if (m@^\[@) {
        $n++;
        if ($id) {
            # check if id is in %idmap
            if ($idmap{$id}) {
                print "Checking out $id\n";
                w($id, $stanza);
            }
        }
        $stanza = "";
        $id = "";
    }
    if (m@^id: (\S+)@) {
        $id = $1;
    }
    if (m@^alt_id: (\S+)@) {
        push(@alt_ids, $1);
    }
    $stanza .= $_;
}
close(F);
#print "n: $n\n";
sub get_path {
    my ($id) = @_;
    my $fn = "$id";
    $fn =~ s@:@_@;
    return "$outdir/$fn.obo"
    
}

sub w {
    my ($id, $stanza) = @_;
    my $path = get_path($id);
    open(W, ">$path") || die($path);
    print W $stanza;
    close(W)
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [-s chunksize] [-x COMMAND \;] OBO-FILES

Checks out IDs from a complete obo file to stanza-specific files
and a terms directory.

Example:

$sn -d terms go-edit.obo GO:0000001

EOM
}

