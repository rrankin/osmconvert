#!/bin/sh

# To the extent possible under law, the person who associated CC0
# with this work has waived all copyright and related or neighboring
# rights to this work.
# http://creativecommons.org/publicdomain/zero/1.0/

# This script brings your local fosm minute-replicate mirror up to date with the
# fosm server.

# It pulls in changes until it fails.

# If you want minutely updates call this every minute (may do unexpected things if run concurrently)
# If you want daily updates call this every day, etc.

# doesn't do any error checking so if things go wrong you may end up with an out of sync mirror

# if you want to manually get an initial chunk of files (eg. to catch up to now) you may want to just use,
# curl --create-dirs -o minute-replicate/100/#1/#2.src.gz http://fosm.org/planet/minute-replicate/100/[000-456]/[000-999].osc.gz
# after you get this initial chunk, you can load the chunk into PostgreSQL in bulk via,
#for f in minute-replicate/*/*/*.osc.gz
#do
#  echo "$f"
#  osm2pgsql --append --slim "$f"
#fi
prog=`basename $0 .sh`
lockfile=/tmp/$prog.lock
if [ -f $lockfile ]
then
    echo "Exit $lockfile exists"
    exit;
fi
trap "rm -f $lockfile; date; exit" INT TERM EXIT
touch $lockfile
    

# should we also merge the diffs into postgres?
# YES
LOAD_PG=true
# NO
#LOAD_PG=

SCRIPT_DIR=`dirname $0`
cd $HOME/changesets

tryNext() {
  NEXT_URL=`$SCRIPT_DIR/next-url.pl`
  curl -sS --fail --create-dirs -o "$NEXT_URL" "http://fosm.org/planet/$NEXT_URL"
  RET=$?
  echo "curl returned $RET"
  if [ $RET -eq 22  ]
  then
    # HTTP page not retrieved
    echo "$NEXT_URL failed"
    rm -f $NEXT_URL
    exit
  else
    echo "GOT $NEXT_URL"
    if [ $LOAD_PG ]
    then
      osm2pgsql --append --slim -P 5432 -b 89.89405,-57.34168,179.74270,7.21491 "$NEXT_URL"
      if [ $? -ne 0 ]
      then
        echo "osm2pgsql failed for $NEXT_URL"
        exit
      else
        tryNext
      fi
    else
      tryNext
    fi
  fi
}

tryNext
