#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper 'Dumper';

my $info = {};
my %urls = ();
my $file = shift;

open my $fh, '<', $file
   or die qq{Can't open file "$file": $!};

while(my $line = <$fh>) {

  next if $. == 1;

  my ($time, $url) = split(/\s/, $line);

  my $mtime;
  if ($time =~ /^(\d{2}:\d{2})/) {
      $mtime = $1;
  }

  $info->{$mtime}{$url}++;

  $urls{$url} = 1;

}

close $fh;
#print Dumper $info;
#print Dumper %urls;

my @urls = sort keys %urls;

print join("\t", "time", @urls), "\n";

foreach my $hour(0 .. 23) {
   foreach my $minute ( 0 .. 59) {

      my @rec;

      my $mtime = sprintf("%02d:%02d", $hour, $minute);

      push @rec, $mtime;

      foreach my $url (@urls) {
         my $count = $info->{$mtime}{$url} || 0;
         push @rec, $count;
      }

      print join ("\t", @rec) . "\n";

   }

}