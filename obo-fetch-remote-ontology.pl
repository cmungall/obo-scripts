#!/usr/bin/perl

use LWP;         # for making web requests

my $verbose;
my $metadata_file;
while (scalar(@ARGV) && $ARGV[0] =~ /^\-.+/) {
    my $opt = shift @ARGV;
    if ($opt eq '-h' || $opt eq '--help') {
        print usage();
        exit 0;
    }
    elsif ($opt eq '--metadata') {
        $metadata_file = shift @ARGV;
    }
    elsif ($opt eq '-v') {
        $verbose = 1;
    }
}

my @onts = @ARGV;

my $ua = LWP::UserAgent->new;

$ua->agent( 'OBO-Fetch/1.001' );
my $url = 'http://obo-registry.googlecode.com/svn/trunk/metadata/ontologies.txt';
if ($verbose) {
    print STDERR "Using: $url\n";
}
my $req = HTTP::Request->new( GET => $url );
my $res = $ua->request( $req );
if ($verbose) {
    print STDERR "Fetched: $url\n";
}

my $content;
if( !$res->is_success ) {
    die;
}
$content = $res->content;
my @lines = split(/\n/,$content);


foreach my $ont (@onts) {
    fetch_ont($ont);
}
exit 0;

sub fetch_ont {
    my $ont = shift;
    if ($verbose) {
        print STDERR "  Scanning: $ont\n";
    }


    $url = '';
    my $match = 0;
    foreach (@lines) {
        my ($t,$v) = split(/\t/,$_);
        next unless $t;
        if ($t eq 'id' || $t eq 'namespace') {
            if ($v eq $ont) {
                $match = 1;
            }
            else {
                $match = 0;
            }
        }

        if ($match) {
            if ($t eq 'download') {
                $url = $v;
            }
            elsif ($t eq 'source' && !$url) {
                $url = $v;
                $url =~ s/.*\|//;
            }
        }
    }

    if ($verbose) {
        print STDERR "Requesting: $url\n";
    }
    $req = HTTP::Request->new( GET => $url );
    $res = $ua->request( $req );
    if( !$res->is_success ) {
        die;
    }
    if ($verbose) {
        print STDERR "Fetched: $url\n";
    }
    $content = $res->content;
    print $content;
}
