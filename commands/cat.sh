#!/bin/sh
# cat.sh: osnx command: Print a remote file from your Nintendo Switch to stdout.
set -e

osnxcatusage=$(printf "Usage:
  %s cat [file] [file]...
" "$0" )

osnxcathelp=$(printf "Print a remote file from your Nintendo Switch to stdout.

%s

Description:
  Read files from your Nintendo Switch over FTP and concatenate them to stdout.
  If file is a directory or does not exist an error will be printed to stderr
  and the program will continue reading from the file list.

  If an error occurs during execution, like the one described above, %s will
  exit with an error code equal to the number of errors that occurred.

  This command makes use of curl's FTP support to retrieve the files.

See Also:
  curl(1)
" "$osnxcatusage" )

osnxcat() {
    case "$1" in
        -h | --help)
            printf "%s\n" "$osnxcathelp"
            return 0 ;;
        "")
            stderrf "%s: Reading from stdin is not supported.\n\n%s\n" "$0" "$osnxcatusage"
            return 126 ;;
    esac

    errors=0

    for arg in "$@"; do
        # $arg may be a directory, so to mimic cat behavior we will need to
        # perform a few checks in order to give the user an accurate error.

        # First we take the happy path, where $arg is the path to an existing
        # file. Stripping off trailing slashes will prevent curl from treating
        # the path as a directory and attempting to list (NLST) it. Without the
        # slash curl will simply try to read (RETR) the file.
        path="$(trim trailing / "$arg")"

        if osnxcurl "$path"; then
            # $path is a file and it was read without issue, so we will
            # continue processing the argument list. This is a minor divergence
            # from cat behavior, where cat will refuse to read the file and
            # exit nonzero with "Not a directory". Mimicking that behavior
            # would require additional FTP overhead that isn't worth the cost.
            continue
        fi

        ((errors=errors+1))

        # Since we know that $path does not lead to a file, it must either be a
        # directory or nonexistent. To determine if the path is a directory we
        # attempt to list its contents with curl's --list-only flag. We add a
        # trailing slash to the path to ensure we list the directory's contents
        # and not the contents of the directory's ours is contained within.
        if osnxcurl "$path/" --list-only >/dev/null; then
            stderrf '%s: Is a directory\n' "$arg"
            continue
        fi

        # If the path cannot be read or listed then it must not exist.
        stderrf '%s: No such file or directory\n' "$arg"
    done

    return "$errors"
}