#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;
use Data::Dumper 'Dumper';

my $file = "packet_info.log";

open my $fh, '<', $file
   or die qq{Can't open file: "$file": $!};

my @header = qw/time packet loss/;
my $packet_infos = [];
my $packet_info;

while (my $line = <$fh>) {

  chomp $line;

  if($line =~ /^(\d{2}:\d{2}:\d{2})/ ){

  $packet_info = {};
  $packet_info->{time} = $1;

  } elsif ($line  =~ /^packet: (\d+)/) {

   $packet_info->{packet} = $1;

  } elsif ($line  =~ /^loss: (\d+)/) {

   $packet_info->{loss} = $1;
   push @$packet_infos, $packet_info;

  }

}

close $fh;

#print Dumper $packet_infos;

print join("\t", @header), "\n";

for my $packet_list ( @$packet_infos ) {

        print $packet_list->{time}. "\t" ,
        $packet_list->{packet}. "\t" ,
        $packet_list->{loss}. "\n";
}