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