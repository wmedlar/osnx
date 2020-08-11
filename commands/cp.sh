#!/bin/sh
set -e

osnxcpusage=$(printf "Usage:
  %s cp [source] [source]... [destination]
" "$0")

osnxcphelp=$(printf "Copy files to and from your Nintendo Switch over FTP.

%s

Description:
  Copy files and directories from your computer running %s to your Nintendo
  Switch, and from your Nintendo Switch to your computer over FTP. All uploads
  and downloads are recursive so copies involving directories will fully
  traverse the directory tree.

  Semantics are similar to cp in that copying a directory with a trailing slash
  will copy the directory contents and not the directory itself. See below for
  an example of this.

Examples:
  upload cheats for version 4.1.1 of Animal Crossing New Horizons to your
  Nintendo Switch running atmosphere:

    %s cp ac5309b683630ced.txt 7515e5f76d09f8a3.txt \\
        switch:/atmosphere/contents/01006F8002326000/cheats/

  upload a directory of Tesla overlays to your Nintendo Switch:

    %s cp .overlays switch:/switch/

  backup your JKSV saves, dropping the 'JKSV/save/' prefix:

    %s cp switch:/JKSV/saves/ ~/switch/saves

  download every screenshot and video capture saved on your Nintendo Switch and
  store them with a flattened directory structure:

    %s cp switch:/Nintendo/Album/2020/[01-12]/[00-31]/ ~/Pictures/switch

See Also:
  curl(1), ftp(1)
" "$osnxcpusage" "$(basename "$0")" "$0" "$0" "$0" "$0" )

osnxcp() {
	# intended behavior:
	# note: a directory here means the argument has a trailing slash, a file does not
	# 1. if the source is a directory and the destination is a directory, copy the contents of src to dest
	# 2. if the source is a directory and the destination is a file, create dest as a directory and perform #1
	# 3. if the source is a directory and the destination is an existing file, fail "%s: not a directory"
	# 4. if the source is a file and the destination is a directory, copy src into dest with the same basename
	# 5. if the source is a file and the destination is a file, copy src to dest
	# 5. if the source is a file adn the destination is an existing file, overwrite

	case "$1" in
		-h | --help)
			printf '%s\n' "$osnxcphelp"
			return 0 ;;
		*)
			if [ "$#" -lt 2 ]; then
				stderrf '%s: Not enough arguments.\n\n%s\n' "$0" "$osnxcpusage"
				return 126
			fi ;;
	esac

	local dest="${*: -1}" # the space is necessary so it's not interpreted as a default
	set -- "${@:0:$#}"    # expands to all args except the last

	# if we have multiple sources then the destination is a directory
	if [ "$#" -gt 1 ]; then
		dest="$dest/"
	fi

	case "$dest" in
		# remote destination
		nx:* | switch:*)
			stderr 'uploading a remote file is not yet supported' ;;

		# local destination
		*)
			# if the destination exists and is a directory, treat it as such
			if [ -d "$dest" ]; then
				dest="$dest/"
			fi

			# error if the destination is a file while we expect it to be a directory
			# -f only detects a file if it doesn't have a trailing slash so trim any off
			if [ -f "$(trim trailing / "$dest")" ]; then
				# we diverge from cp behavior here by only printing the following once
				# cp will print it for every single file which isn't helpful to a user here
				stderrf '%s: not a directory\n' "$dest"
				return 1
			fi

			# determine the ftp server's working directory
			# we can use this to generate and pass relative urls to curl --output
			# then we can have curl create the directory structure when recursively downloading
			# 257 is the successful return code for a pwd command, prefixing the result line
			ftpwd="$(osnx ftp <<< 'pwd' | awk -F '"' '/257/{print $2}')"
			if [ -z "$ftpwd" ]; then
				stderr 'cannot determine ftp working directory, assuming root'
				ftpwd=/
			fi

			for src in "$@"; do
				# trim off remote prefix, e.g., switch:/hbmenu.nro -> /hbmenu.nro
				src="$(trim leading '.*:' "$src")"

				local output
				case "$dest" in
					*/)
						output="$dest/$(basename "$src")" ;;
					*)
						output="$dest" ;;
				esac

				if ! osnxcurl "$src" --create-dirs --output "$output" --remote-time ; then
					stderrf '%s: no such file or directory\n' "$src"
				fi
			done ;;
	esac
}
