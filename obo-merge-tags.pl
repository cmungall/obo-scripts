#!/usr/bin/perl -w

use strict;
my %tag_h=();
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '-t' || $opt eq '--tag') {
        $tag_h{shift @ARGV} = 1;
    }
}
print STDERR "Tags: ", join(', ',keys %tag_h),"\n";

my %filtered_lines_by_id_h=();
while (@ARGV) {
    my $f = pop @ARGV;  # go through in REVERSE order
    my $is_final = !@ARGV;
    my $id;
    my $in_header = 1;
    open(F,$f) || die $f;
    while(<F>) {
        if (/^id:\s+(\S+)/) {
            $id = $1;
        }
        elsif (!$is_final && /^(\S+):/) {
            if (!$id) {
                if (!$in_header) {
                    die "assertion error!";
                }
                $id = ''; # in header - call this ID ''
            }
            if ($tag_h{$1}) {
                push(@{$filtered_lines_by_id_h{$id}},$_);
            }
        }
        elsif ($is_final && /^\s*$/) {
            # end of stanza, show any additional tags
            showtags($id);
            # later on we print the newline stanza separator...
        }
        else {
        }

        if ($is_final) {
            print $_;
        }
    } # end of file

    if ($is_final) {
        # don't forget the last one
        showtags($id);
    }
    close(F);
}

exit 0;

sub showtags {
    my $id = shift || '';
    my %done_h = (); # avoid dupes
    if ($filtered_lines_by_id_h{$id}) {
        foreach (@{$filtered_lines_by_id_h{$id} || []}) {
            next if $done_h{$_};
            print $_;
            $done_h{$_} = 1;
        }
        delete $filtered_lines_by_id_h{$id};
    }
    return;
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

$sn  -t intersection_of -t id-mapping gene_ontology.obo go_xp_cell.obo go_xp_chebi.obo 

EOM
}

