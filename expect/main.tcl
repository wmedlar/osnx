#!/usr/bin/env expect
set root [file dirname [info script]]
source "$root/try.tcl"
source "$root/ftp.tcl"
source "$root/repl.tcl"

lassign $argv host port user password

# Detect if stdin is a terminal, that is if there is already data to read from
# stdin or not. If stdin is a file or pipe (i.e., not a terminal) we'll treat
# this data as an ftp script and run it noninteractively. If it is a terminal
# then we'll run as an interactive client.
if { [catch { exec test -t 0 }] } {
    REPL::interactive 0
} else {
    REPL::interactive 1
}

try {
    FTP::connect $host $port
} on error { err } {
    if { $err eq "" } { set err $::errorInfo }
    set message "failed to connect to $host on port $port: $err"
    REPL::error $message $::errorCode 1
}

if { $user ne "" } {
    try {
        FTP::login $user $password
    } on error { err } {
        if { $err eq "" } { set err $::errorInfo }
        set message "login failed for user \"$user\": $err"
        REPL::error $message $::errorCode
    }
}

while { $FTP::connected && [REPL::read stdin command] } {
    if { $command eq "" } continue

    try {
        try {
            FTP::send $command response
        } trap $FTP::ERROR_REQUIRES_DATA_CONNECTION {} {
            FTP::send PASV _
            FTP::send $command response
        }
    } on error { err } {
        if { $err eq "" } { set err $::errorInfo }
        set message "failed to send command \"$command\": $err"
        set always [expr $::errorCode == $FTP::ERROR_EOF]
        REPL::error $message $::errorCode $always
        continue
    }

    if { [info exists response(result)] && $response(result) ne "" } {
        REPL::print $response(result)
    }
}

catch {FTP::send QUIT}
