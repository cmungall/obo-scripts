#!/usr/bin/perl -pn

# turns CURIEs to hyperlinks
# works in iTerm2
# see: https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda

if (m@(\S+):(\d+)@) {
    s@(\S+):(\d+)@\e]8;;http://purl.obolibrary.org/obo/$1_$2\e\\$1:$2\e]8;;\e\\@;
}
