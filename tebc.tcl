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

proc tcl2llvm {nm} {
    puts "--------------------------------------------------------------"
    set dasm [split [tcl::unsupported::disassemble proc $nm] \n]
    puts "----- Tcl Disassemble ----------------------------------------"
    puts [join $dasm \n]
    # Initialize the JIT
    LLVMLinkInJIT
    LLVMInitializeNativeTarget

    # Create a module and builder
    set m [LLVMModuleCreateWithName "test"]
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
    set func [LLVMAddFunction $m "test" $ft]

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

    set tcl_stack {}
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
	    set rt [$LLVMBuilder1($opcode) $bld [lindex $tcl_stack end] ""]
	    set tcl_stack [list {*}[lrange $tcl_stack 0 end-1] $rt]
	} elseif {[info exists LLVMBuilder2($opcode)]} {
	    set rt [$LLVMBuilder2($opcode) $bld [lindex $tcl_stack end-1] [lindex $tcl_stack end] ""]
	    set tcl_stack [list {*}[lrange $tcl_stack 0 end-2] $rt]
	} elseif {[info exists LLVMBuilderICmp($opcode)]} {
	    set rt [LLVMBuildICmp $bld $LLVMBuilderICmp($opcode) [lindex $tcl_stack end-1] [lindex $tcl_stack end] ""]
	    set tcl_stack [list {*}[lrange $tcl_stack 0 end-2] $rt]
	} else {
	    switch -exact -- $opcode {
		"loadScalar1" {
		    set var $vars([string range [lindex $l 2] 2 end])
		    lappend tcl_stack [LLVMBuildLoad $bld $var ""]
		}
		"storeScalar1" {
		    set var_1 [lindex $tcl_stack end]
		    set idx [string range [lindex $l 2] 2 end]
		    if {[info exists vars($idx)]} {
			set var_2 $vars($idx)
		    } else {
			set var_2 [LLVMBuildAlloca $bld [LLVMInt32Type] ""]
		    }
		    set var_3 [LLVMBuildStore $bld $var_1 $var_2]
		    set vars($idx) $var_2
		    set tcl_stack [lrange $tcl_stack 0 end-1]
		}
		"push1" {
		    set val [lindex $l 4]
		    if {![string is integer -strict $val]} {
			set val 0
		    }
		    lappend tcl_stack [LLVMConstInt [LLVMInt32Type] $val 0]
		}
		"jumpTrue1" {
		    if {[LLVMGetIntTypeWidth [LLVMTypeOf [lindex $tcl_stack end]]] == 1} {
			set cond [lindex $tcl_stack end]
		    } else {
			set cond [LLVMBuildICmp $bld LLVMIntNE [lindex $tcl_stack end] [LLVMConstInt [LLVMInt32Type] 0 0] ""]
		    }
		    LLVMBuildCondBr $bld $cond $block($tgt) $block($ipath($pc))
		    set tcl_stack [list {*}[lrange $tcl_stack 0 end-1] $rt]
		    set ends_with_jump($curr_block) 1
		}
		"jumpFalse1" {
		    if {[LLVMGetIntTypeWidth [LLVMTypeOf [lindex $tcl_stack end]]] == 1} {
			set cond [lindex $tcl_stack end]
		    } else {
			set cond [LLVMBuildICmp $bld LLVMIntNE [lindex $tcl_stack end] [LLVMConstInt [LLVMInt32Type] 0 0] ""]
		    }
		    LLVMBuildCondBr $bld $cond $block($ipath($pc)) $block($tgt)
		    set tcl_stack [list {*}[lrange $tcl_stack 0 end-1] $rt]
		    set ends_with_jump($curr_block) 1
		}
		"startCommand" {
		}
		"jump1" {
		    puts "tgt=$tgt"
		    LLVMBuildBr $bld $block($tgt)
		    set ends_with_jump($curr_block) 1
		}
		"pop" {
		    set tcl_stack [lrange $tcl_stack 0 end-1]
		}
		"done" {
		    LLVMBuildRet $bld [lindex $tcl_stack end]
		    set ends_with_jump($curr_block) 1
		}
		default {
		    error "unknown bytecode '$opcode' in '$l'"
		}
	    }
	}
    }

    puts "Fix increment paths"
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

    puts "----- Input --------------------------------------------------"
    puts [LLVMModuleDump $m]
    puts "----- Optimized ----------------------------------------------"
    LLVMOptimizeModule $m
    puts [LLVMModuleDump $m]
    puts "--------------------------------------------------------------"
    return [list $m $func]
}

lassign [tcl2llvm test] m func

set tclArgs {10 2 3 4 5}
set llvmArgs {}
foreach v $tclArgs {
    lappend llvmArgs [LLVMCreateGenericValueOfInt [LLVMInt32Type] $v 0]
}

lassign [LLVMCreateJITCompilerForModule $m 0] rt EE msg
set res [LLVMRunFunction_Tcl $EE $func $llvmArgs]
puts "test = [test {*}$tclArgs] = [expr {int([LLVMGenericValueToInt $res 0])}]\n"

#puts [time {test 1 2 3 4 5} 1000]
#puts [time {LLVMRunFunction_Tcl $EE $func [list $i0 $i1 $i2 $i3 $i4]} 1000]
