# Check dir for packages:
lappend auto_path [pwd]

package require uxn 1.0
package require system 1.0
package require console 1.0
package require screen 1.0

set romfile [lindex $argv 0]

if { $argc < 1 || $romfile == "--help"} {
  puts "usage: tclkit $argv0 file.rom \[args...\]"
} else {

  uxn set_debug 1
  uxn init
  screen init
  system init
  console init

  system load $romfile

  uxn eval [expr 0x0100]
}