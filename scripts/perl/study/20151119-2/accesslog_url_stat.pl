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

  $info->{$url}{count}++;
  $info->{$url}{response_time_total} += $response_time;
  $info->{$url}{size_total} += $size;

}

close $fh;
#print Dumper $info;

 for my $url ( keys %$info ) {

     my $count = $info->{$url}{count};
     my $response_time_total =  $info->{$url}{response_time_total};
     my $size_total =  $info->{$url}{size_total};

     #Response_time_avg
     my $response_time_avg = $response_time_total / $count;
     $response_time_avg = sprintf("%.1f", $response_time_avg);
     $info->{$url}{response_time_avg} = $response_time_avg;

     #Response_size_avg
     my $response_size_avg = $size_total / $count;
     $response_size_avg = sprintf("%.1f", $response_size_avg);
     $info->{$url}{response_size_avg} = $response_size_avg;

 }

print Dumper $info;

# sort BLOK LIST
my @urls = sort { $info->{$b}{response_time_avg} <=>
                  $info->{$a}{response_time_avg} } keys %$info;

my @header = qw/url count response_time_average size_average/;

print join(',', @header), "\n";

foreach my $url ( @urls ) {

    my $count = $info->{$url}{count};
    my $response_time_avg = $info->{$url}{response_time_avg};
    my $size_avg = $info->{$url}{response_size_avg};

    my @rec = ($url, $count, $response_time_avg, $size_avg);

    print join("\t", @rec) . "\n";

}
