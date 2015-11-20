#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper 'Dumper';

my $info = {};
my $file = shift;

open my $fh, '<', $file
   or die qq{Can't open file "$file": $!};

while(my $line = <$fh>) {

  next if $. == 1;

  my ($time, $url, $response_time, $size) = split(/\s/, $line);

  $info->{$time}{count}++;
  $info->{$time}{response_time_total} += $response_time;
  $info->{$time}{size_total} += $size;

}

close $fh;
#print Dumper $info;

my @header = qw/time count response_time_average size_total/;

print join(',', @header), "\n";

foreach my $time ( sort keys %$info ) {

# my @line = ($time, $info->{$time}{count}, $info->{$time}{response_time_total}, $info->{$time}{size_total});

    my $count = $info->{$time}{count};
    my $response_time_total = $info->{$time}{response_time_total};
    my $size_total = $info->{$time}{size_total};

    my $response_time_average = $response_time_total / $count;

    my @rec = ($time, $count, $response_time_average, $size_total);

    print join(',', @rec) . "\n";

#print Dumper @line;

}