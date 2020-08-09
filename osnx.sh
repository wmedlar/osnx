#!/bin/sh
set -e

osnx() {
    case "$1" in
        "" | -h | --help)
            osnxhelp ;;
        cat)
            osnxcat "${@:2}" ;;
        conf)
            osnxconf "${@:2}" ;;
        cp)
            osnxcp "${@:2}" ;;
        ftp)
            osnxftp "${@:2}" ;;
        help)
            osnxhelp "${@:2}" ;;
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
    program="$(basename "$0")"

    case "$1" in
        "")
            stderrf "%s is a small set of commands for interacting with your Nintendo Switch over FTP.

Usage:
  %s [command]

Available Commands:
  cat     Print a remote file from your Nintendo Switch
  conf    Read %s configuration
  cp      Copy files to and from your Nintendo Switch
  ftp     Open an FTP connection to your Nintendo Switch
  help    Get information on any command
  ip      Detect your Nintendo Switch's IP address
  ls      List a remote directory from your Nintendo Switch
" "$program" "$0" "$program" ;;

        cat)
            stderrf "Print a remote file from your Nintendo Switch to stdout.

Usage:
  %s %s [file] [file]...

Description:
  Read files from your Nintendo Switch over FTP and concatenate them to stdout.
  If file is a directory or does not exist an error will be printed to stderr
  and the program will continue reading from the file list.

  If an error occurs during execution, like the one described above, %s will
  exit with an error code equal to the number of errors that occurred.

  This command makes use of curl's FTP support to retrieve the files

See Also:
  curl(1)
" "$0" "$1" "$program" ;;

       conf)
            stderrf "Read %s configuration.

Usage:
  %s %s get [field]

Description:
  Read a field from the config file at ~/.osnx.yaml. If a field is not set,
  a default value will be used if one is configured. Not every field has a
  default; those that don't will simply print nothing and exit cleanly.

  This command requires yq (https://github.com/mikefarah/yq) to be installed.
  Install with 'brew install yq' or download from the GitHub Releases page.

Available Fields:
  ftp
     .flags    Array of flags passed to the ftp binary in '%s ftp'.
     .port     Port used to connect to your Nintendo Switch's FTP server.

  mac          The MAC address of your Nintendo Switch, used to determine its
               network IP. Most commands will not work if this field is unset.

  Additionally if no argument is passed the entire config file will be printed.

  See Also:
    https://github.com/mikefarah/yq
" "$program" "$0" "$1" "$program" ;;

        cp)
            stderrf "Copy files to and from your Nintendo Switch over FTP.

Usage:
  %s %s [source] [source]... [destination]

Description:
  Copy files and directories from your computer running %s to your Nintendo
  Switch, and from your Nintendo Switch to your computer over FTP. All uploads
  and downloads are recursive so copies involving directories will fully
  traverse the directory tree.

  Semantics are similar to cp in that copying a directory with a trailing slash
  will copy the directory contents and not the directory itself. See below for
  an example of this.

Examples:
  upload cheats for versions 4.1.0 and 4.1.1 of Animal Crossing New Horizons to
  your Nintendo Switch running atmosphere:

    %s %s ac5309b683630ced.txt 7515e5f76d09f8a3.txt \\
        switch:/atmosphere/contents/[...]/cheats/

  upload a directory of Tesla overlays to your Nintendo Switch:

    %s %s .overlays switch:/switch/

  backup your JKSV saves, dropping the 'JKSV/save/' prefix:

    %s %s switch:/JKSV/saves/ ~/switch/saves

  download every screenshot and video capture saved on your Nintendo Switch and
  store them, with a flattened directory structure, in '~/Pictures/switch':

    %s %s switch:/Nintendo/Album/2020/[01-12]/[00-31]/ ~/Pictures/switch

See Also:
  curl(1), ftp(1)
" "$0" "$1" \
  "$program" \
  "$0" "$1" \
  "$0" "$1" \
  "$0" "$1" ;;

        ftp)
            stderrf "Open an FTP connection to your Nintendo Switch.

Usage:
  %s %s [ip] [port] [ <<< command ]

Description:
  Connect to an FTP server, optionally specifying its IP address and port. If
  either parameter is unset at the command line, %s will attempt to discover
  its value automatically either through '%s ip' or '%s conf get ftp.port',
  respectively.

  You may also pass an FTP command through stdin to run, print its result, and
  exit. Available commands depend on your ftp client.

See Also:
  ftp(1), https://github.com/cathery/sys-ftpd-light
" "$0" "$1" "$program" "$program" "$program" ;;

        help)
            stderrf "Get information on any %s command.
Usage:
  %s %s [command]

Available Commands:
  cat     Read a remote file from your Nintendo Switch
  conf    Read osNX configuration and default settings
  cp      Copy files to and from your Nintendo Switch
  ftp     Open an FTP connection to your Nintendo Switch
  help    Print this message
  ip      Detect your Nintendo Switch's IP address
  ls      List a remote directory from your Nintendo Switch
" "$(basename "$0")" "$0" "$1" ;;

        ip)
            stderrf "Detect your Nintendo Switch's IP address.

Usage:
  %s %s [mac]

Description:
  Determine your Nintendo Switch's IP by searching the ARP routing tables for
  the given MAC address, which can either be read from the config file or
  passed as the only argument.

  If no ARP entry is found for the given MAC this command will perform a ping
  scan of the entire network, similar to the nmap utility, to repopulate the
  ARP cache. This behavior is reimplimented in MacOS utilities to avoid
  requiring nmap to be installed as a dependency.

  This command is largely used internally and is exposed to the user for
  interaction with external programs. In general other commands of %s
  depend heavily upon this one and require the MAC address to be present in
  your config file.

See Also:
  arp(8), ipconfig(8), netstat(1), nmap(1), ping(8)
" "$0" "$1" "$program" ;;

        ls)
            stderrf "List a remote directory from your Nintendo Switch.

Usage:
  %s %s [directory] [directory]...

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
" "$0" "$1" ;;

        *)
            stderrf 'command not recognized: "%s"\n\n' "$1"
            osnxhelp
            return 127 ;;
    esac
}

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
        -h | --help)
            osnxhelp conf
            return 0 ;;
        "")
            osnxhelp conf
            return 126 ;;
        get) ;; # so we can handle unrecognized commands without printing the yq warning
        *)
            stderrf 'command not recognized: "%s"\n\n' "$1"
            osnxhelp conf
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
    case "$1" in -h | --help)
        osnxhelp ftp
        return 0 ;;
    esac

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
    case "$1" in -h | --help)
        osnxhelp ip
        return 0 ;;
    esac

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

# shellcheck source=helpers.sh
. "$(dirname "$(readlink "$0")")/helpers.sh"
osnx "$@"
