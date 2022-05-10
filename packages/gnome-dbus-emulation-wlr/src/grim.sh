#!/bin/sh

FILENAME=$1

if [ "$2" = "showcursor" ]; then
    cursor='-c'
else
    cursor=''
fi

# Take Screenshot
# See: https://github.com/emersion/grim
grim -s 1 $cursor -- $1
#grim -s 1 $cursor -t ppm - | convert - -quality 1 $1

if [ "$3" = "showflash" ]; then
  notify-send Screenshot $FILENAME
fi
