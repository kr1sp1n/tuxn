package provide console 1.0

namespace eval ::console {
  # Export all:
  namespace export *
  namespace ensemble create
}

proc ::console::init {} {
  uxn watch .Console/write { val { ::console::write $val } }
}

proc ::console::write {val} {
  puts -nonewline stdout [format %c $val]
}