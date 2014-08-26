#!/bin/sh

# Torrent Renaming Project w/ Applescript & JSON
# aka TRPAJ v1.0 by Carlson, August 2014
#
# Run this script from transmission after download completes.

# Change path if necessary:
PATH_TO_SCRIPT=~/Documents/trpaj.scpt

osascript $PATH_TO_SCRIPT "$TR_TORRENT_DIR" "$TR_TORRENT_NAME"
