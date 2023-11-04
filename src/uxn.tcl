package require Tcl 8.5
package provide uxn 1.0
# package require stack 1.0

namespace eval ::uxn {
  # Export all:
  namespace export *
  namespace ensemble create
  
  # Switch off debug by default:
  variable debug 0

  # Memory:
  variable ram {}
  # Setup ram and fill with 0:
  for { set i 0}  {$i < 0x13000} {incr i} { lappend ram 0 }

  # Devices:
  variable dev {}
  # Setup devices and fill with 0:
  for { set i 0}  {$i < 0x100} {incr i} { lappend dev 0 }

  variable wst_offset [expr 0x10000]
  variable rst_offset [expr 0x11000]
  variable device_offset [ expr 0x12000 ]

  # Loaded program:
  variable program

  # Current opcode:
  variable opcode

  # Short mode:
  variable mode_2

  # Return mode:
  variable mode_r

  # Keep mode:
  variable mode_k

  # Current source stack:
  variable src

  # Current destination stack:
  variable dst
  
  variable stack_offsets

  # Save device callbacks by ports:
  variable device_callbacks
  array set device_callbacks {}

  variable opcodes "
    BRK    INC    POP    NIP    SWP    ROT    DUP    OVR    EQU    NEQ    GTH    LTH    JMP    JCN    JSR    STH
    LDZ    STZ    LDR    STR    LDA    STA    DEI    DEO    ADD    SUB    MUL    DIV    AND    ORA    EOR    SFT
    JCI    INC2   POP2   NIP2   SWP2   ROT2   DUP2   OVR2   EQU2   NEQ2   GTH2   LTH2   JMP2   JCN2   JSR2   STH2
    LDZ2   STZ2   LDR2   STR2   LDA2   STA2   DEI2   DEO2   ADD2   SUB2   MUL2   DIV2   AND2   ORA2   EOR2   SFT2
    JMI    INCr   POPr   NIPr   SWPr   ROTr   DUPr   OVRr   EQUr   NEQr   GTHr   LTHr   JMPr   JCNr   JSRr   STHr
    LDZr   STZr   LDRr   STRr   LDAr   STAr   DEIr   DEOr   ADDr   SUBr   MULr   DIVr   ANDr   ORAr   EORr   SFTr
    JSI    INC2r  POP2r  NIP2r  SWP2r  ROT2r  DUP2r  OVR2r  EQU2r  NEQ2r  GTH2r  LTH2r  JMP2r  JCN2r  JSR2r  STH2r
    LDZ2r  STZ2r  LDR2r  STR2r  LDA2r  STA2r  DEI2r  DEO2r  ADD2r  SUB2r  MUL2r  DIV2r  AND2r  ORA2r  EOR2r  SFT2r
    LIT    INCk   POPk   NIPk   SWPk   ROTk   DUPk   OVRk   EQUk   NEQk   GTHk   LTHk   JMPk   JCNk   JSRk   STHk
    LDZk   STZk   LDRk   STRk   LDAk   STAk   DEIk   DEOk   ADDk   SUBk   MULk   DIVk   ANDk   ORAk   EORk   SFTk
    LIT2   INC2k  POP2k  NIP2k  SWP2k  ROT2k  DUP2k  OVR2k  EQU2k  NEQ2k  GTH2k  LTH2k  JMP2k  JCN2k  JSR2k  STH2k
    LDZ2k  STZ2k  LDR2k  STR2k  LDA2k  STA2k  DEI2k  DEO2k  ADD2k  SUB2k  MUL2k  DIV2k  AND2k  ORA2k  EOR2k  SFT2k
    LITr   INCkr  POPkr  NIPkr  SWPkr  ROTkr  DUPkr  OVRkr  EQUkr  NEQkr  GTHkr  LTHkr  JMPkr  JCNkr  JSRkr  STHkr
    LDZkr  STZkr  LDRkr  STRkr  LDAkr  STAkr  DEIkr  DEOkr  ADDkr  SUBkr  MULkr  DIVkr  ANDkr  ORAkr  EORkr  SFTkr
    LIT2r  INC2kr POP2kr NIP2kr SWP2kr ROT2kr DUP2kr OVR2kr EQU2kr NEQ2kr GTH2kr LTH2kr JMP2kr JCN2kr JSR2kr STH2kr
    LDZ2kr STZ2kr LDR2kr STR2kr LDA2kr STA2kr DEI2kr DEO2kr ADD2kr SUB2kr MUL2kr DIV2kr AND2kr ORA2kr EOR2kr SFT2kr
  "
}

# handle opcodes:
# proc ::uxn::handle { opcode bodies } {
#   variable opcodes

#   set name [lindex $opcodes $opcode]
#   set name_index [lsearch $bodies $name]

#   if { $name_index != -1 } {
#     set body_index [expr $name_index + 1]
#     puts "$name $name_index $body_index"
#     # Generate procedure:
#     proc "::uxn::$name" {} [lindex $bodies $body_index]
#     # Execute:
#     ::uxn::$name
#   }
# }

proc ::uxn::set_debug {val} {
  variable debug
  set debug $val
}

proc ::uxn::log {message} {
  variable debug
  if { $debug } {
    puts $message
  }
}

# 
# STACK PROCEDURES START
# 

# Create a new stack:
proc ::uxn::stack_create {name offset} {
  variable stack_offsets
  set stack_offsets($name) $offset
  log "stack $name: $offset - [expr $offset + 255]"
  return $name
}

# Get offset of a stack:
proc ::uxn::stack_offset {name} {
  variable stack_offsets
  return $stack_offsets($name)
}

proc ::uxn::stack_peek {name index} {
  variable ram
  return [lindex $ram [expr [stack_offset $name] + $index]]
}

# Get content of stack ptr:
proc ::uxn::stack_ptr {name} {
  return [stack_peek $name 0xff]
}

proc ::uxn::stack_inc {name} {
  set old_count [stack_count $name]
  set new_count [expr $old_count + 1]
  set addr [stack_counter_addr $name]
  poke8 $addr $new_count
  return $old_count
}

proc ::uxn::stack_dec {name} {
  variable mode_k
  if ($mode_k) {
    return 
    # TODO:
    # --this.pk
  } else {
    set old_count [stack_count $name]
    set new_count [expr $old_count - 1]
    set addr [stack_counter_addr $name]
    poke8 $addr $new_count
    return $new_count
  }
}

proc ::uxn::stack_push8 {name val} {
  set counter [stack_count $name]
  if { $counter == 0xff } {
    return halt 2
  }
  set offset [stack_offset $name]
  set addr [expr $offset + [stack_inc $name]]
  poke8 $addr $val
}

proc ::uxn::stack_push16 {name val} {
  stack_push8 $name [expr $val >> 0x08]
  stack_push8 $name [expr $val & 0xff]
}

proc ::uxn::stack_pop8 {name} {
  variable ram
  set offset [stack_offset $name]
  if {[stack_ptr $name] == 0x00} {
    halt 1
  } else {
    set dec [stack_dec $name]
    set val [lindex $ram [expr $offset + $dec]]
    return $val
  }
}

proc ::uxn::stack_pop16 {name} {
  return [expr [stack_pop8 $name] + ([stack_pop8 $name] << 8)]
}

proc ::uxn::stack_counter_addr {name} {
  set offset [stack_offset $name]
  return [expr $offset + 0xff]
}

proc ::uxn::stack_count {name} {
  set addr [stack_counter_addr $name]
  return [peek8 $addr]
}

# Show stack (for debugging):
proc ::uxn::stack_show {name} {
  variable ram
  set offset [stack_offset $name]
  for {set i $offset} {$i < [expr $offset + 256]} {incr i} {
    puts "$i: [lindex $ram $i]"
  }
}

# 
# STACK PROCEDURES END
# 


# TODO
proc ::uxn::halt {err} {
  # let vec = peek16(emu.uxn.dev, 0)
  # if(vec)
  #   this.eval(vec)
  # else
  #   emu.console.error_el.innerHTML = "<b>Error</b>: " + (this.mode_r ? "Return-stack" : "Working-stack") + " " + this.errors[err] + "."
  # this.pc = 0x0000
}

# Returns name of opcode:
proc ::uxn::opcode_name { opcode } {
  variable opcodes
  # puts "[expr $opcode & 0xff]"
  # puts [ format %05b [expr $opcode & 0x1f ]]
  set name [lindex $opcodes $opcode]
  return $name
}

# Get wst
proc ::uxn::wst {} {
  variable wst
  return $wst
}

# Get rst
proc ::uxn::rst {} {
  variable rst
  return $rst
}

# Get ram
proc ::uxn::ram {} {
  variable ram
  return $ram
}

# Watch port for changes:
proc ::uxn::watch {port callback} {
  variable device_callbacks
  set device_callbacks($port) $callback
}

proc ::uxn::init {} {
  variable wst_offset
  variable rst_offset
  variable ram
  
  # Working stack:
  stack_create wst $wst_offset
  # Return stack:
  stack_create rst $rst_offset

  log "ram size: [llength $ram]"
}

proc ::uxn::load { rom } {
  variable ram
  variable program

  set program $rom
  for { set i 0}  {$i < [llength $program]} {incr i} {
    poke8 [expr 0x100 + $i] [lindex $program $i]
  }
}

proc ::uxn::device_poke8 {port val} {
  variable dev
  lset dev $port $val
}

proc ::uxn::device_poke16 {port val} {
  device_poke8 $port [expr $val >> 8]
  device_poke8 [expr $port + 1] [expr $val & 0xff]
}

proc ::uxn::device_peek8 {port} {
  variable dev
  return [lindex $dev $port]
}

proc ::uxn::device_peek16 {port} {
  return [expr ([device_peek8 $port] << 8) + [device_peek8 [expr $port + 1]]]
}

proc ::uxn::push { val } {
  variable mode_2
  if { $mode_2 } {
    push16 $val
  } else {
    push8 $val
  }
}

proc ::uxn::push8 { val } {
  variable src
  stack_push8 $src $val
}

proc ::uxn::push16 { val } {
  variable src
  stack_push16 $src $val
}

proc ::uxn::pop {} {
  variable src
  variable mode_2

  if { $mode_2 } {
    return [stack_pop16 $src]
  } else {
    return [stack_pop8 $src]
  }
}

proc ::uxn::peek8 { addr } {
  variable ram
  return [lindex $ram $addr]
}

proc ::uxn::peek16 { addr } {
  return [expr ([peek8 $addr] << 8) + [peek8 [expr $addr + 1]]]
}

proc ::uxn::peek { addr } {
  variable mode_2

  if { $mode_2 } {
    return [peek16 $addr]
  } else {
    return [peek8 $addr]
  }
}

proc ::uxn::poke8 {addr val} {
  variable ram
  lset ram $addr $val
}

proc ::uxn::poke16 {addr val} {
  poke8 $addr [expr $val >> 8]
  poke8 [expr $addr + 1] $val
}

proc ::uxn::poke {addr val} {
  variable mode_2
  if { $mode_2 } {
    poke16 $addr $val
  } else {
    poke8 $addr $val
  }
}

proc ::uxn::rel {val} {
  return [expr $val > 0x80 ? $val - 256 : $val]
}

proc ::uxn::jump {addr pc} {
  variable mode_2
  set x $addr
  if { !mode_2 } {
    set x [expr $pc + [rel $addr]]
  }
  return [expr $x & 0xffff]
}

proc ::uxn::move { distance pc } {
  return [ set pc [ expr ($pc + $distance) & 0xffff ] ]
}

proc ::uxn::callback {port val} {
  variable device_callbacks
  variable dev

  set device "[format %02x [expr $port & 0xf0]]"
  
  log "DEV: $device PORT: [format %02x $port] VAL: [format %02x $val]"
  
  # for {set i 0} {$i < 255} {incr i} {
  #   puts "$i : [lindex $dev $i]"
  # }

  # Check if callback defined:
  if {[info exists device_callbacks($port)]} {
    set callback $device_callbacks($port)
    switch [format %02x $port] {
      # .Screen/pixel
      2e {
        set x [device_peek16 [expr 0x28]]
        set y [device_peek16 [expr 0x2a]]
        apply $callback $x $y
      }
      default { apply $callback $val }
    }
  } else {
    log "No callback for port [format %02x $port] with val: [format %02x $val]"
  } 
}

proc ::uxn::device_poke {port val} {
  variable mode_2

  if { $mode_2 } {
    device_poke16 $port $val
  } else {
    device_poke8 $port $val
  }
  callback $port $val
}

proc ::uxn::eval { pc } {
  variable ram
  variable program
  variable mode_2
  variable mode_r
  variable mode_k
  variable opcode
  variable dev
  variable src
  variable dst
  variable rst
  variable wst

  log "loaded program size: [llength $program]"

  # $device[0x0f] ??

  if { !$pc } {
    return 0
  }
  
  while { 1 } {
    set opcode [peek8 $pc]
    incr pc

    # Set modes:
    set mode_2 [expr $opcode & 0x20]
    set mode_r [expr $opcode & 0x40]
    set mode_k [expr $opcode & 0x80]

    # ???
    if { $mode_k } {
      # this.wst.pk = this.wst.ptr()
      # this.rst.pk = this.rst.ptr()
    }

    if { $mode_r } {
      set src rst
      set dst wst
    } else {
      set src wst
      set dst rst
    }

    set name [ opcode_name $opcode ]
    
    log "0x[format %02x $opcode] 0b[format %08b $opcode] [format %d $opcode] $name"

    switch $name {
      BRK { return 1 }
      INC { push [ expr [pop] + 1 ] }
      DEO -
      DEO2 { device_poke [stack_pop8 $src ] [pop] }
      LIT -
      LIT2 -
      LITr -
      LIT2r { push [peek $pc]; set pc [move [expr !!$mode_2 + 1] $pc] }
    }
  }
}