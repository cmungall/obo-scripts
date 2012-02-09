#!/usr/bin/perl -w
# daily_files.pl
#
# script to generate various daily files from the OBO format file.
#
# usage: perl daily_files.pl <obo_file>
# where obo_file is an ontology file in OBO format,
# e.g. gene_ontology_write.obo

use strict;
use FileHandle;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use File::stat;

use Time::HiRes qw( gettimeofday tv_interval );

use lib "geneontology/go-moose/";
use GOBO::Graph;
use GOBO::Statement;
use GOBO::LinkStatement;
use GOBO::NegatedStatement;
use GOBO::Node;
use GOBO::Parsers::OBOParser;
use GOBO::InferenceEngine;
use GOBO::Writers::OBOWriter;

my $verbose = $ENV{GO_VERBOSE} || 1;
my $timestring = localtime();
my $messages;

my $obo_file = shift @ARGV;
if (!$obo_file || ! -f $obo_file)
{	die "Missing the required file $obo_file\n";
}

my $fh = new FileHandle($obo_file);
my $parser = new GOBO::Parsers::OBOParser(fh=>$fh);
$parser->parse;

$Data::Dumper::Maxdepth = 2;

#print STDERR "parser: " . Dumper( $parser );

my $data;
my $graph = $parser->graph;
my $ie = new GOBO::InferenceEngine(graph=>$graph);

foreach ( @{$graph->terms} )
{	next if $_->obsolete;
	## if it's in a subset, save the mofo.
	my $n = $_;
	if ($n->subsets)
	{	foreach ($n->subsets)
		{	push @{$data->{subset}{$_}}, $n->id;
		}
		$data->{all_slim_terms}{$n->id}++;
	}
}

my $acc = 0;
foreach my $t (keys %{$data->{all_slim_terms}})
{	## keep links to GS terms.
	foreach (@{ $graph->get_target_links($t) }) {
		next unless $data->{all_slim_terms}{$_->target->id};

		$data->{graph}{$t}{$_->target->id}{acc}{$_->relation}++;

		$data->{to_root}{$t}{$_->target->id}{$_->relation} = 'ass';
		$data->{to_leaf}{$_->target->id}{$t}{$_->relation} = 'ass';

		$data->{new_graph}{$t}{$_->target->{id}{$_->relation}++;
	}
	$links = $ie->get_inferred_target_links($t);
	foreach (@{ $ie->get_inferred_target_links($t) }) {
		next unless $data->{all_slim_terms}{$_->target->id};
		next if $data->{graph}{$t}{$_->target->id}{ass}{$_->relation};

		## add to a list of inferred entries
		$data->{graph}{$t}{$_->target->id}{inf}{$_->relation}++;

		$data->{to_root}{$t}{$_->target->id}{$_->relation} = 'inf';
		$data->{to_leaf}{$_->target->id}{$t}{$_->relation} = 'inf';
	}
}

#L : Empty list that will contain the sorted elements
#S : Set of all nodes with no incoming edges
my @paths;

foreach my $k (keys %{$data->{to_root}})
{	push @leaves, $k if ! $data->{to_leaf}{$k};
}

#while S is non-empty do
while (@leaves) {
	#	remove a node n from S
	#	insert n into L
	my $n = shift @leaves;
	push @paths, $n;
#	for each m with edge e to n
	foreach my $m (keys %{$data->{to_root}{$n}})
	{	foreach my $rel (keys %{$data->{to_root}{$n}{$m}})
		{
		#	remove edge e from the graph
			delete $data->{to_root}{$n}{$m}{$rel};
			delete $data->{to_leaf}{$m}{$n}{$rel};

		#	if m has no other incoming edges then
			if (! $data->{to_leaf}{$m})
			{	#	insert m into S
				push @leaves, $m;
				## n-m must be a unique route
				$data->{new_graph}{$n}{$m}{$rel}++;
			}
		}
	}
}

print STDERR "new graph: " . Dumper($data->{new_graph});

#if graph has edges then
#    output error message (graph has at least one cycle)
#else
#    output message (proposed topologically sorted order: L)





=cut
open(IN, '<'.$obo_file) or die "The file $obo_file could not be opened: $!";
open(OUT, '>mini_obo_file') or die "Could not open mini_obo_file for writing: $!";
print "Loading current ontology...\n";
$/ = "\n\n";
while (<IN>)
{	if ($_ !~ /\[Term\]/ms)
	{	print OUT $_;
	}
	else
	{	if ($_ =~ /namespace: biological_process/ms)
		{	print OUT $_;
		}
	}
}
print "Finished loading ontology.\n";
close(IN);

