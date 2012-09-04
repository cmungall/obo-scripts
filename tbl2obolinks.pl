#!/usr/bin/perl

my $rel;
my $swap;
my $src;
my $keep_bangs = 0;
while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-r' || $opt eq '--rel') {
        $rel = shift;
    }
    elsif ($opt eq '--is_a') {
        $rel = 'is_a';
    }
    elsif ($opt eq '--synonym') {
        $rel = 'synonym';
    }
    elsif ($opt eq '--swap') {
        $swap = 1;
    }
    elsif ($opt eq '--source') {
        $src = shift @ARGV;
    }
    elsif ($opt eq '-k') {
        $keep_bangs = 1;
    }
}
my %linkh = ();
while (<>) {
    chomp;
    s/\!.*// unless $keep_bangs;
    s/^\s+//;
    s/\s+$//;
    next unless $_;
    my @cols = split(/\t/);
    if (@cols == 4) {
        @cols = ("$cols[0] ! $cols[1]","$cols[2] ! $cols[3]");
    }
    foreach (@cols) {
	#if (/^(\S+:\d+)\-(.*)/) {
	#    $_ = "$1 ! $2";
	#}
        if ($src) {
            s/ \! / {source="$src"} \! /;
        }
    }
    if (!$rel) {
        $rel = shift @cols;
    }
    if ($swap) {
        push(@{$linkh{$cols[1]}->{$rel}},$cols[0]);
    }
    else {
        push(@{$linkh{$cols[0]}->{$rel}},$cols[1]);
    }
    
}

foreach my $id (keys %linkh) {
    print "[Term]\nid: $id\n";
    my $relh = $linkh{$id};
    foreach my $rel (keys %$relh) {
        if ($rel eq 'xref') {
            print "xref: $_\n" foreach @{$relh->{$rel}};
        }
        elsif ($rel eq 'synonym') {
            print "$rel: \"$_\" EXACT []\n" foreach @{$relh->{$rel}};
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
