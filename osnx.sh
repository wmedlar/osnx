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
    stderr  "  ftp     Open an FTP connection to your Nintendo Switch"
    stderr  "  ip      Detect your Nintendo Switch's IP address"
    stderr  "  ls      List a remote directory from your Nintendo Switch"
}

osnxcat() {
    port="$(osnx conf get ftp.port)"
    ip="$(osnx ip)"

    for file in "$@"; do
        if [ -n "$file" ]; then
            curl --connect-timeout 3 "ftp://$ip:$port/$file"
        fi
    done
}

osnxconf() {
    case "$1" in
        "" | --help)
            osnxconfhelp
            return 0 ;;
    esac

    # TODO: check yq

    case "$1" in
        get)
            osnxconfget "${@:2}" ;;
        loc | location)
            ;;
        set)
            ;;
        *)
            stderrf 'command not recognized: "%s"\n\n' "$1"
            osnxconfhelp
            return 127 ;;
    esac
}

osnxconfhelp() {
    stderrf "Usage:\n  $0 conf [subcommand]\n\n"
    stderr  "Available Subcommands:"
    stderr  "  get    Read a value from osNX configuration"
}

osnxconfget() {
    local default

    case "$1" in
        ftp.port)
            # default to standard sys-ftpd-light port
            default=5000 ;;
    esac

    # check if yq is installed
    if ! command -v yq >/dev/null; then
        stderrf 'cannot read configuration file without yq'

        # if it isn't, but we have a default, print a warning to stderr and use the default
        if [ "${default?x}" ]; then # checks if $default is set, exiting 127 if not
            stderr  ', using default'
            echo "$default"
            return 0
        fi

        # if it isn't and we don't have a default, print and error and exit
        stderr ', please install with "brew install yq"'
        return 127
    fi

    # yq won't print out newlines for defaults, which can be pretty unreadable
    # so to provide a consistent experience we simply add one ourselves by echoing
    value="$(yq read -D "$default" -- ~/.osnx.yaml "$1")"
    echo "$value"
}

osnxftp() {
    local ip
    local port

    case "$#" in
        1)
            ip="$1" ;;
        2)
            ip="$1"
            port="$2" ;;
    esac

    if [ -z "$ip" ]; then
        ip="$(osnx ip)"
    fi

    if [ -z "$port" ]; then
        port="$(osnx conf get ftp.port)"
    fi

    user="$(osnx conf get ftp.user)"
    pass="$(osnx conf get ftp.pass)"

    if [ -n "$user" ] || [ -n "$pass" ]; then
        echo
    fi

    ftp -n -v --prompt='nx> ' "$ip" "$port"
}

osnxip() {
    if [ -z "$1" ]; then
        set -- "$(osnx conf get mac)"
    fi

    if [ -z "$1" ]; then
        stderr 'please set your mac address with "osnx conf set mac <yo:ur:ma:c:ad:dr:es:s>"'
        return 1
    fi

    # switch settings list the mac in XX-XX-[...] format, convert this to xx:xx:[...]
    mac="$(echo "$1" | tr '-' ':' | tr '[:upper:]' '[:lower:]')"
    ip="$(ipfrommac "$mac")"

    # switch will not always be present in arp cache
    # so we'll run a ping scan to see if we can find it
    if [ -z "$ip" ] && command -v nmap >/dev/null; then
        stderr "running ping scan to populate arp cache"
        nmap -sn -Pn 192.168.1.0/24 >/dev/null          # TODO: determine actual network
        # and see if we can find it again
        ip="$(ipfrommac "$mac")"
    fi

    if [ -z "$ip" ]; then
        stderrf "no ip found for mac address %s\n\n" "$1"
        stderr  "confirm your system is online and your mac address is set correctly by checking"
        stderr  "System Settings > Internet > Connection Status > System MAC Address"
        return 1
    fi

    echo "$ip"
}

ipfrommac() {
    netstat -rnlf inet      | # print ipv4 routing tables
    sed -e '1,/default/d'   | # pull out everything after the "default" desination (the first result)
    awk "/$1/"'{print $1}'  # retrive the corresponding ip to our mac address from the first column
}

osnxls() {
    case "$#" in
        0 | 1)
            osnxcat "$1/" ;;
        *)
            # recursively iterate through multiple directories
            # printing each directory name before listing
            osnxlsmultiple "$@" ;;
    esac
}

osnxlsmultiple() {
    errors=0

    for dir in "$@"; do
        stderrf "\n$dir:\n"

        if ! osnxls "$dir"; then
            ((errors=errors+1))
        fi
    done

    return "$errors"
}

# helpers
stderr()  {
    echo "$@" >&2
}

stderrf() {
    printf "$1" "${@:2}" >&2
}

osnx "$@"