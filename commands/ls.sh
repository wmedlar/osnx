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

    errors=0

    if [ "$#" -eq 0 ]; then
        # like ls we will simply list the current directory
        set -- .
    fi

    for arg in "$@"; do
        # remove trailing slashes so we can treat these as files if we need to
        path="$(trim trailing / "$arg")"

        if osnxcurl "$path/" --list-only ; then
            continue
        fi

        # error count is the number of non-directory paths we encounter
        ((errors=errors+1))

        # removing the trailing slash causes curl to treat our path as a file
        # curl will attempt to RETR which will only succeed if our path is a file
        # we only retrieve the first byte to avoid downloading any more than necessary
        if osnxcurl "$path" -r 0-0 >/dev/null; then
            # simply print out the original argument like ls
            echo "$arg"
            continue
        fi

        # if the path can't be listed or read it must not exist
        stderrf '%s: No such file or directory\n' "$arg"
    done

    return "$errors"
}
