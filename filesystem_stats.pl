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
use Cwd qw(abs_path); #easy way to show full path




####################################
# BEGIN User globals
####################################

my $email_logfile_dflt		= "/root/Documents/EBW/logs/email_filesystem_stats.txt";
##list of email recipients -  items separated by ', '  -   '\' before '@' (or other perl symbols)
#my $email_recipients	= 'dave.feany@nsn.com, nic.alanis@nsn.com, trammy.hoang@nsn.com'
my $email_recipients	= "everett.wilson\@nsn.com";
my $warning_threshold_dflt 	= 80;
my $critical_threshold_dflt	= 90;
my $min_file_size_dflt	= 10000000; #won't store files less than 10MB (Mb?)

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


# /home/dfeany1/scripts/find_grep.pl 
my $errlog = "/tmp/$thisfile.log";
open (STDERR, ">$errlog") or die "Could not open error log for output: $errlog";

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







####################################
# Command line definitions
####################################

my $email_logfile   	= (defined $in->{'e'})?   $in->{'e'}: $email_logfile_dflt;
my $warning_threshold 	= (defined $in->{'w'})?   $in->{'w'}: $warning_threshold_dflt;
my $critical_threshold	= (defined $in->{'c'})?   $in->{'c'}: $critical_threshold_dflt;
my $min_file_size	= (defined $in->{'m'})?   $in->{'m'}: $min_file_size_dflt;

##safety to make sure thresholds are not switched
if ($warning_threshold > $critical_threshold) 
{ 
	print "
**Warning threshold cannot be greater than Critical threshold. **
**Defaulting to $warning_threshold_dflt and $critical_threshold_dflt **\n\n";

	$warning_threshold = $warning_threshold_dflt;
	$critical_threshold = $critical_threshold_dflt;
}

# Are they asking for help?
help_info() if ((defined $in->{'h'}) || (defined $in->{'help'}));


####################################
# End command line definitions
####################################








######################################################################
######################################################################
# Start Main Function
######################################################################

##variables
my $df_command = `df -h`;
my @df_array = split( " ",$df_command );
my @main_array;
my @sub_array;
my $num = 0;
my $warning_flag = 0;
my $critical_flag = 0;

##open EMAIL file
open (EMAIL, ">$email_logfile")  or die "Error: Can't open $email_logfile for input!\n\n";

##Print header for file
print EMAIL "
===============================================================
Attention! The following filesystems are approaching capacity: 
==============================================================";



## populating array[x][y] - stores all info given from $df_command
for (my $i=7; $i <= @df_array-1; $i=$i+6 ) {
	for my $j(0..5) ##there are 6 pieces of information given for each filesystem
	{
		$sub_array[ $j ] = $df_array[ $i + $j ];		
	}
	$main_array[ $num ] = [ @sub_array ] ;
	$num++; ##simple counter
}


##########################################################################
####### How to de-reference @main_array data  ############################
##########################################################################
##									##
##	$main_array[x][y]						##
## 		[x] = indexing of file systems. 			##
##			=> 0..(number of filesystems - 1)		##
##			*you will most likely iterate through all 	##
##									##
##		[y] = indexing of information from 'df' command		##
##			=> 0 : Filesystem				##
##			=> 1 : Size					##
##			=> 2 : Used					##
##			=> 3 : Available				##
##			=> 4 : Use%					##
##			=> 5 : Mounted on				##
##			    *this is used most - as sub-rout argument   ##
##########################################################################


##print array for testing
#for my $j(0..@main_array-1)
#{
#	for my $i(0..5)
#	{
#		print "Location 1.$j.$i: $main_array[$j][$i]\n";
#	}
#	print "\n";
#}


##check percentages
for my $j(0..@main_array-1)
{	
	substr($main_array[$j][4], -1, 1) = ""; ##removes '%'  
	my $percent = $main_array[$j][4];       ##stores the percent	
	
	##output: 2.) Filesystem: /dev/sda1:      percent: 28	
	print "\n$j.) Filesystem: $main_array[$j][0]:\tpercent: $percent" ;
	if ($percent >= $critical_threshold) { $critical_flag++; }
	if ($percent >= $warning_threshold) { $warning_flag++; &warning($main_array[$j]); }
}

##checks to see if any are above threshold 
if ( $warning_flag > 0 ) { &email; print"\n\n\n###Stats about filesystems: $email_logfile ###\n\n"; }
else { print "\n\n\n### No filesystems are above the warning threshold of $warning_threshold % ###\n\n"; }

print "\n\n";

close EMAIL;

close (STDERR);
`rm -f $errlog`;

exit(0); 

######################################################################
# End Main Function
######################################################################
######################################################################


######################################################
##  Sub Routines
######################################################



sub warning
{	
	if($_[0][4] >= $critical_threshold) { print " CRITICAL!!! $_[0][5]"; }
	else { print " WARNING! $_[0][5]"; };

	##print current stats to EMAIL - `df -h /backup_clients/condor1/home1`
	print EMAIL "\n\n";
	print EMAIL `df -h $_[0][5]`;
	
	##sub routine for finding largest directories
	&diskuse_du_sort_size($_[0][5]);
	
	##sub routine for finding largest files
	&find_large_files($_[0][5]);
}




##finds and prints to EMAIL the largest 20 directories
sub diskuse_du_sort_size
{	
	##main array
	my @a;
	
	##du -b command, with wanrings suppressed, for given directory
	foreach(`du -b 2>/dev/null $_[0]`)
	{
		##regex to find, split, and store needed information
		$_=~s/\s+/ /g; 
		my ($s,$t)=split(" ", $_); 
		$s=join("", reverse split("", $s)); 
		$s=~s/(.{3})/$1,/g; 
		$s=join("", reverse split("", $s)); 
		$s=~s/^,//; 
		push @a, sprintf "%20s %s\n",$s,$t;
	}
	my $a_size = @a-1; 	##subtract one for indexing
	@a = sort @a;		##sort by size
	my $n;

	##if there are more than 20, only displays the last 20
	if($a_size > 20) { $n = 20; }
	else{ $n = $a_size; }

	##for loop to print the last 20 to EMAIL
	print EMAIL "\n\t##The 20 largest directories in filesystem:\n\n";
	for my $i($a_size-$n..$a_size)
	{
		print EMAIL $a[$i];
	}

}


##finds and prints to EMAIL the largest 20 files
sub find_large_files
{
	my @large_files; ##array of large files
	my $l_f_s; ##large_files_size

	##`find /backup_clients/condor1/home1`
	foreach my $file (`find $_[0]`)
	{
		chomp $file; 		##remove newline char
		my $size = (-s $file);	##find size of given file
		$l_f_s = @large_files;	##size of @large_files
		##if larger then specificed size, add formatted line to array	
		if($size >= $min_file_size) { push @large_files, sprintf("% 15d : %s\n", $size, $file) }
		##sort by size order
		@large_files = sort @large_files;
		##if the array has 21 lines..
		if($l_f_s >= 21)
		{	##remove the smallest valued line (keeps mem usage small)
			splice @large_files, 0, 1;

		}
	}

	##print formatted info to EMAIL
	print EMAIL "\n\t##The 20 largest files in the filesystem:\n\n";
	foreach (@large_files)
	{
		my $s = $1 if($_ =~ / *(\d+) :/);
		my $scomma = commify($s);
		$_ =~ s/ *(\d+) ://;
		printf EMAIL ("% 20s : %s", $scomma, $_);
	}
}



sub email
{	
	my $subject = "WARNING!";
	if ($critical_flag > 0 ) { $subject = "CRITICAL!!!"; }

	print EMAIL "


This email report was generated with an automatically run perl script. 
Script location: $full_path
";
	
	`cat $email_logfile | mailx -s "$subject Filesystems approaching capacity. " $email_recipients`;		
}




# Commifies all numbers in a line regardless of whether they have decimal portions, are preceded by + or -, or whatever:
# from Andrew Johnson <ajohnson@gpu.srv.ualberta.ca>
sub commify
{
	my $input = shift;
	$input = reverse $input;
	$input =~ s<(\d\d\d)(?=\d)(?!\d*\.)><$1,>g;
	return reverse $input;
}


sub help_info
{
   print <<HELP;


	$thisfile: This is a script for automatically monitoring 
	filesystem usage. This script should be set up with a cron job to
	run as often as you want. The following options can be changed
	via command line arguments: 

		./$thisfile -h (-help)
		  Show this help.

	Options: 	
		-e <file to email> \t(dflt=$email_logfile_dflt)
		-w <warning threshold > \t(dflt=$warning_threshold_dflt)
		-c <critical threshold> \t(dflt=$critical_threshold_dflt)
		-m <minimum file size>\t(dflt=$min_file_size_dflt)

	Examples:
		perl $thisfile
		perl $thisfile -e /tmp/email.txt -w 70 -c 85 -m 10000

	
	Important information:
		-This file:	$full_path
		-Emailed file:	$email_logfile 

	Current Bugs:
		You will see some warnings if you are watching the console
		as you run the script: "Use of uninitialized value \$size
		in numeric ge (>=) at...". I believe this happens when the
		find function comes across an empty file. This should not
		affect the outcome of the data, but is still annoying.
		Also, there are many "Permission denied" files. These will
		not be included in the results. 
		


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



