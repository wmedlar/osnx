namespace eval FTP {
    variable last_send ""

    proc send { id command } {
        ::send -i $id "$command\n"

        # Retain the command sent in the global namespace for use in some handlers.
        # Since some commands are sent by the program, and not by the user, this
        # allows us to determine if a user-supplied command can be retried.
        set last_sent $command

        expect {
            # netcat echoes input lines, throw away the line with the command that
            # we just sent.
            -i $id -re "$command\[\r\n\]+" { return ok }
            -i $id eof     { puts stderr "lost connection to server" }
            -i $id timeout { puts stderr "timeout while sending command" }
        }

        return error
    }
}
