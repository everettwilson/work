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
use Cwd qw(abs_path);

####################################
# BEGIN User globals
####################################

my $existing_log	= "/root/Documents/EBW/logs/backup_memory_log.csv";
my $email_file		= "/root/Documents/EBW/logs/email_file.txt";

####################################
# END User globals
####################################


######################################################################
######################################################################
# Main Function
######################################################################
my $full_path = abs_path(__FILE__); #full path & name of file you are looking at
my $thisfile = __FILE__;      # pathname of the file you are looking at right now 
   $thisfile =~ s/^.+\///g;   # extract just the filename
my $user     = getpwuid $<;   # This gets the UNIX username.
my $userdir  = "/home/$user";
my $topdir   = $userdir;

my $day = strftime "%d", localtime; 	#stores current day number
my $month = strftime "%m", localtime;	#stores current month number
my $year = strftime "%y", localtime;	#stores current year number
my $day_name = strftime "%a", localtime;#stores current day name

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
   # print "**** arg($_) **** key($key) **** params($in->{$key}) ****\n";
}

my $dbg = (defined $in->{'dbg'})? $in->{'dbg'} : 0;

# Are they asking for help?
help_info() if ((defined $in->{'h'}) || (defined $in->{'help'}));


####################################
# Command line definitions
####################################

my $input_logfile   = (defined $in->{'f'})?   $in->{'f'}: $existing_log;
my $email_logfile   = (defined $in->{'e'})?   $in->{'e'}: $email_file;


####################################
# End command line definitions
####################################


######################################################################
######################################################################
# Start Main Function
######################################################################


## Open in/out CSV file, output email file. 
open (IN, "+>>$input_logfile")  or die "Error: Can't open $input_logfile for input!\n\n";
open (EMAIL, ">$email_logfile")  or die "Error: Can't open $email_logfile for input!\n\n";



##   15747GB 967GB   13981GB   7% /backup_files/HDD_1
my $BU_HDD_stats = `df -B GB | grep backup_files`;

## Regex to seperate elements, add to array
my @BU_HDD_stats_array = grep { /\S/ } split(/ /,$BU_HDD_stats);

## Stores total memory of disk
my $total_mem = $BU_HDD_stats_array[0];	#xGB
substr($total_mem, -2, 2) = "";   	#Removes "GB";

## Stores used memory of disk
my $used_mem = $BU_HDD_stats_array[1];	#xGB
substr($used_mem, -2, 2) = "";   	#Removes "GB";

## Stores the percentage of disk used
my $used_mem_perc = $BU_HDD_stats_array[3]; #x%
substr($used_mem_perc, -1, 1) = "";   #Removes "%"





## Appends new data to end of CSV file. 
print IN "$day_name,$day,$month,$year,$total_mem,$used_mem,$used_mem_perc\n";



my $line; #declare new line for input
my (@a,@array_of_elements); #arrays - to make an array of arrays ( @a ) 
my $num = 0;  #line counter

## Move curser to beginning of file (since it was previously at end from appending).
seek (IN,0,SEEK_SET);

## Read file, input data into array
while ($line = <IN>)
{
	chomp $line;			#remove "\n"
	if ($line =~ /day/) { }		#skip the first line
	elsif ($line =~ /^$/) { }	# Ignore blank lines
	else {	
		@array_of_elements = split(',', $line);
		$a[$num] = [ @array_of_elements ];
		$num++;  #line counter++
	}
}

close IN;


###############################################################################
##  MAIN DATA ARRAY NOTATION FOR DEREFERENCING INDIVIDUAL DATAS:             ##
##         ** $a[DAY_NUMBER][DATA_NUMBER]; **                                ##
##           								     ##	
##  DAY_NUMBER: [0..n] 0 is oldest day on record, 'n' is the most recent day ## 
##									     ##	
##  DATA_NUMBER: as follows:						     ##
##       0=day_name,1=day,2=month,3=year,4=total_mem,5=used_mem,6=used_mem_% ##
###############################################################################

## stores total number of days on record. 
my $total_days = @a;
$total_days--; #subtract one for indexing
my ($dow,$d,$m,$y,$t,$t_y,$t_d,$u,$u_y,$u_d,$p); #elements

## repens the same file for rewriting data (with possible errors fixed)
open (OUT, ">$input_logfile")  or die "Error: Can't open $input_logfile for input!\n\n";

##remove duplicate entry if run multiple times in one day
if ($a[$total_days][1] == $a[$total_days -1][1] )
{	
	for my $i(0..6)
	{	
		##saves only the newest data
		$a[ $total_days -1 ][ $i ] = $a[ $total_days ][ $i ];
	}
	$total_days--;
}

##print updated log file - no spaces or no duplicate at EOF. 
print OUT "day_of_week,day,month,year,total_size,used,%";
for my $i (0..$total_days)
{
	print OUT "\n";
	for my $j ( 0..5 )
	{
		print OUT "$a[ $i ][ $j ],";
	}
	print OUT "$a[ $i ][ 6 ]";
}
print OUT "\n";




###########################################################
###################### Today's Stats ######################
###########################################################

print EMAIL "
  ######################################
  ########### Current stats ############
  ######################################

";

print EMAIL "\"df -h\"\n\n";
print EMAIL `df -h | grep -E 'Filesystem|Backup_Storage|backup_file'`;




###########################################################
###################### Weekly Stats #######################
###########################################################

print EMAIL "


  ######################################
  ######### Past 7 days stats ##########
  ######################################

Day\tDate\t\tWritten\t  Disk Percentage
=== +\t======== +\t==========\t+ ===============\n";


for my $i (0 .. 6) #for loop for current day (0) to 7 days ago (6)
{
	$dow 	= $a[$total_days - $i][0]; 	#day of week
	$d 	= $a[$total_days - $i][1];	#day 
	$m	= $a[$total_days - $i][2];	#month
	$y	= $a[$total_days - $i][3];	#year

	$u	= $a[$total_days - $i][5];	#used memory
	$u_y	= $a[$total_days - $i - 1][5];	#used memory yesterday
	$u_d	= $u - $u_y;			#change in used mem - 1 day	

	$p	= $a[$total_days - $i][6];	#percent of mem. used
	
	
	
	print EMAIL "$dow .\t$d-$m-$y .\t";	#Wed . 30-07-14 .  \
	printf EMAIL "%7s", "$u_d";		#xx  \     
	print EMAIL " GB\t.\t$p%\n";		# GB   .   8%   \
}

##calculations and rounding for display
my $average_mem_used = ($a[$total_days][5] - $a[$total_days - 7][5])/7;
my $a_m_u_round = sprintf("%.1f", $average_mem_used);
my $days_left = ($a[$total_days][4] - $a[$total_days][5])/$average_mem_used;
my $d_l_round = sprintf("%.1f", $days_left);


print EMAIL "\n\tDaily Average for last week: $a_m_u_round GB.
\tIf this current rate continues, 
\tbackup disk will be full in $d_l_round days.";



###########################################################
###################### Monthly Stats ######################
###########################################################

print EMAIL "



  ######################################
  ######## Month to date stats #########
  ######################################

Day\tDate\t\t  Used\t\t  Disk Percentage
=== +\t======== +\t================\t+ ===============\n";

##checks to see if there is enough data
if ($total_days > 30)
{	
	##compares current day and 30 days ago
	for my $i (0,30)
	{	
		$dow 	= $a[$total_days - $i][0];	#day of week
		$d 	= $a[$total_days - $i][1];	#day
		$m	= $a[$total_days - $i][2];	#month	
		$y	= $a[$total_days - $i][3];	#year
		
		$t	= $a[$total_days - $i][4];	#total
		$u	= $a[$total_days - $i][5];	#used

		$p	= $a[$total_days - $i][6];	#percent

		if ($i == 0) {	#saftey to avoid negative indexing 
			$t_y	= $a[$total_days - 30 ][4];#total_yester(month)
			$t_d	= $t - $t_y;		#total_difference
			$u_y	= $a[$total_days - 30 ][5];#used_yester(month)
			$u_d	= $u - $u_y;		#used_difference

		}
		##print stats formatted into a chart. 
		print EMAIL "$dow .\t$d-$m-$y .\t";	#Tue . 05-08-14 .
		printf EMAIL "%5s", "$u";		#xx 
		if ($i == 0) { print EMAIL " (+$u_d)"; }#(+xx)
		else { print EMAIL "\t\t"; }
		print EMAIL " GB\t.\t$p%\n";		# GB . X 
	}


	##calculations and roudning 
	$average_mem_used = ($a[$total_days][5] - $a[$total_days - 30][5])/30;
	$a_m_u_round = sprintf("%.2f", $average_mem_used); #round to 2 decimals
	$days_left = ($a[$total_days][4] - $a[$total_days][5])/$average_mem_used;
	$d_l_round = sprintf("%.1f", $days_left);	   #round to 1 decimal
	
	
	
	print EMAIL "\n\tDaily Average for last month: $a_m_u_round GB.
	If this current rate continues, backup 
	disk will be full in $d_l_round days.";
	
}
else { print EMAIL "**DATA NOT YET AVAILABLE. ONLY $total_days DAYS ON RECORD SO FAR**\n\n"; }



###########################################################
###################### Yearly Stats #######################
###########################################################

##this is very similar, but a few differences would have made
##a subroutine more difficult than it was worth.. 

print EMAIL "



  ######################################
  ######## Year to date stats  #########
  ######################################

Day\tDate\t\t  Used\t\t  Disk Percentage
=== +\t======== +\t================\t+ ===============\n";


if ($total_days > 364)
{	
	for my $i (0,364)
	{
		$dow 	= $a[$total_days - $i][0];	#day of week
		$d 	= $a[$total_days - $i][1];	#day
		$m	= $a[$total_days - $i][2];	#month
		$y	= $a[$total_days - $i][3];	#year
		
		$t	= $a[$total_days - $i][4];	#total memory
		$u	= $a[$total_days - $i][5];	#used memory
		$p	= $a[$total_days - $i][6];	#percent mem
		
		if ($i == 0) {	#saftey to avoid negative indexing
			$t_y	= $a[$total_days - 365 ][4]; #total_yester(year)
			$t_d	= $t - $t_y;		#difference in total
			$u_y	= $a[$total_days - 365 ][5];	#used_yester(year)
			$u_d	= $u - $u_y;		#difference in used

		}
	
	##print stats formatted into a chart. 
	print EMAIL "$dow .\t$d-$m-$y .\t";
	printf EMAIL "%5s", "$u"; #keeps numbers alligned
	if ($i == 0) { print EMAIL " (+$u_d)"; }
	else { print EMAIL "\t\t"; }
	print EMAIL " GB\t.\t$p%\n";
	}


	$average_mem_used = ($a[$total_days][5] - $a[$total_days - 365][5])/ 365;
	$a_m_u_round = sprintf("%.2f", $average_mem_used);
	$days_left = ($a[$total_days][4] - $a[$total_days][5])/$average_mem_used;
	$d_l_round = sprintf("%.1f", $days_left);


	print EMAIL "\n\tDaily Average for last year: $a_m_u_round GB.
	If this current rate continues, backup 
	disk will be full in $d_l_round days.\n\n";
	
}
else { 
	print EMAIL "\t**Full Year data not yet available.**\n"; 
	
	$average_mem_used = ($a[$total_days][5] - $a[1][5])/ $total_days;
	$a_m_u_round = sprintf("%.2f", $average_mem_used);
	$days_left = ($a[$total_days][4] - $a[$total_days][5])/$average_mem_used;
	$d_l_round = sprintf("%.1f", $days_left);


	print EMAIL "\n\tDaily Average for past $total_days days: $a_m_u_round GB.
	If this current rate continues, backup 
	disk will be full in $d_l_round days.\n\n";
	
}


print EMAIL "



This is an automatic script that is run before each Condor1 backup job 
and sends an email every Saturday. New stats are supposed to be recorded 
every day, however, if a backup job takes more than 24 hours (which is 
very possible), it could skip a day. Manual manipulation of the CSV 
file is always an option. 

Script file: 	$full_path
CSV file: 	\t$existing_log
Email file:	\t$email_logfile 
";

close OUT;
close EMAIL;


###################### Weekly Email ######################

## if the day is saturday, then cat email file to recipients
if ($day_name eq "Sat")
{
	`cat $email_logfile | mailx -s "Backup server disk usage status report" everett.wilson\@nsn.com, dave.feany\@nsn.com, nic.alanis\@nsn.com, trammy.hoang\@nsn.com`;
	## add email addresses to this previous line. Comma separated, with a backslash before the @ symbol (or other perl symbols). 
}

##daily report for testing
else
{	
	`cat $email_logfile | mailx -s "Backup server disk usage status report" everett.wilson\@nsn.com`;
}

exit(0); 

######################################################################
# End Main Function
######################################################################
######################################################################


######################################################
##  Sub Routines
######################################################

sub help_info
{
   print <<HELP;


	$thisfile: This is a script for storing and relaying 
	information about the backup server storage. This script is
	intended to be an automatically run script at the beginning of
	every backup: it will store data to a CSV file, then write a
	neatly formatted summary file. Once a week, this summary will get
	automatically emailed to a list of people. While it will only 
	email information once a week, the summary file will get created
	every day if you want to view it. 

	Also note that this file (especially the EMAIL file) has been
	formatted for Microsoft Outlook. It will not look as neat when
	viewing on Linux. Not much safety went int this file since it is
	not intended to be run manually. You can change some options via
	command line, however, this is not the intended use of the script.

	Important information:
		-This file: $full_path
		-CSV log: $existing_log
		-Email summary file: $email_file
		-Command to run: perl $thisfile
		-Optional Arguments to change default options: 
			-f <CSV file>
			-e <email summary file> 
		
	Examples: 
		perl $thisfile
		perl $thisfile -f csv_log.csv -e email_log.txt
		



	Created by Everett Wilson, Software Integration Summer Intern. 
	August 2014. 
	EverettWilson21\@me.com


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



