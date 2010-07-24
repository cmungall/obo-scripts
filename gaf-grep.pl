#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $regexp = '';
my $noheader;
my $negate;
my $count;
my $aspect;
my $taxon;
my $species;
my %evidenceh = ();
my $date;
my $noqual;
my $source;
my %species2suffix;
my $autofiles;
my $gafdir;
my $dbh;
my $sth_tax;
my $term;
my %taxh = ();
my %subh = ();
my @dbargs = ();
my $verbose;
while (scalar(@ARGV) && $ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '-r' || $opt eq '--regexp') {
        $regexp = shift @ARGV;
    }
    elsif ($opt eq '--regexp-file') {
        my $f = shift @ARGV;
        my @or = ();
        open(F,$f);
        while(<F>) {
            chomp;
            push(@or,$_);
        }
        close(F);
        $regexp = sprintf('id: (%s)', join('|',@or));
    }
    elsif ($opt eq '-t' || $opt eq '--taxon') {
        $taxon = shift @ARGV;
    }
    elsif ($opt eq '-s' || $opt eq '--species') {
        $species = shift @ARGV;
    }
    elsif ($opt eq '--source') {
        $source = shift @ARGV;
    }
    elsif ($opt eq '-a' || $opt eq '--aspect') {
        $aspect = shift @ARGV;
    }
    elsif ($opt eq '--date') {
        $date = shift @ARGV;
    }
    elsif ($opt eq '-o' || $opt eq '--ontology-term') {
        $term = shift @ARGV;
    }
    elsif ($opt eq '-c' || $opt eq '--count') {
        $count = 1;
    }
    elsif ($opt eq '-q' || $opt eq '--no-qualifiers') {
        $noqual = 1;
    }
    elsif ($opt eq '--auto-select') {
        $autofiles = 1;
        $noheader = 1;
    }
    elsif ($opt eq '--gaf-dir') {
        $gafdir = shift @ARGV;
        $autofiles = 1;
        $noheader = 1;
    }
    elsif ($opt eq '-e' || $opt eq '--evidence') {
        %evidenceh = map {s/\s+//g;($_=>1)} split(/[,\/]/,shift @ARGV);
    }
    elsif ($opt eq '--noheader') {
        $noheader = 1;
    }
    elsif ($opt eq '--neg') {
        $negate = 1;
    }
    elsif ($opt eq '-v') {
        $verbose = 1;
    }
    elsif ($opt eq '-d' || $opt =~ /^\-\-db/) {
        require "DBI.pm";
        @dbargs = shift @ARGV;
        #$dbh = DBI->connect(@dbargs);
        #$sth_tax = $dbh->prepare("SELECT * FROM species AS c, species AS p WHERE c.ncbi_taxa_id=? AND p.ncbi_taxa_id=? AND (c.left_value BETWEEN p.left_value AND p.right_value)");
    }
}

init_taxmap();

if ($autofiles) {
    my @files = ();
    if ($taxon) {
        foreach my $sp (keys %species2suffix) {
            if (tax_subsumed_by($sp,$taxon)) {
                push(@files, "gene_association.".$species2suffix{$sp}.".gz");
            }
        }
    }
    if ($species) {
        if ($species2suffix{$species}) {
            @files = "gene_association.".$species2suffix{$species}.".gz";
        }
        else {
            # use ALL files?
            die "don't know what to do with $species";
        }
    }
    if ($gafdir) {
        foreach (@files) {
            $_ = "$gafdir/$_";
        }
    }
    @ARGV = @files;
    if (!@files) {
        die "don't know which files to use";
    }
}

if (!@ARGV) {
    @ARGV = ('-');
}

my $n = 0;
while (@ARGV) {
    my $f = pop @ARGV;
    if ($f eq '-') {
        *F=*STDIN;
    }
    elsif ($f =~ /\.gz$/) {
        open(F,"gzip -dc $f|");
    }
    else {
        open(F,$f) || die "cannot open $f";
    }
    while(<F>) {
        if (/^\!/) {
            print unless $noheader || $count;
        }
        else {
            chomp;
            my @vals = split(/\t/);
            my $ok = 1;
            if ($aspect && $vals[8] ne $aspect) {
            }
            elsif ($taxon && !tax_subsumed_by($vals[12],$taxon)) {
            }
            elsif ($species && $vals[12] ne $species) {
            }
            elsif ($noqual && $vals[3]) {
            }
            elsif (keys(%evidenceh) && !$evidenceh{$vals[6]}) {
                #printf STDERR "E:$vals[6] not in %s\n", keys(%evidenceh);
            }
            elsif ($regexp && $_ !~ /$regexp/) {
            }
            elsif ($term && !term_subsumed_by($vals[4],$term)) {
            }
            elsif ($date && $date =~ /(\d+)\+/ && $vals[13] < $1) {
            }
            elsif ($date && $date =~ /(\d+)\-/ && $vals[13] > $1) {
            }
            elsif ($date && $date =~ /(\d+)/ && $vals[13] < $1) { # default to +
            }
            elsif ($source && $vals[14] ne $source) {
            }
            else {
                print "$_\n"
            }
        }
    }
    close(F);
}
if ($count) {
    print "$n\n";
}

exit 0;

sub logmsg {
    if ($verbose) {
        printf STDERR "@_\n";
    }
}

sub get_sth_tax {
    if (!$sth_tax) {
        if (!@dbargs) {
            @dbargs = ('ebi');
        }
        if ($dbargs[0] eq 'ebi') {
            @dbargs = ('dbi:mysql:database=go_latest;host=mysql.ebi.ac.uk;port=4085','go_select', 'amigo');
        }
        $dbh = DBI->connect(@dbargs);
        $sth_tax = $dbh->prepare("SELECT * FROM species AS c, species AS p WHERE c.ncbi_taxa_id=? AND p.ncbi_taxa_id=? AND (c.left_value BETWEEN p.left_value AND p.right_value)");
    }
    return $sth_tax;
}

sub tax_subsumed_by {
    my $c = shift;
    my $p = shift;
    $c =~ s/taxon://;
    $p =~ s/taxon://;
    if (defined $taxh{$c} && defined $taxh{$c}->{$p}) {
        return $taxh{$c}->{$p};
    }
    logmsg("testing $c < $p");
    get_sth_tax()->execute($c,$p);
    my $v = get_sth_tax()->fetchall_arrayref;
    $v = scalar(@$v);
    $taxh{$c}->{$p} = $v;
    logmsg("     $c < $p :: $v");
    return $v;
}

sub term_subsumed_by {
    my $c = shift;
    my $p = shift;
    if ($p =~ /\[(\S+)\](\S+)/) {
# TODO
        my ($r,$p) = ($1,$2);
        if (defined $subh{$c} && defined $subh{$c}->{$p}) {
            return $subh{$c}->{$p};
        }
        logmsg("testing $c [ $r $p");
        get_sth_term()->execute($c,$r,$p);
        my $v = get_sth_term()->fetchall_arrayref;
        $v = scalar(@$v);
        $subh{$c}->{$p} = $v;
        logmsg("     $c < $p :: $v");
        return $v;
    }
    else {
        return $c eq $p;
    }
}

# cut and paste from filter-gene-associations.pl - should come from metadata file
sub init_taxmap {
    %species2suffix = (
    'taxon:5476'=>'cgd',
    'taxon:162425'=>'aspgd',
    'taxon:5782'=>'dictyBase',
    'taxon:44689'=>'dictyBase',
    'taxon:352472'=>'dictyBase',
    'taxon:366501'=>'dictyBase',
    'taxon:83333'=>'ecocyc',
    'taxon:7227'=>'fb',
    'taxon:5664'=>'GeneDB_Lmajor',
    'taxon:5833'=>'GeneDB_Pfalciparum',
    'taxon:4896'=>'GeneDB_Spombe',
    'taxon:185431'=>'GeneDB_Tbrucei',
    'taxon:37546'=>'GeneDB_tsetse',
    'taxon:9031'=>'goa_chicken',
    'taxon:400035'=>'goa_chicken',
    'taxon:208526'=>'goa_chicken',
    'taxon:208525'=>'goa_chicken',
    'taxon:208524'=>'goa_chicken',
    'taxon:9913'=>'goa_cow',
    'taxon:297284'=>'goa_cow',
    'taxon:30523'=>'goa_cow',
    'taxon:9606'=>'goa_human',
    'taxon:4528'=>'gramene_oryza',
    'taxon:4529'=>'gramene_oryza',
    'taxon:4530'=>'gramene_oryza',
    'taxon:4532'=>'gramene_oryza',
    'taxon:4533'=>'gramene_oryza',
    'taxon:4534'=>'gramene_oryza',
    'taxon:4535'=>'gramene_oryza',
    'taxon:4536'=>'gramene_oryza',
    'taxon:4537'=>'gramene_oryza',
    'taxon:4538'=>'gramene_oryza',
    'taxon:29689'=>'gramene_oryza',
    'taxon:29690'=>'gramene_oryza',
    'taxon:39946'=>'gramene_oryza',
    'taxon:39947'=>'gramene_oryza',
    'taxon:40148'=>'gramene_oryza',
    'taxon:40149'=>'gramene_oryza',
    'taxon:52545'=>'gramene_oryza',
    'taxon:63629'=>'gramene_oryza',
    'taxon:65489'=>'gramene_oryza',
    'taxon:65491'=>'gramene_oryza',
    'taxon:77588'=>'gramene_oryza',
    'taxon:83307'=>'gramene_oryza',
    'taxon:83308'=>'gramene_oryza',
    'taxon:83309'=>'gramene_oryza',
    'taxon:110450'=>'gramene_oryza',
    'taxon:110451'=>'gramene_oryza',
    'taxon:127571'=>'gramene_oryza',
    'taxon:364099'=>'gramene_oryza',
    'taxon:364100'=>'gramene_oryza',
    'taxon:10090'=>'mgi',
    'taxon:10116'=>'rgd',
    'taxon:4932'=>'sgd',
    'taxon:41870'=>'sgd',
    'taxon:285006'=>'sgd',
    'taxon:307796'=>'sgd',
    'taxon:3702'=>'tair',
    'taxon:212042'=>'jcvi_Aphagocytophilum',
    'taxon:198094'=>'jcvi_Banthracis',
    'taxon:227377'=>'jcvi_Cburnetii',
    'taxon:246194'=>'jcvi_Chydrogenoformans',
    'taxon:195099'=>'jcvi_Cjejuni',
    'taxon:195103'=>'jcvi_Cperfringens',
    'taxon:167879'=>'jcvi_Cpsychrerythraea',
    'taxon:243164'=>'jcvi_Dethenogenes',
    'taxon:205920'=>'jcvi_Echaffeensis',
    'taxon:243231'=>'jcvi_Gsulfurreducens',
    'taxon:228405'=>'jcvi_Hneptunium',
    'taxon:265669'=>'jcvi_Lmonocytogenes',
    'taxon:243233'=>'jcvi_Mcapsulatus',
    'taxon:222891'=>'jcvi_Nsennetsu',
    'taxon:220664'=>'jcvi_Pfluorescens',
    'taxon:223283'=>'jcvi_Psyringae',
    'taxon:264730'=>'jcvi_Psyringae_phaseolicola',
    'taxon:211586'=>'jcvi_Soneidensis',
    'taxon:246200'=>'jcvi_Spomeroyi',
        #'taxon:5691'=>'jcvi_Tbrucei_chr2',
    'taxon:686'=>'jcvi_Vcholerae',
    'taxon:6239'=>'wb',
    'taxon:7955'=>'zfin',
    );
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn [--noheader] [-d DBI_SPEC] [-q] [--source SRC] [-e EVIDENCE(s)] [-s SPECIES_TAX_ID] [-t TAX_ID]\
 [-a ASPECT] [--r REGULAR-EXPRESSION] GAF-FILE

Filters GAFs

Examples:

# filter all IMP/IEAs to cell component, remove qualified/negated annotations, from UniProtKB
gaf-grep.pl -a C -e IMP,IEA -q --source UniProtKB gene_association.sgd.gz

# get all annotations to taxon:4932 (direct) -- automatically select the GAF(s) from the current directory
gaf-grep.pl --gaf-dir . -s taxon:4932

# get all mammalian annotations, select GAF(s) automatically. Use ebi mirror to resolve taxon queries
gaf-grep.pl -d ebi --gaf-dir . -t taxon:40674

Arguments:

  --noheader           
              omit GAF header. This is set automaticaly when the GAF is auto-selected
  -q, --no-qualifiers
              omit lines that have NOTs or any qualifier
  -a, --aspect ASPECT
              filter by aspect. One of C or F or P
  -e, --evidence CODE(s)
              filter by evidence code. direct. Separate multiple entries by , or /
  -s, --species taxon:NUM
              filter by species. direct - no taxonomic inference.
  -t, --taxon   taxon:NUM
              filter by taxon. can be non-species, e.g. mammals. taxon inference is used. requires db connection
  --gaf-dir DIR
              gene-associations directory. if this is set then files will be automatically selected based on species/taxon

  -d, --dbi   DBISPEC
              Either a full DBI spec or a shorthand name.
              Currently the only shorthand name is 'ebi'.
              This is currently required for taxonomic inference.
              
              

TODO:

filter bt GO ID

EOM
}

