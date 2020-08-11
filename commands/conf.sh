#!/bin/sh
# conf.sh: osnx command: Print a remote file from your Nintendo Switch to stdout.
set -e

osnxconfusage=$(printf "Usage:
  %s conf get [field]
" "$0" )

osnxconfhelp=$(printf "Read %s configuration.

%s

Description:
  Read a field from the config file at ~/.osnx.yaml. If a field is not set,
  a default value will be used if one is configured. Not every field has a
  default; those that don't will simply print nothing and exit cleanly.

  This command requires yq (https://github.com/mikefarah/yq) to be installed.
  Install with 'brew install yq' or download from the GitHub Releases page.

Available Fields:
  ftp
     .flags    Array of flags passed to the ftp binary in '%s ftp'.
     .port     Port used to connect to your Nintendo Switch's FTP server.

  mac          The MAC address of your Nintendo Switch, used to determine its
               network IP. Most commands will not work if this field is unset.

  Additionally if no argument is passed the entire config file will be printed.

See Also:
  https://github.com/mikefarah/yq
" "$(basename "$0")" "$osnxconfusage" "$(basename "$0")" )

osnxconf() {
	case "$1" in
		-h | --help)
			printf '%s\n' "$osnxconfhelp"
			return 0 ;;
		get) ;; # so we can handle unrecognized commands without printing the yq warning
		*)
			stderrf '%s: Unknown command: "%s"\n\n%s\n' "$0" "$1" "$osnxconfusage"
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
			default='--no-login --no-prompt --prompt="nx> "'
			path='ftp.flags[*]' ;;
		ftp.port)
			# default to standard sys-ftpd-light port
			default=5000 ;;
	esac

	# best-effort attempt with yq simply prints out default value
	if ! binexists yq ; then
		if [ "${default?x}" ]; then # checks if $default is set, exiting 127 if not
			stderrf '%s: yq not found, using configured default\n' "$0"
			echo "$default"
			return 0
		fi

		stderrf '%s: yq not found, cannot read configuration\n' "$0"
		return 126
	fi

	# yq won't print out newlines for defaults, which can be pretty unreadable
	# so to provide a consistent experience we simply add one ourselves by echoing
	value="$(yq read -D "$default" -- ~/.osnx.yaml "$path")"
	echo "$value"
}
