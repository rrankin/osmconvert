#!/bin/bash
# update-osm.sh 14-09-2011
# Copyright Roy Rankin 2011 
# rrankin AT ihug.com.au
#
# This work is licensed under the Australia Creative Commons CC BY-SA 3.0 
# License. Copyright notice must not be removed.
# To view a copy of this license, visit 
#    http://creativecommons.org/licenses/by-sa/3.0/au

# update-osm.sh scans the CHANGESETS directory for changeset directories
# which are newer then the distilled changesets in the o5s directory.
# when this is the case, all changesets in the changeset directory are
# distilled into a single file in the o5cwork directory. All changesets
# in the o5cwork directory are then applied to the $OSM.osm.gz file
# and the result bounded to the area of interest. If this succeeds,
# all the distilled changeset files in o5cwork are moved into the
# o5c directory tree.
#
# log file contains the stderr output from the programs.

# Base of OSM file name to which the changesets are applied.
# Actual name ends with .osm.gz
OSM=australia
# Bounding box (-b) of polygon (-B) of OSM file
BOUND=-b="112.7,-44.0,154.0,-9.8"
# Full path to location of changesets
CHANGESETS=~/changesets/minute-replicate/

date >> log

for LLDIR in `ls -d $CHANGESETS/[0-9][0-9][0-9]`
do
  NEW=0
  LDIR=`basename $LLDIR`
  #
  # Make sure required directories exist
  #
  if ! [ -d o5c/$LDIR ]
  then
      mkdir -p o5c/$LDIR
  fi
  if ! [ -d o5cwork/$LDIR ]
  then
      mkdir -p o5cwork/$LDIR
  fi
  #
  # distile(merge) up to 1000 change sets in a directory into one file
  # Uses oscmerge.pl to merge and convert output changeset to order
  # expected by osmconvert.
  #
  for FDIR in `ls -d $LLDIR/[0-9][0-9][0-9]`
  do
      DIR=`basename $FDIR`
      if [ $FDIR -nt o5c/$LDIR/$DIR.o5c ]
      then
	zcat $FDIR/*.osc.gz | oscmerge.pl \
  	| osmconvert  --out-o5c - \
              > o5cwork/$LDIR/$DIR.o5c 2>> log
  	ret=$?
  	if [ $ret -ne 0 ] 
  	then
  		rm -f o5cwork/$LDIR/$DIR.o5c
  		echo "abort dir=$LDIR/$DIR "
  		exit $ret
  	fi
         echo "processed $LDIR/$DIR returned $ret"
         NEW=1
      fi
  done
  #
  # apply the new distilled changesets to the OSM file and bound the result.
  #
  if  [ $NEW -eq 1 ]
  then
     echo "Modifying $OSM.osm.gz"
     cp $OSM.osm.gz ${OSM}_old.osm.gz
     osmconvert   \
  	$BOUND  --merge-versions  \
  	${OSM}_old.osm.gz o5cwork/$LDIR/*.o5c 2>> log \
  	| gzip > $OSM.osm.gz
  
      ret=${PIPESTATUS[0]}
      if [ $ret -ne 0 ]
      then
  	cp -f ${OSM}_old.osm.gz $OSM.osm.gz
  	echo "abort build osm $ret"
  	exit $ret
      fi
      echo "built $OSM.osm.gz $ret"
      mv -f o5cwork/$LDIR/*.o5c o5c/$LDIR
  else
     echo "nothing to do in $LDIR"
  fi
done
exit 0
