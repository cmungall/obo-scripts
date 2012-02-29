#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;
use Storable;
use DateTime::Format::Strptime;
## CONFIG

my $go_path = '';
my $base_path = '/Users/gwg/';
my $xrf_abbs = $go_path . 'go/doc/GO.xrf_abbs';
my $checks_script = $go_path . 'go/software/utilities/filter-gene-association.pl';
my $path = $go_path.'go/gene-associations/';

my $svn_repo = 'piwi/go/gene-associations/';

my $user = 'aji';
my $submissions;
if ($path =~ /submission/)
{	$submissions++;
}
##

my ($day, $month, $year) = (localtime)[3, 4, 5];
my $today = sprintf("%04d%02d%02d", $year + 1900, $month + 1, $day);
my $saved;

my $verbose = 1;


## get the names of the dbs in this dir
my $db_list = get_dbs_from_dir();
my $prep;

#get_date_rev_info_cvsweb( logfile => 'tair.log.txt', outfile => 'go/gaf-versions/tair/tair_metadata.txt', db => 'tair', save_path => 'go/gaf-versions/tair/' );

#my @todo = qw( PAMGO_Mgrisea PAMGO_Oomycetes PAMGO_Ddadantii PAMGO_Atumefaciens); #jcvi mgi pombase pseudocap reactome rgd sgd sgn tair rgd wb zfin );

my @todo = qw(zfin);

my $all_mdata_file = 'go/gaf-versions/all-metadata.txt';

my $metadata = parse_all_metadata(metadata_file => $all_mdata_file );

commit_monthly_release( metadata => $metadata );

if ($prep)
{
	## prepping files
	foreach my $db (@todo)
#	foreach my $db (@$db_list)
	{	## make sure we have an appropriate directory to save the files
		my $save_path = 'go/gaf-versions/' . $db . '/';
		if (! -e $save_path)
		{	mkdir($save_path);
		}
		## create a derived directory
		my $derived = $save_path . 'derived/';
		if (! -e $derived)
		{	mkdir($derived);
		}

#		get_date_rev_info( db => $db, save_path => $save_path ); #, f_name => $f_name );
#		get_files_from_cvs( db => $db, save_path => $save_path );
		process_directory_files( db => $db, save_path => $save_path, metadata_file => $all_mdata_file );

		print STDERR "Finished processing $db\n" if $verbose;
	}
}
exit(0);

foreach my $y (2004..2011)
{	foreach my $m qw(01 02 03 04 05 06 07 08 09 10 11 12)
	{	print STDERR "Looking at $y$m...\n";
		commit_monthly_release( save_path => 'go/gaf-versions/', metadata => $metadata, date => $y.$m );
	}
}


my $date_h;
foreach my $db (@$db_list)
{	my @dates = sort keys %{$metadata->{rev_date}{$db}{by_date}};
	$metadata->{first}{ $dates[0] }{$db}++;
	$metadata->{last}{ $dates[-1]}{$db}++;
	foreach (@dates)
	{	$date_h->{$_}++;
	}
}


## processing existing files
foreach my $db (@$db_list)
{	## get all file names
	my $save_path = 'go/gaf-versions/' . $db . '/';
	my $derived = $save_path . "derived/";
	## metadata
#	$metadata->{rev_date}{$db} = parse_metadata( db => $db, save_path => $save_path );
	## get the list of quarterly files for this db
	get_quarterly_files( metadata => $metadata, db => $db, derived => $derived );
}
## see which file sets start when.
foreach my $d (sort keys %{$metadata->{first}})
{	print STDERR "$d\n";
	foreach (sort keys %{$metadata->{first}{$d}})
	{	print STDERR "$_\t" . $metadata->{rev_date}{$_}{by_date}{$d} . "\n";
	}
}
print STDERR "\n\n";

my $dbs;
my $stats;
## what's our start date for each project?
foreach my $d (sort keys %{$metadata->{by_date}})
{	if ($metadata->{first}{$d})
	{	foreach (keys %{$metadata->{first}{$d}})
		{	$dbs->{$_}++;
		}
	}
	if ($metadata->{last}{$d})
	{	foreach (keys %{$metadata->{last}{$d}})
		{	delete $dbs->{$_};
		}
	}
	my @files = sort values %{$metadata->{by_date}{$d}};
	print STDERR "files for $d:\n" . join("\n", @files) . "\n"; #sort values %{$metadata->{by_date}{$d}}) . "\n";
	foreach (sort keys %$dbs)
	{	if (! $metadata->{by_date}{$d}{$_})
		{	print STDERR "MISSING $_\n";
		}
	}
#	print STDERR "\n\n";
	$stats = get_stats(metadata => $metadata, date => $d, files => [ @files ], stats => $stats );
	print STDERR "Finished processing files for $d\n";
}

## look at the

exit(0);

sub get_obo_files {

	foreach my $y (2007..2011)
	{	foreach my $m qw(01 02 03 04 05 06 07 08 09 10 11 12)
		{	## cmd
			my $cmd = "cvs -q -d :ext:aji\@ext.geneontology.org:/share/go/cvs update -p -D$y$m"."01 go/ontology/gene_ontology_edit.obo > go/ontology-archive/go-$y$m.obo";
			`$cmd`;
		}
	}
}


sub get_dbs_from_dir {
	opendir(DIR, $path) or die "can't opendir $path: $!";
	my $dbs;
	while (defined(my $file = readdir(DIR)))
	{	## check the file name for the db #
		if ($file =~ /gene_association\.(.+)\.gz/)
		{	push @$dbs, $1;
		}
	}
	closedir(DIR);
	return $dbs;
}


sub get_date_rev_info {
	my %args = (@_);

	my $f_name = 'gene_association.' .$args{db}. '.gz';
	## parse the revision/date list
	## use cvs log command to find the file history

	## log format:
	## ^date: (\d{4})-(\d\d)-(\d\d) \d\d:\d\d:\d\d.*?author: .*?;  state: Exp;  lines: .*?;
	## get the log message
	my $cmd = "cvs -q -d :ext:aji\@ext.geneontology.org:/share/go/cvs log $path$f_name";
	my $text = `$cmd`;
	my @date_arr;

#	print STDERR "text: $text\n" if $verbose;

	my $temp;
	while ($text =~ /----------------------------.*?revision (\d.\d+).*?date: (\d{4})-(\d\d)-(\d\d) \d\d:\d\d:\d\d /sg)
	{	## save the revision and date
		$temp->{by_date}{ $2.$3 }{ $1 }++;
		$temp->{by_rev}{ $1 }{ $2.$3 }++;
	}

	foreach my $d (keys %{$temp->{by_date}})
	{	## find the revision with the earliest date
		## split up the revision into major and minor parts
		my @sorted =
			map  { $_->[0] }
			sort { $a->[1] cmp $b->[1] }
		#	map  { [$_, foo($_)] }
			map {
				my ($maj, $min) = split(/\./, $_, 2);
				[ $_, $maj."\0".$min ];
			} keys %{$temp->{by_date}{$d}};

#		print STDERR "date: $d; sorted: " . join(", ", @sorted) . "\n\n";
		## so for date $d, we want to get $sorted[0]
		$saved->{$args{db}}{by_date}{$d} = $sorted[0];
		$saved->{$args{db}}{by_rev}{ $sorted[0] }{$d}++;
	}

#	print STDERR "saved by date: " . join("\n", map {  "$_: " . join(", ", @{$saved->{by_date}{$_}} )  } sort keys %{$saved->{by_date}}) . "\n\n";

	## save this info so we don't have to retrieve it again
	open(FH, "> $args{save_path}" . "metadata.txt") or die "Could not create file " . $args{save_path} . "metadata for writing: $!";
	print FH "Saved: by date:\n" . join("\n", map { "$_: " . $saved->{$args{db}}{by_date}{$_} } sort keys %{$saved->{$args{db}}{by_date}}) . "\n\n";
	print FH "\n\nAll revisions:\n";
	foreach my $k (sort keys %{$saved->{$args{db}}{by_rev}})
	{	print FH "$k:\n" . join(", ", sort keys %{$saved->{$args{db}}{by_rev}{$k}}) . "\n";
	}
	close(FH);

}

## work out the metadata from a log copied from a cvsweb page
## note that we put in a line so that the format is
## ----------------------------
## Revision 1.1239: download
## Wed Feb 8 03:16:40 2009 UTC (2 years, 11 months ago) by gocvs
## Branches: MAIN


sub get_date_rev_info_cvsweb {
	my %args = (@_);

	## parse the revision/date list
	## use cvs log command to find the file history

	my $temp;
	my $parser = DateTime::Format::Strptime->new( pattern => '%b %d %H:%M:%S %Y' );
	## log format:
	## Revision 1.1239: download
	## Wed Feb 8 03:16:40 2009 UTC (2 years, 11 months ago) by gocvs
	## get the log message
	my $logfile = $args{logfile};
	## open it up, let the separator be the line of hyphens
	open(LOG, "< $args{logfile}") or die "Could not open $args{logfile}: $!";
	{	local $/ = "----------------------------";
		while (<LOG>)
		{	next unless /\w/;
			if (/Revision (\d\.\d+): download\s+\w+ ((Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{1,2} \d\d:\d\d:\d\d (19|20)\d\d UTC)/)
			{	my $rev = $1;
				my $date = $2;
				## parse the date
				my $dt = $parser->parse_datetime( $date );
				## convert into YYYYMMDD
				$date = $dt->strftime( "%Y%m" );

				## save the revision and date
				$temp->{by_date}{ $date }{ $rev }++;
				$temp->{by_rev}{ $rev }{ $date }++;

			}
			elsif (/Revision (\d\.\d+)/)
			{	warn "Could not parse revision/date: check $_";
			}
		}
	}

	foreach my $d (keys %{$temp->{by_date}})
	{	## find the revision with the earliest date
		## split up the revision into major and minor parts
		my @sorted =
			map  { $_->[0] }
			sort { $a->[1] cmp $b->[1] }
		#	map  { [$_, foo($_)] }
			map {
				my ($maj, $min) = split(/\./, $_, 2);
				[ $_, $maj."\0".$min ];
			} keys %{$temp->{by_date}{$d}};

#		print STDERR "date: $d; sorted: " . join(", ", @sorted) . "\n\n";
		## so for date $d, we want to get $sorted[0]
		$saved->{$args{db}}{by_date}{$d} = $sorted[0];
		$saved->{$args{db}}{by_rev}{ $sorted[0] }{$d}++;
	}

	## save this info so we don't have to retrieve it again
	open(FH, "> " . $args{outfile}) or die "Could not create file " . $args{outfile} . " for writing: $!";
	print FH "Saved: by date:\n" . join("\n", map { "$_: " . $saved->{$args{db}}{by_date}{$_} } sort keys %{$saved->{$args{db}}{by_date}}) . "\n\n";
	print FH "\n\nAll revisions:\n";
	foreach my $k (sort keys %{$saved->{$args{db}}{by_rev}})
	{	print FH "$k:\n" . join(", ", sort keys %{$saved->{$args{db}}{by_rev}{$k}}) . "\n";
	}
	close(FH);

	foreach my $d (keys %{$saved->{$args{db}}{by_date}})
	{	## location for saved file
		## date: $d; revision: $saved->{$args{db}}{by_date}{$d}
		my $save_file = $args{db}."-r-".$saved->{$args{db}}{by_date}{$d}."-d-".$d.".gaf.gz";
		## let's check whether we have this file already!
		if (! -e $args{save_path}.$save_file)
		{
			my $cmd = "cvs -q -d :ext:aji\@ext.geneontology.org:/share/go/cvs update -p -r " . $saved->{$args{db}}{by_date}{$d} . " go/gene-associations/gene_association.tair.Mar2004-Feb2009.gz > $args{save_path}$save_file";
			print STDERR "Running $cmd\n" if $verbose;
			my $status = `$cmd`;
			## check the status?
			if ($status =~ /is no longer in the repository/)
			{	warn "ERROR: performing update to " . $saved->{$args{db}}{by_date}{$d} . "; error:\n$status";
			}
		}
	}
}

sub get_files_from_cvs {
	my %args = (@_);
	## get the revisions we're looking for
	my $status;
	my $f_name = 'gene_association.' .$args{db}. '.gz';

	if (! $saved || ! $saved->{$args{db}})
	{	$saved->{$args{db}} = parse_metadata(%args);
	}

	foreach my $d (keys %{$saved->{$args{db}}{by_date}})
	{	## location for saved file
		## date: $d; revision: $saved->{$args{db}}{by_date}{$d}
		my $save_file = $args{db}."-r-".$saved->{$args{db}}{by_date}{$d}."-d-".$d.".gaf.gz";
		## let's check whether we have this file already!
		if (! -e $args{save_path}.$save_file)
		{
			my $cmd = "cvs -q -d :ext:aji\@ext.geneontology.org:/share/go/cvs update -p -r " . $saved->{$args{db}}{by_date}{$d} . " $path$f_name > $args{save_path}$save_file";
			print STDERR "Running $cmd\n" if $verbose;
			$status = `$cmd`;
			## check the status?
			if ($status =~ /is no longer in the repository/)
			{	warn "ERROR: performing update to " . $saved->{$args{db}}{by_date}{$d} . " of $f_name; error:\n$status";
			}
		}
	}
}


sub process_directory_files {
	my %args = (@_);

	## now let's go through the files and tidy things up
	## get the contents of $args{save_path} and iterate through them
	opendir(DIR, $args{save_path}) or die "can't opendir $args{save_path}: $!";
	my @to_check;
	while (defined(my $file = readdir(DIR)))
	{	# do something with "$dirname/$file"
		## check the file name for the revision #
		if ($file =~ /(.*?)-r-(\d\.\d+)-d-(\d{6}).gaf(.gz)?/)
		{	push @to_check, [ $file, $3 ];
#			$rev = $1;
		}
		else
		{	#print STDERR "No revision found for $file!\n";
			next;
		}
	}
	closedir(DIR);

	## make sure that we have the metadata (if reqd)
	## find the latest date for this file, remove annots after that date.
	if (! $saved || ! $saved->{$args{db}})
	{	$saved->{$args{db}} = parse_all_metadata( %args );
	}

	my @sorted = map { $_->[0] } sort { $a->[1] <=> $b->[1] } @to_check;

	my $status;
	my @done;
	foreach my $file (@sorted)
	{	my $rev;
		my $date;
		my $year;
		my $month;
		my $date_8;
		if ($file =~ /(.*?)-r-(\d\.\d+)-d-(\d{4})(\d{2})/)
		{	$rev = $2;
			$year = $3;
			$month = $4;
		}
		$date = $year . $month;
		my $previous_quarter;
		if ($month eq '01')
		{	$previous_quarter = $year;
			$previous_quarter--;
			$previous_quarter .= '1000';
		}
		elsif ($month eq '04')
		{	$previous_quarter = $year . '0100';
		}
		elsif ($month eq '07')
		{	$previous_quarter = $year . '0400';
		}
		elsif ($month eq '10')
		{	$previous_quarter = $year . '0700';
		}

		## add two zeros to the date to convert it into the eight digit format
		$date_8 = $date . "00";


		## make sure that the file exists and has a non-zero size
		if (! -e $args{save_path}.$file || -z $args{save_path}.$file)
		{	print STDERR "$args{save_path}$file does not exist or has zero size!\n";
			next;
		}

		## new files to create
		my $sorted = $args{save_path}. "derived/" . $args{db} . "-r-". $rev . "-sorted.gaf";
		my $filter = $args{save_path}. "derived/" . $args{db} . "-r-". $rev . "-filter.gaf";
		my $recent = $args{save_path}. "derived/" . $args{db} . "-r-". $rev . "-recent.gaf";

		next if (-e $sorted || -e $filter);

#		print STDERR "Looking at $file; revision: $rev; date: $date\n" if $verbose;

		my $n_lines;
		if ($previous_quarter)
		{	$n_lines = remove_dupes_and_filter_by_date( %args, date_8 => $date_8, file => $file, sorted => $sorted, recent => $recent, previous_quarter => $previous_quarter);
		}
		else
		{	$n_lines = remove_dupes_and_filter_by_date( %args, date_8 => $date_8, file => $file, sorted => $sorted);
		}
		## $sorted should now contain all unique lines
		if (! $n_lines || $n_lines == 0)
		{	warn "No body lines found in $file!";
			next;
		}

		if ($submissions)
		{	## if we have the appropriate OBO file, run the GAF filter script
			if ($date > 200610)
			{	my $error = run_checks_script( %args, date => $date, input => $sorted, output => $filter);
				## if it ran OK, let's replace $sorted with $filter
				if (! $error)
				{	my $status = `mv $filter $sorted`;
					if ($status)
					{	warn "Error: mv $filter $sorted: $status";
					}
				}
			}
		}
	}

=cut
		## open the annotation file, remove the header lines
		open(F, "gzip -dc $args{save_path}$file |") || die "cannot open $args{save_path}$file: $!";
		open(HEAD, "> $f_head") or die "Could not open $f_head for writing: $!";
		while (<F>)
		{	next unless /\w/;
			if (/^!/)
			{	print HEAD $_;
			}
			else
			{	## see if we have an annotation line
				if (/(.*?\t){10,}/)
				{	last;
				}
			}
		}
		close(F);
		close(HEAD);

		## sort the file lines, removing dupes, decompressing if rqd
		$status = `gzip -dc $args{save_path}$file | sort -u -o $sorted`;

		if ($status)
		{	warn "running sort -u; status: $status";
		}


		## open the sorted file, remove the header lines and extract the annotation data
		open(F, "< $sorted") || die "cannot open $sorted: $!";
		open(EDIT, "> $f_edit") or die "Could not open $f_edit for writing: $!";

		my $count;
		## now process this file.
		while (<F>)
		{	next unless /\w/;
			next if /^!/;

			## extract the stuff we want
			chomp;
			my @cols = split /\t/, $_;
			my $n_cols = scalar @cols;
			while ($n_cols < 17)
			{	push @cols, "";
				$n_cols++;
			}

			if ($date_8)
			{	## find the date, check if we're OK or not
				next if ! $cols[13]; ## no date specified
				next if $cols[13] > $date_8; ## later than our cutoff date
			}

			## body material!
			print BODY $_ . "\n";
			$count->{body}++;

			print EDIT join("\t", map { "$_" || "" } ($cols[0], $cols[1], "", @cols[3..7],
			("", "", "", ""),
			@cols[12..$#cols]) ). "\n";


		}

		close EDIT;
		close BODY;
		if (! $count->{body} || $count->{body} < 0)
		{	print STDERR "No lines found in body of $file!\n";
			next;
		}

		## sort and remove dupes in EDIT
		my $cmd = "sort -u -o $e_sort $f_edit";
		$status = `$cmd`;
		if ($status)
		{	warn "running sort -u on edited file: $status";
		}

		open(FILE, "< $e_sort") or die "can't open $e_sort: $!";
		$count->{edit} += tr/\n/\n/ while sysread(FILE, $_, 2 ** 16);
		close FILE;

#		push @done, $edited_sort;
		if ($count->{body} != $count->{edit})
		{	warn "$args{db} r $rev diffs: lost " . ($count->{body} - $count->{edit}) . " lines";
		}
#		gaf_stats($edited_sort);
		## put the head and the body of the file back together, save with the new date
		$cmd = `cat $f_head $f_body > $f_new`;
		$status = `$cmd`;
		if ($status)
		{	warn "concatenating head and body files: $status";
		}
		## now run the checks script
		## only need to do this on the submissions files
		if ($error)
		{	## Don't commit!!
		}
		else
		{	## we're ready to commit.
		#	svn_commit_file( %args, date => $date_8, rev => $rev, file => $filter );
		}
	}
=cut
}


=cut

Remove duplicate lines, filter by date

input: file, f_head, sorted, f_body

output: n lines of body

=cut

sub remove_dupes_and_filter_by_date {
	my %args = (@_);

	## open the annotation file, remove the header lines
	open(F, "gzip -dc $args{save_path}$args{file} |") || die "cannot open $args{save_path}$args{file}: $!";
	open(OUT, "> $args{sorted}") or die "Could not open $args{sorted} for writing: $!";
	while (<F>)
	{	next unless /\w/;
		if (/^!/)
		{	print OUT $_;
		}
		else
		{	## see if we have an annotation line
			if (/(.*?\t){10,}/)
			{	last;
			}
		}
	}
	close F;
	close OUT;

	## sort the file lines, removing dupes, decompressing if rqd
	## save the data in a temporary file
	my $temp = $args{sorted} . ".temp";
	my $status = `gzip -dc $args{save_path}$args{file} | sort -u -o $temp`;
	if ($status)
	{	warn "running sort -u; status: $status";
	}

	if ($args{previous_quarter})
	{	open(Q, "> $args{recent}") or die "Could not open $args{recent} for writing: $!";
	}

	## open the sorted file, remove the header lines and extract the annotation data
	open(S, "< $temp") || die "cannot open $temp: $!";
	open(OUT, ">> $args{sorted}") or die "Could not open $args{sorted} for writing: $!";
	my $count = 0;
	my $dates;
	## now process this file.
	while (<S>)
	{	next unless /\w/;
		next if /^!/;

		## extract the stuff we want
		chomp;
		my @cols = split /\t/, $_;

		next if ! $cols[13]; ## no date specified
		if ($cols[13] !~ /^\d{8}$/)
		{	warn "Incorrect date format in $args{file} line\n$_";
			next;
		}

		if ($args{date_8})
		{	## find the date, check if we're OK or not
			$dates->{ $cols[13] }++;
			next if $cols[13] > $args{date_8}; ## later than our cutoff date
		}
		## body material!
		print OUT $_ . "\n";
		$count++;

		if ($args{previous_quarter} && $cols[13] > $args{previous_quarter})
		{	print Q $_ . "\n";
		}
	}
	close OUT;
	close S;
	if ($args{previous_quarter})
	{	close Q;
	}

	print STDERR "file: $args{file}; date: $args{date_8}; previous quarter: ". ( $args{previous_quarter} || "N/A" ) . "\n" . join("\n", map { "$_\t" . $dates->{$_} } sort keys %$dates) . "\n\n";


	## delete the temp file
	unlink $temp;

	return $count;
}

sub run_checks_script {
#	return;
	my %args = (@_);

#	return if $args{date} < 200611;
	## the obo file
	my $cmd = "$checks_script -i $args{input} -p nocheck -o /Users/gwg/go/ontology-archive/go-".$args{date}.".obo -n ".$args{date}."00 -w 2>&1 1>$args{output}";
	print STDERR "running $cmd\n" if $verbose;

	my $status = `$cmd`;
	if ($status =~ /TOTAL ERRORS or WARNINGS = (\d+)\s.*?TOTAL out of date IEAs removed = (\d+)\s.*?Total of (\d+) lines \(not including header\) written to STDOUT./s)
	{	my $total = $3;
		my $errs = $1 - $2;

		return if $errs == 0;
		if ($total == 0)
		{	warn "No lines left after checking $args{input}!";
			return 1;
		}

		## ignoring IEAs, how many dodgy lines did we get rid of?
		my $ten_percent = $total / 10;
		if ($errs > $ten_percent)
		{	## get percentage errors
			my $p = sprintf("%.1f", $errs / $total * 100);
			warn "$args{input} has error rate $p\%";
			return 1;
		}
	}
	elsif ($status =~ /Congratulations, there are no errors/)
	{
	}
	else
	{	warn "No report produced by $checks_script! status: $status";
	}
}

## move files to cvs sub dirs, create GPX files
sub prep_monthly_release {
	my %args = (@_);

	## get all the files for that month
	if (! $args{metadata})
	{	$args{metadata} = parse_all_metadata(%args);
	}
	if ($args{date})
	{	## find that date in the metadata, work out the names of the files reqd
		FILE_CHECK:
		foreach my $db (keys %{$metadata->{rev_date}})
		{	print STDERR "Looking at $db...\n";
			if ($metadata->{rev_date}{$db}{by_date}{$args{date}})
			{	## work out the file name
				my $errs;
				my $rev = $metadata->{rev_date}{$db}{by_date}{$args{date}};
				my $f = $args{save_path} . $db . "/derived/" . $db . "-r-". $rev . "-sorted.gaf";
				if (! -e $f)
				{	warn "Could not find release file $f!";
					$errs++;
					next FILE_CHECK;
				}
				## copy file to the release directory
				## new file name
				my $new_f_name = "gene_association." . $db . "-r-" . $rev . ".gaf";
				my $new_f_dir = $svn_repo . 'gaf/';
				my $status = `cp $f $new_f_dir$new_f_name`;
				if ($status)
				{	warn "Error copying $f: $status";
					$errs++;
					next FILE_CHECK;
				}
				if (! $errs)
				{	## check whether we have the files or not:
					my $gpad_f = $svn_repo . 'gpad/' . $db . "-r-$rev.gpad";
					my $gpi_f = $svn_repo . 'gpi/' . $db . "-r-$rev.gpi";
					if (-e $gpad_f && -e $gpi_f)
					{	next FILE_CHECK;
					}

					## create the GPAD/GPI files
					my $cmd = 'perl /Users/gwg/obo-scripts/gaf2gpx.pl -i ' . $new_f_dir . $new_f_name
					. ' --gpad ' . $svn_repo . 'gpad/' . $db . "-r-$rev.gpad"
					. ' --gpi ' . $svn_repo . 'gpi/' . $db . "-r-$rev.gpi";
#					. ' -v';
					print STDERR "About to GPXify $new_f_name\n";
					my $status = `$cmd`;
					print STDERR $status . "\n";
				}
			}
			else
			{	#warn "No files found for date $args{date}";
			}
		}
		## svn copy svn+ssh://ext.geneontology.org/share/go/svn/trunk/gene-associations svn+ssh://ext.geneontology.org/share/go/svn/releases/YYYY-MM-DD
	}
}

sub commit_monthly_release {
	my %args = (@_);
	## get all the files for that month
	if (! $args{metadata})
	{	$args{metadata} = parse_all_metadata(%args);
	}
	my $m_data = $args{metadata};

	chdir $svn_repo;


#	$meta->{rev_date}{$cols[0]}{by_date}{$cols[1]} = $cols[2];

	my $st = `pwd`;
	print STDERR $st . "\n\n";

	$st = `svn info`;
	print STDERR $st . "\n\n";
	## find that date in the metadata, work out the names of the files reqd
	## index the files by date, not db
	foreach my $db (keys %{$m_data->{rev_date}})
	{	foreach my $date (keys %{$m_data->{rev_date}{$db}{by_date}})
		{	$m_data->{by_date}{$date}{$db} = $m_data->{rev_date}{$db}{by_date}{$date};
		}
	}

	my $path = '/Users/gwg/piwi/';
	foreach my $date (sort keys %{$m_data->{by_date}})
	{	my $err;
		my $status;
		foreach my $db (keys %{$m_data->{by_date}{$date}})
		{	my $rev = $m_data->{by_date}{$date}{$db};
			## copy file to the release directory
			## check whether we have the files or not:
			my $gaf_f  = $path.'gaf/gene_association.' . $db . "-r-" . $rev . ".gaf";
			my $gpad_f = $path.'gpad/' . $db . "-r-$rev.gpad";
			my $gpi_f  = $path.'gpi/' . $db . "-r-$rev.gpi";
			my $new_gaf_f  = "gaf/gene_association." . $db . ".gaf";
			my $new_gpad_f = 'gpad/' . $db . ".gpad";
			my $new_gpi_f  = 'gpi/' . $db . ".gpi";
			if (-e $gpad_f && -e $gpi_f && -e $gaf_f)
			{	# OK, we're good to commit!
				# copy these files to the 'master' version
				my $cmd = "cp $gaf_f $new_gaf_f";
				print STDERR "Running $cmd\n";
				$status = `$cmd`;
				if ($status)
				{	warn $status;
					$err++;
				}
				$cmd = "cp $gpi_f $new_gpi_f";
				print STDERR "Running $cmd\n";
				$status = `$cmd`;
				if ($status)
				{	warn $status;
					$err++;
				}
				$cmd = "cp $gpad_f $new_gpad_f";
				print STDERR "Running $cmd\n";
				$status = `$cmd`;
				if ($status)
				{	warn $status;
					$err++;
				}
			}
			else
			{	warn "Missing files for $date, $db, $rev:" .
				( -e $gpad_f ? "" : " GPAD" )
				. (-e $gpi_f ? "" : " GPI" )
				. (-e $gaf_f ? "" : " GAF" )
				. "\n";
			}
		}
		if ($err)
		{	warn "Aborting commit of files for $date";
			next;
		}
		## otherwise, let's commit!
		my $cmd = "svn commit --username bbop --password bbop -m 'GAF, GPI, GPAD files for date " . $date . "'";
		print STDERR "About to run\n$cmd\n";
		$status = `$cmd 2>&1`;
		if ($status)
		{	warn "svn commit: $status";
		}
		else
		{	warn "svn commit seemed to work!";
		}
#		exit(0);

		## Try making the monthly release
		$cmd = "svn copy svn://piwi.lbl.gov/go/gene-associations svn://piwi.lbl.gov/go/releases/".$date."01";
	#	$status = `$cmd`;
#		if ($status)
#		{	warn "svn copy failed! $status";
		## svn copy svn+ssh://ext.geneontology.org/share/go/gene-associations svn+ssh://ext.geneontology.org/share/go/releases/YYYY-MM-DD
#		}

	}
}

sub svn_commit_file {
	my %args = (@_);

	## copy the file to the correct directory.
	## compress the file??
	## new file name is gene-association.DBNAME.gaf
	my $f_name = "gene-association.".$args{db}.".gaf";
	my $cmd = "cp $args{file} $svn_repo$f_name";
	print STDERR "about to run $cmd\n";
	my $status = `$cmd`;
	if ($status)
	{	warn "copy: $status";
	}
	$user = 'bbop';
	## commit this file to svn?
	chdir $svn_repo;
	$cmd = "svn commit -m 'Gene association file for " . $args{db} . "; release date: " . $args{date} . ", CVS revision: " . $args{rev} . "' $f_name";
	print STDERR "About to run\n$cmd\n";
	$status = `$cmd`;
	if ($status)
	{	warn "svn commit: $status";
	}
	chdir $base_path;

#	$cmd = "svn copy svn+ssh://$user\@ext.geneontology.org/share/go/svn/trunk/gene-associations/$args{f_name} svn+ssh://$user\@ext.geneontology.org/share/go/svn/releases/$args{date}";
#	$status = `$cmd`;
#	if ($status)
#	{	warn "svn copy to release directory: $status";
#	}
}

## input: save_path => ..., db => ...
sub parse_metadata {
	my %args = (@_);
	my $meta;
	## open the metadata file
#	sftp://plutonium.lbl.gov//Users/gwg/go/gaf-versions/aspgd/metadata.txt

	open( M, "< " . $args{save_path} . 'metadata.txt') or die "Could not open metadata file: " . $args{save_path} . "metadata.txt: $!";
	my $on;
	while (<M>)
	{	next unless /\w/;
		last if /All revisions:/;
		if (/Saved: by date:/)
		{	$on++;
		}
		elsif ($on)
		{	if (/(\d{6}): (\d+\.\d+)/)
			{	$meta->{by_date}{$1} = $2;
				$meta->{by_rev}{$2} = $1;
			}
		}
	}
	close(M);
	return $meta;
}

## input: save_path => ..., db => ...
sub parse_all_metadata {
	my %args = (@_);

	my $meta;
	## open the metadata file
	open( M, "< " . $args{metadata_file}) or die "Could not open metadata file " . $args{metadata_file} .": $!";
	my $on;
	while (<M>)
	{	next unless /\w/;
		chomp;
		my @cols = split(/\t/, $_, 3);
		$meta->{rev_date}{$cols[0]}{by_date}{$cols[1]} = $cols[2];
		$meta->{rev_date}{$cols[0]}{by_rev}{$cols[2]} = $cols[1];
	}
	close(M);
	return $meta;
}

sub get_quarterly_files {
	my %args = (@_);
	opendir(DIR, $args{derived}) or die "can't opendir $args{derived}: $!";
	my $files;
	while (defined(my $file = readdir(DIR)))
	{	## check the file name for the db #
		if ($file =~ /-r-(\d\.\d+)-recent\.gaf$/)
		{	## find the date from the metadata
			if ($metadata->{rev_date}{ $args{db} }{by_rev}{$1})
			{	$metadata->{by_date}{ $metadata->{rev_date}{ $args{db} }{by_rev}{$1} }{ $args{db} } = $file;
			}
			else
			{	warn "Could not find date for $file!";
			}
			$metadata->{by_rev}{$args{db}}{$1} = $file;
		}
	}
	closedir(DIR);
	return $files;
}

sub write_metadata {
	my $m_file = 'go/gaf-versions/all-metadata.txt';
	open(M, "> $m_file") or die "Could not open $m_file: $!";
	foreach my $db (sort keys %{$metadata->{rev_date}})
	{	foreach my $d (sort keys %{$metadata->{rev_date}{$db}{by_date}})
		{	print M "$db\t$d\t" . $metadata->{rev_date}{$db}{by_date}{$d} . "\n";
		}
		print M "\n";
	}
	close M;
}

sub get_stats {
	my %args = (@_);


	## fname of the form
	## aspgd/derived/aspgd-r-1.121-recent.gaf
	my $quarter = {
		'01' => '1',
		'02' => '1',
		'03' => '1',
		'04' => '2',
		'05' => '2',
		'06' => '2',
		'07' => '3',
		'08' => '3',
		'09' => '3',
		'10' => '4',
		'11' => '4',
		'12' => '4',
	};

	my $all_stats;
	my $q_stats;
	my $database;
	foreach my $file (@{$args{files}})
	{	## find db name
#		print STDERR "looking at $file\n";
		if ($file =~ /^(.*?)-r-\d\.\d+/)
		{	$database = $1;
		}
		else
		{	warn "Unknown database name: $file";
		}

		my $file_path = "go/gaf-versions/$database/derived/";
#		print STDERR "Looking at $file_path$file for $database\n";

		next unless -e $file_path && -e $file_path.$file;

#		print STDERR "Found file, about to open it...\n";

		if ($file =~ /\.gz$/)
		{	open( FH, "gzip -dc $file_path$file|") or die "Could not open $file: $!";
		}
		else
		{	open( FH, "< $file_path$file") or die "Could not open $file: $!";
		}
		if (! -e 'go/gaf-versions/stats')
		{	mkdir 'go/gaf-versions/stats';
		}

		my $output = "go/gaf-versions/stats/$database-".$args{date}."-stats.txt";
#		print STDERR "output going to $output\n";
		open( OUT, "> $output" ) or die "Could not open $output: $!";

		my $stats;
		while (<FH>)
		{	next unless /\w/;
			next if /^!/;
			chomp;
			my $line = $_;
			my @cols = split /\t/, $_;
			while (scalar @cols < 17)
			{	push @cols, "";
			}
			unshift @cols, "";

			## date filter. Discard anything after $date
			#	next if $cols[14] && $cols[14] > $date;
			## edit the date down to year/month
			my $y = substr( $cols[14], 0, 4 );
			my $m = substr( $cols[14], 4, 2 );
			my $date = $y.$m;
			my $q = $quarter->{$m};

			## don't need to preserve info on
			## GP, qualifier, with/from, own taxon, annot-ext, isoform
	#		my $extra = join(":", $cols[1], $cols[2], $cols[4], $cols[8], $cols[13], $cols[16], $cols[17]);

			my $ev_code_cat;
			if ($cols[7] ne 'IEA' && $cols[7] ne 'ND')
			{	$ev_code_cat = 'EXP';
			}
			else
			{	$ev_code_cat = $cols[7];
			}

			## this leaves us with info on assby, date, term, ref, evcode
			## most important are assby and date

			## extract any literature or pmid/pmcids
			## (ASPGD_REF|CGD_REF|dictyBase_REF|DDB_REF|GOA_REF|SGD_REF|TGD_REF|WB_REF)

			if ($cols[6] =~ /\|/ && $cols[6] =~ /(PMID:\d+)/)
			{	$cols[6] = $1;
			}

			my ($r, $k) = split(/:/, $cols[6], 2);
			if (! $r || ! $k)
			{	print STDERR "Check value for col 6: $cols[6]\n";

			}
			else
			{	$stats->{ref}{ $cols[15] }{ $args{date} }{ $r }{ $k }++;
				$stats->{all_refs}{ $cols[15] }{ $args{date} }{ $cols[6] }++;

				$q_stats->{$cols[15]}{ $args{date} }{ref}{$r}{$k}++;
				$q_stats->{$cols[15]}{ $args{date} }{all_refs}{ $cols[6] }++;

				$all_stats->{$cols[15]}{ $args{date} }{$database}{ref}{$r}{$k}++;
				$all_stats->{$cols[15]}{ $args{date} }{$database}{all_refs}{ $cols[6] }++;

			}
			$stats->{annot}{ $cols[15] }{ $args{date} }++;
			$stats->{gpform}{ $cols[15] }{ $args{date} }{ $cols[1].":".$cols[2].":".($cols[17] || "") }++;
			$stats->{term}{ $cols[15] }{ $args{date} }{ $cols[5] }++;
			$stats->{evcodecat}{ $cols[15] }{ $args{date} }{ $ev_code_cat }++;

			$q_stats->{$cols[15]}{ $args{date} }{annot}++;
			$q_stats->{$cols[15]}{ $args{date} }{gpform}{ $cols[1].":".$cols[2].":".($cols[17] || "") }++;
			$q_stats->{$cols[15]}{ $args{date} }{term}{ $cols[5] }++;
			$q_stats->{$cols[15]}{ $args{date} }{$ev_code_cat}++;

			$all_stats->{$cols[15]}{ $args{date} }{$database}{annot}++;
			$all_stats->{$cols[15]}{ $args{date} }{$database}{gpform}{ $cols[1].":".$cols[2].":".($cols[17] || "") }++;
			$all_stats->{$cols[15]}{ $args{date} }{$database}{term}{ $cols[5] }++;
			$all_stats->{$cols[15]}{ $args{date} }{$database}{$ev_code_cat}++;
		}
		close FH;

		## STATS for each database
		print OUT "db\tdate\tannots\tGPs\tterms\tEXP\tND\tIEA\trefs\tPMIDs\n";
		foreach my $db (sort keys %{$stats->{annot}})
		{	foreach my $date (sort keys %{$stats->{annot}{$db}})
			{	##
				print OUT "$db\t$date\t";
			#	print STDERR "date: $date\n";
				## total annots
				print OUT $stats->{annot}{$db}{$date} . "\t";
				## total GPs/isoforms
				print OUT (scalar keys %{$stats->{gpform}{ $db }{ $date }} || "0" )  . "\t";
				## total terms
				print OUT (scalar keys %{$stats->{term}{ $db }{ $date }} || "0" )  . "\t";
				## EXP annots
				print OUT ( $stats->{evcodecat}{ $db }{ $date }{ EXP } || "0" ) . "\t";
				## ND annots
				print OUT ($stats->{evcodecat}{ $db }{ $date }{ ND } || "0" )  . "\t";
				## IEA annots
				print OUT ($stats->{evcodecat}{ $db }{ $date }{ IEA } || "0" )  . "\t";
				## refs
				print OUT (scalar keys %{$stats->{all_refs}{ $db }{ $date }}) . "\t";
				## number of PMIDs
				print OUT (scalar keys %{$stats->{ref}{ $db }{ $date }{ PMID }}) . "\n";
			}
		}
	#	$all_stats->{$db} = $stats->{ass_by};
	#	print OUT "assby stats: " . Dumper($stats->{ass_by});
		close OUT;
#		print STDERR "Finished $database!\n";

		## print this out every time so that if we get a failure, we'll still have the file.
		open(ALL, "> go/gaf-versions/stats/all_stats-".$args{date}."-new.txt") or die "Could not open the all stats file!";
		foreach my $db (sort keys %$all_stats)
		{	print ALL "Stats for $db\n";
			print ALL "date\tdatabase\tannots\tGPs\tterms\tEXP\tND\tIEA\t";
			print ALL "refs\t";
			print ALL "PMIDs\n";

			foreach my $date (sort keys %{$all_stats->{$db}})
			{
				my $y = substr($date, 0, 4);
				my $m = substr($date, 4, 2);
				my $q = $quarter->{$m};

				foreach my $database (sort keys %{$all_stats->{$db}{$date}})
				{	##
					print ALL "$date\t$database\t";
				#	print STDERR "date: $date\n";
					## total annots
					print ALL $all_stats->{$db}{$date}{$database}{annot} . "\t";
					## total GPs/isoforms
					print ALL (scalar keys %{$all_stats->{ $db }{ $date }{$database}{gpform}} ) . "\t";
					## total terms
					print ALL (scalar keys %{$all_stats->{ $db }{ $date }{$database}{term}}) . "\t";
					## EXP annots
					print ALL ( $all_stats->{ $db }{ $date }{$database}{ EXP } || "0" ) . "\t";
					## ND annots
					print ALL ( $all_stats->{ $db }{ $date }{$database}{ ND } || "0" ) . "\t";
					## IEA annots
					print ALL ( $all_stats->{ $db }{ $date }{$database}{ IEA } || "0" ) . "\t";
		#			## refs
					print ALL ( scalar keys %{$all_stats->{ $db }{ $date }{$database}{all_refs}} || "0" ) . "\t";
					## number of PMIDs
					print ALL (scalar keys %{$all_stats->{$db}{$date}{$database}{ref}{ PMID }}) . "\n";
				}
			}
			print ALL "\n\n";
		}

		close(ALL);
		my $cmd = "cp go/gaf-versions/stats/all_stats-".$args{date}."-new.txt go/gaf-versions/stats/all_stats-".$args{date}.".txt";
		`$cmd`;

	}

	## dump all the data
	store $all_stats, 'go/gaf-versions/stats/raw_data-'.$args{date}.'.txt';
	$args{stats}->{$args{date}} = $stats;
	return $args{stats};

}

sub restore {

	my $total;

	my $equivalents = {
		FB => 'Flybase',
		FlyBase => 'Flybase',
		WB => 'Wormbase',
		RI => 'Roslin_Institute',
		ENSEMBL => 'Ensembl',
		UniProt => 'UniProtKB',
		WormBase => 'Wormbase',
	};

#	AgBase, AspGD, BHF-UCL, bioPIXIE_MEFIT, CGD, DFLAT, dictyBase, EcoCyc, EcoliWiki, Ensembl, Eurofung, FlyBase, Flybase, GDB, GeneDB, GeneDB_Lmajor, GeneDB_Pfalciparum, GeneDB_Spombe, GeneDB_Tbrucei, GOA, GOC, GR, HGNC, HPA, IntAct, InterPro, LIFEdb, MGI, MTBBASE, NTNU_SB, PAMGO_MGG, PINC, PseudoCAP, Reactome, RefGenome, RGD, Roslin_Institute, Sanger, SGD, SGN, SP, SWALL, TAIR, TIGR, UniProtKB, Wormbase, WormBase, YeastFunc, ZFIN



	opendir(DIR, 'go/gaf-versions/stats/') or die "can't opendir go/gaf-versions/stats/: $!";
	while (defined(my $file = readdir(DIR)))
	{	## check the file name for the db #
		if ($file =~ /raw_data-(.*?)\.txt/)
		{	my $date = $1;
			## get the data from the file
			my $hash = retrieve( 'go/gaf-versions/stats/'.$file );
			foreach my $db (keys %$hash)
			{	my $database = $equivalents->{$db} || $db;
				foreach my $d (keys %{$hash->{$db}})
				{	foreach my $spp (keys %{$hash->{$db}{$d}})
					{	## annots
						$total->{$database}{$date}{annot} += $hash->{$db}{$d}{$spp}{annot};
						## terms
						if ($hash->{$db}{$d}{$spp}{terms})
						{	foreach (keys %{$hash->{$db}{$d}{$spp}{terms}})
							{	$total->{$database}{$date}{term}{$_}++;
							}
						}
						foreach (keys %{$hash->{$db}{$d}{$spp}{term}})
						{	$total->{$database}{$date}{term}{$_}++;
						}
						## gp forms
						foreach (keys %{$hash->{$db}{$d}{$spp}{gpform}})
						{	$total->{$database}{$date}{gpform}{$_}++;
						}
					#	## all refs
					#	foreach (keys %{$hash->{$db}{$d}{$spp}{all_refs}})
					#	{	$total->{$db}{$date}{all_refs}{$_}++;
					#	}
						## refs
						foreach my $r (keys %{$hash->{$db}{$d}{$spp}{ref}})
						{	foreach (keys %{$hash->{$db}{$d}{$spp}{ref}{$r}})
							{	$total->{$database}{$date}{ref}{$r}{$_}++;
							}
						}
						## ev code categories
						foreach my $ev qw( IEA ND EXP )
						{	if ($hash->{$db}{$d}{$spp}{$ev})
							{	$total->{$database}{$date}{$ev} += $hash->{$db}{$d}{$spp}{$ev};
							}
						}
					}
				}
			}
		}
	}

	closedir(DIR);

	print STDERR "keys: " . join(", ", sort { lc($a) cmp lc($b) } keys %$total) . "\n\n";

	store $total, "go/gaf-versions/stats/all_raw_data.txt";

	my $date_h;
	## print out stats by quarter
	## print this out every time so that if we get a failure, we'll still have the file.
	open(Q, "> go/gaf-versions/stats/quarter-stats.txt") or die "Could not open the quarter-stats file!";
	print Q "submitter\tdate\tannots\tGPs\tterms\tEXP\tND\tIEA\trefs\tPMIDs\n";
	foreach my $db (sort keys %$total)
	{	foreach my $date (sort keys %{$total->{$db}})
		{	print Q "$db\t$date\t";
			## annots, $total->{$db}{$date}{annot}
			print Q $total->{$db}{$date}{annot} . "\t";

			## gp forms
			print Q ( scalar keys %{$total->{$db}{$date}{gpform}} ) . "\t";

			## terms
			print Q ( scalar keys %{$total->{$db}{$date}{term}} ) . "\t";

			## ev code categories
			foreach my $ev qw( EXP ND IEA )
			{	if ($total->{$db}{$date}{$ev})
				{	print Q $total->{$db}{$date}{$ev};
				}
				print Q "\t";
			}
			## refs
			my $all = 0;
			foreach my $r (keys %{$total->{$db}{$date}{ref}})
			{	$all += ( scalar keys %{$total->{$db}{$date}{ref}{$r}} );
			}
			print Q ("$all" | "0") . "\t";
			## PMIDs
			print Q ( (scalar keys %{$total->{$db}{$date}{ref}{PMID}}) || "0" );

			print Q "\n";
			$date_h->{$date}++;
		}
		## end DB
		print Q "\n";
	}

	print Q "\n\n\n";


	## for tabular display
	my @db_list = sort keys %$total;
	my @date_list = sort keys %$date_h;
	print Q "\n\n";

	foreach my $stat qw( annot EXP ND IEA )
	{	print Q "\n\n$stat stats by date and database\n";
		print Q join("\t", "database", @date_list) . "\n";
		foreach my $db (@db_list)
		{	print Q "$db\t";
			foreach my $date (@date_list)
			{	if ($total->{$db}{$date} && $total->{$db}{$date}{$stat})
				{	print Q $total->{$db}{$date}{$stat};
				}
				print Q "\t";
			}
			print Q "\n";
		}
	}

	foreach my $stat qw( gpform term )
	{	print Q "\n\n$stat stats by date and database\n";
		print Q join("\t", "database", @date_list) . "\n";
		foreach my $db (@db_list)
		{	print Q "$db\t";
			foreach my $date (@date_list)
			{	if ($total->{$db}{$date} && $total->{$db}{$date}{$stat})
				{	print Q ( (scalar keys %{$total->{$db}{$date}{$stat}}) || "0");
				}
				print Q "\t";
			}
			print Q "\n";
		}
	}

	print Q "\n\nPMID stats by date and database\n";
	print Q join("\t", "database", @date_list) . "\n";
	foreach my $db (@db_list)
	{	print Q "$db\t";
		foreach my $date (@date_list)
		{	if ($total->{$db}{$date} && $total->{$db}{$date}{ref} && $total->{$db}{$date}{ref}{PMID})
			{	print Q ( (scalar keys %{$total->{$db}{$date}{ref}{PMID}}) || "0");
			}
			print Q "\t";
		}
		print Q "\n";
	}
=cut
	foreach my $y (sort keys %{$data->{$db}})
	{	foreach my $q (sort keys %{$data->{$db}{$y}})
		{
			foreach my $database (sort keys %{$data->{$db}{$y}{$q}})
			{	##
				print Q "$db\t$y\-$q\t$database\t";
			#	print STDERR "date: $date\n";
				## total annots
				print Q $data->{$db}{$date}{annot} . "\t";
				## total GPs/isoforms
				print Q (scalar keys %{$data->{$db}{$date}{gpform}}) . "\t";
				## total terms
				print Q (scalar keys %{$data->{$db}{$date}{term}}) . "\t";
				## EXP annots
				print Q ( $data->{$db}{$date}{ EXP } || "0" ) . "\t";
				## ND annots
				print Q ( $data->{$db}{$date}{ ND } || "0" ) . "\t";
				## IEA annots
				print Q ( $data->{$db}{$date}{ IEA } || "0" ) . "\t";
	#			## refs
				print Q ( scalar keys %{$data->{$db}{$date}{all_refs}} || "0" ) . "\t";
				## number of PMIDs
				print Q ( $data->{$db}{$date}{ref}{ PMID } || "0" ) . "\n";
			}
		}
	}
	print Q "\n\n";
=cut
	close(Q);

#	print STDERR Dumper($total);
}

sub check_archive_files {
	my %args = (@_);

	## get all the files for that month
	if (! $args{metadata})
	{	$args{metadata} = parse_all_metadata(%args);
	}
	my $metadata = $args{metadata};
	my $errs;
	## find that date in the metadata, work out the names of the files reqd
	foreach my $db (keys %{$metadata->{rev_date}})
	{	foreach my $date (keys %{$metadata->{rev_date}{$db}{by_date}})
		{	## work out the file name
			my $rev = $metadata->{rev_date}{$db}{by_date}{$date};
			my $f = $args{save_path} . $db . "/derived/" . $db . "-r-". $rev . "-sorted.gaf";
			if (! -e $f)
			{	warn "Could not find file $f!";
				$errs++;
				next;
			}
			## find the GPAD / GPI files
			if (! -e $svn_repo . 'gpad/' . $db . "-r-$rev.gpad")
			{	warn "Could not find GPAD file $db\-r-$rev\.gpad";
			}
			if (! -e $svn_repo . 'gpi/' . $db . "-r-$rev.gpi")
			{	warn "Could not find GPI file $db\-r-$rev\.gpi";
			}
		}
	}
}
