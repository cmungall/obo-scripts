#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $negate = 0;
my $typedef = 1;
my $show_header = 1;
my $obsidfile;
my @obsids = ();
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '--typedef') {
        $typedef = 1; # now the default
    }
    elsif ($opt eq '--no-typedef') {
        $typedef = 0;
    }
    elsif ($opt eq '--no-header') {
        $show_header = 0;
    }
    elsif ($opt eq '-i' || $opt eq '--idfile') {
        $obsidfile = shift @ARGV;
    }
    elsif ($opt eq '-l' || $opt eq '--idlist') {
        @obsids = split(/,/,shift @ARGV);
    }
    elsif ($opt eq '-n' || $opt eq '--negate') {
        $negate = 1;
    }
    elsif ($opt eq '-t' || $opt eq '--tag') {
        $tag_h{shift @ARGV} = 1;
    }
    elsif ($opt eq '-') {
    }
    else {
        die "$opt";
    }
}
#if (!@ARGV) {
#    print usage();
#    exit 1;
#}
print STDERR "Tags: ", join(', ',keys %tag_h),"\n";
my %logictag = (
    is_a => 1,
    intersection_of => 1,
    disjoint_from => 1,
    relationship => 1
    );

if ($obsidfile) {
    open(F,$obsidfile) || die $obsidfile;
    while(<F>) {
        chomp;
        s/^\s+//;
        s/\s+$//;
        push(@obsids, $_);
    }
    close(F);
}


my $id;
my $n;
my $is_obs = 0;
while(<>) {
    chomp;
    if (m@^id:\s+(\S+)@) {
        $id = $1;
        if (grep {$_ eq $id} @obsids) {
            $is_obs = 1;
        }
        else {
            $is_obs = 0;
        }
    }
    elsif (m@^name:\s+(.*)@) {
        $n = $1;
        if (grep {lc($_) eq lc($n)} @obsids) {
            $is_obs = 1;
        }
        if ($is_obs) {
            $_ = "name: obsolete $n\nis_obsolete: true";
        }
    }
    elsif (m@^(\S+):\s+(.*)@) {
        my ($tag, $val) = ($1, $2);
        if ($is_obs) {
            if (m@intersection_of: \s+(\S+)\s+(\S+)\s+\!\s+(.*)@) {
                # HACK:
                #print "consider: $2 ! $3\n";
            }
            if ($logictag{$tag}) {
                print STDERR "SKIPPING: $_\n";
                next;
            }
            if (m@xref:\s+(.*)@) {
                $_ = "consider: $1";
            }
        }
    }
    else {
    }

    print "$_\n";
    
}


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

