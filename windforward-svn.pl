#!/usr/bin/perl -w

use strict;
my $gitdir;
my $MSGFILE = "commit-message.txt";

while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-g' || $opt eq '--gitdir') {
        $gitdir = shift @ARGV;
    }
    elsif ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
}
die unless $gitdir;
my $f = shift @ARGV;
my $logf = shift @ARGV;
die unless $f;


#my $cmd = "svn log $f";
#print STDERR "CMD: $cmd\n";
open(F, $logf) || die $logf;
my $log = join("",<F>);
close(F);
my @commits = split(/------*/,$log);

@commits = reverse @commits;
foreach my $commit (@commits) {
    my @lines = split(/\n/, $commit);
    shift @lines;
    my $hline = shift @lines;
    #print "r: $hline\n";

    
    my ($rev, $user, $date, $lineinfo) = split(/ \| /, $hline);

    if (!$rev) {
        next;
    }

    open(F, ">$gitdir/$MSGFILE") || die;
    print F $commit;
    close(F);
    runcmd("svn update -r $rev $f");
    runcmd("(cp $f $gitdir && cd $gitdir && git commit -F $MSGFILE $f)");
}

exit 0;

sub runcmd {
    my @c = @_;
    print STDERR "CMD: @c\n";
    system("@c") && die "@c";
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn FILE.OBO

obodiff over history. Must be run from a cvs directory

Example:

  cd cvs/go/ontology
  $sn gene_ontology_edit.obo
EOM
}


