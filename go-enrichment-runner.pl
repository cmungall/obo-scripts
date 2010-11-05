#!/usr/bin/perl -w

use strict;
my $verbose;
my @programs;
my @input_gene_sets = ();
my @ontology_files = ();
my @gafs = ();
my @background_gene_sets = ();
my @tmp_files = ();
my $numgenes;
my $store_results;
my $parse;
my $outdir = '.';

our $ANNOT_TOOLS = "$ENV{HOME}/obo-galaxy/tools/annotation";
our $CP_ONTOLOGIZER = "$ANNOT_TOOLS";

our %requires_background_h =
    (ontologizer=>1);

while (scalar(@ARGV) && $ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '-v' || $opt eq '--verbose') {
        $verbose = 1;
    }
    elsif ($opt eq '-s' || $opt eq '--store') {
        $store_results = 1;
    }
    elsif ($opt eq '-d' || $opt eq '--dir') {
        $outdir = shift @ARGV;
    }
    elsif ($opt eq '-p' || $opt eq '--program') {
        push(@programs, nextargs());
    }
    elsif ($opt eq '-i' || $opt eq '--input') {
        #push(@input_gene_sets, shift @ARGV);
        push(@input_gene_sets, nextargs());
    }
    elsif ($opt eq '-o' || $opt eq '--ontology') {
        push(@ontology_files, nextargs());
    }
    elsif ($opt eq '-g' || $opt eq '--gaf') {
        push(@gafs, nextargs());
    }
    elsif ($opt eq '-b' || $opt eq '--background') {
        push(@background_gene_sets, nextargs());
    }
    elsif ($opt eq '--background-size') {
        $numgenes = shift @ARGV;
    }
}

if (!@background_gene_sets) {
    @background_gene_sets = (''); #NULL
}

if (! -d $outdir) {
    `mkdir $outdir`;
}

foreach my $program (@programs) {
    foreach my $i (@input_gene_sets) {
        foreach my $o (@ontology_files) {
            foreach my $g (@gafs) {
                foreach my $b (@background_gene_sets) {
                    run($program,$i,$o,$g,$b);
                }
            }
        }
    }
}

cleanup();

exit 0;

sub nextargs {
    my @r = ();
    while (scalar(@ARGV) && $ARGV[0] !~ /^\-/) {
        my $nxt = shift @ARGV;
        push(@r, glob($nxt));
    }
    return @r;
}

sub cleanup {
    foreach (@tmp_files) {
        unlink($_);
    }
}

# -- subs --

sub run {
    my ($program,$i,$o,$g,$bg) = @_;

    my ($exec,$subprog) = split_progname($program);

    if ($requires_background_h{$exec} && !$bg) {
        $bg = mk_tmp_file('background','txt');
        system("gzip -dc $g | cut -f3 > $bg");
    }

    my $cmd;
    if ($exec eq 'ontologizer') {
        $cmd = "java -Xmx1024M -jar $CP_ONTOLOGIZER/Ontologizer.jar  -g '$o' -a '$g' -c '$subprog' -s '$i' -p '$bg'";
    }
    elsif ($exec eq 'termfinder') {
        if (!$numgenes) {
            $numgenes = 25000;
        }
        my $g_unzipped = mk_tmp_file("unzipped","gaf");
        print `gzip -dc $g > $g_unzipped`;
        $cmd = "$ANNOT_TOOLS/analyze.pl $g_unzipped $numgenes $o $i";
    }
    elsif ($exec eq 'blip') {
        $cmd = "blip ontol-enrichment -cache_file blip_enrichment_cache.pro -idfile $i -ontology $o -gaf $g"
    }
    else {
    }

    my $out = mk_tmp_file("out","enr");

    $cmd .= "> $out";

    print "# program: $program\n";
    print "# input: $i\n";
    print "# ontology: $o\n";
    print "# GAF: $g\n";
    print "# background: $bg\n";
    print "# command: $cmd\n";
    my $err = system($cmd);

    if ($exec eq 'ontologizer') {
        open(F,$out);
        my $ok = 0;
        while (<F>) {
            if (/^INFO: "(.*)" success/) {
                $out = $1;
                $ok = 1;
            }
        }
        if (!$ok) {
            failme();
        }
        close(F);
    }

    if ($parse) {
        parse($out,$exec);
    }



    if ($store_results) {
        my $perm = mk_file_name([$program,$i,$o,$g,$bg],'enr');
        print `mv $out $perm`;
    }
    else {
        open(F,$out);
        my @lines = ();
        while (<F>) {
            chomp;
            push(@lines, $_);
        }
        close(F);
        if ($exec eq 'ontologizer') {
            my $kc = 5;
            @lines = map {[split(/\t/)]} @lines;
            @lines = sort {$a->[$kc] <=> $b->[$kc]} @lines;
            @lines = map {join("\t",@$_)} @lines;
        }
        foreach (@lines) {
            print "$_\n";
        }
    }

    return 0;
}

sub split_progname {
    return split("/",shift);
}

sub mk_tmp_file {
    my $base = shift;
    my $suffix = shift;
    my $f = "$outdir/$base$$.$suffix";
    push(@tmp_files,$f);
    return $f;
}

sub mk_file_name {
    my @parts = @{shift || []};
    my $suffix = shift;
    @parts = map {s/.*\///g;$_} @parts;
    my $f = join("-",@parts);
    return "$outdir/$f";
}

sub parse {
    my ($f,$fmt) = @_;
    my $func = "parse_".$fmt;
    return $func->($f);
}

sub parse_default {
    my $f = shift;
    my @rows = ();

    open(F,$f);
    while (<F>) {
        chomp;
        push(@rows, "# $_");
    }
    return @rows;
}

sub parse_blip {
    return parse_default(@_);
}

sub parse_ontologizer {
    return parse_default(@_);
}

sub parse_termfinder {
    my $f = shift;
    my $aspect;
    my $row = {};
    my @rows = ($row);
    my $in_hdr = 1;

    open(F,$f);
    while (<F>) {
        chomp;
        if (/Finding terms for (\S+)/) {
            $aspect = $1;
            $in_hdr = 0;
        }
        if ($in_hdr) {
            push(@rows, "# $_");
            next;
        }

        if (/^\-\- (\d+) of \d+/) {
            $row = {};
            push(@rows,$row);
        }
        elsif (/^GOID\s*(\S+)/) {
            $row->{class_id} = $1;
        }
        elsif (/^TERM\s*(.*)/) {
            $row->{class_name} = $1;
        }
        elsif (/^CORRECTED P\-VALUE\s*(.*)/) {
            $row->{corrected_p_value} = $1;
        }
        elsif (/^UNCORRECTED P\-VALUE\s*(.*)/) {
            $row->{uncorrected_p_value} = $1;
        }
        elsif (/The genes annotated to this node are/) {
            my $nxt = <>;
            $row->{genes} = [split(/,\s*/,$nxt)];
        }
        
    }
    close(F);
    return @rows;
}

# -- usage --

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [--noheader] [-d DBI_SPEC] [-q] [--source SRC] [-e EVIDENCE(s)] [-s SPECIES_TAX_ID] [-t TAX_ID]\

wrapper for various term enrichment programs

Examples:


EOM
}

