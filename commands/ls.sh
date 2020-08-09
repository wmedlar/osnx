osnxls() {
    case "$1" in -h | --help)
        osnxhelp ls
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
        stderrf '%s: no such file or directory\n' "$arg"
    done

    return "$errors"
}