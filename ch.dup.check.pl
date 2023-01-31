#!/usr/bin/perl

use strict;
use warnings;
use Term::ANSIColor;



######################################################################################
# define: Abrufzeichen to check / against; file extensions for input; library in use #
######################################################################################

my $wab_1 = "ZDB-54-DH";
my $wab_2 = "WISO";

my $ext_1 = "*.fix.*u";     # to address unique matches
my $ext_2 = "*.fix.n.m";    # to address multiple matches

my $lib = "EBX01";


######################################################################################
# fetch input files(!) if existing, readable, >0 and not empty                       #
######################################################################################

opendir(DIR, ".");
my @infiles = glob ("${ext_1} ${ext_2}"), readdir(DIR);
closedir(DIR);

if (!@infiles) {
    print color("red"), "\nERROR:", color("reset")," No input files found!\n\n";
    exit;
    }

my @procfiles = ();
foreach my $file (@infiles) {
   if (-e $file && -f _ && -s _ >0) {
    unless(-z $file) {
        push  @procfiles, $file;
        }
        else {
            print color("bright_yellow"), "\nWARNING:", color("reset")," input file $file is empty! $file is omitted from further processing.\n";
            }
        }
        elsif (-s $file == 0) {
            print color("bright_yellow"), "\nWARNING:", color("reset")," size of input file $file is zero!\n$file is omitted from further processing.\n\n";
            }
            unless (-r $file) {
            print color("red"), "\nERROR:", color("reset")," input file $file not redable! Access denied\n\n";
            }
}


######################################################################################
# fetch ALEPH Ids from input files                                                   #
######################################################################################

open my $ofile_1, '>' , "all-u.sys" || die 'unable to write output file all-u.sys';
open my $ofile_2, '>' , "dup.sys" || die 'unable to write output file dup.sys';

(my $proc_ext_1 = $ext_1) =~ s/\./\\./g;
$proc_ext_1 =~ s/\*/\.\*/g;
(my $proc_ext_2 = $ext_2) =~ s/\./\\./g;
$proc_ext_2 =~ s/\*/\.\*/g;

foreach my $pfile (@procfiles) {
    if ($pfile =~ /$proc_ext_1/) {						#formerly: ($pfile =~ m/.*\.fix\..*u/) based on DuHu metadata
		print "\nProcessing $pfile\n";
		open my $infile_1, '<', $pfile;
		while (my $line = <$infile_1>) {
			chomp($line);
			if ($line =~ / 078e  L /) {
				$line =~ s/ 078e  L \$\$a\Q$wab_1/$lib/g;
				print $ofile_1 "$line\n";
				}
			}
		close $infile_1;
		sleep 1;
		print "\n";
        }
    elsif ($pfile =~ /$proc_ext_2/) {						#formerly: ($pfile =~ m/.*\.fix\.n\.m/) based on DuHu metadata
        print "\nProcessing $pfile\n";
        open my $infile_2, '<', $pfile;
        while (my $line = <$infile_2>) {
            chomp($line);
            if ($line =~ / DUP   L /) {
                $line =~ s/.*a//g;
				$line =~ s/$/$lib/g;
                $line =~ s/,/$lib\n/g;
                print $ofile_2 "$line\n";
                }
            }
        close $infile_2;
        sleep 1;
        print "\n";
        }
}

close $ofile_1;
close $ofile_2;


######################################################################################
# process Ids to ALEPH-seq                                                           #
######################################################################################

system ("/exlibris/mpdl/proc/mar.seq-print.csh $lib all-u.sys");
system ("/exlibris/mpdl/proc/mar.seq-print.csh $lib dup.sys");


######################################################################################
# identify $wab_2 duplicates                                                         #
######################################################################################

opendir(DIR, ".");
my @seqfiles = glob ("*.sys.seq"), readdir(DIR);
closedir(DIR);

my $ofname = lc $wab_2;
open my $ofile_3, '>' , "$ofname-del.sys";

foreach my $sfile (@seqfiles) {
    print "\nProcessing ".$sfile."\n";
    open my $infile_3, '<', $sfile;
    while (my $line = <$infile_3>) {
		chomp($line);
		if ($line =~ / 078e  L \$\$a\Q$wab_2/) {
			$line =~ s/^.*://g;
			$line =~ s/ 078e  L \$\$a\Q$wab_2/$lib/g;
			print $ofile_3 "$line\n";
			}
		}
    close $infile_3;
    sleep 1;
    print "\n"
}

close $ofile_3;


######################################################################################
# process final ALEPH-seq and report results                                         #
######################################################################################

opendir(DIR, ".");
my @finfiles = glob ("*-del.sys"), readdir(DIR);
closedir(DIR);

my $count = 0;
foreach my $ffile (@finfiles) {
    open my $infile_4, '<', $ffile;
    $count++ while <$infile_4>;
    unless ($count == 0) {
        print "\nProcessing ".$ffile."\n";
        sleep 1;
        system ("/exlibris/mpdl/proc/mar.seq-print.csh $lib $ffile");
        print color("green"), "RESULT:", color("reset")," duplicate check finished. $count duplicates between $wab_1 and $wab_2 found. Please check ".$ffile.".seq before initiating deletion procedure.\n\n";
        sleep 1;
        exit;
        }
    else {
    print color("green"), "RESULT:", color("reset")," duplicate check finished. No duplicates detected. Proceed without duplicate deletion!\n";
    exit;
    }
}

1;

# END # ch - 20.12.2022 #