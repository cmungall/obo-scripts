#!/usr/bin/perl -w

use strict;
my $use_consider;
my $use_replaced_by;
my $use_xref;
my $use_xref_inverse;
my $use_link_to;
my $verbose;
my $silent = 0;
my %colnoh;
my $regex_filter;
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
    elsif ($opt eq '--use-link-to') {
        $use_link_to = shift @ARGV;
    }
    elsif ($opt eq '--regex-filter') {
        $regex_filter = shift @ARGV;
    }
    elsif ($opt eq '-k' || $opt eq '--col') {
        $colnoh{shift @ARGV} = 1;
    }
}
if (!@ARGV) {
    print usage();
    exit 0;
}

my @inputfiles = (); # files to map

my @reffs = ();      # files to use in mapping
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
my %alt = (); # use this to map
my %rep = ();
my %cdr = ();
my %xrefh = ();
my %invxrefh = ();
my %validh = ();
my %linkh = ();

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
    elsif (/^(intersection_of|relationship):\s+\S+\s+(\S+):(\S+)/) {
        push(@{$linkh{$id}->{$2}},"$2:$3");
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
                $alt{$k} = idfilter($cdr{$k});
            }
        }
    }
}
if ($use_replaced_by) {
    foreach my $k (keys %rep) {
        printf STDERR "replaced_by $k --> @{$rep{$k}}\n";
        if (@{$rep{$k}} == 1) {
            if (!$alt{$k}) {
                $alt{$k} = idfilter($rep{$k});
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
        if (!$alt{$k}) {
            $alt{$k} = idfilter($xrefh{$k});
        }
    }
}
if ($use_link_to) {
    foreach my $k (keys %linkh) {
        printf STDERR "using link $k --> @{$linkh{$k}->{$use_link_to}}\n";
        if (@{$linkh{$k}->{$use_link_to}} == 1) {
            if (!$alt{$k}) {
                $alt{$k} = idfilter($linkh{$k}->{$use_link_to});
            }
        }
    }
}
if ($use_xref_inverse) {
    foreach my $k (keys %invxrefh) {
        printf STDERR "using xref (inv) $k --> @{$invxrefh{$k}}\n";
        if (@{$invxrefh{$k}} == 1) {
            if (!$alt{$k}) {
                $alt{$k} = idfilter($invxrefh{$k});
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

    if (%colnoh) {
        map_tab_files($f);
    }
    else {
        map_obo_files($f);
    }
}


printf STDERR "Fixed: $n\n";
foreach (@hdr) {
    print "$_";
}
#print "\n";
foreach (@out) {
    print "$_";
}
exit 0;

sub idfilter {
    my $arr = shift;
    if ($regex_filter) {
        $arr = [grep {m/$regex_filter/x} @$arr];
    }
    if (scalar(@$arr)>1) {
        warn("MULTIPLE: @$arr");
    }
    return $arr->[0];
}

sub map_tab_files {
    my $f = shift;
    open(F,$f);
    while (<F>) {
        chomp;
        my @vals = split(/\t/,$_);
        my $modified = 0;
        foreach my $k (keys %colnoh) {
            my $v = $vals[$k-1];
            if ($alt{$v}) {
                $vals[$k-1] = $alt{$v};
                $modified = 1;
            }
        }
        if ($modified) {
            push(@out,join("\t",@vals)."\n");
        }
        else {
            #print STDERR "not modified";
        }
    }
    close(F);
}
sub map_obo_files {
    my $f = shift;
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
$sn [--use-consider] [--use-replaced_by] [--use-xref] [--use-xref-inverse] MAPPING-FILE-1 [MAPPING-FILE-n...] FILE-TO-MAP

maps ID references, by default based on alt_id

If you want to map multiple files:

$sn [--use-consider] [--use-replaced_by] [--use-xref] [--use-xref-inverse] MAPPING-FILE-1 [MAPPING-FILE-n...] -i FILE-TO-MAP1 [FILE-TO-MAP-2...]

by default the file(s) to map are obo files.

EOM
}

