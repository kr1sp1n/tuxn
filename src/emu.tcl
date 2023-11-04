lappend auto_path [pwd]

package require Tk
package require uxn 1.0

wm title . "tuxn"
# wm minsize . 512 320
# wm maxsize . 512 320
# wm resizable . 0 0

grid [tk::canvas .canvas] -sticky nwes -column 0 -row 0
# grid columnconfigure . 0 -weight 1
# grid rowconfigure . 0 -weight 1

# bind .canvas <1> "set lastx %x; set lasty %y"
# bind .canvas <B1-Motion> "addLine %x %y"

# proc addLine {x y} {
#   .canvas create line $::lastx $::lasty $x $y
#   set ::lastx $x; set ::lasty $y
# }

# puts [::tcl::unsupported::representation $ram]

set romfile [lindex $argv 0]

# Scale pixels:
variable pixel_size 4

if { $argc < 1 || $romfile == "--help"} {
  puts "usage: tclkit $argv0 file.rom \[args...\]"
} else {
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

  uxn set_debug 1
  uxn init

  # .System/r:
  uxn watch [expr 0x08] { val { puts "SET R: [format %02x $val]" } }

  # .Console/write:
  uxn watch [expr 0x18] { val { puts -nonewline stdout [format %c $val] } }
  
  #  .Screen/pixel:
  uxn watch [expr 0x2e] { {x y} {
    variable pixel_size
    puts "x: $x y: $y"
    .canvas create rectangle $x $y [expr $x + $pixel_size] [expr $y + $pixel_size] -outline "" -fill black
  }}
  
  uxn load $program
  uxn eval [expr 0x0100]
}


# # ASCII:
# set byte1 "\uff"
# set byte2 [string repeat "\uff" 5]
# puts $byte1
# puts $byte2
# [format "%d" 0x$a$b]