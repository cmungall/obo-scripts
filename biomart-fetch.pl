#!/usr/bin/perl

use strict;
use LWP::UserAgent;

my @atts = ();
my @incfilters = ();
my $dataset = 'hsapiens_gene_ensembl';
my $path="http://www.biomart.org/biomart/martservice?";
my $print_header = 0;

while (scalar(@ARGV) && $ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '-a') {
        push(@atts, shift @ARGV);
    }
    elsif ($opt eq '-i') {
        push(@incfilters, shift @ARGV);
    }
    elsif ($opt eq '-g') {
        push(@atts, 'ensembl_gene_id');
    }
    elsif ($opt eq '-p' || $opt eq '--preset') {
        my $preset = shift @ARGV;
        @atts = @{presets()->{$preset}};
        if (!@atts) {
            die "no such preset: $preset";
        }
    }
    elsif ($opt eq '-c') {
        $print_header = 1;
    }
    elsif ($opt eq '-d') {
        $dataset = shift @ARGV;
    }
    elsif ($opt eq '-s') {
        $path = shift @ARGV;
    }
    else {
        die "unknown option: $opt";
    }
}
push(@atts, @ARGV);

if (!@atts) {
    @atts = qw(ensembl_gene_id entrezgene);
}
elsif (@atts == 1) {
    push(@atts,'entrezgene');
}
#print STDERR "ATTS: @atts\n";

my $xml = mk_xml();

my $request = HTTP::Request->new("POST",$path,HTTP::Headers->new(),'query='.$xml."\n");
my $ua = LWP::UserAgent->new;

my $response;

print_header() if $print_header;
my $ok = 0;
my $n = 1;
while (!$ok && $n < 4) {
    $ua->request($request, 
	     sub{   
		 my($data, $response) = @_;
		 if ($response->is_success && $data !~ /^Query ERROR/) {
		     print "$data";
                     $ok = 1;
		 }
		 else {
		     warn ("Problems with the web server: ".$response->status_line);
                     print STDERR "DATA: $data\n";
                     $ok = 0;
                     sleep(30);
                     $n++;
		 }
	     },1000);
}
exit !$ok;


sub presets {
    {
        basic=>[qw(ensembl_gene_id external_gene_id gene_biotype entrezgene ox_refseq_mrna__dm_dbprimary_acc_1074 ox_refseq_ncrna__dm_dbprimary_acc_1074)],
        varpheno=>[qw(ensembl_gene_stable_id refsnp_id chr_name chrom_start allele minor_allele minor_allele_freq minor_allele_count clinical_significance phenotype_description study_type study_external_ref study_description variation_names source_name associated_gene phenotype_name associated_variant_risk_allele risk_allele_freq_in_controls polyphen_prediction polyphen_score sift_prediction sift_score p_value)],
        zfin=>[qw(ensembl_gene_id zfin_id uniprot_sptrembl)],
        zfin_expr=>[qw(ensembl_gene_id zfin_id anatomical_system_zfin)],
    };
}

sub mk_xml {

    my $attxml = join("\n",
                      (map {
                          "                   <Attribute name=\"$_\"/>"
                      } @atts),
                      (map {
                          "                   <Filter name=\"$_\" excluded=\"0\"/>"
                       } @incfilters));


    

    <<EOM
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "1" count = "" datasetConfigVersion = "0.6" >
			
	<Dataset name = "$dataset" interface = "default" >
           $attxml
	</Dataset>
</Query>

EOM
}

sub print_header {
    print join("\t", @atts)."\n";
}

sub usage {
    my $sn = 'biomart-fetch.pl';

    <<FOOBAR;
$sn [-s SERVERURL] [-a ATT1...] [-d DATASET] [-p PRESET...] ATTS

Extracts data from BioMart

Options:
  -a ATTRIBUTE : For a full list of attributes go to http://www.ensembl.org/biomart
  -d DATASET: default is hsapiens_gene_ensembl
  -p PRESET : so for only one - basic

Examples:

# get mapping of ensembl genes to entrezgene
$sn -a ensembl_gene_id -a entrezgene

# shorthand for the same thing:
$sn -g entrezgene

# use an existing packaged set of annotations
$sn --preset basic

# preset for zfin IDs
$sn  -d drerio_gene_ensembl --preset zfin



FOOBAR
}

