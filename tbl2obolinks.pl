#!/usr/bin/perl

my $rel;
if ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-r' || $opt eq '--rel') {
        $rel = shift;
    }
    if ($opt eq '--is_a') {
        $rel = 'is_a';
    }
}
my %linkh = ();
while (<>) {
    chomp;
    s/\!.*//;
    s/^\s+//;
    s/\s+$//;
    next unless $_;
    my @cols = split(/\t/);
    foreach (@cols) {
	if (/^(\S+:\d+)\-(.*)/) {
	    $_ = "$1 ! $2";
	}
    }
    if (!$rel) {
        $rel = shift @cols;
    }
    push(@{$linkh{$cols[0]}->{$rel}},$cols[1]);
    
}

foreach my $id (keys %linkh) {
    print "[Term]\nid: $id\n";
    my $relh = $linkh{$id};
    foreach my $rel (keys %$relh) {
        if ($rel eq 'xref') {
            print "xref: $_\n" foreach @{$relh->{$rel}};
        }
        elsif ($rel eq 'is_a') {
            print "is_a: $_\n" foreach @{$relh->{$rel}};
        }
        elsif ($rel eq 'equivalent_to') {
            print "equivalent_to: $_\n" foreach @{$relh->{$rel}};
        }
        elsif ($rel eq 'def_xref') {
            printf("def: \".\" [%s]\n",
		   join(', ', @{$relh->{$rel}}));
        }
        else {
            print "relationship: $rel $_\n" foreach @{$relh->{$rel}};
        }
    }
    print "\n";
}

exit 0;

sub print_term {
    my $id = shift;
    my $n = shift;
    print "[Term]\nid: $id\nname: $n\n\n"
}
