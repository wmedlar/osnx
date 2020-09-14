namespace eval REPL {
    variable default_prompt "osnx> "
    variable noninteractive 0
    variable prompt         $REPL::default_prompt

    proc interactive { { value "" } } {
        if { $value eq "" } {
            return [expr ! $REPL::noninteractive]
        }

        set REPL::noninteractive [expr { $value ? 0 : 1 }]
        set REPL::prompt         [expr { $value ? $REPL::default_prompt : "" }]
        log_user                 [expr { $value ? 1 : 0} ]
    }

    proc error { message exit_code { always 0 }} {
        REPL::print $message $always

        if { $REPL::noninteractive || $always } {
            exit $exit_code
        }
    }

    proc print { message { always 0 }} {
        if { $REPL::noninteractive || $always } {
            puts stderr $message
        }
    }

    proc read { chan var } {
        upvar $var command

        # Enable non-blocking mode so we can react to interrupt signals
        # immediately instead of waiting for the user to press enter.
        chan configure $chan -blocking false

        send_user $REPL::prompt
        while { [gets $chan command] < 0 } {
            if { [eof $chan] } {
                catch { close $chan }
                return false
            }
        }

        chan configure $chan -blocking true
        return true
    }
}
