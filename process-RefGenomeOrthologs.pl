#!/usr/bin/perl
while(<>) {
    chomp;
    s/ENTREZ/NCBIGene/g;
    my @vals = split(/\t/);
    if (@vals == 6) {
        splice(@vals,3,2,("$vals[3]/$vals[4]"));
    }
    my ($x,$y,$rel,$anc,$fam) = @vals;
    print join("\t",
               (proc_idstr($x),
                proc_idstr($y),
                $rel,
                $anc,
                $fam))."\n";
}
exit 0;

sub proc_idstr {
    my ($sp,$mod,$pr) = split(/\|/,$_[0]);
    return (proc_id($mod),proc_id($pr));
}

sub proc_id {
    return join(':',split(/=/,$_[0]));
}
