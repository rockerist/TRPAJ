TRPAJ
=====

Torrent Renaming Project with Applescript and JSON
v1.0

The scripts in this project are used to rename movie video torrents to desired 
format. The main part is the trpaj.scpt Applescript file, which means that, for 
now, only Mac OS X users can use the scripts. Porting to other platforms is not 
my priority right now.

For now, the script only works if called by a shell script trpaj.sh, which is 
executed upon download complete in Transmission torrent client. Other usage 
methods might be developed sometime in the future, however, the main goal of 
this project is to rename video torrents, including TV torrents, which will be 
implemented soon.


##  Usage:
To use these script you need following things:
* a system running on Mac OS X
* a Transmission client
* JSON Helper
* tmdb API-key

JSON Helper is a free application you can get from the App Store.

Tmdb API-key reffers to the theMovieDb.org's API developer's key. You can 
obtain one by registering with theMovieDb.org for free. This until I can figure 
out how to hide the key in Applescript.

Once set up, the scripts work for themselves.


##  Installation
Go to Transmission, Properties | Transfers and check the *When download completes call script:* box.
Select the _trpaj.sh_ script.

Place the _trpaj.scpt_ wherever you want, just make sure that `PATH_TO_SCRIPT` on line 9 of _trpaj.sh_ points to the Applescript file. If you don't want to complicate things, just put your _trpaj.scpt_ in your home directory's _Documents_ folder.
`PATH_TO_SCRIPT=~/Documents/trpaj.scpt`

In _trpaj.scpt_, on line 12 replace the *####* in `set apiURL to "&api_key=####"` with your actual API-key.

