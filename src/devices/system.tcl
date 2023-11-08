package provide system 1.0

namespace eval ::system {
  # Export all:
  namespace export *
  namespace ensemble create

  variable colors
  # Set default system colors RGB x 4:
  array set colors { 0 {0 0 0} 1 {0 0 0} 2 {0 0 0} 3 {0 0 0} }
}

# Initialize system:
proc ::system::init {} {
  # Save callback function to handle events of ports:
  uxn watch .System/red { val { ::system::set_r $val }}
  uxn watch .System/green { val { ::system::set_g $val }}
  uxn watch .System/blue { val { ::system::set_b $val }}
}

proc ::system::load {romfile} {
  set fp [open $romfile r]
  fconfigure $fp -translation binary
  set file [read $fp]
  close $fp

  # binary to hex:
  binary scan $file H* rom

  # A list type of the binary rom:
  set program {}
  foreach {a b} [split $rom {}] {
    # Save as integer representation:
    lappend program [expr 0x$a$b]
  }
  # Write in uxn ram:
  uxn load $program
}

proc ::system::colors {index} {
  variable colors
  return $colors($index)
}

# index is 0 (R), 1 (G) or 2 (B)
proc ::system::set_colors {val index} {
  variable colors
  set i 0
  foreach hex [split [format %.4x $val] {}] {
    set rgb $colors($i)
    scan $hex %x decimal
    lset rgb $index $decimal
    set colors($i) $rgb
    incr i
  }
  screen blank [color_index_hex 0]
}

# Return hex color of rgb list:
proc ::system::color_hex {rgb} {
  set r [lindex $rgb 0]
  set g [lindex $rgb 1]
  set b [lindex $rgb 2]
  return [format "#%.1x%.1x%.1x" $r $g $b]
}

# Pass system color index and get hex color:
proc ::system::color_index_hex {index} {
  variable colors

  set rgb $colors($index)
  return [color_hex $rgb]
}

proc ::system::set_r {val} {
  set_colors $val 0
}

proc ::system::set_g {val} {
  set_colors $val 1
}

proc ::system::set_b {val} {
  set_colors $val 2
}