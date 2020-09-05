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
    send "$command\n"

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
            continue
        }

        # "211-Extensions supported: / 211 End" -
        -re {^211[^\r\n]*[\r\n]+} {
            # Read and print each line until the next non-indented 211
            # signifies the end of the response.
            expect {
                -re {^211[^\r\n]*[\r\n]+} {
                    continue
                }
                -re {^([^\r\n]+)[\r\n]+} {
                    # Interior lines are always indented, strip this out.
                    puts [string trimleft $expect_out(1,string)]
                    exp_continue
                }
                default { exit 1 }
            }
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

            exp_continue
        }

        # "250-Status / 250 End"
        -re {^250[^\r\n]*[\r\n]+} {
            # Read and print each line until the next non-indented 250
            # signifies the end of the response.
            expect {
                -re {^250[^\r\n]*[\r\n]+} {
                    continue
                }
                -re {^([^\r\n]+)[\r\n]+} {
                    # Interior lines are always indented, strip this out.
                    puts [string trimleft $expect_out(1,string)]
                    exp_continue
                }
                default { exit 1 }
            }
        }

        # "257 "path" -
        -re {^257[^\"]*"(.*)"[\r\n]+} {
            puts $expect_out(1,string)
        }

        # "502 Invalid command" - The command does not exist or is not
        # supported by this server.
        -re {^502[^\"]*"(.*)"[\r\n+]} {
            puts stderr "invalid command: $expect_out(1,string)"
            exit 1
        }

        # "503 Bad sequence of commands" - We must enter passive mode and spawn
        # a new connection to retrieve the response from this command. See the
        # "227 Entering passive mode" and "150 Ready" handlers for more detail.
        -re {^503[^\r\n]*[\r\n]+} {
            # We resend the command here instead of in 227 to avoid an infinite
            # loop if the "PASV" command is passed over stdin.
            send "PASV\nTYPE I\n$command\n"
            exp_continue
        }

        # "550 Unavailable"
        # this file or directory is not readable or does not exist
        -re {^550[^\r\n]*[\r\n]+} {
            puts stderr "file or directory not available"
            exit 1
        }

        -re {^(\d\d\d).*[\r\n]+} {
            puts stderr "uncaught server return code: $expect_out(1,string)"
            puts stderr $expect_out(buffer)
        }

        default { exit 1 }
    }

    send_user "$prompt"
}
