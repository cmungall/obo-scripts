#!/usr/bin/perl

use strict;
use LWP::UserAgent;

my @atts = ();
my $dataset = 'hsapiens_gene_ensembl';
my $path="http://www.biomart.org/biomart/martservice?";

while (scalar(@ARGV) && $ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '-a') {
        push(@atts, shift @ARGV);
    }
    elsif ($opt eq '-g') {
        push(@atts, 'ensembl_gene_id');
    }
    elsif ($opt eq '--preset') {
        my $preset = shift @ARGV;
        @atts = @{presets()->{$preset}};
        if (!@atts) {
            die "no such preset: $preset";
        }
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

$ua->request($request, 
	     sub{   
		 my($data, $response) = @_;
		 if ($response->is_success && $data !~ /^Query ERROR/) {
		     print "$data";
		 }
		 else {
		     warn ("Problems with the web server: ".$response->status_line);
                     exit 1;
		 }
	     },1000);

exit 0;

sub presets {
    {
        basic=>[qw(ensembl_gene_id external_gene_id gene_biotype entrezgene ox_refseq_mrna__dm_dbprimary_acc_1074 ox_refseq_ncrna__dm_dbprimary_acc_1074)],
        zfin=>[qw(ensembl_gene_id zfin_id uniprot_sptrembl)],
        zfin_expr=>[qw(ensembl_gene_id zfin_id anatomical_system_zfin)],
    };
}

sub mk_xml {

    my $attxml = join("\n",
                      map {
                          "                   <Attribute name=\"$_\"/>"
                      } @atts);

    <<EOM
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "0" count = "" datasetConfigVersion = "0.6" >
			
	<Dataset name = "$dataset" interface = "default" >
           $attxml
	</Dataset>
</Query>

EOM
}

sub usage {
    my $sn = 'biomart-fetch.pl';

    <<FOOBAR;
$sn [-a ATT1...] [-d DATASET] [-p PRESET...] ATTS

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

