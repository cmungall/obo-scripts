#!/usr/bin/perl -w
use strict;

my %MAP = (
    equivalentTo => "skos:exactMatch",
    obsoleteEquivalent => "skos:exactMatch",
    equivalentObsolete => "skos:exactMatch",
    );

my @hdr = qw(
    subject_id subject_label
    predicate_id
    object_id object_label
    match_type
    confidence
    comment
    );

print join("\t", @hdr)."\n";

my $id;
my $name;
while(<>) {
    chomp;
    if (/^id:\s+(\S+)/) {
        $id = $1;
        $name = "";
    }
    elsif (/^name:\s+(.*)/) {
        $name = $1;
    }
    elsif (m@xref:\s+(\S+)(.*)@) {
        my $x = $1;
        my $xn = "";
        my $rest = $2;
        my $pred = "skos:closeMatch";
        my $match_type = "xref";
        my $comment = "";
        my $confidence = "0.5";
        if ($rest =~ m@ \! (.*)@) {
            $xn = $1;
        }
        if ($rest =~ m@\{(.*)}@) {
            my $qualstr = $1;
            $comment = $qualstr;
            my @quals = split(/, /, $qualstr);
            foreach my $q (@quals) {
                my ($k, $v) = split('=',$q);
                $v =~ s@\"@@g;
                if ($v =~ m@^MONDO:(\S+)@) {
                    my $type = $1;
                    if ($MAP{$type}) {
                        $pred = $MAP{$type};
                    }
                }
                # ORDO specific
                if ($v =~ m@^E \(Exact@) {
                    $pred = 'skos:exactMatch';
                    $confidence = 0.9;
                }
                if ($v =~ m@^NTBT@) {
                    $pred = 'owl:subClassOf';
                    $confidence = 0.9;
                }
                if ($v =~ m@^BTNT@) {
                    $pred = 'inverseOf(owl:subClassOf)';
                    $confidence = 0.9;
                }
            }
        }
        my @row = (
            $id, $name,
            $pred,
            $x, $xn,
            $match_type,
            $confidence,
            $comment
            );
        print join("\t", @row)."\n";
    }
}
