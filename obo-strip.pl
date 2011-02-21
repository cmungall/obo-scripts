#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $negate = 0;
my $typedef = 1;
my $show_header = 1;
my %idspace_h = ();
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
    elsif ($opt eq '-n' || $opt eq '--negate') {
        $negate = 1;
    }
    elsif ($opt eq '-s' || $opt eq '--idspace') {
        $idspace_h{shift @ARGV} = 1;
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

#print STDERR "Tags: ", join(', ',keys %tag_h),"\n";

my $on = 1;
my $in_header = 1;
my @lines = <>;
my $id;
while($_ = shift @lines) {
    if (/^\[(\S+)\]/) {
        $in_header=0;
	if ($1 eq 'Typedef' && !$typedef) {
	    $on = 0;
	}
	else {
	    $on = 1;
	}
    }

    if ($in_header) {
        if ($show_header) {
            print;
        }
    } 
    else {
	if (/^\[/) {
	    $on = 1;
	}

        if (/^id:\s*(\S+)/) {
	    $id = $1;
	    if ($id =~ /(\w+):/) {
		$on = !$idspace_h{$1};
	    }
	    print $_
	}
        elsif (/^(\w+):\s*(.*)/) {
	    print $_ if $tag_h{$1} && $on;
	}
        elsif (/^\s*\n$/) {
	    print $_;
	}
	else {
	    print $_;
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
$sn [-t tag]* [--no-header] FILE [FILE...]

strips all tags except selected

Example:

$sn  -t id -t xref gene_ontology.obo

EOM
}

