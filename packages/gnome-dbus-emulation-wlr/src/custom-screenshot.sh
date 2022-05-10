#!/bin/sh

FILENAME=$1

if [ "$2" = "showcursor" ]; then
    cursor='-c'
else
    cursor=''
fi

# Take Screenshot
# See: https://github.com/emersion/grim

#TODO: Consider launching a selection dialog with fzf for outputs, everything, or slurp. Remember it for the calling program ID to allow psuedo-video
grim -s 1 $cursor -g "$(slurp)" -- $FILENAME

if [ "$3" = "showflash" ]; then
  notify-send Screenshot $FILENAME
fi
