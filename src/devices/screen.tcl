package provide screen 1.0
package require Tk 8.6

namespace eval ::screen {
  # Export all:
  namespace export *
  namespace ensemble create

  # Default screen size:
  variable width 512
  variable height 320

  # Background layer:
  variable bg [image create photo -width $width -height $height]

  # Foreground layer:
  variable fg [image create photo -width $width -height $height]

  variable canvas [canvas .canvas]
  $canvas configure -borderwidth 0 -highlightthickness 0 -width $width -height $height

  # Scale pixels:
  variable pixel_size 1

  variable blending {
    {0 0 0 0 1 0 1 1 2 2 0 2 3 3 3 0}
    {0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3}
    {1 2 3 1 1 2 3 1 1 2 3 1 1 2 3 1}
    {2 3 1 2 2 3 1 2 2 3 1 2 2 3 1 2}
  }
}

proc ::screen::blank {color} {
  variable canvas
  $canvas configure -background $color
}

# Initialize screen:
proc ::screen::init {} {
  variable width
  variable height
  variable canvas
  variable bg
  variable fg

  uxn device_poke16 [expr 0x22] $width
  uxn device_poke16 [expr 0x24] $height

  uxn watch .Screen/width { val { ::screen::set_width $val } }
  uxn watch .Screen/height { val { ::screen::set_height $val } }
  uxn watch .Screen/pixel { {x y fg color} { ::screen::pixel $x $y $fg $color } }
  uxn watch .Screen/sprite { {auto x y addr val} { ::screen::sprite $auto $x $y $addr $val } }

  wm title . tuxn
  . configure -bg black

  # wm resizable . 0 0
  window_set_size
  
  $canvas create image 0 0 -anchor nw -image $bg
  $canvas create image 0 0 -anchor nw -image $fg

  pack $canvas
}

proc ::screen::window_set_size {} {
  variable width
  variable height
  wm minsize . $width $height
  wm maxsize . $width $height
}

proc ::screen::set_width {val} {
  variable width
  variable canvas
  variable bg
  variable fg
  
  set width $val
  window_set_size
  $canvas configure -width $width
  $bg configure -width $width
  $fg configure -width $width
}

proc ::screen::set_height {val} {
  variable height
  variable canvas
  variable bg
  variable fg

  set height $val
  window_set_size
  $canvas configure -height $height
  $bg configure -height $height
  $fg configure -height $height
}

proc ::screen::pixel {x y fg color} {
  variable pixel_size
  variable canvas
  set hex_color [system color_index_hex $color]
  $canvas create rectangle $x $y [expr $x + $pixel_size] [expr $y + $pixel_size] -outline "" -fill $hex_color
}

proc ::screen::sprite { auto x y addr val } {
  variable pixel_size
  variable colors
  variable blending
  variable bg
  variable fg

  set 2bpp [expr !!($val & 0x80)]
  set length [expr $auto >> 4]
  set ctx [expr $val & 0x40 ? {$fg} : {$bg}]
  set color [expr $val & 0xf]
  set opaque [expr $color % 5]
  set flipx [expr $val & 0x10]
  set fx [expr $flipx ? -1 : 1]
  set flipy [expr $val & 0x20]
  set fy [expr $flipy ? -1 : 1]
  set dx [expr ($auto & 0x1) << 3]
  set dxy [expr $dx * $fy]
  set dy [expr ($auto & 0x2) << 2]
  set dyx [expr $dy * $fx]
  set addr_incr [expr ($auto & 0x4) << (1 + $2bpp)]

  for { set i 0}  {$i <= $length} {incr i} {
    set x1 [expr $x + $dyx * $i]
    set y1 [expr $y + $dxy * $i]
    # Get 8x8 image data from position:
    set data [$ctx data -from $x1 $y1 [expr $x1 + 8] [expr $y1 + 8]]
    for { set v 0}  {$v < 8} {incr v} {
      set c [expr [uxn peek8 [expr ($addr + $v) & 0xffff]] | ($2bpp ? [expr [uxn peek8 [expr ($addr + $v + 8) & 0xffff]] << 8] : 0)]
      set v1 [expr $flipy ? 7 - $v : $v]
      for { set h 7}  {$h >= 0} {incr h -1; set c [expr $c >> 1]} {
        set ch [expr ($c & 1) | (($c >> 7) & 2)]
        if { $opaque || $ch } {
          # Pixel index:
          # set index [expr (($flipx ? 7 - $h : $h) + $v1 * 8) * 4]
          set b [lindex $blending $ch $color]
          set rgb [system colors $b]
          set r [lindex $rgb 0]
          set g [lindex $rgb 1]
          set b [lindex $rgb 2]
          lset data $v $h [format "#%01x%01x%01x" $r $g $b]
          # imDat.data[imdati+3] = (!b && (ctrl & 0x40)) ? 0 : 255 // alpha
        }
      }
    }
    $ctx put $data -to $x1 $y1
    set addr [expr $addr + $addr_incr]
  }
  if { $auto & 0x1 } {
    set x [expr $x + $dx * $fx]
    uxn device_poke16 [expr 0x28] $x
  }
  if { $auto & 0x2 } {
    set y [expr $y + $dy * $fy]
    uxn device_poke16 [expr 0x2a] $y
  }
  if { $auto & 0x4 } {
    uxn device_poke16 [expr 0x2c] $addr
  }
}