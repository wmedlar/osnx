#!/bin/sh
set -e

osnxhelpusage=$(printf "Usage:
  %s help [command]

Available Commands:
  cat     Read a remote file from your Nintendo Switch
  conf    Read %s configuration and default settings
  cp      Copy files to and from your Nintendo Switch
  ftp     Open an FTP connection to your Nintendo Switch
  help    Print this message
  ip      Detect your Nintendo Switch's IP address
  ls      List a remote directory from your Nintendo Switch
" "$0" "$(basename "$0")" )

osnxhelphelp=$(printf "Get information on any %s command.

%s
" "$(basename "$0")" "$osnxhelpusage" )

osnxhelp() {
    case "$1" in
        -h | --help | "")
            printf '%s\n' "$osnxhelphelp"
            return 0 ;;

        cat)
            osnxcat --help ;;

        conf)
            osnxconf --help ;;

        cp)
            osnxcp --help ;;

        ftp)
            osnxftp --help ;;

        help)
            osnxhelp --help ;;

        ip)
            osnxip --help ;;

        ls)
            osnxls --help ;;

        *)
            stderrf '%s: Unknown command: "%s"\n\n%s\n' "$0" "$1" "$osnxhelpusage"
            return 127 ;;
    esac
}
