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