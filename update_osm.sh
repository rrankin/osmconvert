#!/bin/bash
# update-osm.sh 06-09-2011
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
# log file contains the stderr output from osmconvert and starts fresh 
# on each run.

# Base of OSM file name to which the changesets are applied.
# Actual name ends with .osm.gz
OSM=australia
# Bounding box (-b) of polygon (-B) of OSM file
BOUND=-b="112.7,-44.0,154.0,-9.8"
# Full path to location of changesets
CHANGESETS=~/changesets/minute-replicate/
#
# Do work in directory where changeset directories are,
# after remembering where we are now
#
HERE=`pwd`
cp /dev/null log

cd $CHANGESETS
for LDIR in `ls -d [0-9][0-9][0-9]`
do
  NEW=0
  #
  # Make sure required directories exist
  #
  if ! [ -d $HERE/o5c/$LDIR ]
  then
      mkdir -p $HERE/o5c/$LDIR
  fi
  if ! [ -d $HERE/o5cwork/$LDIR ]
  then
      mkdir -p $HERE/o5cwork/$LDIR
  fi
  #
  # distile up to 1000 change sets in a directory into one file
  #
  for DIR in `ls -d $LDIR/[0-9][0-9][0-9]`
  do
      if [ $DIR -nt $HERE/o5c/$DIR.o5c ]
      then
  	osmconvert  \
  	    --merge-versions  --out-o5c \
  	    $DIR/*.osc.gz \
              > $HERE/o5cwork/$DIR.o5c 2>> $HERE/log
  	ret=$?
  	if [ $ret -ne 0 ] && [ $ret -ne 91 ] && [ $ret -ne 92 ] 
  	then
  		rm -f $HERE/o5cwork/$DIR.o5c
  		echo "abort dir=$DIR "
  		exit $ret
  	fi
         echo "processed $DIR returned $ret"
         NEW=1
      fi
  done
  #
  # apply the new distilled changesets to the OSM file and bound the result.
  #
  if  [ $NEW -eq 1 ]
  then
     echo "Modifying $HERE/$OSM.osm.gz"
     cp $HERE/$OSM.osm.gz $HERE/${OSM}_old.osm.gz
     osmconvert   \
  	$BOUND  --merge-versions  \
  	$HERE/${OSM}_old.osm.gz $HERE/o5cwork/$LDIR/*.o5c 2>> $HERE/log \
  	| gzip > $HERE/$OSM.osm.gz
  
      ret=${PIPESTATUS[0]}
      if [ $ret -ne 0 ] && [ $ret -ne 91 ] && [ $ret -ne 92 ] 
      then
  	cp -f $HERE/${OSM}_old.osm.gz $HERE/$OSM.osm.gz
  	echo "abort build osm $ret"
  	exit $ret
      fi
      echo "built $OSM.osm.gz $ret"
      mv -f $HERE/o5cwork/$LDIR/*.o5c $HERE/o5c/$LDIR
  else
     echo "nothing to do in $LDIR"
  fi
done
exit 0
