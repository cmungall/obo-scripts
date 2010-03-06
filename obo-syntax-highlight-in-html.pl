#!/usr/bin/perl -w
use strict;
use Data::Stag qw(:all);

my @hdrs = ();
my @nodedivs = ();

my $base = "http://purl.org/obo/html";
my $title = "OBO";

while ($ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-t' || $opt eq '--title') {
        $title = shift @ARGV;
    }
    else {
        die $opt;
    }
}

my $in_hdr = 1;
my %idh;
my @lines=();
while (<>) {
    push(@lines,$_);
    if (/^id: (.*)\n/) {
        $idh{$1}= 1;
    }
}
foreach (@lines) {
    chomp;
    if (/^\[/ && $in_hdr) {
        $in_hdr = 0;
    }
    if ($in_hdr) {
        push(@hdrs,$_);
    }
    if (/^(\[.*)/) {
        push(@nodedivs,["<span class='stanza-open'>$1</span>"]);
    }
    my $node = $nodedivs[-1];
    my @elts = ();
    my $cmts = '';
    if (/^(.*)(\!.*)/) {
        $_ = $1;
        $cmts = $2;
    }
    if (/^([\w\-]+):\s*(.*)/) {
        my ($k,$v) = ($1,$2);
        if ($k eq 'id') {
            push(@elts,"<a name='$v'/>");
        }
        else {
            $v =~ s/\"([^\"]*)\"/\"\<span class=\"quoted\"\>$1\<\/span\>\"/g;
            $v =~ s/\[([^\]]*)\]/<span class=\"bracketed\"\>\[$1\]\<\/span\>/g;
            #$v =~ s/(\w+:\S+)/\<a class=idref href=\'$1\'\>$1\<\/a\>/ge;
            #$v =~ s/(\w+:\S+)/<a class=\"idref\" href=\"idlink($1)\"\>$1\<\/a\>/g;
            $v =~ s/(http:.*)/http_href($1)/ge;
            $v =~ s/(\w+:[\w\-]+)/idlink($1)/ge;
        }
        push(@elts, 
             "<span class='key'>$k</span>: ",
             "<span class='value'>$v</span>",
            );
    }
    else {
    }
    push(@elts,
         "<span class='comment'>$cmts</span>");
    if ($node) {
        push(@$node, "<span>".join('',@elts)."</span>\n");
    }
}

my $body = join("\n",map {"<div class='node'>".join('',@$_)."</div>"} @nodedivs);

print <<EOM
<html>
 <head>
   <title>$title</title>
   <style type="text/css">
<!--
.comment
{
  color: #f00;
  font-style: italic;
}
.quoted
{
  color: #800;
  font-weight: bold;
  font-style: italic;
}
.key
{
  color: #008;
  font-weight: bold;
}
.value
{
  color: #000;
}
.idref
{
  color: #488;
}
.bracketed
{
  font-weight: bold;
}
.stanza-open
{
  color: #882;
  font-size: large;
}

-->
   </style>
 </head>
<body>
<pre>
$body
</pre>
</body>
</html>
EOM
;

exit 0;


sub idlink {
    my $id = shift;
    my $href = "#".$id;
    if (!$idh{$id}) {
        if ($id =~ /(\w+):/) {
            $href="$base/$1.html#".$id;
        }
        else {
            $href="$base#".$id;
        }
    }
    return "<a class=\"idref\" href=\"$href\">$id</a>";
}

sub http_href {
    my $url = shift;
    return "<a class=\"idref\" href=\"$url\">$url</a>";
}
