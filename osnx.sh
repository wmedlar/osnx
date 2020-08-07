#!/bin/sh
set -e

osnx() {
    case "$1" in
        "" | -h | --help | help)
            osnxhelp ;;
        cat)
            osnxcat "${@:2}" ;;
        conf)
            osnxconf "${@:2}" ;;
        cp)
            osnxcp "${@:2}" ;;
        ftp)
            osnxftp "${@:2}" ;;
        ip)
            osnxip "${@:2}" ;;
        ls)
            osnxls "${@:2}" ;;
        *)
            stderrf 'command not recognized: "%s"\n\n' "$1"
            osnxhelp
            return 127 ;;
    esac
}

osnxhelp() {
    stderrf "Usage:\n  $0 [command]\n\n"
    stderr  "Available Commands:"
    stderr  "  cat     Read a remote file from your Nintendo Switch"
    stderr  "  conf    Read and modify osNX configuration"
    stderr  "  cp      Copy files to and from your Nintendo Switch"
    stderr  "  ftp     Open an FTP connection to your Nintendo Switch"
    stderr  "  ip      Detect your Nintendo Switch's IP address"
    stderr  "  ls      List a remote directory from your Nintendo Switch"
}

osnxcat() {
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

osnxcp() {
    # intended behavior:
    # note: a directory here means the argument has a trailing slash, a file does not
    # 1. if the source is a directory and the destination is a directory, copy the contents of src to dest
    # 2. if the source is a directory and the destination is a file, create dest as a directory and perform #1
    # 3. if the source is a directory and the destination is an existing file, fail "%s: not a directory"
    # 4. if the source is a file and the destination is a directory, copy src into dest with the same basename
    # 5. if the source is a file and the destination is a file, copy src to dest
    # 5. if the source is a file adn the destination is an existing file, overwrite

    case "$#" in
        0)
            # print usage
            ;;
        1)
            # print usage
            return 126 ;;
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

osnxcurl() {
    ip="$(osnx ip)"
    port="$(osnx conf get ftp.port)"
    user="$(osnx conf get ftp.user)"
    pass="$(osnx conf get ftp.pass)"

    curl                 \
        --disable-epsv    \
        --silent           \
        --connect-timeout 3 \
        --ftp-method nocwd   \
        --user "$user:$pass"  \
        "${@:2}" -- "ftp://$ip:$port/$1"

    # TODO add error handling for connection timeout
}

osnxconf() {
    case "$1" in
        "" | --help)
            osnxconfhelp
            return 0 ;;
        get) ;; # so we can handle unrecognized commands without printing the yq warning
        *)
            stderrf 'command not recognized: "%s"\n\n' "$1"
            osnxconfhelp
            return 127 ;;
    esac

    if ! binexists yq ; then
        stderr 'cannot read configuration file without yq'
        stderr 'please install with "brew install yq"'
        stderr 'configuration interaction without yq will be best-effort'
    fi

    case "$1" in
        get)
            osnxconfget "${@:2}" ;;
    esac
}

osnxconfhelp() {
    stderrf "Usage:\n  $0 conf [subcommand]\n\n"
    stderr  "Available Subcommands:"
    stderr  "  get    Read a value from osNX configuration"
}

osnxconfget() {
    local default
    local path="$1"

    case "$path" in
        ftp.flags)
            default='-n --prompt="nx >"'
            path='ftp.flags[*]' ;;
        ftp.port)
            # default to standard sys-ftpd-light port
            default=5000 ;;
    esac

    # best-effort attempt with yq simply prints out default value
    if ! binexists yq ; then
        if [ "${default?x}" ]; then # checks if $default is set, exiting 127 if not
            stderr 'yq not found, using configured default'
            echo "$default"
            return 0
        fi

        stderr 'yq not found, cannot read configuration'
        return 126
    fi

    # yq won't print out newlines for defaults, which can be pretty unreadable
    # so to provide a consistent experience we simply add one ourselves by echoing
    value="$(yq read -D "$default" -- ~/.osnx.yaml "$path")"
    echo "$value"
}

osnxftp() {
    local flags
    local ip
    local port

    case "$#" in
        1)
            ip="$1" ;;
        2)
            ip="$1"
            port="$2" ;;
    esac

    flags="$(osnx conf get ftp.flags | tr '\n' ' ')"
    eval set -- "$flags"

    if [ -z "$ip" ]; then
        ip="$(osnx ip)"
    fi

    if [ -z "$port" ]; then
        port="$(osnx conf get ftp.port)"
    fi

    ftp "$@" -- "$ip" "$port"
}

osnxip() {
    local mac="$1"

    if [ -z "$mac" ]; then
        mac="$(osnx conf get mac)"
    fi

    if [ -z "$mac" ]; then
        stderr 'please set your mac address with "osnx conf set mac <yo:ur:ma:c:ad:dr:es:s>"'
        return 1
    fi


    # switch settings list the mac in AB-0X-[...] format, convert this to ab:x:[...]
    mac="$(tr -- '-[:upper:]' ':[:lower:]' <<< "$mac" | sed -E 's/0([a-f0-9])/\1/g')"

    # minimum mac size, with leading zeroes stripped out, would be 11 (e.g., 1:2:3:4:5:6)
    # maximum mac size, with doublets and leading zeroes, would be 17 (e.g., a1:b2:c3:d4:e5:f6)
    # anything outside of this range is either mistyped or the sign of a bug in "osnx conf get"
    if [ "${#mac}" -lt 11 ] || [ "${#mac}" -gt 17 ]; then
        stderrf 'mac address %s does not appear to be a valid mac address\n' "$mac"
        stderr  'please confirm your mac address is set correctly by checking'
        stderr  'System Settings > Internet > Connection Status > System MAC Address'
    fi

    ip="$(ipfrommac "$mac")"

    # switch will not always be present in arp cache
    # so we'll run a ping scan to see if we can find it
    if [ -z "$ip" ]; then
        stderr "running ping scan to populate arp cache"
        nmap # not the real nmap!
        # and see if we can find it again
        ip="$(ipfrommac "$mac")"
    fi

    if [ -z "$ip" ]; then
        stderrf "no ip found for mac address %s\n\n" "$1"
        stderr  "please confirm your system is online"
        return 1
    fi

    echo "$ip"

    # TODO save ip in config for duration of osnx invocation to save cpu cycles
}

osnxls() {
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

# shellcheck source=helpers.sh
. "$(dirname "$(readlink "$0")")/helpers.sh"
osnx "$@"
