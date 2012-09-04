#!/usr/bin/perl -w
use strict;

# See: http://obofoundry.org/wiki/index.php/Ontology_registry_overhaul

print hdr();

my %prop =
    (
     title=>'rdfs:label',
     namespace=>'oboInOwl:IDSpace',
     home=>'foaf:homepage',
     description=>'dc:description',
     replaced_by=>'obo:IAO_0100001',
    );

my %h = ();
my $id;
while (<>) {
    if (/^(\S+)\t(.*)/) {
        die "got $1 -- is $h{$1}, now $2 in $id" if $h{$1};
        $h{$1} = $2;
        if ($1 eq 'id') {
            $id = $2;
        }
    }
    elsif (/^(\S+)\s*$/) {
        print STDERR "NO_VAL: $1\n";
    }
    elsif (/^\s*$/) {
        spit();
    }
    else {
        print STDERR "BAD_FMT: $_ in $id\n";
    }
}
spit();
exit 0;

sub spit {
    if (!$h{namespace}) {
        foreach my $k (keys %h) {
            print STDERR "NOMAP  $k ==> $h{$k}\n";
        }
        return;
    }
    my $idspace = $h{namespace};
    my $ont = sprintf("obo:%s.owl",lc($idspace));
    print "## --------------------\n";
    print "## $h{title}\n";
    print "## --------------------\n\n";
    print "$ont rdf:type oboInOwl:OntologyRepresentation";
    foreach my $k (keys %h) {
        my $v = $h{$k};
        next if !$v;
        $v =~ s/\"/\\\"/g;
        if ($v =~ /.*\|(.*)/) {
            $v = $1;
        }
        my $type = '@en';
        if ($v =~ /^http/) {
            $type = '^^xsd:anyURI';
        }
        my $p = $prop{$k};
        if ($p) {
            print ";\n";
            printf '    %s "%s"%s',$p, $v, $type;
        }
    }
    print ".\n\n";
    %h=();
}

sub hdr {
    <<EOM;
\@prefix : <http://purl.obofoundry.org/obo/> .
\@prefix ro: <http://www.obofoundry.org/ro/ro.owl#> .
\@prefix bfo: <http://www.ifomis.org/bfo/1.1#> .
\@prefix obo: <http://purl.obofoundry.org/obo/> .
\@prefix owl: <http://www.w3.org/2002/07/owl#> .
\@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
\@prefix xml: <http://www.w3.org/XML/1998/namespace> .
\@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
\@prefix xsp: <http://www.owl-ontologies.com/2005/08/07/xsp.owl#> .
\@prefix daml: <http://www.daml.org/2001/03/daml+oil#> .
\@prefix owl2: <http://www.w3.org/2006/12/owl2#> .
\@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
\@prefix snap: <http://www.ifomis.org/bfo/1.1/snap#> .
\@prefix span: <http://www.ifomis.org/bfo/1.1/span#> .
\@prefix swrl: <http://www.w3.org/2003/11/swrl#> .
\@prefix swrlb: <http://www.w3.org/2003/11/swrlb#> .
\@prefix owl2xml: <http://www.w3.org/2006/12/owl2-xml#> .
\@prefix protege: <http://protege.stanford.edu/plugins/owl/protege#> .
\@prefix oboInOwl: <http://www.geneontology.org/formats/oboInOwl#> .
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .
\@prefix dc: <http://protege.stanford.edu/plugins/owl/dc/protege-dc.owl#> .
\@base <http://purl.obofoundry.org/obo/iao/ontology-metadata.owl> .

EOM
}
