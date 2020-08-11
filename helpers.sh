#!/bin/sh
set -e

binexists() {
	command -v "$1" >/dev/null
}

curlexitfatal() {
	# An exit code will return 0 to signify that it's fatal, and a 0 otherwise.
	# For documentation on curl exit codes see:
	#   https://curl.haxx.se/libcurl/c/libcurl-errors.html
	case "$1" in
		0)
			# success!
			return 1 ;;
		19)
			# failed to RETR path, either a directory or nonexistent
			return 1 ;;
		28)
			# connection timed out, likely the server isn't reachable
			return 0 ;;
		*)
			stderr "Uncaught curl exit code: $1"
			return 0 ;;
	esac
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
	# TODO limit the number of active ping forks for subnets larger than /24
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

trimusage=$(printf "Usage:
  trim <leading | trailing | both> [max] <substring> <string> [separator=|]
")

trimhelp=$(printf "Trim a substring from either or both ends of a string.

  %s

Description:
  Trim a substring from either or both ends of another string, optionally up to
  a max count. The substring may also be a (non-extended) regular expressions
  pattern understood by sed.

  If the substring contains the default sed separator '|' another can be passed
  as the final argument. trim will print an error and exit if the substring
  given contains the sed separator.

  When max is set, up to that many occurances of the substring will be removed,
  otherwise all occurances of substring will be removed. Setting max takes
  precedence over setting the sed separator. To set the sed operator with no
  max, use a max of 0.

Examples:
  $ trim trailing ' on main' 'simping on main'
  simping

  $ trim both '~' '~~~buying gf~~~'
  buying gf

  $ trim leading 2 '[^/]*/' pictures/of/my/beautiful/wife/
  my/beautiful/wife/

See Also:
  sed(1)
" "$trimusage" )
trim() {
	direction="$1"

	case "$#" in
		0)
			stderrf '%s\n' "$trimhelp"
			return 0 ;;
		1 | 2)
			stderrf 'trim: Not enough arguments.\n\n%s\n' "$trimusage"
			return 1 ;;
		3)
			max=0
			substring="$2"
			string="$3"
			separator='|' ;;
		4)
			max="$2"
			substring="$3"
			string="$4"
			separator='|' ;;
		5)
			max="$2"
			substring="$3"
			string="$4"
			separator="$5" ;;
		*)
			stderrf 'trim: Too many arguments.\n\n%s\n' "$trimusage"
			return 1 ;;
	esac

	# Triggers if $substring contains $separator, opposite to how it reads.
	case "$substring" in *"$separator"*)
		stderrf 'trim: Substring "%s" contains sed separator "%s"\n' \
			"$substring" "$separator"
		return 1 ;;
	esac

	template="$(printf 's%s%%s%s%s' "$separator" "$separator" "$separator")"

	case "$max" in
		0 | -1)
			maxpattern='*' ;;
		*)
			maxpattern="\{0,$max\}" ;;
	esac

	# shellcheck disable=SC2059
	case "$1" in
		leading)
			sed "$(printf "$template" "^\($substring\)$maxpattern")" \
				<<< "$string" ;;
		trailing)
			sed "$(printf "$template" "\($substring\)$maxpattern$")" \
				<<< "$string" ;;
		both)
			trim leading \
				"$max" \
				"$substring" \
				"$(trim trailing "$max" "$substring" "$string" "$separator")" \
				"$separator" ;;
		*)
			stderrf 'trim: Unrecognized direction modifier: "%s"\n\n%s\n' \
				"$direction" "$trimusage"
			return 1 ;;
	esac
}

# usage: stderrf '%s' 'string' -> 'string'
stderrf() {
	# shellcheck disable=SC2059
	printf "$1" "${@:2}" >&2
}

# usage: errorf '%s' 'string' -> 'string\n'
stderr()  {
	stderrf '%s\n' "$*"
}
