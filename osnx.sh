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
    mac="$(echo "$mac" | tr -- '-[:upper:]' ':[:lower:]' | sed -E 's/0([a-f0-9])/\1/g')"

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
binexists() {
    command -v "$1" >/dev/null
}

ipfrommac() {
    # we don't want a missing match to stop execution of the entire script
    # leave that logic to the main functions since this will likely be retried
    netstat -rnlf inet | awk "/$1/"'{ print $1; exit 0 }'
}

# performs a ping scan of devices on the network to populate the arp cache
# is it slower than the real nmap? yes, by a lot (~1.5s vs nmap's ~0.1s)
# but it's still fast enough and it prevents adding one more dependency
nmap() {
    # we can calculate the first and last address of the network with our computer's ip and network's mask
    IFS=. read -r ip1 ip2 ip3 ip4 <<< "$(ipconfig getifaddr en0)"
    IFS=. read -r nm1 nm2 nm3 nm4 <<< "$(ipconfig getoption en0 subnet_mask)"

    # first address can be calculated by and-ing each ip and netmask octet
    read -r f1 f2 f3 f4 <<< "$((ip1 & nm1)) $((ip2 & nm2)) $((ip3 & nm3)) $((ip4 & nm4))"

    # last address can be calculated by or-ing each octect from
    # the first ip with each complemented octect from the netmask
    read -r l1 l2 <<< "$((f1 | 255-nm1)) $((f2 | 255-nm2))"
    read -r l3 l4 <<< "$((f3 | 255-nm3)) $((f4 | 255-nm4))"

    # finally we can concoct every single ip on the network with ranges
    addresses="$(eval echo {$f1..$l1}.{$f2..$l2}.{$f3..$l3}.{$f4..$l4})"

    local jobs

    # and then ping every single address to fill out the arp cache!
    for address in $addresses; do
        # explanation of options, most set for speeeeeed:
        #   -n don't attempt to look up names for the output we're ignoring
        #   -q less verbose output (that we're still ignoring)
        #   -t 1  exit after one second regardless of the response
        #   -c 1  send a single packet
        #   -s 0  that includes no data bytes
        #   -W 1  and is ignored if not replied to in one second
        ( ping -nq -c 1 -s 0 -t 1 -W 1 "$address" || true) &>/dev/null &
        jobs="$jobs $!"
    done

    wait $jobs
}

stderr()  {
    echo "$@" >&2
}

stderrf() {
    printf "$1" "${@:2}" >&2
}

osnx "$@"