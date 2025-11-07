#!/usr/bin/perl
#we do it in perl, since that's available on ubuntu:latest
=head1 parse_tomcat_access_logs()

Make an abstract of the tomcat access logs. This can be called manually,
but it return format is also recognized by ScriptMeterBinder.java (in vpro-shared-monitoring) which will use it as gauges for micrometer.

Parameters

=over 2

=item - max age in minutes (defaults to 60, one hour)

=back

It will give of the number of requests per

=over 2

=item - method and (beginning of) the path

=item - client

=item - status code

=item - what we might come up later

=back

January 2025 - Michiel Meeuwissen

=cut

use strict;
use warnings;


my $dir="/data/logs";
my $age = "60"; # max age in minutes
if (scalar(@ARGV) ge 1) {
  $age = $ARGV[0];
}

# just determin current date minus age as a iso string
# this can be used to compare agains date in access logs itself, and skip them if those are earlier
my $after =`date --iso-8601=minutes --date="\${dataset_date} -$age minute"`;

# no need to consider alder files
my $findcommand="find $dir -cmin -$age -name 'tomcat_access.log*'";

# in tomcat access logs the java application's 'context' may appear
# which is for all entries the same (since we do only one application per tomcat)
# so we remove it from the reports
my $context=$ENV{CONTEXT};
if (! defined($context)) {
  $context="ROOT";
}
# The path of the request is split, only this many entries are then used for reporting
my $pathlength=$ENV{ACCESS_LOG_PATH_LENGTH};
if (! defined($pathlength)) {
  $pathlength=2;
}

my $aggregations = $ENV{ACCESS_LOG_AGGREGATIONS};


open(FILELIST,"$findcommand |")||die("can't open $findcommand |");
my @filelist=<FILELIST>;
close FILELIST;

my %result=();
for my $file (@filelist)  {
  print $file;
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

    if (defined($aggregations)) {
      $_ = $full_path;
      eval($aggregations);
      $full_path = $_;
    }

    my @split_full_path=split /\?/, $full_path;
    my $path=$split_full_path[0];
    my @split_path=split '/', $path;
    shift @split_path; # path starts with / so first element will be empty string, discard it.
    if ( @split_path != 0 && $split_path[0] eq "$context" ) {
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

