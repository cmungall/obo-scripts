#!/usr/bin/perl

while(<>) {
    s@ \{.*@@;
    if (m@^relationship: (\S+)@) {
        $r{$1} ++;
    }
    if (m@^property_value: (\S+)@) {
        $r{$1} ++;
    }
    if (m@^intersection_of: (\S+) (\S+)@) {
        if ($2 ne '!') {
            $r{$1} ++;
        }
    }
    if (m@^property_value: \S+ "@ && $_ !~ m@xsd@) {
        print STDERR "BAD: $_";
    }

    last if m@Typedef@;
}

$id = undef;
while (<>) {
    if (m@^id: (\S+)@) {
        $id = $1;
    }
    if (m@^name:@) {
        $r{$id} = undef;
    }
}

foreach my $id (keys %r) {
    if ($r{$id}) {
        print STDERR "ERR: $id $r{$id}\n";
    }
}
