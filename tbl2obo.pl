#!/usr/bin/perl

while (<>) {
    chomp;
    s/\!.*//;
    s/^\s+//;
    s/\s+$//;
    next unless $_;
    if (/(\S+:\S+)\s+(.*)/) {
        print_term($1,$2);
    }
    elsif (/(\S+)\s+(.*)/) {
        print_term($1,$2);
    }
    else {
        warn("Cannot parse: $_");
    }
}
exit 0;

sub print_term {
    my $id = shift;
    my $n = shift;
    my $s;
    if ($n =~ /(.*)\t(.*)/) {
        $n = $1;
        $s = $2; 
    }
    print "[Term]\nid: $id\nname: $n\n";
    print "synonym: \"$s\" EXACT []\n" if $s;
    print "\n";
}
