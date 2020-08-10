#!/bin/sh
set -e

osnxipusage=$(printf "Usage:
  %s ip [mac]
" "$0" )

osnxiphelp=$(printf "Detect your Nintendo Switch's IP address.

%s

Description:
  Determine your Nintendo Switch's IP by searching the ARP routing tables for
  the given MAC address, which can either be read from the config file or
  passed as the only argument.

  If no ARP entry is found for the given MAC this command will perform a ping
  scan of the entire network, similar to the nmap utility, to repopulate the
  ARP cache. This behavior is reimplimented in MacOS utilities to avoid
  requiring nmap as a dependency.

  This command is largely used internally and is exposed to the user for
  interaction with external programs. In general other commands of %s
  depend heavily upon this one and require the MAC address to be present in
  your config file.

See Also:
  arp(8), ipconfig(8), netstat(1), nmap(1), ping(8)
" "$osnxipusage" "$(basename "$0")" )

osnxip() {
    case "$1" in -h | --help)
        printf '%s\n' "$osnxiphelp"
        return 0 ;;
    esac

    if [ "$#" -gt 1 ]; then
        stderrf '%s: Too many arguments.\n\n%s\n' "$0" "$osnxipusage"
        return 126
    fi

    mac="$1"

    if [ -z "$mac" ]; then
        mac="$(osnx conf get mac)"
    fi

    if [ -z "$mac" ]; then
        stderr 'please set your mac address'
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