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

	# Retrieve the destination from the end of the arguments list. The space is
	# important in the expansion below to avoid invoking a default value.
	#    ${@:-1} expands to 1 if $@ is unset
	#   ${@: -1} expands to the last value in $@
	dest="${@: -1}"

	# A remote path is signaled by prefixing it with either "nx:" or "switch:",
	# similar to rsync's host prefixes.
	case "$dest" in
		nx:* | switch:*)
			osnxcplocal2remote "$dest" "${@:0:$#}"
			return 1 ;;

		*)
			osnxcpremote2local "$dest" "${@:0:$#}" ;;
	esac
}

osnxcplocal2remote() {
	stderrf '%s: Uploading to Nintendo Switch not yet supported.' "$0"
}

osnxcpremote2local() {
	if [ "$#" -gt 2 ]; then
		# If we have multiple sources then the destination *must* be a
		# directory.
		dest="$1/"
	else
		# Destination can either be a directory or a file. If it does not
		# already exist it will be created, either as a file or a directory
		# depending on the type of the source.
		dest="$1"
	fi

	case "$dest" in
		*/)
			# test expressions will work with directories that don't end in a
			# slash but will not work with files that do, so remove all
			# trailing slashes.
			desttest="$(trim trailing / "$1")"

			# It's okay if the path doesn't exist, we'll create it later, but
			# it's not okay if the path exists and is not a directory.
			if [ -e "$desttest" ] && [ ! -d "$desttest" ]; then
				stderrf '%s: Not a directory: %s\n' "$0" "$1"
				return 1
			fi ;;

		*)
			# Files should be copied into the directory if it already exists,
			# so we suffix it with a slash to signify.
			if [ -d "$dest" ]; then
				dest="$dest/"
			fi ;;
	esac

	# Count errors because we may have an arbitrary number successes depending
	# on how deep a potential source directory may go, with no way to know this
	# upfront.
	errors=0

	for arg in "${@:2}"; do
		# All sources must be prefixed with "nx:" or "switch:" for the time
		# being. This may change since local-to-local copying is eschewed
		# entirely to avoid potentially dangerous typos.
		case "$arg" in
			nx:* | switch:*)
				src="$(trim leading '.*:' "$arg")" ;;
			*)
				stderrf '%s: Not copying local directory: "%s"\n' "$0" "$arg"
				(( errors=errors+1 ))
				continue ;;
		esac

		filepath="$(trim trailing / "$src")"

		# Retrieve the first byte of a RETR on a file. Because we trim trailing
		# slashes this will fail when attempting to RETR a directory, making it
		# an effective method of determining if a path leads to a file.
		if osnxcurl "$filepath" -r 0-0 &>/dev/null ; then
			if ! osnxget "$filepath" "$dest" ; then
				stderrf '%s: Failed to retrieve file: "%s"\n' "$0" "$arg"
				(( errors=errors+1 ))
			fi
		elif curlexitfatal "$?" ; then
			stderrf '%s: Failed to retrieve file: "%s"\n' "$0" "$arg"
			(( errors=errors+1 ))
		fi
	done

	return "$errors"
}

osnxget() {
	case "$2" in
		*/)
			output="$2/$(basename $1)" ;;
		*)
			output="$2" ;;
	esac

	if osnxcurl "$1" --create-dirs -o "$output" ; then
		return 0
	elif curlexitfatal "$?" ; then
		stderrf '%s: Failed to retrieve file: "%s"\n' "$0" "$1"
		return 1
	fi
}
