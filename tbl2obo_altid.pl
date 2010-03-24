#!/usr/bin/perl

my $rel;
if ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '--rel') {
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
    @cols = map {s/(\d+)\-(\S+)/$1 ! $2/;$_} @cols;
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
        else {
            print "alt_id: $_\n" foreach @{$relh->{$rel}};
        }
    }
    print "\n";
}

exit 0;

sub print_term {
    my $id = shift;
    my $n = shift;
    print "[Term]\nid: $id\nalt_id: $n\n\n"
}
