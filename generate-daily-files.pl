#!/usr/bin/perl -w

=head1 NAME

generate-daily-files.pl - generate various daily files from a v1.2 OBO file

=head1 SYNOPSIS

## Simple settings: run from the go/ directory or its parent; locations of
derived and mappings directories are assumed by the script

 perl generate-daily-files.pl /path/to/obo_file

## Specify directory locations:

 perl generate-daily-files.pl /path/to/obo_file -d /path/to/derived_file_dir
 -o /path/to/obsolete_file_dir -m /path/to/mapping_file_dir

=head1 DESCRIPTION

Parses an OBO v1.2 file and generates a number of files from it.

In the I<derived_file_dir> directory:

 - terms_and_ids
 - terms_ids_obs
 - terms_alt_ids

In the I<obsolete_file_dir> directory:

 - obsoletes-exact
 - obsoletes-inexact

In the go/<mapping_file_dir> directory:

 - ec2go
 - metacyc2go
 - reactome2go
 - resid2go
 - um-bbd_enzymeid2go
 - um-bbd_pathwayid2go
 - wikipedia2go

If an output file differs significantly from the old version of the file, the
old file will be saved as I<file_name>.old for manual comparison.


=head2 Input Options

=head3 Simple (assumes GO 2010/2011 CVS directory structure)

Put the script either the go/ directory or its parent, and point it to the
location of the OBO format file:

 perl generate-daily-files.pl /path/to/obo_file

Running the script without specifying the location of the derived, obsolete, and
mapping file directories and not changing the values in the defaults hashref
assumes the file system has the following structure:

 go/ontology/$ontology_file ## (may be in a subdirectory)
   /doc/                    ## derived and obsoletes go here
   /external2go/            ## mappings files go here
   /generate-daily-files.pl       ## location of this script

The script may either be in the go/ directory (as above) or its parent

=head3 Custom Configs

These settings may be altered by specifying directories on the command line or
hardcoded by editing the values in the 'defaults' hashref.

=head3 Command-line Configuration

Note that the command syntax should be

 perl generate-daily-files.pl /path/to/obo_file -x I<option_one> -y I<option_two> (etc.)

i.e. the first argument must always be the path to the OBO file.

=over

Either all three or none of these options should be set.

=item -o || --obsolete /path/to/obsolete_file_dir

Full path to the obsoletes directory

=item -d || --derived /path/to/derived_file_dir

Full path to the derived files directory

=item -m || --mapping /path/to/mapping_file_dir

Full path to the mappings directory

=back

=head3 Optional switches

=over

=item -v || --verbose

prints various messages during the execution of the script

=back

=head3 Command-line Configuration

Note that the command syntax should be

 perl generate-daily-files.pl /path/to/obo_file -x I<option_one> -y I<option_two> (etc.)

i.e. the first argument must always be the path to the OBO file.

=cut

use strict;
use FileHandle;
use Data::Dumper;
use File::stat;

my $bin_dir;
my $dist_dir;

my $defaults = {

	## base directory
	base_dir => 'go',

	## ontology directory - append this to base dir, above, to specify directory
	## under which the OBO file is found. Required if
	ontology_dir => 'ontology',

	## dir for the tab-delimited term info files
	## if using the simple config option (i.e. only entering the OBO file path
	## on the cmd line), this should be the path that needs to be appended to
	## base_dir, above
	derived_dir => 'doc',
	derived_file_prefix => 'GO.',
	derived_file_suffix => '',
	## the derived files to create
	derived_to_create => [
		[ [ qw(id name ns) ], 'terms_and_ids' ],
		[ [ qw(id alt_id name ns obs) ], 'terms_alt_ids' ],
		[ [ qw(id name ns obs) ], 'terms_ids_obs' ],
	],

	## terms_alt_ids: GO:0000000 (primary) [tab] GO:0000000 (secondary, separated by space(s) if >1) [tab] text string [tab] F|P|C [tab] (obs)
	## terms_ids_obs: GO:0000000 [tab] text string [tab] F|P|C [tab] (obs)

	## dir for the obsolete files
	obsolete_dir => 'doc',
	obsolete_file_prefix => '',
	obsolete_file_suffix => '',

	## dir for the mappings to external dbs
	mapping_dir => 'external2go',
	## xrefs to map from the obo file
	xrefs_to_map => [ qw(ec metacyc um-bbd_pathwayid um-bbd_enzymeid um-bbd_reactionid rhea kegg resid reactome wikipedia) ],
	## prefix and suffix for mapping files
	mapping_file_prefix => '',
	mapping_file_suffix => '2go',

	namespace_abbr => {
		biological_process => 'P',
		cellular_component => 'C',
		molecular_function => 'F',
	},
};

BEGIN {
	use Cwd;
	use File::Basename;
	$bin_dir = dirname(__FILE__);
	$bin_dir = Cwd::abs_path($bin_dir);
	($dist_dir = $bin_dir) =~ s/bin\/?$//;
}

use lib ($dist_dir, $bin_dir);
use GOBO::Logger;
my $logger;

run_script(\@ARGV);

exit(0);

sub run_script {
	my $options = parse_options(@_);
	$logger->info( "Parsed options. Now starting script..." );
#	$logger->logdie("Options: " . Dumper($options));

	my $timestring = localtime();
	my $fh = new FileHandle( $options->{obo_file} );
	my $data;

	open(IN, '<'. $options->{obo_file}) or $logger->logdie("The file " . $options->{obo_file} . " could not be opened: $!");
	## get the header data from the file, parse the file.
	{	$logger->info("Loading current ontology...");
		local $/ = "\n\n";
		my @arr = split("\n", <IN> );#grep { /(^date: | cvs version)/i } split("\n", <FH> );
		
		## date: 04:01:2011 16:56
		## remark: cvs version: $Revision: 1.1692 $
		foreach (@arr)
		{	if ($_ =~ /date: (.+)$/)
			{	print STDERR "Found the date! $1\n";
				$data->{header}{date} = $1;
			}
			elsif ($_ =~ /cvs version: \$Revision: (\S+)/)
			{	print STDERR "Found the cvs revision! $1\n";
				$data->{header}{cvs_version} = $1;
			}
			elsif ($_ =~ /^(.*?): (.+)/)
			{	$data->{header}{$1}{$2}++;
			}
		}
		if ( ! $data->{header}{date} || ! $data->{header}{cvs_version} )
		{	$logger->warn("Could not find the data or cvs version of " . $options->{obo_file});
		}

		local $/ = "\n[";
		while (<IN>)
		{	if (/^\[?(\S+)\]\s*.*?^id:\s*(\S+)/sm)
			{	# extract the interesting data
				if ($1 eq "Term")
				{	my $h;
					map {
						if (/(.*?): ?(.+)( ?\!.*)?/)
#						{	$h->{$1} = $2;
						{	$h->{$1}{$2}++;
						}
					}
					split("\n", $_);
					if (! $h->{id})
					{	$logger->warn("Found a block with no id!");
						next;
					}
					else
					{	my $id = (keys %{$h->{id}})[0];
						$data->{term}{ $id } = $h;
					}
				}
			}
		}
	}

	close(IN);
	$logger->info("Finished loading ontology.");

	# check that we have all the bits we need
#	if (! defined $graph || scalar @{$graph->terms} == 0 || ! $parser->parsed_header || ! keys %{$data->{term}})
	if (! keys %{$data->{term}})
	{	$logger->logdie("Crap! Could not parse the file! Dying") unless $options->{test_mode};
	}

	# get the CVS version and date
	my $date = $data->{header}{date} || 'unknown';
	my $cvs_version = $data->{header}{cvs_version} || 'unknown';


	my $fn = {
		ns => sub
		{	my $t_data = shift;
#			print STDERR "looking t_data: " . Dumper($t_data);
			my $ns = (keys %{$t_data->{namespace}})[0];
			return $defaults->{namespace_abbr}{ $ns } || $ns;
		},
		obs => sub
		{	my $t_data = shift;
			if ($t_data->{is_obsolete})
			{	return "obs";
			}
			else
			{	return "";
			}
		},
	};

	### Terms / IDs / Obsoletes

	## create the files and put the file handles in a hash
	my $path = $options->{derived_dir};
	my $prefix = $defaults->{derived_file_prefix} || "";
	my $suffix = $defaults->{derived_file_suffix} || "";

	my $files_by_ref;

	foreach my $f (@{$defaults->{derived_to_create}})
	{	my $f_name;
		if ($f->[1])
		{	## we have a file name
			$f_name = "$path/$prefix" . $f->[1] . $suffix;
		}
		else
		{
			$f_name = "$path/$prefix" . join("_", @{$f->[0]}) . $suffix;
		}
		my $fh = FileHandle->new("> $f_name.new") or $logger->logdie("Couldn't open $f_name.new for writing: $!");
		## open the old file and get the headers
		my $h_lines = get_file_header( f_in => $f_name, obo_file => $options->{obo_file}, cvs_version => $cvs_version, date => $date, timestring => $timestring );
		print $fh @$h_lines;
		if ($options->{test_mode})
		{	$logger->info("$f header:\n" . join("", @$h_lines));
		}
		$files_by_ref->{$f_name} = { fh => $fh, cols => [ @{$f->[0]} ], f_name => $f_name };
	}

	## Go through the terms and print out the info for the terms / etc. files
	## save the obsolete and xref data
	unless ($options->{test_mode}) {
#		foreach my $n (sort { $a->id cmp $b->id } @{$graph->terms} )
		foreach my $id (sort keys %{$data->{term}} )
		{	#my $id = $n->id;
			#if ( ! $n->label || ! $n->namespace )
			#{	$logger->warn($n->id . ": missing name or namespace!");
			if ( ! $data->{term}{$id}{name} || ! $data->{term}{$id}{namespace} )
			{	$logger->warn("$id: Missing name or namespace!");
				next;
			}
			if ($data->{term}{$id}{is_obsolete})
			{	$data->{obsoletes}{$id}++;
			}

			foreach my $fbr (keys %$files_by_ref)
			{
				print { $files_by_ref->{$fbr}{fh} }
				join("\t",
					map {
						my $x = $_;
						if ($data->{term}{$id}{$x})
						{	join(" ", sort keys %{$data->{term}{$id}{$x}});
						}
						elsif ($fn->{$x}) {
							&{$fn->{$x}}( $data->{term}{$id} );
						}
						else
						{	"";
						}
					} @{$files_by_ref->{$fbr}{cols}}) . "\n";
			}
			## some checking stuff here...
			if ($data->{term}{$id}{alt_id})
			{	foreach (keys %{$data->{term}{$id}{alt_id}})
				{	# ensure we don't have duplicate alt_ids
					if ($data->{alt_id}{$_})
					{	$logger->error("$_ is an alt ID for $id and ". $data->{alt_id}{$_} ."!");
						next;
					}
					$data->{alt_id}{$_} = $id;
				}
			}

			if ($data->{term}{$id}{xref})
			{	if ($data->{term}{$id}{is_obsolete})
				{#	$logger->error("Error: xrefs found for obsolete term $id");
					next;
				}
				# store the xrefs for usage in a minute
				foreach my $ref (keys %{$data->{term}{$id}{xref}})
				{	my ($db, $key) = split(":", $ref, 2);
					# if there are any gubbins at the end, they're likely to be the xref
					# label. Check and label if a label exists
					my $name;
					if ($key =~ / \"(.+?)\"/)
					{	$name = $1;
					}
					$key =~ s/ \".+//;
					# check that if the ref is from EC, it is a complete xref
					if ($db eq 'EC')
					{	next if $key =~ /-/;
					}

					push @{ $data->{xref}{$db}{$key} }, $id;
					$data->{xref_map}{ lc($db) } = $db if ! $data->{xref_map}{ lc($db) };
					if ($name)
					{	$data->{xref_name}{$db}{$key} = $name;
					}
				}
			}
		}
	}

	## close and save files
	foreach (keys %$files_by_ref)
	{	$files_by_ref->{$_}{fh}->close;
		if (! $options->{test_mode})
		{	check_file_size_and_save( $files_by_ref->{$_}{f_name} );
		}
		else
		{	## delete the file
			unlink $files_by_ref->{$_}{f_name}.".new";
		}
	}


	## create the files for the obsolete terms
	undef $files_by_ref;
	$path = $options->{obsolete_dir};
	$prefix = $defaults->{obsolete_file_prefix} || '';
	$suffix = $defaults->{obsolete_file_suffix} || '';

	foreach my $f ('obsoletes-exact', 'obsoletes-inexact')
	{	my $f_name = "$path/$prefix$f$suffix";
		my $fh = FileHandle->new("> $f_name.new") or $logger->logdie("Couldn't open $f_name.new for writing: $!");

		my $h_lines = get_file_header( f_in => $f_name, obo_file => $options->{obo_file}, cvs_version => $cvs_version, date => $date, timestring => $timestring );
		print $fh @$h_lines;
		if ($options->{test_mode})
		{	$logger->info("$f header:\n" . join("", @$h_lines));
		}
		$files_by_ref->{$f} = $fh;
	}

	## go through the obsolete terms and print out the consider and replaced bys
	my $file_obs_type = { 'consider' => 'obsoletes-inexact', 'replaced_by' => 'obsoletes-exact' };

	unless ($options->{test_mode}) {
		foreach my $id (sort keys %{$data->{obsoletes}})
		{	foreach (keys %$file_obs_type)
			{	if ($data->{term}{$id}{$_})
				{	foreach my $c (keys %{$data->{term}{$id}{$_}})
					{	# check the term exists
						if ($data->{term}{$c})
						{	if ($data->{obsoletes}{$c})
							{	$logger->warn("$id has obsolete term $c in $_ list!");
							}
						}
						elsif ($data->{alt_id}{$c})
						{	if ($data->{obsoletes}{ $data->{alt_id}{$c} })
							{	$logger->warn("$id has $c in $_ list; $c is an alt ID for ".$data->{alt_id}{$c} . " and ". $data->{alt_id}{$c}." is obsolete!");

							}
							else
							{	$logger->warn("$id has $c in $_ list; $c is an alt ID for ".$data->{alt_id}{$c});
							}
						}
						else
						{	$logger->warn("$c is not a term or an alt_id!");
					#		next;
						}
						print { $files_by_ref->{ $file_obs_type->{$_} } } "$id\t$c\n";
					}
				}
			}
		}
	}


	## close and save files
	foreach my $f (keys %$files_by_ref)
	{	$files_by_ref->{$f}->close;
		if (! $options->{test_mode})
		{	check_file_size_and_save( "$path/$prefix$f$suffix" );
		}
		else
		{	## delete the file
			unlink "$path/$prefix$f$suffix".".new";
		}
	}

	### External mappings files

	undef $files_by_ref;
	$path = $options->{mapping_dir};
	$prefix = $defaults->{mapping_file_prefix} || '';
	$suffix = $defaults->{mapping_file_suffix} || '';

	my @dbxrefs_to_get = @{$defaults->{xrefs_to_map}}; #qw(ec metacyc um-bbd_pathwayid um-bbd_enzymeid um-bbd_reactionid rhea kegg resid reactome wikipedia);

#	$logger->info("Starting the external2go file mappings.\nCreating files...");

	foreach my $db (@{$defaults->{xrefs_to_map}})
	{	my $f_name = "$path/$prefix$db$suffix";
		my $fh = FileHandle->new("> $f_name.new") or $logger->logdie("Couldn't open $f_name.new for writing: $!");
		## open the old file and get the headers
		my $h_lines = get_file_header( f_in => $f_name, obo_file => $options->{obo_file}, cvs_version => $cvs_version, date => $date, timestring => $timestring );
		print $fh @$h_lines;
		if ($options->{test_mode})
		{	$logger->info("$db header:\n" . join("", @$h_lines));
		}
		$files_by_ref->{ $db } = { fh => $fh,  f_name => $f_name };
	}

	## print out mappings for each of the xrefs
	unless ($options->{test_mode}) {
		foreach (@dbxrefs_to_get)
		{	my $db = $data->{xref_map}{$_} || ( $logger->warn("Could not find $_ in the xref map!") && next);
			if ( ! $data->{xref}{$db} || ! values %{$data->{xref}{$db}} )
			{	$logger->warn("Could not find any xrefs for $db!");
				next;
			}
			foreach my $ref (sort keys %{$data->{xref}{$db}})
			{	foreach my $id (sort @{$data->{xref}{$db}{$ref}})
				{	if ($data->{xref_name}{$db} && $data->{xref_name}{$db}{$ref})
					{	print { $files_by_ref->{ lc($db) }{fh} } "$db:$ref " . $data->{xref_name}{$db}{$ref} . " > GO:" . (keys %{$data->{term}{$id}{name}})[0] . " ; $id\n";
					}
					else
					{	print { $files_by_ref->{ lc($db) }{fh} } "$db:$ref > GO:" . (keys %{$data->{term}{$id}{name}})[0] . " ; $id\n";
					}
				}
			}
		}
	}

	$logger->info("Closing files and saving.");

	foreach (keys %$files_by_ref)
	{	$files_by_ref->{$_}{fh}->close;
		if (! $options->{test_mode})
		{	check_file_size_and_save( $files_by_ref->{$_}{f_name} );
		}
		else
		{	## delete the file
			unlink $files_by_ref->{$_}{f_name}.".new";
		}
	}

	$logger->info("$0 done");

}

sub get_file_header {
	my %args = @_;
	my @lines;

	## check the file exists. If not, make up a header
	if (-e $args{f_in} && -r $args{f_in})
	{
		open(FH, "< " . $args{f_in}) or $logger->logdie("Couldn't open $args{f_in} for reading: $!");
		{	local $/ = "\n";
			while (my $line = <FH>)
			{	if ($line !~ /^!/)
				{	## ok, we're done here. Return!
					last;
				}
				
				next unless $line =~ /[\w\!]/;
				
				if ($line =~ /^! Generated from file (.*?),$/)
				{	## switch this line
					push @lines, "! Generated from file $args{obo_file},\n";
				}
				elsif ($line =~ /^! CVS revision: (.*?); date: (.*)$/)
				{	push @lines, "! CVS revision: $args{cvs_version}; date: $args{date}\n";
				}
				elsif ($line =~ /^! Last update at .*? by the script .*?/)
				{	push @lines, "! Last update at $args{timestring} by the script $0\n";
				}
				else
				{	push @lines, $line;
				}
			}
		}
	}

	if (! @lines)
	{	## make up a header
		push @lines, join("\n",
			'! version: $Revision: 0.000 $',
			'! date: $Date: 0000/00/00 00:00:00 $',
			'!',
			"! $args{f_in}",
			"! Generated from file $args{obo_file},",
			"! CVS revision: $args{cvs_version}; date: $args{date}",
			"! Last update at $args{timestring} by the script " . scr_name(),
			"!\n");
	}

	return \@lines;
}



## this subr checks that the new file isn't massively different
## in size to the existing file
sub check_file_size_and_save {
	my $file_name = shift;

	my $new_file = stat($file_name.'.new') or $logger->logdie("Couldn't stat $file_name.new : $!");
	if (-e $file_name)
	{	my $old_file = stat($file_name) or $logger->logdie("Couldn't stat $file_name : $!");

		#	check that the file no less than 10% smaller than the original file size
		my $ten_percent = $old_file->size / 10;

		if ($new_file->size < $ten_percent)
		{	#	if it's 90% out, fail it
			$logger->warn("$file_name: new file size ".$new_file->size.", old file size ".$old_file->size.", ten percent: $ten_percent\nNew file saved as $file_name.new, old file kept as $file_name.");
			return;
		}
		elsif ($new_file->size < ($old_file->size - $ten_percent))
		{	#	file is between 10% and 90% of the size of the original -> warn
			$logger->warn("$file_name: new file size ".$new_file->size.", old file size ".$old_file->size."\nKeeping old file as $file_name.old just in case.");
			rename($file_name, $file_name.'.old');
			rename($file_name.'.new', $file_name);
			return;
		}
	}
	#	this looks OK. rename the new file to the old file name
	rename($file_name.'.new', $file_name);
	$logger->info("$file_name looks fine! Removing '.new' suffix.");
	return;
}

# parse the options from the command line
sub parse_options {
	my $args = shift;
	my $errs;
	my $opt;

	$opt->{obo_file} = shift @$args;
	if (! $opt->{obo_file} )
	{	push @$errs, "Please specify an obo file to use";
		return
	}
	elsif (! -f $opt->{obo_file})
	{	push @$errs, "Please check that " . $opt->{obo_file} . " exists and can be read";
	}

	if (! @$args)
	{	$opt->{simple_config} = 1;
	}

	while (@$args && $args->[0] =~ /^\-/) {
		my $o = shift @$args;
		if ($o eq '-m' || $o eq '--mapping')
		{	if (@$args && $args->[0] !~ /^\-/)
			{	$opt->{mapping_dir} = shift @$args;
				$opt->{mapping_dir} .= "/" unless substr($opt->{mapping_dir}, -1, 1) eq '/';
			}
		}
		elsif ($o eq '-d' || $o eq '--derived')
		{	if (@$args && $args->[0] !~ /^\-/)
			{	$opt->{derived_dir} = shift @$args;
				$opt->{derived_dir} .= "/" unless substr($opt->{derived_dir}, -1, 1) eq '/';
			}
		}
		elsif ($o eq '-o' || $o eq '--obsolete')
		{	if (@$args && $args->[0] !~ /^\-/)
			{	$opt->{obsolete_dir} = shift @$args;
				$opt->{obsolete_dir} .= "/" unless substr($opt->{obsolete_dir}, -1, 1) eq '/';
			}
		}
		elsif ($o eq '-v' || $o eq '--verbose')
		{	$opt->{verbose} = 1;
		}
		elsif ($o eq '-t' || $o eq '--test')
		{	$opt->{test_mode} = 1;
		}
		elsif ($o eq '--galaxy') {
			$opt->{galaxy} = 1;
		}
		else {
			push @$errs, "Ignored nonexistent option $o";
		}
	}

	if (! $opt->{obsolete_dir} && ! $opt->{derived_dir} && ! $opt->{mapping_dir})
	{	$opt->{simple_config} = 1;
	}

	return check_options($opt, $errs);
}


# process the input params
sub check_options {
	my ($opt, $errs) = (@_);

	if (!$opt)
	{	GOBO::Logger::init_with_config( 'standard' );
		$logger = GOBO::Logger::get_logger();
		$logger->logdie("Error: please ensure you have specified an ontology file to use.\nThe help documentation can be accessed with the command\n\t" . scr_name() . " --help");
	}

	if (! $opt->{verbose})
	{	$opt->{verbose} = $ENV{GO_VERBOSE} || 0;
	}

	if ($opt->{galaxy})
	{	GOBO::Logger::init_with_config( 'galaxy' );
		$logger = GOBO::Logger::get_logger();
	}
	elsif ($opt->{verbose} || $opt->{test} || $ENV{DEBUG})
	{	GOBO::Logger::init_with_config( 'verbose' );
		$logger = GOBO::Logger::get_logger();
	}
	else
	{	GOBO::Logger::init_with_config( 'standard' );
		$logger = GOBO::Logger::get_logger();
	}

	if ($errs && @$errs)
	{	foreach (@$errs)
		{	$logger->error($_);
		}
	}
	undef $errs;

	if ($opt->{simple_config})
	{	## we need to work out the dir structure from the path to the obo file
		my $ont_dir = qr/$defaults->{ontology_dir}/i;
		my $base; # = qr/$defaults->{base_dir}/i;

		if ($opt->{obo_file} =~ /(.*?\/)$ont_dir\//)
		{	$base = $1;
			foreach my $dir qw( mapping_dir obsolete_dir derived_dir )
			{	$opt->{$dir} = $base . $defaults->{$dir};
			}
		}
		elsif ($opt->{obo_file} =~ /^$ont_dir\//)
		{	## in the base directory
			## no need to do anything with any extra path
			foreach my $dir qw( mapping_dir obsolete_dir derived_dir )
			{	$opt->{$dir} = $defaults->{$dir};
			}
		}
		else
		{	## help! No idea what's going on here.
			$logger->info("No idea where the mapping, obsolete or derived directories are!");
			push @$errs, "Unable to calculate location of mapping, obsolete and derived directories. Please specify their locations on the command line";
		}
	}

	foreach my $dir qw( mapping_dir obsolete_dir derived_dir )
	{	if (! $opt->{$dir})
		{	push @$errs, "Please specify a path to the " . $dir;
		}
		else
		{	$opt->{$dir} .= "/" unless substr($opt->{$dir}, -1, 1) eq '/';
			if (! -d $opt->{$dir} )
			{	push @$errs, $opt->{$dir} . " could not be found";
			}
		}
	}

	if ($errs && @$errs)
	{	$logger->logdie("Please correct the following parameters to run the script:\n" . ( join("\n", map { " - " . $_ } @$errs ) ) . "\nThe help documentation can be accessed with the command\n\t" . scr_name() . " --help");
	}

	return $opt;
}

sub scr_name {
	my $n = $0;
	$n =~ s/^.*\///;
	return $n;
}

1;
