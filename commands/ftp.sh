#!/bin/sh
set -e

osnxftpusage=$(printf "Usage:
  %s ftp [ip] [port] [ <<< command ]
" "$0" )

osnxftphelp=$(printf "Open an FTP connection to your Nintendo Switch.

%s

Description:
  Connect to an FTP server, optionally specifying its IP address and port. If
  either parameter is unset at the command line, %s will attempt to discover
  its value automatically either through '%s ip' or '%s conf get ftp.port',
  respectively.

  You may also pass an FTP command through stdin to run, print its result, and
  exit. Available commands depend on your ftp client.

See Also:
  ftp(1), https://github.com/cathery/sys-ftpd-light
" "$osnxftpusage" "$(basename "$0")" "$(basename "$0")" "$(basename "$0")" )

osnxftp() {
    case "$1" in -h | --help)
        printf '%s\n' "$osnxftphelp"
        return 0 ;;
    esac

    if [ "$#" -gt 2 ]; then
        stderrf '%s: Too many arguments.\n\n%s\n' "$0" "$osnxftpusage"
        return 126
    fi

    ip="$1"
    port="$2"

    if [ -z "$ip" ]; then
        ip="$(osnx ip)"
    fi

    if [ -z "$port" ]; then
        port="$(osnx conf get ftp.port)"
    fi

    eval set -- "$(osnx conf get ftp.flags | tr '\n' ' ')"
    ftp "$@" -- "$ip" "$port"
}
