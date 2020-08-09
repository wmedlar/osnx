osnxhelp() {
    program="$(basename "$0")"

    case "$1" in
        "")
            stderrf "%s is a small set of commands for interacting with your Nintendo Switch over FTP.

Usage:
  %s [command]

Available Commands:
  cat     Print a remote file from your Nintendo Switch
  conf    Read %s configuration
  cp      Copy files to and from your Nintendo Switch
  ftp     Open an FTP connection to your Nintendo Switch
  help    Get information on any command
  ip      Detect your Nintendo Switch's IP address
  ls      List a remote directory from your Nintendo Switch
" "$program" "$0" "$program" ;;

        cat)
            stderrf "Print a remote file from your Nintendo Switch to stdout.

Usage:
  %s %s [file] [file]...

Description:
  Read files from your Nintendo Switch over FTP and concatenate them to stdout.
  If file is a directory or does not exist an error will be printed to stderr
  and the program will continue reading from the file list.

  If an error occurs during execution, like the one described above, %s will
  exit with an error code equal to the number of errors that occurred.

  This command makes use of curl's FTP support to retrieve the files

See Also:
  curl(1)
" "$0" "$1" "$program" ;;

       conf)
            stderrf "Read %s configuration.

Usage:
  %s %s get [field]

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
" "$program" "$0" "$1" "$program" ;;

        cp)
            stderrf "Copy files to and from your Nintendo Switch over FTP.

Usage:
  %s %s [source] [source]... [destination]

Description:
  Copy files and directories from your computer running %s to your Nintendo
  Switch, and from your Nintendo Switch to your computer over FTP. All uploads
  and downloads are recursive so copies involving directories will fully
  traverse the directory tree.

  Semantics are similar to cp in that copying a directory with a trailing slash
  will copy the directory contents and not the directory itself. See below for
  an example of this.

Examples:
  upload cheats for versions 4.1.0 and 4.1.1 of Animal Crossing New Horizons to
  your Nintendo Switch running atmosphere:

    %s %s ac5309b683630ced.txt 7515e5f76d09f8a3.txt \\
        switch:/atmosphere/contents/[...]/cheats/

  upload a directory of Tesla overlays to your Nintendo Switch:

    %s %s .overlays switch:/switch/

  backup your JKSV saves, dropping the 'JKSV/save/' prefix:

    %s %s switch:/JKSV/saves/ ~/switch/saves

  download every screenshot and video capture saved on your Nintendo Switch and
  store them, with a flattened directory structure, in '~/Pictures/switch':

    %s %s switch:/Nintendo/Album/2020/[01-12]/[00-31]/ ~/Pictures/switch

See Also:
  curl(1), ftp(1)
" "$0" "$1" \
  "$program" \
  "$0" "$1" \
  "$0" "$1" \
  "$0" "$1" ;;

        ftp)
            stderrf "Open an FTP connection to your Nintendo Switch.

Usage:
  %s %s [ip] [port] [ <<< command ]

Description:
  Connect to an FTP server, optionally specifying its IP address and port. If
  either parameter is unset at the command line, %s will attempt to discover
  its value automatically either through '%s ip' or '%s conf get ftp.port',
  respectively.

  You may also pass an FTP command through stdin to run, print its result, and
  exit. Available commands depend on your ftp client.

See Also:
  ftp(1), https://github.com/cathery/sys-ftpd-light
" "$0" "$1" "$program" "$program" "$program" ;;

        help)
            stderrf "Get information on any %s command.
Usage:
  %s %s [command]

Available Commands:
  cat     Read a remote file from your Nintendo Switch
  conf    Read osNX configuration and default settings
  cp      Copy files to and from your Nintendo Switch
  ftp     Open an FTP connection to your Nintendo Switch
  help    Print this message
  ip      Detect your Nintendo Switch's IP address
  ls      List a remote directory from your Nintendo Switch
" "$(basename "$0")" "$0" "$1" ;;

        ip)
            stderrf "Detect your Nintendo Switch's IP address.

Usage:
  %s %s [mac]

Description:
  Determine your Nintendo Switch's IP by searching the ARP routing tables for
  the given MAC address, which can either be read from the config file or
  passed as the only argument.

  If no ARP entry is found for the given MAC this command will perform a ping
  scan of the entire network, similar to the nmap utility, to repopulate the
  ARP cache. This behavior is reimplimented in MacOS utilities to avoid
  requiring nmap to be installed as a dependency.

  This command is largely used internally and is exposed to the user for
  interaction with external programs. In general other commands of %s
  depend heavily upon this one and require the MAC address to be present in
  your config file.

See Also:
  arp(8), ipconfig(8), netstat(1), nmap(1), ping(8)
" "$0" "$1" "$program" ;;

        ls)
            stderrf "List a remote directory from your Nintendo Switch.

Usage:
  %s %s [directory] [directory]...

Description:
  List directories from your Nintendo Switch over FTP, printing out their
  contents to stdout. Any number of directories can be passed as arguments and
  all will be listed. If no arguments are passed, the working directory of the
  FTP server (usually /) will be listed.

  Listing is performed with curl's --list-only flag, which issues an NLST
  command to the FTP server. Unlike the true ls, this command will list
  absolute paths of directory contents rather than paths relative to the
  directory being listed. This behavior may change in the future to more
  closely mimic ls.

See Also:
  curl(1), ftp(1), ls(1)
" "$0" "$1" ;;

        *)
            stderrf 'command not recognized: "%s"\n\n' "$1"
            osnxhelp
            return 127 ;;
    esac
}