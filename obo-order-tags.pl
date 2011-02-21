#!/usr/bin/perl -w

use strict;
while ($ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
}

my @TERM_TAGS = qw(
id
is_anonymous
name
namespace
alt_id
def
comment
subset
synonym
xref
property_value
is_a
intersection_of
union_of
disjoint_from
relationship
created_by
creation_date
is_obsolete
replaced_by
consider
);

my @TYPEDEF_TAGS = qw(
id
is_anonymous
name
namespace
alt_id
def
comment
subset
synonym
xref
property_value
domain
range
is_anti_symmetric
is_cyclic
is_reflexive
is_symmetric
is_transitive
is_a
intersection_of
union_of
disjoint_from
inverse_of
transitive_over
holds_over_chain
equivalent_to_chain
disjoint_over
relationship
created_by
creation_date
is_obsolete
replaced_by
consider
expand_assertion_to
expand_expression_to
is_metadata_tag
is_class_level
);

my %tagrankh =
(
 'Term'=>numerify(@TERM_TAGS),
 'Typedef'=>numerify(@TYPEDEF_TAGS),
);

my $id;
my $stanza_type;
my $in_body;
my @lines = ();
while (<>) {
    chomp;
    if (/^\[(\w+)\]/) {
        $in_body = 1;
        $stanza_type = $1;
        if (@lines) {
            die "@lines";
        }
    }
    elsif (/^id:\s*(.*)/) {
            $id = $1;
    }
    elsif (/^(\S+):\s*(.*)/) {
        push(@lines,$_);
    }
    elsif (/^\!/) {
        push(@lines,$_);
    }
    elsif (/^\s*$/) {
        if ($in_body) {
            write_stanza();
        }
        else {
            # no sorting of hdr tags yet
            foreach (@lines) {
                print "$_\n";
            }
            print "\n";
            @lines = ();
        }
    }
    else {
        if ($in_body) {
            die $_;
        }
    }
}
if (@lines) {
    write_stanza();
}

exit(0);

sub write_stanza {
    if (!$id && !(@lines)) {
        return;
    }
    die "no id for: @lines" unless $id;
    die unless $stanza_type;
    die unless @lines;
    print "[$stanza_type]\n";
    print "id: $id\n";
    foreach (sort { rnk($a) <=> rnk($b) } @lines) {
        print "$_\n";
    }
    print "\n";
    $id = '';
    @lines = ();
}

sub rnk {
    my ($line) = @_;
    if ($line =~ /(\S+):/) {
        return $tagrankh{$stanza_type}->{$1} || die "$1 in $line";
    }
    die $line;
}

sub numerify {
    my @arr = @_;
    my $n = 1;
    my %h = 
        map { ($_ => $n++) } @arr;
    return \%h;
        
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn OBO-FILE [OBO-FILE2...]

performs syntactic check on intersection_of definitions

Example:

$sn mammalian_phenotype_xp.obo

EOM
}

