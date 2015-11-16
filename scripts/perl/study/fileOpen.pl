#!/usr/bin/perl

use strict;
use warnings;

my $file = 'file.txt';


# read <
# write > 
# append >>

open my $fh, '<', $file
  or die "Can't open file \"$file\": $!";


while (my $line = <$fh>) {

   my($key, $value) = split(':', $line);

   print $value;

}

close($fh);