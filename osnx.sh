#!/bin/sh
set -e

# shellcheck source=commands/cat.sh
# shellcheck source=commands/conf.sh
# shellcheck source=commands/cp.sh
# shellcheck source=commands/ftp.sh
# shellcheck source=commands/help.sh
# shellcheck source=commands/ip.sh
# shellcheck source=commands/ls.sh
for command in "$(dirname "$(readlink "$0")")"/commands/*; do
  . "$command"
done

# shellcheck source=helpers.sh
. "$(dirname "$(readlink "$0")")/helpers.sh"

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

osnx "$@"
