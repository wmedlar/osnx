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
            osnxhelp cp
            return 0 ;;
        "")
            osnxhelp cp
            return 126 ;;
        *)
            # we can't do anything with just one file
            if [ -z "$2" ]; then
                osnxhelp cp
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