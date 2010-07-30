#!/usr/bin/perl -w

use strict;
my $use_consider;
my $use_replaced_by;
my $use_xref;
my $use_xref_inverse;
my $verbose;
my @inputfiles = ();
my $silent = 0;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '-s' || $opt eq '--silent') {
        $silent = 1;
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
    elsif ($opt eq '-x' || $opt eq '--use-xref') {
        $use_xref = 1;
    }
    elsif ($opt eq '-y' || $opt eq '--use-xref-inverse') {
        $use_xref_inverse = 1;
    }
}
if (!@ARGV) {
    print usage();
    exit 0;
}

my @reffs = ();
while (my $f = shift @ARGV) {
    if ($f eq '-i' || $f eq '--input-files') {
        @inputfiles = @ARGV;
	last;
    }
    if (!@ARGV) {
	@inputfiles = ($f); # use last by default
    }
    else {
	push(@reffs,$f);
    }
}
@ARGV = @reffs;

my $id;
my %alt = ();
my %rep = ();
my %cdr = ();
my %xrefh = ();
my %invxrefh = ();
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
    elsif (/^xref:\s+(\S+)/) {
        push(@{$xrefh{$id}},$1);
        push(@{$invxrefh{$1}},$id);
    }
    elsif (/^is_obsolete:.*true/) {
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
if ($use_xref) {
    foreach my $k (keys %xrefh) {
        printf STDERR "using xref $k --> @{$xrefh{$k}}\n";
        if (@{$xrefh{$k}} == 1) {
            if (!$alt{$k}) {
                $alt{$k} = $xrefh{$k}->[0];
            }
        }
    }
}
if ($use_xref_inverse) {
    foreach my $k (keys %invxrefh) {
        printf STDERR "using xref (inv) $k --> @{$invxrefh{$k}}\n";
        if (@{$invxrefh{$k}} == 1) {
            if (!$alt{$k}) {
                $alt{$k} = $invxrefh{$k}->[0];
            }
        }
    }
}

printf STDERR "mappings: %d\n", scalar(keys %alt);

# now perform mappings on the main file
my $n = 0;
my @hdr = ();
my @out = ();
foreach my $f (@inputfiles) {
    open(F,$f);
    push(@out, "! input: $f\n");
    my $in_hdr = 1;
    while(<F>) {
	chomp;
	if (/^\[/) {
	    $in_hdr = 0;
	}
	if ($in_hdr) {
	    push(@hdr,"$_\n")
		unless /^\s*$/;
	    next;
	}
	if (/^(alt_id|xref):/) {
	    # prevent self-replacements
	    push(@out, "$_\n");
	    next;
	}
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

	if (!$silent) {
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

	push(@out, "$_\n");
    }
    close(F);
    push(@out, "\n");
}
printf STDERR "Fixed: $n\n";
foreach (@hdr) {
    print "$_";
}
print "\n";
foreach (@out) {
    print "$_";
}
exit 0;

sub check {
    my $x = shift;
    if (!$validh{$x}) {
        if ($verbose) {
            print STDERR "Invalid ref: $x Line: $_\n";
        }
    }
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [--use-consider] [--use-replaced_by] [--use-xref] [--use-xref-inverse] REFERENCED-FILE-1 [REFERENCED-FILE-n...] REFERENCING-FILE

maps ID references based on alt_id


EOM
}

