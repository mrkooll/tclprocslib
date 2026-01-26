# Arguments processing procedures
# Author 1999-2026 Maksym Tiurin <mrkooll@bungarus.info>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::args {
	variable version 1.0
	namespace export parse_args getopt getswitchopt
}

package provide args $::args::version

# parse_args -- parse arguments list for other procedure
# parse_args _args agrs_list ?flags_list?
#
# Generates code for parse parent procedure argument lists and runs
# it. Also creates variables in parent procedure level. Created
# variable names equal to parameters names without lead minus.
#
# Arguments:
# _args     -   name of parent procedure variable with list of arguments
# args_list -   dict with parameters (key) with defaults (value) for
#               parent procedure
# ?flags_list - list of parent procedure flags
#
# Side Effects:
# Creates variables in parent procedure level.
#
# Results:
# None.
proc ::args::parse_args {_args args_list {flags_list {}}} {
	# bind local variable name with parent variable
	upvar 1 $_args args
	# create body of switch code block
	set switch_block "\{--\} \{set args \[lrange \$args 1 end\] ; break\}"
	# create body of arguments parser code
	set proc_code "foreach arg \$args \{"
	# process arguments with default values
	foreach {key default_value} $args_list {
		# create variable with default value in parent procedure level 
		{*}[list uplevel 1 [list set $key $default_value]]
		# add case for this key to switch code block
		append switch_block " \{-[set key]\} "
		append switch_block "\{uplevel 1 \[list set $key \[lindex \$args 1\]\] ; set args \[lrange \$args 2 end\]\}"
	}
	# process flags
	foreach key $flags_list {
		# create variable with value 0 in parent procedure level 
		uplevel 1 set $key 0
		# add case for this flag to switch code block
		append switch_block " \{-[set key]\} "
		append switch_block "\{uplevel 1 set $key 1 ; set args \[lrange \$args 1 end\]\}"
	}
	# complete body of arguments parser code
	append proc_code "switch -exact -- \$arg \{ $switch_block \}\}"
	# run generated code
	eval $proc_code
}

# getopt -- command line options parser
#
# Parse argv list for options. Support short, long and GNU-style long
# options. Also support default value for options.
#
# Arguments:
# _argv     - name of variable with argv list
# names     - list with options that are searched in _argv
# ?_var     - name of variable for searched option value (default no variable)
# ?default  - string with default value of searched option (default no value)
#
# Side Effects:
# remove found option from _argv list
# ?set found option value to _var variable
#
# Results:
# 1 when option was found
# 0 when option was not found
proc ::args::getopt {_argv names {_var ""} {default ""}} {
	upvar 1 $_argv argv $_var var
	foreach name $names {
		if [regexp {^--.*=$} $name] {
			# GNU-style long option
			set gnu 1
			set pos [lsearch -regexp $argv ^$name.*\$]
		} else {
			set gnu 0
			set pos [lsearch -regexp $argv ^$name\$]
		}
		if {$pos>=0} {
			set to $pos
			if {$_var ne ""} {
				if $gnu {
					set var [join [lrange [split [lindex $argv $pos] "="] 1 end] "="]
				} else {
					set var [lindex $argv [incr to]]
				}
			}
			set argv [lreplace $argv $pos $to]
			return 1
		}
	}
	if {$pos<0} {
		if {[llength [info level 0]] == 5} {set var $default}
		return 0
	}
}
# getswitchopt -- command line options parser for switches
#
# Parse argv list for options. Support short, long and GNU-style long
# options. When option was found function invert value of specified variable.
#
# Arguments:
# _argv     - name of variable with argv list
# names     - list with options that are searched in _argv
# _var      - name of variable for searched switch option value
#
# Side Effects:
# remove found option from _argv list
# ?invert value of _var variable if option was found
#
# Results:
# 1 when option was found
# 0 when option was not found
proc ::args::getswitchopt {_argv names _var} {
	upvar 1 $_argv argv $_var var
	if ![info exists var] {
		set var 0
	}
	set result [::args::getopt argv $names]
	if $result {
		set var [expr ! $var]
	}
	return $result
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:

