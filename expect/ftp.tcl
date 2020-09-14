namespace eval FTP {
    # Track connection status for control and data connections.
    variable connected 0
    variable ctrl_conn 0
    variable data_conn 0

    variable ERROR_UNKNOWN                  1
    variable ERROR_EOF                      2
    variable ERROR_TIMEOUT                  3
    variable ERROR_UNEXPECTED_RESPONSE      4
    variable ERROR_SERVICE_NOT_AVAILABLE    5
    variable ERROR_REQUIRES_DATA_CONNECTION 6
    variable ERROR_INVALID_CREDENTIALS      7
    variable ERROR_REQUIRES_AUTHENTICATION  8

    proc connect { host port } {
        set FTP::ctrl_conn [FTP::open_connection $host $port]
        set    ::spawn_id  $FTP::ctrl_conn

        try {
            FTP::receive response
        } trap $FTP::ERROR_EOF {} {
            throw $FTP::ERROR_EOF "server is unavailable"
        }

        if { $response(code) == 220 } {
            set FTP::connected 1
        } else {
            set message "server sent unexpected response: $response(line)"
            throw $FTP::ERROR_UNEXPECTED_RESPONSE $message
        }
    }

    proc login { user { password "" } } {
        FTP::send "USER $user" response
        switch -glob -- $response(code) {
            230* {
                # User authentication was successful and server is ready to
                # accept commands.
            }

            331* {
                # User is valid but requires a password.
                if { $password eq "" } {
                    set message "password required"
                    throw $FTP::ERROR_INVALID_CREDENTIALS $message
                }
            }

            430* -
            502* -
            530* {
                # User authentication failed.
                # 502 is not a standard response to bad auth, but is a bug in
                # ftpd. See: https://github.com/mtheall/ftpd/pull/118
                set message "invalid user"
                throw $FTP::ERROR_INVALID_CREDENTIALS $message
            }

            default {
                set message "server sent unexpected response: $response(line)"
                throw $FTP::ERROR_UNEXPECTED_RESPONSE $message
            }
        }

        # Return early to save a level of indentation.
        if { $password eq "" } return

        FTP::send "PASS $password" response
        switch -glob -- $response(code) {
            230* {
                # Password authentication was successful and server is ready to
                # accept commands.
            }

            430* -
            530* {
                set message "invalid password"
                throw $FTP::ERROR_INVALID_CREDENTIALS $message
            }

            default {
                set message "server sent unexpected response: $response(line)"
                throw $FTP::ERROR_UNEXPECTED_RESPONSE $message
            }
        }
    }

    proc open_connection { host port } {
        spawn -noecho nc $host $port
        return $spawn_id
    }

    proc open_data_connection { host port } {
        set FTP::data_conn [FTP::open_connection $host $port]
        chan configure $FTP::data_conn -blocking false -translation binary
    }

    proc receive { var } {
        upvar $var response

        # Pre-parse the code and line from the response we just received. The
        # -notransfer flag prevents us from consuming the expect buffer so that
        # responses can be handled in the subsequent expect block.
        expect {
            -notransfer -re {^(\d\d\d)[\s-]?([^\r\n]*)[\r\n]+} {
                set response(code) $expect_out(1,string)
                set response(line) $expect_out(2,string)
            }

            # A response without a code is malformed and may signify that we
            # did not consume the entire expect buffer in the previous
            # response.
            -re {([^\r\n]*)[\r\n]+} {
                set response(code) ""
                set response(line) $expect_out(1,string)
                throw $FTP::ERROR_UNEXPECTED_RESPONSE "unexpected response"
            }

            eof {
                set FTP::connected 0
                set message "server unexpectedly closed connection"
                throw $FTP::ERROR_EOF $message
            }

            timeout {
                set message "timed out while waiting for server"
                throw $FTP::ERROR_TIMEOUT $message
            }
        }

        expect {
            # Remove line breaks to simplify response parsing.
            -re {^[\r\n]+} { exp_continue }

            # "150 Ready" - Command received, server is ready to send response
            # over the data connection.
            -re {^150[^\r\n]*[\r\n]+} {

                while { ! [eof $FTP::data_conn] } {
                    puts -nonewline [read $FTP::data_conn 10000]
                }

                # Continue in expectation of a 226 closing the data connection.
                exp_continue
            }

            # "221 Disconnecting" - Server is closing the connection, likely as
            # the result of a QUIT command. We signal a break to the event loop
            # to close the program.
            -re {^221[^\r\n]*[\r\n]+} { set FTP::connected 0 }

            # "226 Closing data connection" - Action was successful and the
            # data connection has closed. This is the final response we expect
            # to see from a successful (i.e., completed or aborted) data
            # transfer. Subsequent commands must open a new data connection.
            -notransfer -re {^226[^\r\n]*[\r\n]+} {
                set FTP::data_conn 0
                set response(result) [FTP::receive_multiline 226]
            }

            # "227 Entering passive mode (h1,h2,h3,h4,p1,p2)" -
            -re {^227[^\d\r\n]*\(?(\d+,\d+,\d+,\d+),(\d+),(\d+)\)?[\r\n]+} {
                set host   [string map {, .} $expect_out(1,string)]
                set port [
                    expr ($expect_out(2,string) << 8) + $expect_out(3,string)
                ]

                FTP::open_data_connection $host $port
            }

            # "230 User logged in, proceed" - User has successfully logged in
            # and server is ready to accept commands.
            -re {^230[^\r\n]*[\r\n]+} {}

            # "257 "/path/to/pwd" -
            -re {^257[^\r\n]*"([^\r\n]+)"[^\r\n]*[\r\n]+} {
                set response(result) $expect_out(1,string)
            }

            # "421 Service not available" - Server is not available for some
            # reason and has closed the control connection. This can be a
            # response to any command.
            -re {^421[^\r\n]*[\r\n]+} {
                set FTP::connected 0
                set message "server not available"
                throw $FTP::ERROR_SERVICE_NOT_AVAILABLE $message
            }

            # "425 No data connection" - This command requires opening a data
            # connection by issuing a PORT or PASV command, or  See
            # 150 and 227 for more details.
            -re {^425[^\r\n]*[\r\n]+} -
            -re {^503[^\r\n]*[\r\n]+} {
                set message "requires data connection"
                throw $FTP::ERROR_REQUIRES_DATA_CONNECTION $message
            }

            # "430 Invalid username or password" - Username or password that
            # was sent is not correct.
            -re {^430[^\r\n]*[\r\n]+} {
                set message "invalid username or password"
                throw $FTP::ERROR_INVALID_CREDENTIALS $message
            }

            # "530 Not logged in" - Previous command sent is only available to
            # logged in users. We must send a USER command, and likely a PASS,
            # to authenticate.
            -re {^530[^\r\n]*[\r\n]+} {
                set message "requires authentication"
                throw $FTP::ERROR_REQUIRES_AUTHENTICATION $message
            }

            # "XXX-Start / XXX End" - A multiline response to commands like
            # HELP, with its data indented and sandwiched between two coded
            # responses.
            -notransfer -re {^(\d\d\d)-[^\r\n]*[\r\n]+} {
                # We capture the response code again here as it may differ from
                # the initial response code if that handler used exp_continue.
                set code $expect_out(1,string)
                set response(result) [FTP::receive_multiline $code]
            }

            # Unhandled responses or responses that require no additional
            # handling. Unhandled responses are implemented as they are
            # encountered.
            -re {^(\d\d\d)([^\r\n]*)[\r\n]+} {}

            eof {
                set FTP::connected 0
                set message "server unexpectedly closed connection"
                throw $FTP::ERROR_EOF $message
            }

            timeout {
                set message "timed out while waiting for server"
                throw $FTP::ERROR_TIMEOUT $message
            }
        }
    }

    proc receive_multiline { code } {
        set lines {}

        expect {
            # Each subsequent line in the array will have its response code
            # suffixed with a dash (e.g., "221-Local time is now 04:20.")
            # except for the final line.
            -re "^(?:$code-)\[^\r\n\]*\[\r\n\]+" {
                exp_continue
            }

            # Not every line has a response code, however. The ones that do not
            # are usually the lines we're looking for.
            -re "^(\[^(?:$code)\]\[^\r\n\]*)\[\r\n\]+" {
                lappend lines [string trimleft $expect_out(1,string)]
                exp_continue
            }

            # The presence of a response code and the absence of a dash combine
            # to signify that this is the final line.
            -re "^(?:$code\[^-\])\[^\r\n\]*\[\r\n\]+" {}

            eof {
                set FTP::connected 0
                set message "server unexpectedly closed connection"
                throw $FTP::ERROR_EOF $message
            }
            timeout {
                set message "timed out while waiting for server"
                throw $FTP::ERROR_TIMEOUT $message
            }
        }

        return [join $lines \n]
    }

    proc send { command var } {
        upvar $var response

        # Netcat echoes input lines, so we temporarily disable send logging to
        # stdout to avoid reprinting user input. Note that this is different
        # from what we do with $command in the expect block below.
        set log_user_previous [log_user -info]
        log_user 0

        try {
            ::send -- $command\n

            expect {
                # The expect buffer contains the contents of our previous send, the
                # command we just issued.
                -re $command\[\r\n\]+ {}

                # We received an unexpected line that wasn't our command.
                -re {[^\r\n]*[\r\n]+} {
                    throw $FTP::ERROR_UNEXPECTED_RESPONSE "unexpected response"
                }

                eof {
                    set FTP::connected 0
                    set message "server unexpectedly closed connection"
                    throw $FTP::ERROR_EOF $message
                }

                timeout {
                    set message "timed out while waiting for server"
                    throw $FTP::ERROR_TIMEOUT $message
                }
            }
        } finally {
            log_user $log_user_previous
        }

        log_user $log_user_previous

        FTP::receive response
    }
}
