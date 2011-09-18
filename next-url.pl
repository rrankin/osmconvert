#!/usr/bin/perl -w

# Inspect a local minute-replicate mirror and return the URL of the next diff file

# To the extent possible under law, the person who associated CC0
# with this work has waived all copyright and related or neighboring
# rights to this work.
# http://creativecommons.org/publicdomain/zero/1.0/

use strict;
use warnings;

# minute-replicate/A/B/C;

my $Base = "minute-replicate";
my $A = largest_dir_entry($Base);
my $B = largest_dir_entry("$Base/$A");
my $C = largest_dir_entry("$Base/$A/$B");
#print "A=$A B=$B C=$C\n";
my $largest_C;
if ($C =~ /^(\d+).osc.gz/)
{
    $largest_C = $1;
}
else
{
	die "$Base/$A/$B/$C does not match target\n";
}
if ( $largest_C < 999)
{  $largest_C += 1; }
else
{
   $largest_C = 0;
   if ( $B < 999 )
   {    $B += 1; }
   else
   {
	$B = 0;
        $A += 1;
   }
}
printf "$Base/%03d/%03d/%03d.osc.gz\n", $A, $B, $largest_C;


exit 0;

# Read directory, find largest entry starting with 3 numbers
sub largest_dir_entry
{

    my($dir) = @_;	# directory to search

    opendir(my $Bdh, $dir) || die "$!: $dir";

    my @files = readdir($Bdh); closedir $Bdh;
    my @files_sorted = sort @files;
    my $largest;
    do
    {
        $largest = pop @files_sorted;
    } while ($largest !~ /^\d{3}/);
    return $largest;
}

