#!/bin/sh
set -e

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
    addresses="$(eval echo {"$f1".."$l1"}.{"$f2".."$l2"}.{"$f3".."$l3"}.{"$f4".."$l4"})"

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

    # shellcheck disable=SC2086
    wait $jobs
}

# trim [leading | trailing | both] [text] [from-string] [sed-separator=|]
# removes any number of appearances of text from the corresponding side of from-string
# text can also be a regex pattern
# e.g., trim leading '.*:' switch:/switch/.overlays -> /switch/.overlays
#       trim trailing . 'texting like my grandpa ...' -> 'texting like my grandpa '
# the sed separator is also adjustable if your text contains the default of |
trim() {
    # default of | should be less commonly used in text than other keyboard characters
    if [ -z "$4" ]; then
        set -- "$1" "$2" "$3" '|'
    fi

    # triggers if $2 contains $4, opposite of how it reads
    case "$2" in *"$4"*)
        stderr 'text to trim contains sed separator, please specify a different separator'
        return 1
    esac

    # sed template pattern to pass to printf, keeps the sed code a little cleaner
    template="s$4%s$4$4"

    case "$1" in
        leading)
            sed "$(printf "$template" "^\($2\)*")" <<< "$3"
            ;;
        trailing)
            sed "$(printf "$template" "\($2\)*$")" <<< "$3"
            ;;
        both)
            trim leading "$2" "$(trim trailing "$2" "$3" "$4")" "$4"
            ;;
        *)
            stderrf '%s: unrecognized modifier, choose from: "leading", "trailing", "both"\n' "$1"
            return 1
    esac
}

stderr()  {
    echo "$@" >&2
}

stderrf() {
    # shellcheck disable=SC2059
    printf "$1" "${@:2}" >&2
}
