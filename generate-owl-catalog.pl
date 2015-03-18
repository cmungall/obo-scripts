#!/usr/bin/perl -w
use strict;

my $prefix = 'http://purl.obolibrary.org/obo/';
my $base = './';
my $is_append;
my $is_written_header;
while (@ARGV) {
    my $opt = shift @ARGV;
    if ($opt =~ /^\-/) {
        if ($opt eq '-b' || $opt eq '--base') {
            $base = shift @ARGV;
        }
        elsif ($opt eq '-p' || $opt eq '--prefix') {
            $prefix = shift @ARGV;
        }
        elsif ($opt eq '-a') {
            $is_append = 1;
        }
        elsif ($opt eq '-') {
            my @files = <>;
            mk(@files);
        }
        else {
            die $opt;
        }
    }
    else {
        my $dir = $opt;
        open(F,"find $dir -name '*.owl'|") || die $dir;
        my @files = <F>;
        close(F);
        mk(@files);
    }
}

if (!$is_append) {
    print "</catalog>\n";
}


exit 0;

sub mk {
    my @files = @_;
    foreach (@files) {
        chomp;
        my $local = $base . $_;
        if (m@^/@) {
            $local = $_;
        }
        #$local =~ tr@^./@/@;
        #$local =~ tr@^//@/@g;
        my $line = sprintf('    <uri id="User Entered Import Resolution" name="%s%s" uri="%s"/>',$prefix,$_,$local);
        if (!$is_append && !$is_written_header) {
            print '<?xml version="1.0" encoding="UTF-8" standalone="no"?>',"\n";
            print '<catalog prefer="public" xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">', "\n";
            
        }
        if (!$is_written_header) {
            print "\n    <!-- $base -->\n";
            $is_written_header = 1;
        }


        print "$line\n";
    }

}

=head1

Examples:

svn list -R ~/repos/go/ontology/ | generate-owl-catalog.pl -p $OBO/go/  -


=cut
