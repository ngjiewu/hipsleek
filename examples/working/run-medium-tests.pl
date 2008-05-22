#!/usr/bin/perl

use File::Find;
use File::Basename;
use Getopt::Long;

GetOptions( "stop"  => \$stop);
$sleek_path = @ARGV[0];
$exempl_path = "$sleek_path/examples/working";
$exec_path = '../../..';
@excl_files = ();
$error_count = 0;
$error_files = "";
$hip = "$exec_path/hip";
$sleek = "$exec_path/sleek";
$perf_file = "performances";
if ($output_file) {}
else { $output_file = "log"; }


open(LOGFILE, ">> $output_file") || die ("Could not open $output_file.\n");

print "==============\nStarting hip tests:\n";
$time = 0;
find(\&hip_process_file, "$exempl_path/hip");
print LOGFILE "This run took in total $time\n";
print "Starting sleek tests:\n";
find(\&sleek_process_file, "$exempl_path/sleek");

close(LOGFILE);

if ($error_count > 0) {
  print "Total number of errors: $error_count in files: $error_files.\n";
}

exit(0);


sub hip_process_file {
  $file = $_;
	@file_part = (fileparse($file,'\..*'));
  my $ext = (@file_part)[2];

  if ($ext eq ".ss" && not(grep(/^($file_part[0])$/,@excl_files))) {
	print "Checking $file\n";
	my $output = `$hip $file 2>&1`;
	if ($output =~/Total verification time: (\d*.\d*) second/){
		$time = $time + $1;
		open(PERF, ">> $performances") || die ("Could not open $performances.\n");
		print PERF "\n it took: $time\n";
		close(PERF);
	}
	
	print LOGFILE "\n======================================\n";
	print LOGFILE "$output";

	if ($output =~ /.*(e|E)rror.*/) {
	  print "Error found\n";
	  $error_count++;
	  $error_files = $error_files . " " . $file;
	  if ($stop) {
		exit(0);
	  }
	}
  }
}
sub sleek_process_file  {
  $file = $_;
  @file_part = (fileparse($file,'\..*'));
  my $ext = (@file_part)[2];
  my $ext = (fileparse($file,'\..*'))[2];

	if ($ext eq ".slk" && not(grep(/^($file_part[0])$/,@excl_files))) {
		print "Checking $file\n";
       my $output = `$sleek $file 2>&1`;
        print LOGFILE "\n======================================\n";
        print LOGFILE "$output";

        if (($output =~ /.*(e|E)rror.*/)||($output =~ /.*(f|F)ail.*/)) {
          print "Error found\n";
          $error_count++;
          $error_files = $error_files . " " . $file;
          if ($stop) {
                exit(0);
          }
        }
  }
}