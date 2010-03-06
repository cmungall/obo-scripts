#!/usr/bin/perl -w

use strict;
my $use_consider;
my $use_replaced_by;
my $verbose;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '-c' || $opt eq '--use-consider') {
        $use_consider = 1;
    }
    elsif ($opt eq '-v' || $opt eq '--verbose') {
        $verbose = 1;
    }
    elsif ($opt eq '-r' || $opt eq '--use-replaced_by') {
        $use_replaced_by = 1;
    }
}
if (!@ARGV) {
    print usage();
    exit 0;
}

# everything except last is used to build the reference map
my $lastf = pop @ARGV;
my $id;
my %alt = ();
my %rep = ();
my %cdr = ();
my %validh = ();

# build map
while (<>) {
    chomp;
    if (/^id:\s+(\S+)/) {
        $id = $1;
	$validh{$id} = 1;
    }
    elsif (/^alt_id:\s+(\S+)/) {
        $alt{$1} = $id;
    }
    elsif (/^replaced_by:\s+(\S+)/) {
        push(@{$rep{$id}},$1);
    }
    elsif (/^consider:\s+(\S+)/) {
        push(@{$cdr{$id}},$1);
    }
    elsif (/^is_obolete:.*true/) {
	delete $validh{$id};
    }
}

if ($use_consider) {
    foreach my $k (keys %cdr) {
        printf STDERR "using consider $k --> @{$cdr{$k}}\n";
        if (@{$cdr{$k}} == 1) {
            if (!$alt{$k}) {
                $alt{$k} = $cdr{$k}->[0];
            }
        }
    }
}
if ($use_replaced_by) {
    foreach my $k (keys %rep) {
        printf STDERR "replaced_by $k --> @{$rep{$k}}\n";
        if (@{$rep{$k}} == 1) {
            if (!$alt{$k}) {
                $alt{$k} = $rep{$k}->[0];
                printf STDERR "  $k --> $alt{$k}\n";
            }
        }
        else {
            printf STDERR "  ditching\n";
        }
       
    }
}

printf STDERR "mappings: %d\n", scalar(keys %alt);

# now perform mappings on the main file
my $n = 0;
open(F,$lastf);
while(<F>) {
    chomp;
    my @toks = split(' ',$_);
    my $oldtoks = "@toks";
    @toks = map {$alt{$_} || $_} @toks;
    if ("@toks" ne $oldtoks) {
        $n++;
	if ($verbose) {
	    print STDERR "Mapped $oldtoks --> @toks\n";
	}
    }
    #foreach my $k (keys %alt) {
    #    my $r = $alt{$k};
    #    s/$k/$r/ge;
    #}
    $_ = join(' ',@toks);

    if (1) {
	if (/^id:\s*(\S+)/) {
	    check($1);
	}
	elsif (/^is_a:\s*(\S+)/) {
	    check($1);
	}
	elsif (/^relationship:\s*\S+\s+(\S+)/) {
	    check($1);
	}
	elsif (/^intersection_of:\s*\S+\s+(\S+:\S+)/) {
	    check($1);
	}
	elsif (/^intersection_of:\s*(\S+:\S+)/) {
	    check($1);
	}
    }

    print "$_\n";
}
close(F);
printf STDERR "Fixed: $n\n";
exit 0;

sub check {
    my $x = shift;
    if (!$validh{$x}) {
	print STDERR "Invalid ref: $x Line: $_\n";
    }
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [--use-consider] [--use-replaced_by] REFERENCED-FILE-1 [REFERENCED-FILE-n...] REFERENCING-FILE

maps based on alt_id


EOM
}

