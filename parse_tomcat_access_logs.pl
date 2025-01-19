#!/usr/bin/perl

#we do it in perl, since that's available on ubuntu:latest

=head1 parse_tomcat_access_logs()

Make an abstract of the tomcat access logs

Parameters

- max age in minutes (defaults to 1440, one day)

=cut

use strict;
use warnings;


my $dir="/data/logs";
my $age = "60"; # max age in minutes
if (scalar(@ARGV) ge 1) {
  $age = $ARGV[0];
}
my $now="\${dateset_date}";
if (scalar(@ARGV) ge 2) {
  $now= $ARGV[1];
}

my $after =`date --iso-8601=minutes --date="\${dataset_date} -$age minute"`;
my $findcommand="find $dir -cmin -$age -name 'tomcat_access.log*'";
my $context=$ENV{CONTEXT};
if (! defined($context)) {
  $context="ROOT";
}
my $pathlength=$ENV{ACCESS_LOG_PATH_LENGTH};
if (! defined($pathlength)) {
  $pathlength=2;
}
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
    $result{"status"}{"status=$status"}++;
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
    shift @split_path; # path starts with / so first element will be empty string, discard it.
    if ($split_path[0] eq $context) {
      shift @split_path;
    }
    if ($#split_path ge ($pathlength - 1)) {
      $#split_path = $pathlength - 1;
    }
    if (defined($split_path[0]) && $split_path[0] eq 'manage') {
      next;
    }
    my $short_path=join('/',@split_path);

    $result{"clients"}{"client=$client"}++;
    $result{"paths"}{"method=$method,path=$short_path"}++;
  }
}


while(my($name, $counts) = each %result) {
  while(my($key, $count) = each %$counts) {
    print ("tomcat_access_$name\t$count\t$key\n");
  }
}

