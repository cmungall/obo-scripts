#!/usr/bin/perl

my $idspace;
my $diff;
while ($ARGV[0] =~ /^(\-.*)/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '-i' || $opt eq '--idspace') {
        $idspace = shift @ARGV;
    }
    elsif ($opt eq '-d' || $opt eq '--differentium') {
        $diff = shift @ARGV;
        unless ($diff =~ /\s/) {
            $diff .= " ".shift @ARGV;
        }
    }
    else {
        die "Command line option \"$opt\" not known";
    }
}
die "You must specify an idspace; for example:\n$0 --idspace CL" unless $idspace;
die "You must specify a differentium; for example:\n$0 -d \"part_of NCBITax:zebrafish\"" unless $diff;

my %done = ();
my $id;
while (<>) {
    chomp;
    $id = $1 if /^id: (\S+)/;
    print "$_\n";
    if (/^xref(\w*):\s*(.*)/) {
        my $xref = $2;
        if ($done{$id}) {
            print STDERR "ignoring additional xref: $xref for $id\n";
        }
        else {
            $done{$id}=1;
            if ($xref =~ /(.*):/ &&  $1 eq $idspace) {
                print "intersection_of: $xref\n";
                print "intersection_of: $diff\n";
            }
        }
    }
}
exit 0;

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}

sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [--idspace IDSPACE] [--differentium RELATION TERMID] FILE

Promotes xref to genus-differentia definitions.

This script is useful for keeping an ontology consistent with some
reference ontology, when these two ontologies reference the same or
highly similar kinds of entities.

For example, the ZFA contains links to CL, the OBO Foundry reference
ontology for cell types. If our input file contains:

[Term]
id: ZFA:0000134
name: neurons
namespace: zebrafish_anatomy
relationship: end ZFS:0000044     ! Adult
relationship: part_of ZFA:0000396     ! nervous system
relationship: start ZFS:0000026     ! Segmentation:14-19 somites
xref: CL:0000540
xref: ZFIN:ZDB-ANAT-010921-563

And we run:
obo-promote-dbxref-to-intersection.pl --idspace CL -d part_of NCBITax:7955 zfa.obo

We get:

[Term]
id: ZFA:0000134
name: neurons
namespace: zebrafish_anatomy
relationship: end ZFS:0000044     ! Adult
relationship: part_of ZFA:0000396     ! nervous system
relationship: start ZFS:0000026     ! Segmentation:14-19 somites
intersection_of: CL:0000540   
intersection_of: part_of NCBITax:7955
xref: CL:0000540
xref: ZFIN:ZDB-ANAT-010921-563


EOM
}

