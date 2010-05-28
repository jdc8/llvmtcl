namespace eval llvmtcl {
    namespace export *
    namespace ensemble create

    proc OptimizeModule {m optimizeLevel optimizeSize unitAtATime unrollLoops simplifyLibCalls haveExceptions targetDataRef} {
	set pm [llvmtcl CreatePassManager]
	llvmtcl AddTargetData $targetDataRef $pm
	llvmtcl CreateStandardModulePasses $pm $optimizeLevel $optimizeSize $unitAtATime $unrollLoops $simplifyLibCalls $haveExceptions
	llvmtcl RunPassManager $pm $m
	llvmtcl DisposePassManager $pm
    }

    proc OptimizeFunction {m f optimizeLevel targetDataRef} {
	set fpm [llvmtcl CreateFunctionPassManagerForModule $m]
	llvmtcl AddTargetData $targetDataRef $fpm
	llvmtcl CreateStandardFunctionPasses $fpm $optimizeLevel
	llvmtcl InitializeFunctionPassManager $fpm
	llvmtcl RunFunctionPassManager $fpm $f
	llvmtcl FinalizeFunctionPassManager $fpm
	llvmtcl DisposePassManager $fpm
    }

    proc Optimize {m funcList} {
	set td [llvmtcl CreateTargetData ""]
	llvmtcl SetDataLayout $m [llvmtcl CopyStringRepOfTargetData $td]
	foreach f $funcList {
	    llvmtcl OptimizeFunction $m $f 3 $td
	}
	llvmtcl OptimizeModule $m 3 0 1 1 1 0 $td
    }

    proc Execute {m f args} {
	lassign [llvmtcl CreateJITCompilerForModule $m 0] rt EE msg
	set largs {}
	foreach arg $args {
	    lappend largs [llvmtcl CreateGenericValueOfInt [llvmtcl Int32Type] $arg 0]
	}
	set rt [llvmtcl GenericValueToInt [llvmtcl RunFunction $EE $f $largs] 0]
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
	set bld [llvmtcl CreateBuilder]
	# Create function
	if {![info exists funcar($m,$procName)]} {
	    set argl {}
	    foreach l $dasm {
		set l [string trim $l]
		if {[regexp {slot \d+, .*arg, \"} $l]} {
		    lappend argl [llvmtcl Int32Type]
		}
	    }
	    set ft [llvmtcl FunctionType [llvmtcl Int32Type] $argl 0]
	    set func [llvmtcl AddFunction $m $procName $ft]
	    set funcar($m,$procName) $func
	}
	if {$functionDeclarationOnly} {
	    return $funcar($m,$procName)
	}
	set func $funcar($m,$procName)
	# Create basic blocks
	set block(0) [llvmtcl AppendBasicBlock $func "block0"]
	set next_is_ipath -1
	foreach l $dasm {
	    set l [string trim $l]
	    if {![string match "(*" $l]} { continue }
	    set opcode [lindex $l 1]
	    if {$next_is_ipath >= 0} {
		regexp {\((\d+)\) } $l -> pc
		if {![info exists block($pc)]} {
		    set block($pc) [llvmtcl AppendBasicBlock $func "block$pc"]
		}
		set ipath($next_is_ipath) $pc
		set next_is_ipath -1
	    }
	    if {[string match "jump*1" $opcode] || [string match "jump*4" $opcode] || [string match "startCommand" $opcode]} {
		# (pc) opcode offset
		regexp {\((\d+)\) (jump\S*[14]|startCommand) (\+*\-*\d+)} $l -> pc cmd offset
		set tgt [expr {$pc + $offset}]
		if {![info exists block($tgt)]} {
		    set block($tgt) [llvmtcl AppendBasicBlock $func "block$tgt"]
		}
		set next_is_ipath $pc
	    }
	}
	llvmtcl PositionBuilderAtEnd $bld $block(0)
	set curr_block $block(0)
	# Create stack and stack pointer
	set tstp [llvmtcl PointerType [llvmtcl Int8Type] 0]
	set at [llvmtcl ArrayType [llvmtcl PointerType [llvmtcl Int8Type] 0] 100]
	set ts [llvmtcl BuildArrayAlloca $bld $at [llvmtcl ConstInt [llvmtcl Int32Type] 1 0] ""]
	set tsp [llvmtcl BuildAlloca $bld [llvmtcl Int32Type] ""]
	llvmtcl BuildStore $bld [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] $tsp
	# Load arguments into llvm, allocate space for slots
	set n 0
	foreach l $dasm {
	    set l [string trim $l]
	    if {[regexp {slot \d+, .*arg, \"} $l]} {
		set arg_1 [llvmtcl GetParam $func $n]
		set arg_2 [llvmtcl BuildAlloca $bld [llvmtcl Int32Type] ""]
		set arg_3 [llvmtcl BuildStore $bld $arg_1 $arg_2]
		set vars($n) $arg_2
		incr n
	    } elseif {[string match "slot *" $l]} {
		set arg_2 [llvmtcl BuildAlloca $bld [llvmtcl Int32Type] ""]
		set vars($n) $arg_2
	    }
	}
	# Convert Tcl parse output
	set LLVMBuilder2(bitor) BuildXor
	set LLVMBuilder2(bitxor) BuildOr
	set LLVMBuilder2(bitand) BuildAnd
	set LLVMBuilder2(lshift) BuildShl
	set LLVMBuilder2(rshift) BuildAShr
	set LLVMBuilder2(add) BuildAdd
	set LLVMBuilder2(sub) BuildSub
	set LLVMBuilder2(mult) BuildMul
	set LLVMBuilder2(div) BuildSDiv
	set LLVMBuilder2(mod) BuildSRem

	set LLVMBuilder1(uminus) BuildNeg
	set LLVMBuilder1(bitnot) BuildNot

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
		llvmtcl PositionBuilderAtEnd $bld $block($pc)
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
		push $bld [llvmtcl $LLVMBuilder1($opcode) $bld [pop $bld [llvmtcl Int32Type]] ""]
	    } elseif {[info exists LLVMBuilder2($opcode)]} {
		set top0 [pop $bld [llvmtcl Int32Type]]
		set top1 [pop $bld [llvmtcl Int32Type]]
		push $bld [llvmtcl $LLVMBuilder2($opcode) $bld $top1 $top0 ""]
	    } elseif {[info exists LLVMBuilderICmp($opcode)]} {
		set top0 [pop $bld [llvmtcl Int32Type]]
		set top1 [pop $bld [llvmtcl Int32Type]]
		push $bld [llvmtcl BuildIntCast $bld [llvmtcl BuildICmp $bld $LLVMBuilderICmp($opcode) $top1 $top0 ""] [llvmtcl Int32Type] ""]
	    } else {
		switch -exact -- $opcode {
		    "loadScalar1" {
			set var $vars([string range [lindex $l 2] 2 end])
			push $bld [llvmtcl BuildLoad $bld $var ""]
		    }
		    "storeScalar1" {
			set var_1 [top $bld [llvmtcl Int32Type]]
			set idx [string range [lindex $l 2] 2 end]
			if {[info exists vars($idx)]} {
			    set var_2 $vars($idx)
			} else {
			    set var_2 [llvmtcl BuildAlloca $bld [llvmtcl Int32Type] ""]
			}
			set var_3 [llvmtcl BuildStore $bld $var_1 $var_2]
			set vars($idx) $var_2
		    }
		    "incrScalar1" {
			set var $vars([string range [lindex $l 2] 2 end])
			llvmtcl BuildStore $bld [llvmtcl BuildAdd $bld [llvmtcl BuildLoad $bld $var ""] [top $bld [llvmtcl Int32Type]] ""] $var
		    }
		    "incrScalar1Imm" {
			set var $vars([string range [lindex $l 2] 2 end])
			set i [lindex $l 3]
			set s [llvmtcl BuildAdd $bld [llvmtcl BuildLoad $bld $var ""] [llvmtcl ConstInt [llvmtcl Int32Type] $i 0] ""]
			push $bld $s
			llvmtcl BuildStore $bld $s $var
		    }
		    "push1" {
			set tval [lindex $l 4]
			if {[string is integer -strict $tval]} {
			    set val [llvmtcl ConstInt [llvmtcl Int32Type] $tval 0]
			} elseif {[info exists funcar($m,$tval)]} {
			    set val $funcar($m,$tval)
			} else {
			    set val [llvmtcl ConstInt [llvmtcl Int32Type] 0 0]
			}
			push $bld $val
		    }
		    "jumpTrue4" -
		    "jumpTrue1" {
			set top [pop $bld [llvmtcl Int32Type]]
			if {[llvmtcl GetIntTypeWidth [llvmtcl TypeOf $top]] == 1} {
			    set cond $top
			} else {
			    set cond [llvmtcl BuildICmp $bld LLVMIntNE $top [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] ""]
			}
			llvmtcl BuildCondBr $bld $cond $block($tgt) $block($ipath($pc))
			set ends_with_jump($curr_block) 1
		    }
		    "jumpFalse4" -
		    "jumpFalse1" {
			set top [pop $bld [llvmtcl Int32Type]]
			if {[llvmtcl GetIntTypeWidth [llvmtcl TypeOf $top]] == 1} {
			    set cond $top
			} else {
			    set cond [llvmtcl BuildICmp $bld LLVMIntNE $top [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] ""]
			}
			llvmtcl BuildCondBr $bld $cond $block($ipath($pc)) $block($tgt)
			set ends_with_jump($curr_block) 1
		    }
		    "tryCvtToNumeric" {
			push $bld [pop $bld [llvmtcl Int32Type]]
		    }
		    "startCommand" {
		    }
		    "jump4" -
		    "jump1" {
			llvmtcl BuildBr $bld $block($tgt)
			set ends_with_jump($curr_block) 1
		    }
		    "invokeStk1" {
			set objc [lindex $l 2]
			set objv {}
			set argl {}
			for {set i 0} {$i < ($objc-1)} {incr i} {
			    lappend objv [pop $bld [llvmtcl Int32Type]]
			    lappend argl [llvmtcl Int32Type]
			}
			set objv [lreverse $objv]
			set ft [llvmtcl PointerType [llvmtcl FunctionType [llvmtcl Int32Type] $argl 0] 0]
			set fptr [pop $bld $ft]
			push $bld [llvmtcl BuildCall $bld $fptr $objv ""]
		    }
		    "pop" {
			pop $bld [llvmtcl Int32Type]
		    }
		    "done" {
			if {!$done_done} {
			    llvmtcl BuildRet $bld [top $bld [llvmtcl Int32Type]]
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
	    llvmtcl PositionBuilderAtEnd $bld $block($pc)
	    if {![info exists ends_with_jump($block($pc))] || !$ends_with_jump($block($pc))} {
		set tpc [expr {$pc+1}]
		while {$tpc < 1000} {
		    if {[info exists block($tpc)]} {
			llvmtcl BuildBr $bld $block($tpc)
			break
		    }
		    incr tpc
		}
	    }
	}
	# Cleanup and return
	llvmtcl DisposeBuilder $bld
	return $func
    }

    # Helper functions, should not be called directly

    proc AddTcl2LLVMUtils {m} {
	variable funcar
	variable utils_added
	set bld [llvmtcl CreateBuilder]
	set ft [llvmtcl FunctionType [llvmtcl Int32Type] [list [llvmtcl Int32Type]] 0]
	set func [llvmtcl AddFunction $m "llvm_mathfunc_int" $ft]
	set funcar($m,tcl::mathfunc::int) $func
	set block [llvmtcl AppendBasicBlock $func "block"]
	llvmtcl PositionBuilderAtEnd $bld $block
	llvmtcl BuildRet $bld [llvmtcl GetParam $func 0]
	llvmtcl DisposeBuilder $bld
	set utils_added($m) 1
    }

    proc push {bld val} {
	variable tstp
	variable ts
	variable tsp
	# Allocate space for value
	set valt [llvmtcl TypeOf $val]
	set valp [llvmtcl BuildAlloca $bld $valt "push"]
	llvmtcl BuildStore $bld $val $valp
	# Store location on stack
	set tspv [llvmtcl BuildLoad $bld $tsp "push"]
	set tsl [llvmtcl BuildGEP $bld $ts [list [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] $tspv] "push"]
	llvmtcl BuildStore $bld [llvmtcl BuildPointerCast $bld $valp $tstp ""] $tsl
	# Update stack pointer
	set tspv [llvmtcl BuildAdd $bld $tspv [llvmtcl ConstInt [llvmtcl Int32Type] 1 0] "push"]
	llvmtcl BuildStore $bld $tspv $tsp
    }
    
    proc pop {bld valt} {
	variable ts
	variable tsp
	# Get location from stack and decrement the stack pointer
	set tspv [llvmtcl BuildLoad $bld $tsp "pop"]
	set tspv [llvmtcl BuildAdd $bld $tspv [llvmtcl ConstInt [llvmtcl Int32Type] -1 0] "pop"]
	llvmtcl BuildStore $bld $tspv $tsp
	set tsl [llvmtcl BuildGEP $bld $ts [list [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] $tspv] "pop"]
	set valp [llvmtcl BuildLoad $bld $tsl "pop"]
	# Load value
	set pc [llvmtcl BuildPointerCast $bld $valp [llvmtcl PointerType $valt 0] "pop"]
	set rt [llvmtcl BuildLoad $bld $pc "pop"]
	return $rt
    }
    
    proc top {bld valt {offset 0}} {
	variable ts
	variable tsp
	# Get location from stack
	set tspv [llvmtcl BuildLoad $bld $tsp "top"]
	set tspv [llvmtcl BuildAdd $bld $tspv [llvmtcl ConstInt [llvmtcl Int32Type] -1 0] "top"]
	set tsl [llvmtcl BuildGEP $bld $ts [list [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] $tspv] "top"]
	set valp [llvmtcl BuildLoad $bld $tsl "top"]
	# Load value
	return [llvmtcl BuildLoad $bld [llvmtcl BuildPointerCast $bld $valp [llvmtcl PointerType $valt 0] "top"] "top"]
    }
}
