#!/usr/bin/perl -w

# Add $path list onto library path array @INC
BEGIN 
{
    open (PATHLIST, "echo \$PATH |") or die "Can't get \$PATH\n";
        $pathlist = <PATHLIST>;
        chomp $pathlist;
    close PATHLIST;
    unshift(@INC, split(/[:| ]/, $pathlist));
}

use strict;
use POSIX;
#use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
#		      clock_gettime clock_getres clock );


####################################
# BEGIN User globals
####################################

my $logdir 		= "/home/dfeany1/logs";
my $ifconfig		= "/sbin/ifconfig";
my $period_dflt		= 10;				#Change the following to fit your needs
my $iterations_dflt	= 2;				
my $log_file_dflt	= "ifrates_smoke_test_"; 	
my $log_path_dflt	= "/root/Documents/EBW/logs/";
my $log 		= '.log';
my $interface_script_path 	= '/home/dfeany1/scripts/interface_rates.pl';
my $filter_dflt		= '| grep -i "date\|eth\|packets"';
my $kill_dflt		= 'none';

####################################
# END User globals
####################################


######################################################################
######################################################################
# Main Function
######################################################################
my $thisfile = __FILE__;      # pathname of the file you are looking at right now
   $thisfile =~ s/^.+\///g;   # extract just the filename
my $user     = getpwuid $<;   # This gets the UNIX username.
my $userdir  = "/home/$user";
my $topdir   = $userdir;
my $now_string = strftime "%b-%e-%Y-%H:%M:%S", localtime; #gets the local time: M-D-Y-H:M:S

# Capture args
my $hash_delimiter = "::";
my @args = split(/ -/, " ". join("$hash_delimiter ", @ARGV));

# Remove first, since not populated, i.e. == ()
shift @args;

# Place args into %in hash
my $in;
my $key;
my @param;
foreach (@args)
{
   ($key, @param) = split(/$hash_delimiter */, $_);
   $in->{$key} = join(' ', @param);
   print "Location 1: **** arg($_) \t**** key($key) \t**** params($in->{$key}) ****\n";
}

my $dbg = (defined $in->{'dbg'})? $in->{'dbg'} : 0;

# Are they asking for help?
help_info() if ((defined $in->{'h'}) || (defined $in->{'help'}));

####################################
# Command line definitions
####################################
my $interface   = (defined $in->{'i'})? $in->{'i'}: syntax_err();
my $period      = (defined $in->{'t'})? $in->{'t'}: $period_dflt;
my $iterations  = (defined $in->{'n'})? $in->{'n'}: $iterations_dflt;
my $log_file	= (defined $in->{'f'})? $in->{'f'}: $log_file_dflt;
my $log_path	= (defined $in->{'p'})? $in->{'p'}: $log_path_dflt;
my $filter	= (defined $in->{'x'})? $in->{'x'}: $filter_dflt;
my $kill_int	= (defined $in->{'k'})? $in->{'k'}: $kill_dflt;
####################################
# End command line definitions
####################################

######################################################################
######################################################################
# Start Main Function
######################################################################


##############Everett's work#####################

##Variables
my $clear		= 'clear';

##makes array of the -i arguments 
my @interface_array  = split(' ', $in->{'i'});

##clear the screen
system($clear);


##loop for each interface given
foreach my $inter (@interface_array)
{	
	##if the -k (kill) option is NOT specified, do the following
	if($kill_int eq 'none'){
		##ifrates_smoke_test_Jul-17-2014-11:57:52_eth1.log
		my $log_file = "$log_file$now_string\_$inter$log";

		##/home/dfeany1/scripts/interface_rates.pl -i eth1 -t 1 -n 5 | grep -i "date\|eth\|packets" > /temp/ifrates_smoke_test.eth1.log &;
		my $full_run_script_string = "$interface_script_path -i $inter -t $period -n $iterations $filter > $log_path$log_file &";		
		##running the script
		system($full_run_script_string);
	
		##print a summary of the test run
		summary_info($inter);
	
		print "\t\t-Process ID:\t";
		##simply finds the process ID of the test just run. 
		print join('', split(/ /, substr(`ps -ef | grep interface_rates | grep $inter | grep -v grep`, 8, 7)));
		print "\n\n";


	##if the -k (kill) option IS specified, do the following
	}else {
		print "\t## Attempting to kill monitering processes for $inter ##\n\n";

		##bash grep regex returns related processes (full info)
		my $output = `ps -ef | grep interface_rates | grep $inter | grep -v grep`;	
		
		##checks to make sure there is a returned processes
		if($output eq ''){print "There are currently no running jobs for the $inter interface.\n\n";}
		else {
			##slightly roundabout way of isolating the process ID for the running monitoring process. 
			my $final_kill_process = join('', split(/ /, substr($output, 8, 7)));

			print "Kill the running process wih ID: $final_kill_process\n\n"; `kill $final_kill_process`;
		}
	}
}



exit(0); 

######################################################################
# End Main Function
######################################################################
######################################################################


######################################################
##  Sub Routines
######################################################

sub summary_info
{
	my $i = "@_";
   	print <<SUMMARY;

\tRate Monitor Tool Summary for $i:
\t\t-Using tool:\t$interface_script_path
\t\t-with filter:\t$filter
\t\t-Interface:\t$i
\t\t-Period:\t$period seconds
\t\t-Iterations:\t$iterations
\t\t-Log File:\t$log_path$log_file$now_string\_$i$log
SUMMARY
;
   #exit(0); 
}

sub no_jobs
{
	my $i = "@_";
        print <<NO_RUNNING_JOBS;

There are currently no running jobs for the $i interface. 

NO_RUNNING_JOBS
;
exit(1);
}

##############End Everett's work#####################

sub help_info
{
   print <<HELP;

\t$thisfile:  Stores running statistics for an eLITE ethernet interface to log file
\t 
\t./$thisfile -h (-help)
\t  Show this help.
\t
\tOptions: 	
\t\t-i <interface name> \t(no dflt - MUST be included)
\t\t-t <period> \t\t(dflt=$period_dflt)
\t\t-n <iterations> \t(dflt=$iterations_dflt)
\t\t-f <log file name>\t(dflt="$log_file_dflt<interface$log>")
\t\t-p <log file path>\t(dflt=$log_path_dflt)
\t\t-x <filter>\t\t(-x with no arguments for no filter; dflt=$filter_dflt)
\t\t-k <kill interface process> \t(no arguments given - uses the arguments from -i)

\tExample - First run: './$thisfile -i eth0 eth1'
\tThen to kill, simply: './$thisfile -i eth0 eth1 -k'
 

HELP
;
   exit(0); 
}


sub syntax_err
{
        print <<CLOSING_HELP;

SYNTAX ERROR!
Use the following to show help.
    perl $thisfile -h

CLOSING_HELP
;
exit(1);
}

