#!/bin/bash
set -e

osnxftpusage=$(printf "Usage:
  %s ftp [flag] [flag]... [ <<< command ]
" "$0" )

osnxftphelp=$(printf "Open an FTP connection to your Nintendo Switch.

%s

Description:
  Connect to your Nintendo Switch's FTP server using the IP and port found via
  '%s ip' or '%s conf get ftp.port', respectively. If 'ftp.user' and 'ftp.pass'
  are set, the program will attempt to automatically log into the server as the
  user. This operation can be quite slow, to disable it either comment out your
  username from your config or pass the '--no-login' flag.

  You may also pass an FTP command through stdin to run and exit, e.g.,
    %s ftp <<< 'put atmosphere/contents/420000000000000E/exefs.nsp

  Available commands depend on your ftp client.

See Also:
  ftp(1), https://github.com/cathery/sys-ftpd-light
" "$osnxftpusage" "$(basename "$0")" "$(basename "$0")" "$(basename "$0")" "$0" )

osnxftp() {
	case "$1" in -h | --help)
		printf '%s\n' "$osnxftphelp"
		return 0 ;;
	esac

	ip="$(osnx ip)"
	port="$(osnx conf get ftp.port)"
	user="$(osnx conf get ftp.user)"
	pass="$(osnx conf get ftp.pass)"
	flags="$(osnx conf get ftp.flags)"

	# Because flags are a newline-separated array they need a little
	# post-processing to be properly interpreted by ftp.
	eval set -- "$(tr '\n' ' ' <<< "$flags")" "$@"

	# We make use of ftp's support for netrc files to enable automatic login
	# for users that set their credentials. netrc files contain a host login
	# information somewhat similar to an SSH config, but are standardized and
	# understood by a wide variety of programs. See:
	#   https://www.gnu.org/software/inetutils/manual/html_node/The-_002enetrc-file.html
	#
	# If netrc-facilitated login takes a very long time, like it does on my
	# machine, add the --no-login flag and login manually.
	if [ -n "$user" ]; then
		netrc="$(mktemp -dt osnxftp)/netrc"
		trap 'rm -rf "$(dirname "$netrc")"' exit
		# The netrc file must be readable only by its owner. install does this
		# in a single step by setting the file mode while creating the file
		# from stdin.
		install -m 0600 /dev/stdin "$netrc" <<< "$(printf 'machine %s
			login %s
			password %s
		' "$ip" "$user" "$pass"
		)"
		set -- --netrc="$netrc" "$@"
	fi

	ftp "$@" -- "$ip" "$port"
}
