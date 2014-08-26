#	Torrent Renaming Project w/ Applescript & JSON
#	aka TRPAJ v1.0 by Carlson, August 2014
#

on run argv
	
	##	VARIABLES
	
	#	Set the destination directory for moving,
	#	leave empty ("") for rename only.
	set dDir to "~/Movies/"
	set apiURL to "&api_key=327a7002b11d7bbb6590aa9629ef7535"
	
	#	Retrieve arguments:
	set torrentDir to item 1 of argv
	set torrentName to item 2 of argv
	#	Test values:
	--set torrentDir to "~/Downloads"
	--set torrentName to "They Came Together (2014)"
	set torrentName to do shell script ("echo " & quoted form of torrentName & " | sed -E 's/( |\\(|\\))/\\\\\\1/g'")
	set torrentPath to torrentDir & "/" & torrentName as string
	
	##	SHELLWORK
	
	#	Check for video files in torrent directory
	set dirReturn to do shell script "ls -Rp " & torrentPath
	set dirContents to paragraphs of dirReturn as list
	set videoFiles to GetVideos(dirContents, torrentPath & "/")
	--return videoFiles
	(*
	if (number of items in videoFiles = 1) then
		do shell script "echo 'No video files in this directory.' >> " & torrentPath & "/res.txt"
		return 0
	end if
	*)
	
	#	If more video files, choose the largest
	set movieFile to ChooseMovieFile(videoFiles)
	--return movieFile
	#	To avoid renaming video files from non-movie torrents
	if (IsMovie(movieFile) is false) then
		do shell script "echo 'There is a video but no movies.' >> " & torrentPath & "/res.txt"
		return 0
	end if
	
	set queryString to MakeString(torrentPath, item 1 of movieFile, apiURL)
	
	#	Now, let's get the JSON and set rename string
	set renameString to GetNewName(queryString, item 4 of movieFile)
	
	#	Finally, rename the file:
	set moveCommand to "mv -f " & item 1 of movieFile & " " & quoted form of (dDir & renameString)
	
	do shell script (moveCommand)
	return moveCommand
	
end run
#
#
#
#
#
#
#
#
#
#
#
#
#
#
on GetVideos(_dirContents, _dirPath)
	
	set folderFlag to false
	set extList to {".avi", ".mp4", ".mkv", ".mpeg", ".mpg", ".mov", ".wmv", ".rm", ".qt", ".3gp", ".ogm"}
	set videoList to {""} as list
	set firstTime to true
	
	repeat with lineFromLS in _dirContents
		
		try
			if (lineFromLS = "") then -- Nothing to analyze
				set folderFlag to true -- Next line is subfolder path
				error 0 -- Continue repeat loop
			end if
			
			if folderFlag is true then
				set _dirPath to value of lineFromLS -- change working directory
				set folderFlag to false -- Next line is either blank or file
				error 0 -- Continue repeat loop
			end if
			
			#	Regular expression to extract the extension with sed
			set sedArgOpt to "s/\\(.*\\)\\(\\.[a-zA-Z0-9]\\{2,4\\}$\\)/\\2/p"
			
			#	Create shell line:
			set executeCmd to "echo " & quoted form of lineFromLS & " | sed -n " & quoted form of sedArgOpt
			set regExpResult to do shell script (executeCmd)
			
			if regExpResult is in extList then
				if (firstTime is true) then
					set firstTime to false
					set item 1 of videoList to (_dirPath & lineFromLS)
				else
					set videoList to videoList & (_dirPath & lineFromLS)
				end if
			end if
		end try
		
	end repeat
	
	return videoList
	
end GetVideos
#
#
#
#
#
#
#
#
#
#
#
on ChooseMovieFile(_videoFiles)
	
	set sizeOfLargest to -1
	set chosenMovieFile to "picka ti se ogadila jebem ti mater"
	
	repeat with videoEntry in _videoFiles
		set videoEntryTemp to do shell script ("echo " & videoEntry)
		try
			if (videoEntry is not "") then
				
				#	Get information for the video file
				tell application "System Events"
					set timeScale to time scale of movie file videoEntryTemp --as alias
					set durationOfVideo to duration of movie file videoEntryTemp
					set durationScaled to durationOfVideo / timeScale / 60
					set sizeOfVideoFile to size of movie file videoEntryTemp
				end tell
				
				#	Get extension
				set extension to do shell script ("echo " & quoted form of videoEntryTemp & " | sed -n 's/\\(.*\\)\\(\\.[a-zA-Z0-9]\\{3,4\\}$\\)/\\2/p'")
				if (sizeOfVideoFile > sizeOfLargest) then
					set chosenMovieFile to {videoEntry, sizeOfVideoFile, durationScaled, extension}
					set sizeOfLargest to sizeOfVideoFile
				end if
			end if
		end try
	end repeat
	
	return chosenMovieFile
	
end ChooseMovieFile
#
#
#
#
#
#
#
#
#
#
#
on IsMovie(_movieFile)
	
	#	This is a tricky one.
	#	I do a basic length and size check and do a regular
	#	expression check for usual tv torrent names.
	#
	#	What is the cutoff for the length of a film? (minutes)
	set cutoffLength to 81
	#
	#	What is the cutoff size of a movie video file? (Bytes)
	set cutoffSize to 6.0E+8 -- 600 000 000 = 600 MB
	
	#	Regular expression for SxxExx format
	set sedArgOpt1 to "s/\\(.*\\)\\([sS][0-9]\\{1,2\\}[eE][0-9]\\{1,2\\}\\)\\(.*\\)/false/p"
	#	Regular expression for SSxEE format
	set sedArgOpt2 to "s/\\(.*\\)\\([0-9]\\{1,2\\}[xX][0-9]\\{1,2\\}\\)\\(.*\\)/false/p"
	
	set checkRE to "echo " & quoted form of item 1 of _movieFile & " | sed -n " & quoted form of sedArgOpt1
	set reCheck1 to do shell script (checkRE)
	set checkRE to "echo " & quoted form of item 1 of _movieFile & " | sed -n " & quoted form of sedArgOpt2
	set reCheck2 to do shell script (checkRE)
	
	#	Checking for regular expressions first.
	#	If filename is not tv-like, check cutoff length and size
	if (reCheck1 = "false") then
		set isAMovie to false
	else if (reCheck2 = "false") then
		set isAMovie to false
	else if (item 3 of _movieFile < cutoffLength) then
		set isAMovie to false
	else if (item 2 of _movieFile < cutoffSize) then
		set isAMovie to false
	else
		set isAMovie to true
	end if
	
	return isAMovie
	
end IsMovie
#
#
#
#
#
#
#
#
#
#
on MakeString(_dirName, _fileName)
	
	#	Check if strings are equal after stripping down.
	#	If not, choose the longer one to represent the query:
	set sedArgOpt to "s/\\(\\.[a-zA-Z0-9]\\{2,4\\}\\)\\{0,1\\}$//p"
	set executeCmd to "echo " & quoted form of _fileName & " | sed -n " & quoted form of sedArgOpt
	set _fileName to do shell script (executeCmd) -- Trims the extension
	
	set sedArgOpt to "s/\\(.*\\)\\/\\(.*\\)$/\\2/p"
	set executeCmd to "echo " & quoted form of _fileName & " | sed -n " & quoted form of sedArgOpt
	set _fileName to do shell script (executeCmd) -- Only filename
	
	set executeCmd to "echo " & quoted form of _dirName & " | sed -n " & quoted form of sedArgOpt
	set _dirName to do shell script (executeCmd) -- Only directory name
	
	if (_fileName = _dirName) then
		set unprocessedString to _fileName
	else if (length of _fileName > length of _dirName) then
		set unprocessedString to _fileName
	else
		set unprocessedString to _dirName
	end if
	
	#
	#	Processing the string into a query
	#
	set queryString to do shell script ("echo " & quoted form of unprocessedString & " | sed -n 's/[\\._]/ /gp'") -- Replace dots and underscores with space
	#	If there is junk, remove it:
	#	Set the shittiest regexp ever because OS X's sed is always case insensitive
	set shittyRE to "s/(([dD][vV][dD]|[hH][dD]|[bB][rR]|[bB][dD]|[wW][eE][bB])+([rR][iI][pP]|[cC][aA][mM]|[tT][sS])|[xX][vV][iI][dD]|[dD][iI][vV][xX]|[0-9][cC][dD]|720[pP]|1080[pP]|[cC][dD]\\.[0-9]|\\[|\\{|\\(|.[0-9]{4}).*//"
	set queryString to do shell script ("echo " & quoted form of queryString & " | sed -E " & quoted form of shittyRE)
	
	return queryString
	
end MakeString
#
#
#
#
#
#
#
#
#
#
on GetNewName(_queryString, _extension, _apiURL)
	
	#	Make query search compatible
	set _queryString to do shell script ("echo " & quoted form of _queryString & " | sed 's/ /+/g'")
	tell application "JSON Helper"
		
		#	Set API URLs:
		set searchURL to "http://api.themoviedb.org/3/search/movie?query="
		set fetchURL to "http://api.themoviedb.org/3/movie/"
		set appendURL to "?append_to_response=credits"
		
		#	Fetch search results
		set fetchResults to fetch JSON from (searchURL & _queryString & _apiURL)
		
		#	Extract data
		set movieTitle to original_title of item 1 of results of fetchResults as string
		set movieID to |id| of item 1 of results of fetchResults as string
		set releaseDate to release_date of item 1 of results of fetchResults as string
		set releaseYear to ((characters 4 thru 1 of releaseDate) as string)
		
		#	Get other information (director)
		set movieData to fetch JSON from (fetchURL & movieID & appendURL & _apiURL)
		set nrOfItems to count of items of crew of credits of movieData
		
		set iterations to 1
		
		repeat while iterations < nrOfItems + 1
			set tempString to job of item iterations of crew of credits of movieData as string
			if tempString is "Director" then
				set directorName to |name| of item iterations of crew of credits of movieData
				exit repeat
			end if
			set iterations to iterations + 1
		end repeat
		
	end tell
	
	return movieTitle & " - " & releaseYear & " - " & directorName & _extension
	
end GetNewName
