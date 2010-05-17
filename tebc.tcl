lappend auto_path .
package require llvmtcl

namespace import llvmtcl::*

proc test {a b c d e} {
    if {$a <= 66 && $a > 50} {
	set rt 100
    } else {
	set rt 0
    }
    return $rt
}

proc test2 {a b c d e} {
    return [expr {222*($a+444)}]
}

proc test3 {a b c d e} {
    set rt 1
    for {set i 1} {$i < $a} {incr i} {
	set rt [expr {$rt*$i}]
    }
    return $rt
}

proc test4 {a b c d e} {
    return [expr {$a+$b}]
}

proc test5 {a b c d e} {
    return [expr {12+[test4 $a $b $c $d $e]+34}]
}

proc tcl2llvm {m nm funcarnm} {
    upvar $funcarnm funcar
    puts "--------------------------------------------------------------"
    set dasm [split [tcl::unsupported::disassemble proc $nm] \n]
    puts "----- Tcl Disassemble ----------------------------------------"
    puts [join $dasm \n]

    set bld [LLVMCreateBuilder]

    # Create function
    set argl {}
    foreach l $dasm {
	set l [string trim $l]
	if {[regexp {slot \d+, .*arg, \"} $l]} {
	    lappend argl [LLVMInt32Type]
	}
    }

    set ft [LLVMFunctionType [LLVMInt32Type] $argl 0]
    set func [LLVMAddFunction $m $nm $ft]

    # Create basic blocks
    puts "----- Creating basic blocks ----------------------------------"
    set block(0) [LLVMAppendBasicBlock $func "block0"]
    set next_is_ipath -1
    foreach l $dasm {
	set l [string trim $l]
	if {![string match "(*" $l]} { continue }
	set opcode [lindex $l 1]
	if {$next_is_ipath >= 0} {
	    regexp {\((\d+)\) } $l -> pc
	    puts "Basic block as increment path: $next_is_ipath->$pc"
	    if {![info exists block($pc)]} {
		set block($pc) [LLVMAppendBasicBlock $func "block$pc"]
	    }
	    set ipath($next_is_ipath) $pc
	    set next_is_ipath -1
	}
	if {[string match "jump*1" $opcode] || [string match "startCommand" $opcode]} {
	    # (pc) opcode offset
	    regexp {\((\d+)\) (jump\S*1|startCommand) (\+*\-*\d+)} $l -> pc cmd offset
	    set tgt [expr {$pc + $offset}]
	    puts "Basic block as target: ???->$tgt"
	    if {![info exists block($tgt)]} {
		set block($tgt) [LLVMAppendBasicBlock $func "block$tgt"]
	    }
	    set next_is_ipath $pc
	}
    }
    LLVMPositionBuilderAtEnd $bld $block(0)
    set curr_block $block(0)

    # Load arguments into llvm stack, allocate space for slots
    puts "----- Putting arguments on stack -----------------------------"
    set n 0
    foreach l $dasm {
	set l [string trim $l]
	if {[regexp {slot \d+, .*arg, \"} $l]} {
	    puts $l
	    set arg_1 [LLVMGetParam $func $n]
	    set arg_2 [LLVMBuildAlloca $bld [LLVMInt32Type] ""]
	    set arg_3 [LLVMBuildStore $bld $arg_1 $arg_2]
	    set vars($n) $arg_2
	    incr n
	} elseif {[string match "slot *" $l]} {
	    set arg_2 [LLVMBuildAlloca $bld [LLVMInt32Type] ""]
	    set vars($n) $arg_2
	}
    }

    # Convert Tcl parse output
    puts "----- Converting Tcl Disassemble -----------------------------"
    set LLVMBuilder2(bitor) LLVMBuildXor
    set LLVMBuilder2(bitxor) LLVMBuildOr
    set LLVMBuilder2(bitand) LLVMBuildAnd
    set LLVMBuilder2(lshift) LLVMBuildShl
    set LLVMBuilder2(rshift) LLVMBuildAShr
    set LLVMBuilder2(add) LLVMBuildAdd
    set LLVMBuilder2(sub) LLVMBuildSub
    set LLVMBuilder2(mult) LLVMBuildMul
    set LLVMBuilder2(div) LLVMBuildSDiv
    set LLVMBuilder2(mod) LLVMBuildSRem
    set LLVMBuilder1(uminus) LLVMBuildNeg
    set LLVMBuilder1(bitnot) LLVMBuildNot

    set LLVMBuilderICmp(eq) LLVMIntEQ
    set LLVMBuilderICmp(neq) LLVMIntNE
    set LLVMBuilderICmp(lt) LLVMIntSLT
    set LLVMBuilderICmp(gt) LLVMIntSGT
    set LLVMBuilderICmp(le) LLVMIntSLE
    set LLVMBuilderICmp(ge) LLVMIntGE

    set ::tcl_stack {}
    foreach l $dasm {
	set l [string trim $l]
	if {![string match "(*" $l]} { continue }
	puts $l
	regexp {\((\d+)\) (\S+)} $l -> pc opcode
	if {[info exists block($pc)]} {
	    puts "Position builder at end of $pc"
	    LLVMPositionBuilderAtEnd $bld $block($pc)
	    set curr_block $block($pc)
	}
	set ends_with_jump($curr_block) 0
	unset -nocomplain tgt
	if {[string match "jump*1" $opcode] || [string match "startCommand" $opcode]} {
	    regexp {\(\d+\) (jump\S*1|startCommand) (\+*\-*\d+)} $l -> cmd offset
	    set tgt [expr {$pc + $offset}]
	}
	if {[info exists LLVMBuilder1($opcode)]} {
	    push $bld [$LLVMBuilder1($opcode) $bld [pop $bld] ""]
	} elseif {[info exists LLVMBuilder2($opcode)]} {
	    set top0 [pop $bld]
	    set top1 [pop $bld]
	    push $bld [$LLVMBuilder2($opcode) $bld $top1 $top0 ""]
	} elseif {[info exists LLVMBuilderICmp($opcode)]} {
	    set top0 [pop $bld]
	    set top1 [pop $bld]
	    push $bld [LLVMBuildICmp $bld $LLVMBuilderICmp($opcode) $top1 $top0 ""]
	} else {
	    switch -exact -- $opcode {
		"loadScalar1" {
		    set var $vars([string range [lindex $l 2] 2 end])
		    push $bld [LLVMBuildLoad $bld $var ""]
		}
		"storeScalar1" {
		    set var_1 [top $bld]
		    set idx [string range [lindex $l 2] 2 end]
		    if {[info exists vars($idx)]} {
			set var_2 $vars($idx)
		    } else {
			set var_2 [LLVMBuildAlloca $bld [LLVMInt32Type] ""]
		    }
		    set var_3 [LLVMBuildStore $bld $var_1 $var_2]
		    set vars($idx) $var_2
		}
		"incrScalar1" {
		    set var $vars([string range [lindex $l 2] 2 end])
		    LLVMBuildStore $bld [LLVMBuildAdd $bld [LLVMBuildLoad $bld $var ""] [top $bld] "$l"] $var
		}
		"incrScalar1Imm" {
		    set var $vars([string range [lindex $l 2] 2 end])
		    set i [lindex $l 3]
		    set s [LLVMBuildAdd $bld [LLVMBuildLoad $bld $var ""] [LLVMConstInt [LLVMInt32Type] $i 0] ""]
		    push $bld $s
		    LLVMBuildStore $bld $s $var
		}
		"push1" {
		    set val [lindex $l 4]
		    if {![string is integer -strict $val]} {
			set val 0
		    }
		    push $bld [LLVMConstInt [LLVMInt32Type] $val 0] [lindex $l 4]
		}
		"jumpTrue1" {
		    set top [pop $bld]
		    if {[LLVMGetIntTypeWidth [LLVMTypeOf $top]] == 1} {
			set cond $top
		    } else {
			set cond [LLVMBuildICmp $bld LLVMIntNE $top [LLVMConstInt [LLVMInt32Type] 0 0] ""]
		    }
		    LLVMBuildCondBr $bld $cond $block($tgt) $block($ipath($pc))
		    set ends_with_jump($curr_block) 1
		}
		"jumpFalse1" {
		    set top [pop $bld]
		    if {[LLVMGetIntTypeWidth [LLVMTypeOf $top]] == 1} {
			set cond $top
		    } else {
			set cond [LLVMBuildICmp $bld LLVMIntNE $top [LLVMConstInt [LLVMInt32Type] 0 0] ""]
		    }
		    LLVMBuildCondBr $bld $cond $block($ipath($pc)) $block($tgt)
		    set ends_with_jump($curr_block) 1
		}
		"startCommand" {
		}
		"jump1" {
		    LLVMBuildBr $bld $block($tgt)
		    set ends_with_jump($curr_block) 1
		}
		"invokeStk1" {
		    set objc [lindex $l 2]
		    set objv {}
		    for {set i 0} {$i < ($objc-1)} {incr i} {
			lappend objv [pop $bld]
		    }
		    set objv [lreverse $objv]
		    set f $funcar([popv $bld])
		    push $bld [LLVMBuildCall $bld $f $objv ""]
		}
		"pop" {
		    pop $bld
		}
		"done" {
		    LLVMBuildRet $bld [top $bld]
		    set ends_with_jump($curr_block) 1
		}
		default {
		    error "unknown bytecode '$opcode' in '$l'"
		}
	    }
	}
    }

    # Fix increment paths
    foreach {pc b} [array get block] {
	LLVMPositionBuilderAtEnd $bld $block($pc)
	if {![info exists ends_with_jump($block($pc))] || !$ends_with_jump($block($pc))} {
	    set tpc [expr {$pc+1}]
	    while {$tpc < 1000} {
		if {[info exists block($tpc)]} {
		    LLVMBuildBr $bld $block($tpc)
		    break
		}
		incr tpc
	    }
	}
    }

    puts "--------------------------------------------------------------"

    return $func
}

proc push {bld var_1 {val 0}} {
    global tcl_stack
    puts "push $var_1 $val"
    set var_2 [LLVMBuildAlloca $bld [LLVMTypeOf $var_1] ""]
    set var_3 [LLVMBuildStore $bld $var_1 $var_2]
    lappend tcl_stack [list $var_2 $val]
}

proc pop {bld} {
    global tcl_stack
    if {[llength $tcl_stack] == 0} {
	error "Stack empty"
    }
    set top [lindex $tcl_stack end 0]
    set tcl_stack [lrange $tcl_stack 0 end-1]
    return [LLVMBuildLoad $bld $top ""]
}

proc popv {bld} {
    global tcl_stack
    if {[llength $tcl_stack] == 0} {
	error "Stack empty"
    }
    set top [lindex $tcl_stack end 1]
    set tcl_stack [lrange $tcl_stack 0 end-1]
    return $top
}

proc top {bld {offset 0}} {
    global tcl_stack
    if {[llength $tcl_stack] == 0} {
	error "Stack empty"
    }
    set top [lindex $tcl_stack end-$offset 0]
    return [LLVMBuildLoad $bld $top ""]
}

proc topv {bld {offset 0}} {
    global tcl_stack
    if {[llength $tcl_stack] == 0} {
	error "Stack empty"
    }
    return [lindex $tcl_stack end-$offset 1]
}

# Initialize the JIT
LLVMLinkInJIT
LLVMInitializeNativeTarget

# Create a module and builder
set m [LLVMModuleCreateWithName "atest"]

# Convert Tcl to LLVM
foreach nm {test test2 test3 test4 test5} {
    set func($nm) [tcl2llvm $m $nm func]
}

puts "----- Input --------------------------------------------------"
puts [LLVMModuleDump $m]

puts "----- Optimized ----------------------------------------------"
LLVMOptimizeModule $m
puts [LLVMModuleDump $m]

puts "----- Test ---------------------------------------------------"
set tclArgs {5 2 3 4 5}
set llvmArgs {}
foreach v $tclArgs {
    lappend llvmArgs [LLVMCreateGenericValueOfInt [LLVMInt32Type] $v 0]
}

lassign [LLVMCreateJITCompilerForModule $m 0] rt EE msg

foreach {nm f} [array get func] {
    set res [LLVMRunFunction_Tcl $EE $f $llvmArgs]
    puts "$nm = [$nm {*}$tclArgs] = [expr {int([LLVMGenericValueToInt $res 0])}]\n"
}

