osnxcat() {
    case "$1" in
        -h | --help)
            osnxhelp cat
            return 0 ;;
        "")
            # unlike the actual cat we don't read from stdin
            osnxhelp cat
            return 126 ;;
    esac

    errors=0

    for arg in "$@"; do
        # remove trailing slashes, these should be files we're working with
        path="$(trim trailing / "$arg")"

        # since we removed trailing slashes, curl will treat our path as a file
        # the "read" command, RETR, only works on files so directories will fail
        if osnxcurl "$path"; then
            continue
        fi

        # error count is the number of non-file paths we encounter
        ((errors=errors+1))

        # adding the trailing slash back in causes curl to treat our path as a directory
        # curl will attempt to NLST which will only succeed if the path is a directory
        if osnxcurl "$path/" --list-only >/dev/null; then
            stderrf '%s: is a directory\n' "$arg"
            continue
        fi

        # if the path can't be read or listed it must not exist
        stderrf '%s: no such file or directory\n' "$arg"
    done

    return "$errors"
}