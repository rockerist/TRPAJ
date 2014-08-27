#	Torrent Renaming Project w/ Applescript & JSON
#	aka TRPAJ v1.0 by Carlson, August 2014
#

on run argv

	--	SET VARIABLES AND PROPERTIES

	--	Set the destination directory for moving,
	--	leave empty ("") for rename only.
	set dDir to "~/Movies/"
	--	Replace the #### with your API-key
	set apiURL to "&api_key=####"
	(*
	--	Enable keeping log, for now only idea
	property enableLog:	false
	--	Empty ("") means a file will be stored in the original torrent folder
	property pathToLog: ""
	*)

	--	Retrieve arguments
	set torrentDir to item 1 of argv
	set torrentName to item 2 of argv

	set torrentPath to torrentDir & "/" & torrentName as string
	set torrentPath to RunSed(torrentPath, "-E ", "s/( |\\(|\\))/", "\\\\\\1", "g")

	--	Check for video files in torrent directory
	set dirReturn to do shell script "ls -Rp " & torrentPath
	set dirContents to paragraphs of dirReturn as list

	--	NUTSHELL

	--	Get all video files in folder
	set videoFiles to GetVideos(dirContents, torrentPath & "/")

	--	Check if any video files
	if (videoFiles = "" as list) then
		return -1	--	No execution errors, no video files
	end if
	--	If more video files in torrent dir, choose the largest
	set movieFile to ChooseMovieFile(videoFiles)

	--	Avoid renaming video files from non-movie torrents
	if (IsMovie(movieFile) is false) then
		return -2 --	No execution errors, yes video files BUT NO MOVIES
	end if

	--	Make file name into searchable string
	set queryString to MakeString(torrentPath, item 1 of movieFile, apiURL)

	--	Get JSON from themoviedb.org and set rename string
	set renameString to GetNewName(queryString, item 4 of movieFile, apiURL)

	--	Return rename string to it's backslashed state
	set renameString to RunSed(renameString, "-E ", "s/( |\\(|\\))/", "\\\\\\1", "g")

	--	Rename the file:
	set moveCommand to "mv -f " & item 1 of movieFile & " " & dDir & renameString
	do shell script (moveCommand)

	return 0 --	All is well, there were video files and now they are moved

end run


on GetVideos(_dirContents, _dirPath)

	--	Get all video files in a directory, and all the subdirectories
	--	Discard other files or folders

	--	Indicates next line is a folder
	set folderFlag to false
	--	List of common video file extensions
	set extList to {".avi", ".mp4", ".mkv", ".mpeg", ".mpg", ".mov", ".wmv", ".rm", ".qt", ".3gp", ".ogm"}
	--	Set default value for return
	set videoList to {""} as list
	--	A flag to rewrite videoList
	set firstTime to true

	repeat with lineFromLS in _dirContents

		--	Analyze every line of ls command
		try
			if (lineFromLS = "") then
				--	Nothing to analyze, next line is subfolder path
				set folderFlag to true
				--	Continue repeat loop
				error 0
			end if

			if folderFlag is true then
				--	Change working directory
				set _dirPath to value of lineFromLS
				--	Next line is either blank or file
				set folderFlag to false
				--	Continue repeat loop
				error 0
			end if

			--	Regular expression to extract the extension with sed
			set fExt to RunSed(lineFromLs,"-n ","s/\\(.*\\)\\(\\.[a-zA-Z0-9]\\{2,4\\}$\\)/","\\2","p")

			--	Check if video file (by extension comparison)
			if fExt is in extList then

				--	Backslash the hell out of it
				set lineFromLS to RunSed(lineFromLS, "-E ", "s/( |\\(|\\))/", "\\\\\\1", "g")

				--	If this is the first video file in directory
				if (firstTime is true) then
					--	Not first time anymore
					set firstTime to false
					--	Replace first entry ("") with file path
					set item 1 of videoList to (_dirPath & lineFromLS)
				else
					--	Not the first time; Append file path to the list
					set videoList to videoList & (_dirPath & lineFromLS)
				end if

			end if
		end try

	end repeat

	return videoList

end GetVideos


on ChooseMovieFile(_videoFiles)

	--	Choose the largest video file by size
	--	Works with one or more entries

	--	Anything has more than -1 bytes
	set sizeOfLargest to -1
	--	A placeholder for the returned variable, pardon my French
	set chosenMovieFile to "picka ti se ogadila jebem ti mater"

	--	Go through files and return the biggest one
	repeat with videoEntry in _videoFiles

		--	This is a work-around a problem I had with folder
		--	directories with spaces in them. Echoed result of
		--	videoEntry strips the backslashes, which is good
		--	for "System Events" but bad for bash, thus *Temp

		set videoEntryTemp to do shell script ("echo " & videoEntry)
		try
			--	Check if it's not empty string
			if (videoEntry is not "") then

				--	Get meta information for the file(s)
				tell application "System Events"

					--	For some reason, this is always 600
					set timeScale to time scale of movie file videoEntryTemp
					--	Upscaled by timeScale, in seconds
					set durationOfVideo to duration of movie file videoEntryTemp
					--	Downscale by timeScale and 60 to get minutes
					set durationScaled to durationOfVideo / timeScale / 60
					--	In Bytes, so probably hundreds of millions
					set sizeOfVideoFile to size of movie file videoEntryTemp

				end tell

				--	Get extension, I know, again...
				set extension to RunSed(videoEntryTemp,"-n ","s/\\(.*\\)\\(\\.[a-zA-Z0-9]\\{3,4\\}$\\)/","\\2","p")

				--	Check sizes
				if (sizeOfVideoFile > sizeOfLargest) then
					--	Set return value
					set chosenMovieFile to {videoEntry, sizeOfVideoFile, durationScaled, extension}
					--	Update largest file size
					set sizeOfLargest to sizeOfVideoFile
				end if

			end if
		end try

	end repeat

	return chosenMovieFile

end ChooseMovieFile


on IsMovie(_movieFile)

	--	This is a tricky one.
	--	I do a basic length and size check and do a regular
	--	expression check for usual tv torrent names.
	--	Only the length check doesn't work.

	--	Set cutoff (minimum) time (in minutes) for a movie
	set cutoffLength to 81

	--	Set cutoff (minimum) size (in Bytes) for a movie
	set cutoffSize to 6.0E+8 -- 600 000 000 = 600 MB

	--	Sometimes TV shows can meet cutoff values,
	--	so we check in the file name for TV patterns

	--	Regular expression for SxxExx format (S02E14)
	set sedArgOpt1 to "s/\\(.*\\)\\([sS][0-9]\\{1,2\\}[eE][0-9]\\{1,2\\}\\)\\(.*\\)/"
	--	Regular expression for SSxEE format (3x02)
	set sedArgOpt2 to "s/\\(.*\\)\\([0-9]\\{1,2\\}[xX][0-9]\\{1,2\\}\\)\\(.*\\)/"

	--	Regular expressions return "false" if the pattern
	--	is found, "" otherwise.
	set reCheck1 to RunSed(_movieFile,"-n ",sedArgOpt1,"false","p")
	set reCheck2 to RunSed(_movieFile,"-n ",sedArgOpt2,"false","p")

	--	Checking for regular expressions first.
	--	If file name is not a tv pattern (value is "")
	--	then check against cutoff values.
	if (reCheck1 = "false") then
		set isAMovie to false
	else if (reCheck2 = "false") then
		set isAMovie to false
		--else if (item 3 of _movieFile < cutoffLength) then
		--	set isAMovie to false
	else if (item 2 of _movieFile < cutoffSize) then
		set isAMovie to false
	else
		--	The file hasn't met ANY of the conditions
		--	which would exclude it from being a movie.
		set isAMovie to true
	end if

	return isAMovie

end IsMovie


on MakeString(_dirName, _fileName)

	--	Check if strings are equal after stripping down.
	--	If not, choose the longer one to represent the query.

	--	Trim the extension from filename
	set sedArgOpt to "s/\\(\\.[a-zA-Z0-9]\\{2,4\\}\\)\\{0,1\\}$/"
	set _fileName to RunSed(_fileName,"-n ",sedArgOpt,"","p")

	--	Remove path prior to the file name
	set sedArgOpt to "s/\\(.*\\)\\/\\(.*\\)$/"
	set _fileName to RunSed(_fileName,"-n ",sedArgOpt,"\\2","p")
	--	Remove path prior to the directory name
	set _dirName to RunSed(_dirName,"-n ",sedArgOpt,"\\2","p")

	if (_fileName = _dirName) then
		set unprocessedString to _fileName
	else if (length of _fileName > length of _dirName) then
		set unprocessedString to _fileName
	else
		set unprocessedString to _dirName
	end if

	--	Processing the string into a query
	--	Replace . and _ with space
	set queryString to RunSed(unprocessedString,"-n ","s/[\\._]/"," ","gp")

	--	If there is junk, remove it:
	--	Set the shittiest regexp ever because OS X's sed is always case insensitive
	set shittyRE to "s/(([dD][vV][dD]|[hH][dD]|[bB][rR]|[bB][dD]|[wW][eE][bB])+([rR][iI][pP]|[cC][aA][mM]|[tT][sS])|[xX][vV][iI][dD]|[dD][iI][vV][xX]|[0-9][cC][dD]|720[pP]|1080[pP]|[cC][dD]\\.[0-9]|\\[|\\{|\\(|.[0-9]{4}).*/"
	set queryString to RunSed(queryString,"-E ",shittyRE,"","")

	return queryString

end MakeString


on GetNewName(_queryString, _extension, _apiURL)

	--	Get data necessary for file renaming
	--	Make query search compatible with themoviedb.api
	set _queryString to RunSed(_queryString,"","s/ /","+","g")

	tell application "JSON Helper"

		--	Set API URLs:
		set searchURL to "http://api.themoviedb.org/3/search/movie?query="
		set fetchURL to "http://api.themoviedb.org/3/movie/"
		set appendURL to "?append_to_response=credits"

		--	Fetch search results
		set fetchResults to fetch JSON from (searchURL & _queryString & _apiURL)

		--	Extract data
		set movieTitle to original_title of item 1 of results of fetchResults as string
		set movieID to |id| of item 1 of results of fetchResults as string
		set releaseDate to release_date of item 1 of results of fetchResults as string
		set releaseYear to ((characters 4 thru 1 of releaseDate) as string)

		--	Get other information (director)
		set movieData to fetch JSON from (fetchURL & movieID & appendURL & _apiURL)
		set nrOfItems to count of items of crew of credits of movieData

	end tell
	--	Trim forbidden chars from movieTitle
	set movieTitle to RunSed(movieTitle, "-E ", "s/:/", "", "g")
	set iterations to 1

	repeat while iterations < nrOfItems + 1
		set tempString to job of item iterations of crew of credits of movieData as string
		if tempString is "Director" then
			set directorName to |name| of item iterations of crew of credits of movieData
			exit repeat
		end if
		set iterations to iterations + 1
	end repeat

	--	Format: %title% - %year% - %director%.%extension%
	return movieTitle & " - " & releaseYear & " - " & directorName & _extension

end GetNewName

on RunSed(_echoArgument, _sedOptions, _sedRegExp, _sedReplace, _sedFlags)

	--	Handles every call to bash regarding regular expressions.
	--
	--	Usage limitations:
	--	*	If set (if not ""), _sedOptions MUST end with a
	--		space, like so "-n "
	--	*	_sedRegExp MUST begin with s/ and end with
	--		a slash, like so "s/REGEXP/"
	--	*	Because of I don't know why, no slashes are allowed
	--		in _sedReplace
	--	*	No slashes in _sedFlags either
	--	Obviously, these limitations are only instructional,
	--	no security is implemented. If you change regexps,
	--	make sure you know what you're doing.

	--	For line brevity reasons, copy the input to shorter vars
	set eA to quoted form of _echoArgument
	copy _sedOptions to sO
	copy _sedRegExp to sE
	copy _sedReplace to sR
	copy _sedFlags to sF

	--	Concatenate to argument
	set sedArgument to quoted form of (sE & sR & "/" & sF)
	--	Concatenate to command
	set command to "echo " & eA & " | sed " & sO & sedArgument

	--	Run in Bash
	set output to do shell script (command)

	return output

end RunSed
