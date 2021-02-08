#!/usr/bin/perl -n
chomp;
$h{$_}++ unless /^\!/;
END {
    foreach (keys %h) {
	print "$h{$_}\t$_\n";
    }
}
