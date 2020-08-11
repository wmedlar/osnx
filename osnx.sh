#!/bin/sh
set -e

# It's far more helpful to have available commands in the usage dialog, shown
# when an invalid command is given, than not to and require the user run
# another command just to see them.
cmdusage=$(printf "Usage:
  %s [command]

Available Commands:
  cat     Print a remote file from your Nintendo Switch
  conf    Read %s configuration
  cp      Copy files to and from your Nintendo Switch
  ftp     Open an FTP connection to your Nintendo Switch
  help    Get information on any command
  ip      Detect your Nintendo Switch's IP address
  ls      List a remote directory from your Nintendo Switch
" "$0" "$(basename "$0")" )

cmdhelp=$(printf "%s is a small set of commands for interacting with your Nintendo Switch over FTP.

%s
" "$(basename "$0")" "$cmdusage" )

osnx() {
    case "$1" in
        -h | --help | "")
            printf '%s\n' "$cmdhelp"
            return 0 ;;
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
            stderrf '%s: Unknown command: "%s"\n\n%s\n' "$0" "$1" "$cmdusage"
            return 127 ;;
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
    return "$?"
}

# shellcheck source=commands/cat.sh
# shellcheck source=commands/conf.sh
# shellcheck source=commands/cp.sh
# shellcheck source=commands/ftp.sh
# shellcheck source=commands/help.sh
# shellcheck source=commands/ip.sh
# shellcheck source=commands/ls.sh
for command in "$(dirname "$(readlink "$0")")"/commands/*.sh; do
  . "$command"
done

# shellcheck source=helpers.sh
. "$(dirname "$(readlink "$0")")/helpers.sh"

osnx "$@"
