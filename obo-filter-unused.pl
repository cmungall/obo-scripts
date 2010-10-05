#!/usr/bin/perl -w

use strict;
my $idspace;
my $verbose;
my $filter_dangling = 1; # default
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '--xp2rel') {
	# default
    }
    elsif ($opt eq '--idspace') {
        $idspace = shift @ARGV;
    }
    elsif ($opt eq '--verbose' || $opt eq '-v') {
        $verbose = 1;
    }
    elsif ($opt eq '-') {
    }
    else {
        die "$opt";
    }
}

# ----------------------------------------
# keep track of references typedefs, synonymtypedefs etc
# ----------------------------------------
my %synonymtypedef = ();
my %subsetdef = ();
my %used = ();

# ----------------------------------------
# load all lines
# ----------------------------------------

my @all_lines = ();
while (<>) {
    s/\s+$//;
    chomp;
    if (/^synonym:\s*\".*\"\s+(\w+)\s+(\S+)/) {
        $synonymtypedef{$2} = 1;
    }
    elsif (/^intersection_of:\s*(\S+)/) {
        $used{$1} = 1;
    }
    elsif (/^relationship:\s*(\S+)/) {
        $used{$1} = 1;
    }
    elsif (/^transitive_over:\s*(\S+)/) {
        $used{$1} = 1;
    }
    elsif (/^holds_over_chain:\s*(\S+)\s+(\S+)/) {
        $used{$1} = 1;
        $used{$2} = 1;
    }
    elsif (/^is_a:\s*(\S+)/) {
        $used{$1} = 1;
    }
    elsif (/^subset:\s*(\S+)/) {
        $subsetdef{$1} = 1;
    }
    push(@all_lines,$_);
}

# ----------------------------------------
# process all lines
# ----------------------------------------

my @lines = ();
my $id;
my $st;
my $hide = 0;
foreach (@all_lines) {
    chomp;

    if (/^\[(\S+)\]/) {
       $st = $1; 
       $hide = 0;
    }
    elsif (/^id:\s*(\S+)/) {
       $id = $1;
       if ($st eq 'Typedef') {
           if (!$used{$id}) {
               $hide = 1;
               while ($lines[-1] !~ /^\[/) {
                   pop @lines;
               }
               pop @lines;
           }
       }
    }
    elsif (/^synonymtypedef:\s*(\S+)/) {
        if (!$used{$1}) {
            next;
        }
    }
    elsif (/^subsetdef:\s*(\S+)/) {
        if (!$subsetdef{$1}) {
            next;
        }
    }

    if ($hide) {
        next;
    }

    if (!$idspace) {
	if (/^id:\s+(\S+):(\S+)/) {
	    $idspace = $1;
	}
    }
    # buffer
    push(@lines, $_);

}

# ----------------------------------------
# write file
# ----------------------------------------
foreach (@lines) {
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
$sn [--idspace IDSPACE] FILE

strips all tags except selected

Example:

$sn  -t id -t xref gene_ontology.obo

EOM
}

