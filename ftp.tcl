#!/usr/bin/env expect

lassign $argv ip port user password

# Detect if stdin is a terminal, that is if there is already data to read from
# stdin or not. If stdin is a file or pipe (i.e., not a terminal) we'll treat
# this data as an ftp script and run it noninteractively. If it is a terminal
# then we'll run as an interactive client.
if { [catch { exec test -t 0 }] } {
    # Disable prompt and raw server response logging to minimize noise.
    set interactive 0
    set prompt ""
    log_user 0
} else {
    # Use a friendly prompt to display interactivity and resemble a REPL.
    set interactive 1
    set prompt "osnx> "
}

spawn -noecho nc "$ip" "$port"
set control $spawn_id

proc ftpsend { id command } {
    send -i $id "$command\n"

    # Retain the command sent in the global namespace for use in some handlers.
    # Since some commands are sent by the program, and not by the user, this
    # allows us to determine if a user-supplied command can be retried.
    global last_sent
    set    last_sent $command

    expect {
        # netcat echoes input lines, throw away the line with the command that
        # we just sent.
        -i $id -re "$command\[\r\n\]+" { return ok }
        -i $id eof     { puts stderr "lost connection to server" }
        -i $id timeout { puts stderr "timeout while sending command" }
    }

    return error
}

expect {
    # "220 Hello!"
    -re {220[^\r\n]*[\r\n]+} {}
    default {
        puts stderr "timed out waiting to connect"
        exit 1
    }
}

send_user "$prompt"

while { [gets stdin command] > -1 } {
    ftpsend $control $command

    expect {
        # Remove command echoing and line breaks to simplify response parsing.
        -re {^[^\d]+[^\r\n]+} { exp_continue }
        -re {^[\r\n]+} { exp_continue }

        # "150 Ready" - Command received, server is ready to send response over
        # the data connection.
        -re {^150[^\r\n]*[\r\n]+} {
            expect {
                -i $data \n {
                    puts -nonewline $expect_out(buffer)
                    exp_continue
                }
                -i $data full_buffer {
                    puts -nonewline $expect_out(buffer)
                    exp_continue
                }
                -i $data eof {
                    puts -nonewline $expect_out(buffer)
                }
                default { exit 1 }
            }

            # ensure the data connection closes
            wait -i $data
            exp_continue
        }

        # "200 OK" - Command was successful, catch-all for responses without
        # additional output. For responses that require a data connection this
        # usually precedes a "150 Ready".
        -re {^200[^\r\n]*[\r\n]+} {
            if { [info exists data] } {
                # Command required opening a data connection to retrieve
                # response. Continue waiting until a 150, signifying the data
                # is ready to be sent.
                exp_continue
            }

            # Command did not require opening a data connection and will have
            # no further response. We can simply continue to the next command.
        }

        # "221 Disconnecting"
        -re {^221[^\r\n]*[\r\n]+} {
            catch close
            catch wait
            break
        }

        # "226 OK" - Action was successful, closing data connection. This is
        # the final response we should expect to see from a successful, or
        # successfully aborted, transfer.
        -re {^226[^\r\n]*[\r\n]+} {
            if { [info exists data] } {
                # Subsequent commands must open a new data connection, so we
                # unset the connection's spawn id to avoid attempting to use a
                # closed channel.
                unset data
            }
        }

        # "227 Entering passive mode (h1,h2,h3,h4,p1,p2)" - Response to the
        # PASV command, this opens a new server connection on ip (h1.h2.h3.h4)
        # and port (p1 * 256 + p2) for data retrieval (the "data connection").
        -re {^227[^\d\r\n]*\(?(\d+,\d+,\d+,\d+),(\d+),(\d+)\)?[\r\n]+} {
            set data_ip   [string map {, .} $expect_out(1,string)]
            set data_port [expr ($expect_out(2,string) << 8) + $expect_out(3,string)]

            # Spawn our data connection then hand control back to the control
            # connection to continue response processing.
            spawn -noecho nc "$data_ip" "$data_port"
            set data     $spawn_id
            set spawn_id $control

            # Since login can happen automatically and transparently we may
            # need to resend the user's command to fufill the requested action.
            # This pattern is also used in 230 when logging in.
            if { ! [string match -nocase $last_sent $command] } {
                ftpsend $control $command
                exp_continue
            }
        }

        # "230 OK" - User has successfully logged in.
        -re {^230[^\r\n]*[\r\n]+} {
            # Since login can happen automatically and transparently we may
            # need to resend the user's command to fufill the requested action.
            # This pattern is also used in 227 when entering passive mode.
            if { ! [string match -nocase $last_sent $command] } {
                ftpsend $control $command
                exp_continue
            }
        }

        # "257 "path" -
        -re {^257[^\"]*"(.*)"[\r\n]+} {
            puts $expect_out(1,string)
        }

        # "331 Need password"
        -re {^331[^\r\n]*[\r\n]+} {
            if { $password eq "" } {
                puts stderr "server requires login but password not set"
                exit 1
            }

            ftpsend $control "PASS $password"
            exp_continue
        }

        # "502 Invalid command "<command>" " - The command does not exist or is not
        # supported by this server.
        -re {^502[^\"]*"(.*)"[\r\n+]} {
            puts stderr "invalid command: $expect_out(1,string)"
            exit 1
        }

        # "503 Bad sequence of commands" - We must enter passive mode and spawn
        # a new connection to retrieve the response from this command. See the
        # "227 Entering passive mode" and "150 Ready" handlers for more detail.
        -re {^503[^\r\n]*[\r\n]+} {
            ftpsend $control "PASV"
            exp_continue
        }

        # "530 Not logged in"
        -re {^530[^\r\n]*[\r\n]+} {
            if { $user eq "" } {
                puts stderr "server requires login but username not set"
                exit 1
            }

            ftpsend $control "USER $user"
            exp_continue
        }

        # "550 Unavailable"
        # this file or directory is not readable or does not exist
        -re {^550[^\r\n]*[\r\n]+} {
            puts stderr "file or directory not available"
            exit 1
        }

        # "XXX-Start / XXX End" - A multiline response to commands like HELP,
        # with its data indented and sandwiched between two coded responses.
        # We'll read each line and trim off the leading whitespace for a
        # better user experience.
        -re {^(\d\d\d)-[^\r\n]*[\r\n]+} {
            set code $expect_out(1,string)

            expect {
                -re "^$code\[^\r\n\]*\[\r\n\]+" {
                    # A subsequent response with the same code signifies the
                    # end of the multiline response.
                }
                -re {^([^\r\n]+)[\r\n]+} {
                    puts [string trimleft $expect_out(1,string)]
                    exp_continue
                }
                eof {
                    puts stderr "received eof while waiting for server response"
                    exit 1
                }
                timeout {
                    puts stderr "timed out while waiting for server response"
                    exit 1
                }
            }

            unset code
        }

        -re {^(\d\d\d).*[\r\n]+} {
            # Unhandled response, log for future implementation.
            puts stderr "unhandled server response: $expect_out(buffer)"
        }

        eof {
            puts stderr "server closed connection"
            exit 1
        }

        timeout {
            puts stderr "server did not respond within timeout"
            exit 1
        }
    }

    send_user "$prompt"
}
