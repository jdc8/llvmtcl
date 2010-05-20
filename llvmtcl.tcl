namespace eval llvmtcl {
    namespace export *

    variable funcid -1

    proc LLVMOptimizeModule {m optimizeLevel optimizeSize unitAtATime unrollLoops simplifyLibCalls haveExceptions} {
	set pm [LLVMCreatePassManager]
	LLVMCreateStandardModulePasses $pm $optimizeLevel $optimizeSize $unitAtATime $unrollLoops $simplifyLibCalls $haveExceptions
	LLVMRunPassManager $pm $m
	LLVMDisposePassManager $pm
    }

    proc LLVMOptimizeFunction {m f optimizeLevel} {
	set fpm [LLVMCreateFunctionPassManagerForModule $m]
	LLVMCreateStandardFunctionPasses $fpm $optimizeLevel
	LLVMInitializeFunctionPassManager $fpm
	LLVMRunFunctionPassManager $fpm $f
	LLVMFinalizeFunctionPassManager $fpm
	LLVMDisposePassManager $fpm
    }

    proc LLVMTclAddFunctionTable {m} {
	variable funcid
	variable funcar
	variable funcidar
	set t [LLVMPointerType [LLVMInt8Type] 0]
	set at [LLVMArrayType $t 100]
	set ft [LLVMAddGlobal $m $at "__tclftable"]
	set v [LLVMConstIntToPtr [LLVMConstInt [LLVMInt32Type] 0 0] $t]
	set va [LLVMConstArray $t [lrepeat 100 $v]]
	LLVMSetInitializer $ft $va
	set bld [LLVMCreateBuilder]
	set fpt [LLVMPointerType [LLVMInt8Type] 0]
	set func [LLVMAddFunction $m "__get_functionpointer" [LLVMFunctionType $fpt [list [LLVMInt32Type]] 0]]
	set block [LLVMAppendBasicBlock $func ""]
	LLVMPositionBuilderAtEnd $bld $block
	set ft [LLVMGetNamedGlobal $m "__tclftable"]
	set tsl [LLVMBuildGEP $bld $ft [list [LLVMConstInt [LLVMInt32Type] 0 0] [LLVMGetParam $func 0]] ""]
	LLVMBuildRet $bld [LLVMBuildLoad $bld $tsl ""]
	LLVMDisposeBuilder $bld
	set funcar($m,__get_functionpointer) $func
	set funcidar($m,__get_functionpointer) [incr funcid]
	return $func
    }

    proc LLVMTclInitFunctionTable {m} {
	variable funcid
	variable funcar
	variable funcidar
	set bld [LLVMCreateBuilder]
	set func [LLVMAddFunction $m "__init_tcltable" [LLVMFunctionType [LLVMVoidType] {} 0]]
	set funcar($m,__init_tcltable) $func
	set funcidar($m,__init_tcltable) [incr funcid]
	set block [LLVMAppendBasicBlock $func ""]
	LLVMPositionBuilderAtEnd $bld $block
	set ft [LLVMGetNamedGlobal $m "__tclftable"]
	foreach {k v} [array get funcidar "$m,*"] {
	    set tsl [LLVMBuildGEP $bld $ft [list [LLVMConstInt [LLVMInt32Type] 0 0] [LLVMConstInt [LLVMInt32Type] $v 0]] ""]
	    LLVMBuildStore $bld [LLVMBuildPointerCast $bld $funcar($k) [LLVMPointerType [LLVMInt8Type] 0] ""] $tsl
	}
	LLVMBuildRetVoid $bld
	LLVMDisposeBuilder $bld
	return $func
    }

    proc Tcl2LLVM {m procName {functionDeclarationOnly 0}} {
	variable tstp
	variable ts
	variable tsp
	variable funcar
	variable funcidar
	variable funcid
	# Disassemble the proc
	set dasm [split [tcl::unsupported::disassemble proc $procName] \n]
	# Create builder
	set bld [LLVMCreateBuilder]
	# Create function
	if {![info exists funcar($m,$procName)]} {
	    set argl {}
	    foreach l $dasm {
		set l [string trim $l]
		if {[regexp {slot \d+, .*arg, \"} $l]} {
		    lappend argl [LLVMInt32Type]
		}
	    }
	    set ft [LLVMFunctionType [LLVMInt32Type] $argl 0]
	    set func [LLVMAddFunction $m $procName $ft]
	    set funcar($m,$procName) $func
	    set funcidar($m,$procName) [incr funcid]
	}
	if {$functionDeclarationOnly} {
	    return $funcar($m,$procName)
	}
	set func $funcar($m,$procName)
	# Create basic blocks
	set block(0) [LLVMAppendBasicBlock $func "block0"]
	set next_is_ipath -1
	foreach l $dasm {
	    set l [string trim $l]
	    if {![string match "(*" $l]} { continue }
	    set opcode [lindex $l 1]
	    if {$next_is_ipath >= 0} {
		regexp {\((\d+)\) } $l -> pc
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
		if {![info exists block($tgt)]} {
		    set block($tgt) [LLVMAppendBasicBlock $func "block$tgt"]
		}
		set next_is_ipath $pc
	    }
	}
	LLVMPositionBuilderAtEnd $bld $block(0)
	set curr_block $block(0)
	# Create stack and stack pointer
	set tstp [LLVMPointerType [LLVMInt8Type] 0]
	set at [LLVMArrayType [LLVMPointerType [LLVMInt8Type] 0] 100]
	set ts [LLVMBuildArrayAlloca $bld $at [LLVMConstInt [LLVMInt32Type] 1 0] ""]
	set tsp [LLVMBuildAlloca $bld [LLVMInt32Type] ""]
	LLVMBuildStore $bld [LLVMConstInt [LLVMInt32Type] 0 0] $tsp
	# Load arguments into llvm, allocate space for slots
	set n 0
	foreach l $dasm {
	    set l [string trim $l]
	    if {[regexp {slot \d+, .*arg, \"} $l]} {
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

	foreach l $dasm {
	    puts $l
	    set l [string trim $l]
	    if {![string match "(*" $l]} { continue }
	    regexp {\((\d+)\) (\S+)} $l -> pc opcode
	    if {[info exists block($pc)]} {
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
		push $bld [LLVMBuildIntCast $bld [LLVMBuildICmp $bld $LLVMBuilderICmp($opcode) $top1 $top0 ""] [LLVMInt32Type] ""]
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
			    if {[info exists funcidar($m,$val)]} {
				set val $funcidar($m,$val)
				puts "push function [lindex $l 4] as $val"
			    } else {
				set val 0
			    }
			}
			push $bld [LLVMConstInt [LLVMInt32Type] $val 0]
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
			set argl {}
			for {set i 0} {$i < ($objc-1)} {incr i} {
			    lappend objv [pop $bld]
			    lappend argl [LLVMInt32Type]
			}
			set objv [lreverse $objv]
			set f [pop $bld] ;# id of function to be called
			# Lookup f in array of function pointer (as void*)
			set vfptr [LLVMBuildCall $bld $funcar($m,__get_functionpointer) $f ""]
			# convert the type and call
			set ft [LLVMFunctionType [LLVMInt32Type] $argl 0]
			set fptr [LLVMBuildPointerCast $bld $vfptr [LLVMPointerType $ft 0] ""]
			# call the function
			push $bld [LLVMBuildCall $bld $fptr $objv ""]
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
	# Set increment paths
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
	# Cleanup and return
	LLVMDisposeBuilder $bld
	return $func
    }

    proc push {bld val} {
	variable tstp
	variable ts
	variable tsp
	# Allocate space for value
	puts 1
	set valp [LLVMBuildAlloca $bld [LLVMInt32Type] ""]
	puts 2
	LLVMBuildStore $bld $val $valp
	# Store location on stack
	puts 3
	set tspv [LLVMBuildLoad $bld $tsp ""]
	puts 4
	set tsl [LLVMBuildGEP $bld $ts [list [LLVMConstInt [LLVMInt32Type] 0 0] $tspv] ""]
	puts 4.5
	LLVMBuildStore $bld [LLVMBuildPointerCast $bld $valp $tstp ""] $tsl
	# Update stack pointer
	puts 5
	set tspv [LLVMBuildAdd $bld $tspv [LLVMConstInt [LLVMInt32Type] 1 0] ""]
	puts 6
	LLVMBuildStore $bld $tspv $tsp
	puts 7
    }
    
    proc pop {bld} {
	variable ts
	variable tsp
	# Get location from stack and decrement the stack pointer
	set tspv [LLVMBuildLoad $bld $tsp ""]
	set tspv [LLVMBuildAdd $bld $tspv [LLVMConstInt [LLVMInt32Type] -1 0] ""]
	LLVMBuildStore $bld $tspv $tsp
	set tsl [LLVMBuildGEP $bld $ts [list [LLVMConstInt [LLVMInt32Type] 0 0] $tspv] ""]
	set valp [LLVMBuildLoad $bld $tsl ""]
	# Load value
	return [LLVMBuildLoad $bld [LLVMBuildPointerCast $bld $valp [LLVMPointerType [LLVMInt32Type] 0] ""] ""]
    }
    
    proc top {bld {offset 0}} {
	variable ts
	variable tsp
	# Get location from stack
	set tspv [LLVMBuildLoad $bld $tsp ""]
	set tspv [LLVMBuildAdd $bld $tspv [LLVMConstInt [LLVMInt32Type] -1 0] ""]
	set tsl [LLVMBuildGEP $bld $ts [list [LLVMConstInt [LLVMInt32Type] 0 0] $tspv] ""]
	set valp [LLVMBuildLoad $bld $tsl ""]
	# Load value
	return [LLVMBuildLoad $bld [LLVMBuildPointerCast $bld $valp [LLVMPointerType [LLVMInt32Type] 0] ""] ""]
    }
}
