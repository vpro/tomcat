#!/usr/bin/perl

#we do it in perl, since that's available on ubuntu:latest
# Results can be picked up by nl.vpro.monitoring.binder.ScriptMeterBinder

use strict;
use warnings;


my $dir="/data/logs";
my $after = "1 week before now";
if (scalar(@ARGV) ge 2) {
  $dir = $ARGV[0];
  $after = $ARGV[1];
} elsif (scalar(@ARGV) ge 1) {
  $after = $ARGV[0];
}

my $findcommand="find $dir -name 'tomcat_access.log*'";
open(FILELIST,"$findcommand |")||die("can't open $findcommand |");
my @filelist=<FILELIST>;
close FILELIST;


my %result=();
for my $file (@filelist)  {
  #print $file;
  my $fh;
  if ($file =~ /.gz$/) {
    open($fh, "gunzip -c $file |") or die $!;
  } else {
    open($fh, "cat $file |") or die $!;
  }

  while(<$fh>){

    my @field=split /\t/;
    my $date=$field[0];
    if ($date lt $after) {
      next;
    }
    my $full_client=$field[3];
    my $client=(split " ", $full_client)[0];
    my $request=$field[7];
    my $status=$field[8];
    if ($status ge 300) {
      next;
    }
    $request =~ s/^"|"$//g;
    my @split_request=split ' ', $request;
    my $method=$split_request[0];
    if ($method eq 'OPTIONS') {
      next;
    }
    my $full_path=$split_request[1];

    my @split_full_path=split /\?/, $full_path;
    my $path=$split_full_path[0];
    my @split_path=split '/', $path;
    if (scalar(@split_path) < 4) {
      next;
    }
    my $api="$split_path[0]/$split_path[1]/$split_path[2]/$split_path[3]";

    $result{"clients"}{"client=$client"}++;
    $result{"methods"}{"method=$method,api=$api"}++;
    $result{"api"}{"api=$api"}++;
    $result{"status"}{"status=$status"}++;
  }
}


while(my($name, $counts) = each %result) {
  while(my($key, $count) = each %$counts) {
    print ("$name\t$count\t$key\n");
  }
}
