#!/usr/bin/perl

use strict;
use warnings;
use URI;
use LWP::UserAgent;
use XML::Simple;
use Data::Dumper;
use Time::Local;
my $current_time = time()-9 * 3600;

my $host_name = $ARGV[0];
my $service = $ARGV[1];
my $item_key = " -k $ARGV[2]";
my $zabbix_sender = '/usr/bin/zabbix_sender';
my $zabbix_server = ' -z 127.0.0.1';
my $zabbix_host = " -s $host_name";


# Azure Resions are..
# (West US, East US, North Europe, West Europe, East Asia, Southeast Asia, Japan East, Japan West)

my $url = URI->new("http://azure.microsoft.com/ja-jp/status/feed/?service=$service");

my $ua = LWP::UserAgent->new();
my $res = $ua->get($url);
my $xml = XML::Simple->new;
my $data = $xml->XMLin( $res->content );

#print Dumper $data;

# check if entry exists
unless  ( exists($data->{'channel'}->{'item'}->{'pubDate'}) ){

  &send_zabbix("OK");
  print "OK";
  exit;

}

foreach my $item ( $data->{'channel'}->{'item'}){

   $item->{pubDate} =~ s/GMT//g;
   $item->{pubDate} =~ s/,//g;

   my($week, $day,$month,$year,$time) = split(/\s+/, $item->{pubDate});
   my($hour, $min, $sec) = split(/:/, $time);
   my $gm = timelocal($sec, $min, $hour, $day, &month_to_epoch($month), $year-1900);

   # check if the entory is whithin one hour
   my $diff_time = $current_time - $gm;

   next if ( $diff_time > 3600);
#   next if ( $diff_time > 360000);

print Dumper $item->{'az:tags'}->{'az:tag'};

   # check if the resion is related
   next if ( $item->{'az:tags'}->{'az:tag'} !~ /(West US)|(Japan East)|(East US)|(North Europe)|(West Europe)|(East Asia)|(Southeast Asia)|(Japan West)|(Australia East)/);

     my  $desc = $item->{'description'} . " in " . $item->{'az:tags'}->{'az:tag'};
#    print $item->{'az:tags'}->{'az:tag'}, "\n";

     &send_zabbix($desc);

}

print "OK";


sub month_to_epoch() {

  my $input = shift ;

  my %list = (
     'Jan' => 0,
     'Feb' => 1,
     'Mar' => 2,
     'Apr' => 3,
     'May' => 4,
     'Jun' => 5,
     'Jul' => 6,
     'Aug' => 7,
     'Sep' => 8,
     'Oct' => 9,
     'Nov' => 10,
      'Dec' => 11);

    return $list{$input};
}

sub send_zabbix() {

  my $value = shift ;
  my $cmd = $zabbix_sender . $zabbix_server .  $zabbix_host . $item_key . ' -o ' . '"' . $value . '"' . " >/dev/null";

  if (system($cmd)){

   print "NG";
   exit;

  }

}