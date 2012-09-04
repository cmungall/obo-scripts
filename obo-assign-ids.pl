#!/usr/bin/perl -w

use strict;
my %tag_h=();
my $regexp = '';
my $noheader;
my $negate;
my $idmatch;
my $idspace;
my $idnum;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    print STDERR "opt:$opt\n";
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    if ($opt eq '-m' || $opt eq '--idmatch') {
        $idmatch = shift @ARGV;
        print STDERR "m=$idmatch\n";
    }
    if ($opt eq '-s' || $opt eq '--idspace') {
        $idspace = shift @ARGV;
    }
    if ($opt eq '-n' || $opt eq '--idnum') {
        $idnum = shift @ARGV;
    }
    if ($opt eq '--noheader') {
        $noheader = 1;
    }
}

die usage() unless $idmatch;
die usage() unless $idspace;
if (!$idnum) {
    print `egrep '^id: $idspace:0' $ARGV[0] | sort`;
    die "specify --idnum";
}

my %idmap = ();
my @lines = ();
while(<>) {
    push(@lines,$_);
    if (/^id:\s*(\S+)/) {
        my $id = $1;
        #if ($id =~ /$idmatch/ && $id !~ /^$idspace:\d+$/) {
        if ($id =~ /$idmatch/) {
            if ($idmap{$id}) {
            }
            elsif ($id =~ /^$idspace:\d+$/) {
                $idmap{$id} = undef;
            }
            else {
                $idmap{$id} = sprintf("$idspace:%07d",$idnum++);
                #print STDERR "$id ==> $idmap{$id}\n";
            }
        }
    }
}

foreach (@lines) {
    if (/^id:\s*(\S+)/) {
        if ($idmap{$1}) {
            print "id: $idmap{$1}\n";
            print "alt_id: $1\n";
        }
        else {
            print $_;
        }
    }
    elsif (/^(is_a|relationship|intersection_of|union_of)/) {
        foreach my $k (keys %idmap) {
            if (/$k\s/) {
                s/$k/$idmap{$k}/g;
            }
        }
        print;
    }
    else {
        if (/($idspace:\S+)/x) {
            my $id = $1;
            if ($idmap{$id}) {
                my $new = $idmap{$id};
                s/$idspace:\S+/$new/g;            
            }
        }
        print $_;
    }
}


exit 0;

sub compr {
    my $s = shift;
    $s =~ s/\s+//g;
    $s;
}

sub scriptname {
    my @p = split(/\//,$0);
    pop @p;
}


sub usage {
    my $sn = scriptname();

    <<EOM;
$sn --idmatch REGEXP --idspace IDSPACE --idnum COUNTER [OBO FILES]

Assigns OBO-style identifiers to terms

EOM
}

