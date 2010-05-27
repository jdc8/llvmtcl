namespace eval llvmtcl {
    namespace export *

    proc LLVMOptimizeModule {m optimizeLevel optimizeSize unitAtATime unrollLoops simplifyLibCalls haveExceptions targetDataRef} {
	set pm [LLVMCreatePassManager]
	LLVMAddTargetData $targetDataRef $pm
	LLVMCreateStandardModulePasses $pm $optimizeLevel $optimizeSize $unitAtATime $unrollLoops $simplifyLibCalls $haveExceptions
	LLVMRunPassManager $pm $m
	LLVMDisposePassManager $pm
    }

    proc LLVMOptimizeFunction {m f optimizeLevel targetDataRef} {
	set fpm [LLVMCreateFunctionPassManagerForModule $m]
	LLVMAddTargetData $targetDataRef $fpm
	LLVMCreateStandardFunctionPasses $fpm $optimizeLevel
	LLVMInitializeFunctionPassManager $fpm
	LLVMRunFunctionPassManager $fpm $f
	LLVMFinalizeFunctionPassManager $fpm
	LLVMDisposePassManager $fpm
    }

    proc AddTcl2LLVMUtils {m} {
	variable funcar
	variable utils_added
	set bld [LLVMCreateBuilder]
	set ft [LLVMFunctionType [LLVMInt32Type] [list [LLVMInt32Type]] 0]
	set func [LLVMAddFunction $m "llvm_mathfunc_int" $ft]
	set funcar($m,tcl::mathfunc::int) $func
	set block [LLVMAppendBasicBlock $func "block"]
	LLVMPositionBuilderAtEnd $bld $block
	LLVMBuildRet $bld [LLVMGetParam $func 0]
	LLVMDisposeBuilder $bld
	set utils_added($m) 1
    }

    proc Tcl2LLVM {m procName {functionDeclarationOnly 0}} {
	variable tstp
	variable ts
	variable tsp
	variable funcar
	variable utils_added
	if {![info exists utils_added($m)] || !$utils_added($m)} {
	    AddTcl2LLVMUtils $m
	}
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
	    if {[string match "jump*1" $opcode] || [string match "jump*4" $opcode] || [string match "startCommand" $opcode]} {
		# (pc) opcode offset
		regexp {\((\d+)\) (jump\S*[14]|startCommand) (\+*\-*\d+)} $l -> pc cmd offset
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

	set done_done 0
	foreach l $dasm {
	    #puts $l
	    set l [string trim $l]
	    if {![string match "(*" $l]} { continue }
	    regexp {\((\d+)\) (\S+)} $l -> pc opcode
	    if {[info exists block($pc)]} {
		LLVMPositionBuilderAtEnd $bld $block($pc)
		set curr_block $block($pc)
		set done_done 0
	    }
	    set ends_with_jump($curr_block) 0
	    unset -nocomplain tgt
	    if {[string match "jump*1" $opcode] || [string match "jump*4" $opcode] || [string match "startCommand" $opcode]} {
		regexp {\(\d+\) (jump\S*[14]|startCommand) (\+*\-*\d+)} $l -> cmd offset
		set tgt [expr {$pc + $offset}]
	    }
	    if {[info exists LLVMBuilder1($opcode)]} {
		push $bld [$LLVMBuilder1($opcode) $bld [pop $bld [LLVMInt32Type]] ""]
	    } elseif {[info exists LLVMBuilder2($opcode)]} {
		set top0 [pop $bld [LLVMInt32Type]]
		set top1 [pop $bld [LLVMInt32Type]]
		push $bld [$LLVMBuilder2($opcode) $bld $top1 $top0 ""]
	    } elseif {[info exists LLVMBuilderICmp($opcode)]} {
		set top0 [pop $bld [LLVMInt32Type]]
		set top1 [pop $bld [LLVMInt32Type]]
		push $bld [LLVMBuildIntCast $bld [LLVMBuildICmp $bld $LLVMBuilderICmp($opcode) $top1 $top0 ""] [LLVMInt32Type] ""]
	    } else {
		switch -exact -- $opcode {
		    "loadScalar1" {
			set var $vars([string range [lindex $l 2] 2 end])
			push $bld [LLVMBuildLoad $bld $var ""]
		    }
		    "storeScalar1" {
			set var_1 [top $bld [LLVMInt32Type]]
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
			LLVMBuildStore $bld [LLVMBuildAdd $bld [LLVMBuildLoad $bld $var ""] [top $bld [LLVMInt32Type]] ""] $var
		    }
		    "incrScalar1Imm" {
			set var $vars([string range [lindex $l 2] 2 end])
			set i [lindex $l 3]
			set s [LLVMBuildAdd $bld [LLVMBuildLoad $bld $var ""] [LLVMConstInt [LLVMInt32Type] $i 0] ""]
			push $bld $s
			LLVMBuildStore $bld $s $var
		    }
		    "push1" {
			set tval [lindex $l 4]
			if {[string is integer -strict $tval]} {
			    set val [LLVMConstInt [LLVMInt32Type] $tval 0]
			} elseif {[info exists funcar($m,$tval)]} {
			    set val $funcar($m,$tval)
			} else {
			    set val [LLVMConstInt [LLVMInt32Type] 0 0]
			}
			push $bld $val
		    }
		    "jumpTrue4" -
		    "jumpTrue1" {
			set top [pop $bld [LLVMInt32Type]]
			if {[LLVMGetIntTypeWidth [LLVMTypeOf $top]] == 1} {
			    set cond $top
			} else {
			    set cond [LLVMBuildICmp $bld LLVMIntNE $top [LLVMConstInt [LLVMInt32Type] 0 0] ""]
			}
			LLVMBuildCondBr $bld $cond $block($tgt) $block($ipath($pc))
			set ends_with_jump($curr_block) 1
		    }
		    "jumpFalse4" -
		    "jumpFalse1" {
			set top [pop $bld [LLVMInt32Type]]
			if {[LLVMGetIntTypeWidth [LLVMTypeOf $top]] == 1} {
			    set cond $top
			} else {
			    set cond [LLVMBuildICmp $bld LLVMIntNE $top [LLVMConstInt [LLVMInt32Type] 0 0] ""]
			}
			LLVMBuildCondBr $bld $cond $block($ipath($pc)) $block($tgt)
			set ends_with_jump($curr_block) 1
		    }
		    "tryCvtToNumeric" {
			push $bld [pop $bld [LLVMInt32Type]]
		    }
		    "startCommand" {
		    }
		    "jump4" -
		    "jump1" {
			LLVMBuildBr $bld $block($tgt)
			set ends_with_jump($curr_block) 1
		    }
		    "invokeStk1" {
			set objc [lindex $l 2]
			set objv {}
			set argl {}
			for {set i 0} {$i < ($objc-1)} {incr i} {
			    lappend objv [pop $bld [LLVMInt32Type]]
			    lappend argl [LLVMInt32Type]
			}
			set objv [lreverse $objv]
			set ft [LLVMPointerType [LLVMFunctionType [LLVMInt32Type] $argl 0] 0]
			set fptr [pop $bld $ft]
			push $bld [LLVMBuildCall $bld $fptr $objv ""]
		    }
		    "pop" {
			pop $bld [LLVMInt32Type]
		    }
		    "done" {
			if {!$done_done} {
			    LLVMBuildRet $bld [top $bld [LLVMInt32Type]]
			    set ends_with_jump($curr_block) 1
			    set done_done 1
			}
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
	set valt [LLVMTypeOf $val]
	set valp [LLVMBuildAlloca $bld $valt "push"]
	LLVMBuildStore $bld $val $valp
	# Store location on stack
	set tspv [LLVMBuildLoad $bld $tsp "push"]
	set tsl [LLVMBuildGEP $bld $ts [list [LLVMConstInt [LLVMInt32Type] 0 0] $tspv] "push"]
	LLVMBuildStore $bld [LLVMBuildPointerCast $bld $valp $tstp ""] $tsl
	# Update stack pointer
	set tspv [LLVMBuildAdd $bld $tspv [LLVMConstInt [LLVMInt32Type] 1 0] "push"]
	LLVMBuildStore $bld $tspv $tsp
    }
    
    proc pop {bld valt} {
	variable ts
	variable tsp
	# Get location from stack and decrement the stack pointer
	set tspv [LLVMBuildLoad $bld $tsp "pop"]
	set tspv [LLVMBuildAdd $bld $tspv [LLVMConstInt [LLVMInt32Type] -1 0] "pop"]
	LLVMBuildStore $bld $tspv $tsp
	set tsl [LLVMBuildGEP $bld $ts [list [LLVMConstInt [LLVMInt32Type] 0 0] $tspv] "pop"]
	set valp [LLVMBuildLoad $bld $tsl "pop"]
	# Load value
	set pc [LLVMBuildPointerCast $bld $valp [LLVMPointerType $valt 0] "pop"]
	set rt [LLVMBuildLoad $bld $pc "pop"]
	return $rt
    }
    
    proc top {bld valt {offset 0}} {
	variable ts
	variable tsp
	# Get location from stack
	set tspv [LLVMBuildLoad $bld $tsp "top"]
	set tspv [LLVMBuildAdd $bld $tspv [LLVMConstInt [LLVMInt32Type] -1 0] "top"]
	set tsl [LLVMBuildGEP $bld $ts [list [LLVMConstInt [LLVMInt32Type] 0 0] $tspv] "top"]
	set valp [LLVMBuildLoad $bld $tsl "top"]
	# Load value
	return [LLVMBuildLoad $bld [LLVMBuildPointerCast $bld $valp [LLVMPointerType $valt 0] "top"] "top"]
    }
}
