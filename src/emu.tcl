lappend auto_path [pwd]

package require Tk 8.6
package require uxn 1.0

variable system_colors
# Set default system colors RGB x 4:
array set system_colors { 0 {0 0 0} 1 {0 0 0} 2 {0 0 0} 3 {0 0 0} }

variable blending {
  {0 0 0 0 1 0 1 1 2 2 0 2 3 3 3 0}
  {0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3}
  {1 2 3 1 1 2 3 1 1 2 3 1 1 2 3 1}
  {2 3 1 2 2 3 1 2 2 3 1 2 2 3 1 2}
}

# grid [tk::canvas .canvas] -sticky nwes -column 1 -row 0

# puts [::tcl::unsupported::representation $ram]

set romfile [lindex $argv 0]

# Scale pixels:
variable pixel_size 1

proc generate_data {width height} {
  set data [list]
  for {set x 0} {$x < $width} {incr x} {
    set row [list]
    for {set y 0} {$y < $height} {incr y} {
       lappend row #ff00ff
       # [format "#%02x%02x%02x" [random_byte] [random_byte] [random_byte]]
    }
    lappend data $row
  }
  return $data
}
 
proc random_byte {} {
   return [expr {int(rand() * 256)}]
}

variable bg [image create photo]
variable fg [image create photo]

canvas .canvas

# label .l -image $bg

# label .l -image bg
# label .l -text "In the\nMiddle!" -bg black -fg white
# place .canvas -x 0 -y 0
pack .canvas

proc screen_blank {} {
  .canvas configure -background [system_color_hex 0]
}

# index is 0 (R), 1 (G) or 2 (B)
proc system_set_colors {val index} {
  variable system_colors
  set i 0
  foreach hex [split [format %.4x $val] {}] {
    set rgb $system_colors($i)
    scan $hex %x decimal
    lset rgb $index $decimal
    set system_colors($i) $rgb
    incr i
  }
  screen_blank
}

proc system_set_r {val} {
  system_set_colors $val 0
}

proc system_set_g {val} {
  system_set_colors $val 1
}

proc system_set_b {val} {
  system_set_colors $val 2
}

variable screen_width 0
variable screen_height 0

proc screen_pixel {x y fg color} {
  variable pixel_size
  set hex_color [system_color_hex $color]
  .canvas create rectangle $x $y [expr $x + $pixel_size] [expr $y + $pixel_size] -outline "" -fill $hex_color
}

proc screen_sprite { auto x y addr val } {
  variable pixel_size
  variable system_colors
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
          set rgb $system_colors($b)
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

proc screen_set_width {width} {
  variable screen_width
  variable bg
  variable fg
  
  set screen_width $width
  window_set_size
  .canvas configure -width $width
  $bg configure -width $width
  $fg configure -width $width
}

proc screen_set_height {height} {
  variable screen_height
  variable bg
  variable fg

  set screen_height $height
  window_set_size
  .canvas configure -height $height
  $bg configure -height $height
  $fg configure -height $height
}

# Return hex color of rgb list:
proc color_hex {rgb} {
  set r [lindex $rgb 0]
  set g [lindex $rgb 1]
  set b [lindex $rgb 2]
  return [format "#%.1x%.1x%.1x" $r $g $b]
}

# Pass system color index and get hex color:
proc system_color_hex {index} {
  variable system_colors

  set rgb $system_colors($index)
  return [color_hex $rgb]
}

proc window_set_size {} {
  variable screen_width
  variable screen_height
  wm minsize . $screen_width $screen_height
  wm maxsize . $screen_width $screen_height
}

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

  screen_set_width [uxn screen_get_width]
  screen_set_height [uxn screen_get_height]

  wm title . "tuxn : $romfile"
  wm resizable . 0 0
  window_set_size

  .canvas configure -borderwidth 0 -highlightthickness 0 -width $screen_width -height $screen_height

  .canvas create image 255 160 -image $bg
  # .canvas create image 0 0 -image $fg

  # Save callback function to handle events of ports:
  uxn watch .System/red { val { system_set_r $val }}
  uxn watch .System/green { val { system_set_g $val }}
  uxn watch .System/blue { val { system_set_b $val }}

  uxn watch .Console/write { val { puts -nonewline stdout [format %c $val] } }
  
  uxn watch .Screen/width { val { screen_set_width $val } }
  uxn watch .Screen/height { val { screen_set_height $val } }
  uxn watch .Screen/pixel { {x y fg color} { screen_pixel $x $y $fg $color } }
  uxn watch .Screen/sprite { {auto x y addr val} { screen_sprite $auto $x $y $addr $val } }
  # uxn watch .Screen/vector { val { puts "LOLLLL: $val" } }
  # uxn watch .Screen/x { val {  } }
  # uxn watch .Screen/y { val {  } }

  uxn load $program
  uxn eval [expr 0x0100]
}