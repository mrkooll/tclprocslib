# Package to pretty print data
# Author 2014-2026 Maksym Tiurin <mrkooll@bungarus.info>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::pretty_print {
	variable version 0.2
	namespace export pdict ptable
}

package provide pretty_print $::pretty_print::version

lappend auto_path [file dirname [info script]]
package require args

# ::pretty_print::isdict -- check is value a valid dict
# isdict value
# 
# Check is value tcl dict
#
# Arguments:
# value    - value to check
#
# Side Effects:
# None.
#
# Results:
# 0 when value is not a dict
# 1 when value is dict
# set procbody {}
# set fRepExist [expr {0 < [llength [info commands ::tcl::unsupported::representation]]}]
# if {$fRepExist} {
# 	set procbody {return [string match "value is a dict*" [::tcl::unsupported::representation $value]]}
# } else {
# 	set procbody {return [expr ([llength $value] % 2) == 0]}
# }
# {*}[list proc ::pretty_print::isdict {value} $procbody]
# unset procbody
# unset fRepExist
proc ::pretty_print::isdict {value} {
	return [expr ([llength $value] % 2) == 0]
}

# ::pretty_print::pdict -- pretty print dictionary
# pdict d ?i ?p ?s
#
# Pretty print dictionary
#
# Arguments:
# d - dict value or variable name
# i - iteration (default 0)
# p - prefix (default "  ")
# s - key/value delimiter (default " -> ")
#
# Side Effects:
# None.
#
# Results:
# None.
proc ::pretty_print::pdict { d {i 0} {p "  "} {s " -> "} } {
	if {(![string is list $d] || [llength $d] == 1)
	    && [uplevel 1 [list info exists $d]] } {
		# d is variable name, not value
		set dictName $d
		unset d
		upvar 1 $dictName d
		puts "dict $dictName"
	}
	if {! [isdict $d]} {
		return -code error  "error: pdict - argument is not a dict"
	}
	set prefix [string repeat $p $i]
	set max 0
	foreach key [dict keys $d] {
		if { [string length $key] > $max } {
			set max [string length $key]
		}
	}
	dict for {key val} ${d} {
		puts -nonewline "${prefix}[format %-${max}s $key]$s"
		if {[isdict $val]} {
			puts ""
			pdict $val [expr {$i+1}] $p $s
		} else {
			puts "'${val}'"
		}
	}
	return
}

# ::pretty_print::strip_ansi -- remove ANSI escape sequences from string
# strip_ansi text
#
# Remove ANSI escape sequences (color codes, cursor movement, etc.)
# from string. Useful for calculating visible width of colored text.
#
# Arguments:
# text - string possibly containing ANSI escape sequences
#
# Side Effects:
# None.
#
# Results:
# String with all ANSI escape sequences removed.
proc ::pretty_print::strip_ansi {text} {
	# ANSI escape sequence pattern: ESC [ ... final_byte
	# ESC is \x1b or \033, final byte is letter A-Z or a-z
	regsub -all {\x1b\[[0-9;]*[A-Za-z]} $text {} result
	return $result
}

# ::pretty_print::visible_length -- calculate visible length of string
# visible_length text
#
# Calculate visible length of string ignoring ANSI escape sequences.
#
# Arguments:
# text - string possibly containing ANSI escape sequences
#
# Side Effects:
# None.
#
# Results:
# Integer with visible character count.
proc ::pretty_print::visible_length {text} {
	return [string length [strip_ansi $text]]
}

# ::pretty_print::wrap_text -- wrap long string
# wrap_text text max_width
#
# Internal procedure to wrap long text for table print
#
# Arguments:
# text      - string with text
# max_width - max line length
#
# Side Effects:
# None.
#
# Results:
# list with splitted text
proc ::pretty_print::wrap_text {text max_width} {
	if {[string length $text] <= $max_width} {
		return [list $text]
	}
	set lines []
	set current_line ""
	foreach word [split $text] {
		# Handle very long words - force break them
		if {[string length $word] > $max_width} {
			# Flush current line if any
			if {$current_line ne ""} {
				lappend lines [string trim $current_line]
				set current_line ""
			}
			# Break long word into chunks
			set remaining $word
			while {[string length $remaining] > $max_width} {
				lappend lines [string range $remaining 0 [expr {$max_width - 1}]]
				set remaining [string range $remaining $max_width end]
			}
			set current_line $remaining
			continue
		}
		# Try to add word to current line
		set test_line [expr {$current_line eq "" ? $word : "$current_line $word"}]
		if {[string length $test_line] <= $max_width} {
			set current_line $test_line
		} else {
			# Word doesn't fit, start new line
			if {$current_line ne ""} {
				lappend lines $current_line
			}
			set current_line $word
		}
	}
	# Add remaining
	if {$current_line ne ""} {
		lappend lines $current_line
	}
	return $lines
}

# ::pretty_print::pad_ansi -- pad string with ANSI codes to visible width
# pad_ansi text width ?align
#
# Pad string containing ANSI codes to specified visible width.
#
# Arguments:
# text  - string possibly containing ANSI escape sequences
# width - desired visible width
# align - "left" (default) or "right"
#
# Side Effects:
# None.
#
# Results:
# Padded string.
proc ::pretty_print::pad_ansi {text width {align "left"}} {
	set visible_len [visible_length $text]
	set padding [expr {$width - $visible_len}]
	if {$padding <= 0} {
		return $text
	}
	set spaces [string repeat " " $padding]
	if {$align eq "right"} {
		return "${spaces}${text}"
	} else {
		return "${text}${spaces}"
	}
}

# ::pretty_print::ptable -- print data as table
# ptable ?arguments dict_list
#
# Print data as table
#
# Arguments:
# -column_order order  - list with headers in required order (default
#                        empty list)
#                        If order is not specified dict keys order
#                        from the first element of dict_list is used
# -max_col_width width - max width of the table column (default 80)
# dict_list            - list of dictionaries with data to print as table
#                        format is:
#                        {
#                         {header1 value1 header2 value2}
#                         ...
#                        }
#
# Side Effects:
# None.
#
# Results:
# None.
proc ::pretty_print::ptable {args} {
	::args::parse_args args \
	  [list column_order {} max_col_width 80] \
	  [list]

	set dict_list [lindex $args 0]
	if {![llength $dict_list]} {
		puts "No data"
		return
	}
	# Determine column order
	if {![llength $column_order]} {
		set columns []
		set all_keys [dict create]
		foreach d $dict_list {
			dict for {k v} $d {
				if {![dict exists $all_keys $k]} {
					dict set all_keys $k 1
					lappend columns $k
				}
			}
		}
	} else {
		set columns $column_order
	}
	# Calculate column widths (capped at max_col_width)
	# Use visible_length to handle ANSI codes
	set widths [dict create]
	foreach col $columns {
		set max_width [string length $col]
		foreach d $dict_list {
			if {[dict exists $d $col]} {
				set val [dict get $d $col]
				set len [visible_length $val]
				if {$len > $max_width} {
					set max_width $len
				}
			}
		}
		if {$max_width > $max_col_width} {
			set max_width $max_col_width
		}
		dict set widths $col $max_width
	}
	# Print header
	set header_parts []
	set separator_parts []
	foreach col $columns {
		set width [dict get $widths $col]
		lappend header_parts [format "%-*s" $width $col]
		lappend separator_parts [string repeat "-" $width]
	}
	puts [join $header_parts " | "]
	puts [join $separator_parts "-+-"]
	# Print rows
	foreach d $dict_list {
		# Prepare wrapped values and determine max lines
		set cell_lines [dict create]
		set max_lines 1
		foreach col $columns {
			set width [dict get $widths $col]
			set val [expr {[dict exists $d $col] ? [dict get $d $col] : "-"}]
			# Check if numeric (use stripped value for check)
			set stripped_val [strip_ansi $val]
			set is_num [string is double -strict $stripped_val]
			# Wrap text, keep numbers as-is
			if {!$is_num && [visible_length $val] > $width} {
				set lines [wrap_text $val $width]
			} else {
				set lines [list $val]
			}
			dict set cell_lines $col [list $lines $is_num]
			if {[llength $lines] > $max_lines} {
				set max_lines [llength $lines]
			}
		}
		# Print multi-line row
		for {set i 0} {$i < $max_lines} {incr i} {
			set row_parts []
			foreach col $columns {
				set width [dict get $widths $col]
				lassign [dict get $cell_lines $col] lines is_num
				set val [expr {$i < [llength $lines] ? [lindex $lines $i] : ""}]
				# Right align numbers, left align text
				# Use pad_ansi for proper padding with ANSI codes
				if {$is_num && $val ne ""} {
					lappend row_parts [pad_ansi $val $width "right"]
				} else {
					lappend row_parts [pad_ansi $val $width "left"]
				}
			}
			puts [join $row_parts " | "]
		}
	}
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
