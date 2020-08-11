#!/bin/sh
set -e

osnxlsusage=$(printf "Usage:
  %s ls [directory] [directory]...
" "$0" )

osnxlshelp=$(printf "List a remote directory from your Nintendo Switch.

%s

Description:
  List directories from your Nintendo Switch over FTP, printing out their
  contents to stdout. Any number of directories can be passed as arguments and
  all will be listed. If no arguments are passed, the working directory of the
  FTP server (usually /) will be listed.

  Listing is performed with curl's --list-only flag, which issues an NLST
  command to the FTP server. Unlike the true ls, this command will list
  absolute paths of directory contents rather than paths relative to the
  directory being listed. This behavior may change in the future to more
  closely mimic ls.

See Also:
  curl(1), ftp(1), ls(1)
" "$osnxlsusage" )

osnxls() {
	case "$1" in -h | --help)
		printf '%s\n' "$osnxlshelp"
		return 0 ;;
	esac

	# Why do we count successes instead of failures? Successes are easier to
	# track down, only need to be incremented in a single code path, and can
	# be used to determine the number of failures.
	successes=0

	if [ "$#" -eq 0 ]; then
		# Like ls we will simply list the current directory. We use an empty
		# string here for clarity when printing to the user, since they didn't
		# pass in an argument, while we use a '.' internally for accuracy since
		# we append a trailing slash to the path.
		set -- ""
	fi

	for arg in "$@"; do
		# remove trailing slashes so we can treat these as files if we need to
		path="$(trim trailing / "$arg")"

		# This function call will list both the contents of a directory, and
		# individual files, the same behavior as ls, eliminating the need for
		# additional code paths. This is a combination of the behavior of
		# curl's --ftp-method=nocwd and --list-only flags, and including the
		# trailing slash in the path.
		#
		# The --ftp-method=nocwd flag in osnxcurl prevents curl from changing
		# the working directory to the final element of the directory tree
		# before performing operations on the given path. Since we append a
		# trailing slash to our path this will always be our directory name or,
		# potentially, filename. Attempting to change directory to a file would
		# cause a "(9) Server denied you to change to the given directory"
		# error. --ftp-method=nocwd avoids this issue entirely by simply
		# performing all operations within the FTP server's default working
		# directory, with no directory changes.
		if osnxcurl "${path:-.}/" --list-only ; then
			(( successes=successes+1 ))

		elif curlexitfatal "$?" ; then
			stderrf '%s: Failed to list path: "%s"\n' "$0" "$arg"

		else
			# If we can't list the path, and curl didn't fail to connect, then
			# the path must not exist.
			stderrf '%s: No such file or directory: "%s"\n' "$0" "$arg"
		fi
	done

	return "$(( $#-$successes ))"
}
