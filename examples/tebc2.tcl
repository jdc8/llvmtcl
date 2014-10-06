lappend auto_path ..
package require llvmtcl

namespace eval LLVM {
    namespace path ::llvmtcl
    LinkInJIT
    InitializeNativeTarget
    variable counter 0
    variable optimiseRounds 10;#10
    variable dumpPre {}
    variable dumpPost {}
    variable int32 [Int32Type]

    variable unaryOpcode
    array set unaryOpcode {
	uminus BuildNeg
	bitnot BuildNot
    }
    variable binaryOpcode
    array set binaryOpcode {
	bitor BuildXor
	bitxor BuildOr
	bitand BuildAnd
	lshift BuildShl
	rshift BuildAShr
	add BuildAdd
	sub BuildSub
	mult BuildMul
	div BuildSDiv
	mod BuildSRem
    }
    variable comparison
    array set comparison {
	eq LLVMIntEQ
	neq LLVMIntNE
	lt LLVMIntSLT
	gt LLVMIntSGT
	le LLVMIntSLE
	ge LLVMIntGE
    }

    proc DisassembleTclBytecode {procName} {
	lmap line [split [::tcl::unsupported::disassemble proc $procName] \n] {
	    string trim $line
	}
    }

    proc GenerateDeclaration {m procName} {
	variable tstp
	variable ts
	variable tsp
	variable funcar
	variable int32
	# Disassemble the proc
	set dasm [DisassembleTclBytecode $procName]
	# Create function
	if {[info exists funcar($m,$procName)]} {
	    error "duplicate $procName"
	}
	set argl {}
	foreach l $dasm {
	    set l [string trim $l]
	    if {[regexp {slot \d+, .*arg, [""]} $l]} {
		lappend argl $int32
	    }
	}
	set ft [FunctionType $int32 $argl 0]
	set func [AddFunction $m $procName $ft]
	return [set funcar($m,$procName) $func]
    }

    proc BytecodeCompile {m procName {functionDeclarationOnly 0}} {
	variable tstp
	variable ts
	variable tsp
	variable funcar
	variable int32
	variable unaryOpcode
	variable binaryOpcode
	variable comparison

	# Disassemble the proc
	set dasm [DisassembleTclBytecode $procName]
	# Create builder
	set bld [CreateBuilder]
	# Create function
	if {![info exists funcar($m,$procName)]} {
	    error "Undeclared $procName"
	}
	set func $funcar($m,$procName)
	# Create basic blocks
	set block(0) [AppendBasicBlock $func "block0"]
	set next_is_ipath -1
	foreach l $dasm {
	    set l [string trim $l]
	    if {![string match "(*" $l]} { continue }
	    set opcode [lindex $l 1]
	    if {$next_is_ipath >= 0} {
		regexp {\((\d+)\) } $l -> pc
		if {![info exists block($pc)]} {
		    set block($pc) [AppendBasicBlock $func "block$pc"]
		}
		set ipath($next_is_ipath) $pc
		set next_is_ipath -1
	    }
	    if {[string match {jump*[14]} $opcode] || "startCommand" eq $opcode} {
		# (pc) opcode offset
		regexp {\((\d+)\) (jump\S*[14]|startCommand) (\+*\-*\d+)} $l -> pc cmd offset
		set tgt [expr {$pc + $offset}]
		if {![info exists block($tgt)]} {
		    set block($tgt) [AppendBasicBlock $func "block$tgt"]
		}
		set next_is_ipath $pc
	    }
	}
	PositionBuilderAtEnd $bld $block(0)
	set curr_block $block(0)
	# Create stack and stack pointer
	set tstp [PointerType [Int8Type] 0]
	set at [ArrayType [PointerType [Int8Type] 0] 100]
	set ts [BuildArrayAlloca $bld $at [ConstInt $int32 1 0] ""]
	set tsp [BuildAlloca $bld $int32 ""]
	BuildStore $bld [ConstInt $int32 0 0] $tsp
	# Load arguments into llvm, allocate space for slots
	set n 0
	foreach l $dasm {
	    set l [string trim $l]
	    if {[regexp {slot \d+, .*arg, [""]} $l]} {
		set arg_1 [GetParam $func $n]
		set arg_2 [BuildAlloca $bld $int32 ""]
		set arg_3 [BuildStore $bld $arg_1 $arg_2]
		set vars($n) $arg_2
		incr n
	    } elseif {[string match "slot *" $l]} {
		set arg_2 [BuildAlloca $bld $int32 ""]
		set vars($n) $arg_2
	    }
	}

	# Convert Tcl parse output
	set done_done 0
	foreach l $dasm {
	    #puts $l
	    set l [string trim $l]
	    if {![string match "(*" $l]} { continue }
	    regexp {\((\d+)\) (\S+)} $l -> pc opcode
	    if {[info exists block($pc)]} {
		PositionBuilderAtEnd $bld $block($pc)
		set curr_block $block($pc)
		set done_done 0
	    }
	    set ends_with_jump($curr_block) 0
	    unset -nocomplain tgt
	    if {[string match {jump*[14]} $opcode]} {
		regexp {\(\d+\) (jump\S*[14]|startCommand) (\+*\-*\d+)} $l -> cmd offset
		set tgt [expr {$pc + $offset}]
	    }
	    if {[info exists unaryOpcode($opcode)]} {
		push $bld [$unaryOpcode($opcode) $bld [pop $bld $int32] ""]
	    } elseif {[info exists binaryOpcode($opcode)]} {
		set top0 [pop $bld $int32]
		set top1 [pop $bld $int32]
		push $bld [$binaryOpcode($opcode) $bld $top1 $top0 ""]
	    } elseif {[info exists comparison($opcode)]} {
		set top0 [pop $bld $int32]
		set top1 [pop $bld $int32]
		push $bld [BuildIntCast $bld [BuildICmp $bld $comparison($opcode) $top1 $top0 ""] $int32 ""]
	    } else {
		switch -exact -- $opcode {
		    "loadScalar1" {
			set var $vars([string range [lindex $l 2] 2 end])
			push $bld [BuildLoad $bld $var ""]
		    }
		    "storeScalar1" {
			set var_1 [top $bld $int32]
			set idx [string range [lindex $l 2] 2 end]
			if {[info exists vars($idx)]} {
			    set var_2 $vars($idx)
			} else {
			    set var_2 [BuildAlloca $bld $int32 ""]
			}
			set var_3 [BuildStore $bld $var_1 $var_2]
			set vars($idx) $var_2
		    }
		    "incrScalar1" {
			set var $vars([string range [lindex $l 2] 2 end])
			BuildStore $bld [BuildAdd $bld [BuildLoad $bld $var ""] [top $bld $int32] ""] $var
		    }
		    "incrScalar1Imm" {
			set var $vars([string range [lindex $l 2] 2 end])
			set i [lindex $l 3]
			set s [BuildAdd $bld [BuildLoad $bld $var ""] [ConstInt $int32 $i 0] ""]
			push $bld $s
			BuildStore $bld $s $var
		    }
		    "push1" - "push4" {
			set tval [lindex $l 4]
			if {[string is integer -strict $tval]} {
			    set val [ConstInt $int32 $tval 0]
			} elseif {[info exists funcar($m,$tval)]} {
			    set val $funcar($m,$tval)
			} elseif {$tval eq "tailcall"} {
			    ### HACK! HACK! HACK! ###
			    continue
			} else {
			    set val [ConstInt $int32 0 0]
			}
			push $bld $val
		    }
		    "jumpTrue4" -
		    "jumpTrue1" {
			set top [pop $bld $int32]
			if {[GetIntTypeWidth [TypeOf $top]] == 1} {
			    set cond $top
			} else {
			    set cond [BuildICmp $bld LLVMIntNE $top [ConstInt $int32 0 0] ""]
			}
			BuildCondBr $bld $cond $block($tgt) $block($ipath($pc))
			set ends_with_jump($curr_block) 1
		    }
		    "jumpFalse4" -
		    "jumpFalse1" {
			set top [pop $bld $int32]
			if {[GetIntTypeWidth [TypeOf $top]] == 1} {
			    set cond $top
			} else {
			    set cond [BuildICmp $bld LLVMIntNE $top [ConstInt $int32 0 0] ""]
			}
			BuildCondBr $bld $cond $block($ipath($pc)) $block($tgt)
			set ends_with_jump($curr_block) 1
		    }
		    "tryCvtToNumeric" {
			push $bld [pop $bld $int32]
		    }
		    "startCommand" {
		    }
		    "jump4" -
		    "jump1" {
			BuildBr $bld $block($tgt)
			set ends_with_jump($curr_block) 1
		    }
		    "invokeStk1" {
			set objc [lindex $l 2]
			set objv {}
			set argl {}
			for {set i 0} {$i < ($objc-1)} {incr i} {
			    lappend objv [pop $bld $int32]
			    lappend argl $int32
			}
			set objv [lreverse $objv]
			set ft [PointerType [FunctionType $int32 $argl 0] 0]
			set fptr [pop $bld $ft]
			push $bld [BuildCall $bld $fptr $objv ""]
		    }
		    "tailcall" {
			set objc [lindex $l 2]
			set objv {}
			set argl {}
			for {set i 0} {$i < ($objc-2)} {incr i} {
			    lappend objv [pop $bld $int32]
			    lappend argl $int32
			}
			set objv [lreverse $objv]
			set ft [PointerType [FunctionType $int32 $argl 0] 0]
			set fptr [pop $bld $ft]
			set tc [BuildCall $bld $fptr $objv ""]
			# MAGIC! Requires a recent-enough LLVM to really work
			SetTailCall $tc 2
			push $bld $tc
			BuildRet $bld [top $bld $int32]
			set ends_with_jump($curr_block) 1
			set done_done 1
		    }
		    "pop" {
			pop $bld $int32
		    }
		    "done" {
			if {!$done_done} {
			    BuildRet $bld [top $bld $int32]
			    set ends_with_jump($curr_block) 1
			    set done_done 1
			}
		    }
		    "nop" {
		    }
		    "unsetScalar" {
			# Do nothing; it's not *right* but it's OK with ints
		    }
		    default {
			error "unknown bytecode '$opcode' in '$l'"
		    }
		}
	    }
	}

	# Set increment paths
	foreach {pc b} [array get block] {
	    PositionBuilderAtEnd $bld $block($pc)
	    if {!$ends_with_jump($block($pc))} {
		for {set tpc [expr {$pc+1}]} {$tpc < 1000} {incr tpc} {
		    if {[info exists block($tpc)]} {
			BuildBr $bld $block($tpc)
			break
		    }
		}
	    }
	}

	# Cleanup and return
	DisposeBuilder $bld
	return $func
    }

    # Helper functions, should not be called directly

    proc AddUtils {m} {
	variable funcar
	variable int32
	set bld [CreateBuilder]
	set ft [FunctionType $int32 [list $int32] 0]
	set func [AddFunction $m "llvm_mathfunc_int" $ft]
	set funcar($m,tcl::mathfunc::int) $func
	set block [AppendBasicBlock $func "block"]
	PositionBuilderAtEnd $bld $block
	BuildRet $bld [GetParam $func 0]
	DisposeBuilder $bld
    }

    proc push {bld val} {
	variable tstp
	variable ts
	variable tsp
	variable int32
	# Allocate space for value
	set valt [TypeOf $val]
	set valp [BuildAlloca $bld $valt "push"]
	BuildStore $bld $val $valp
	# Store location on stack
	set tspv [BuildLoad $bld $tsp "push"]
	set tsl [BuildGEP $bld $ts [list [ConstInt $int32 0 0] $tspv] "push"]
	BuildStore $bld [BuildPointerCast $bld $valp $tstp ""] $tsl
	# Update stack pointer
	set tspv [BuildAdd $bld $tspv [ConstInt $int32 1 0] "push"]
	BuildStore $bld $tspv $tsp
    }
    
    proc pop {bld valt} {
	variable ts
	variable tsp
	variable int32
	# Get location from stack and decrement the stack pointer
	set tspv [BuildLoad $bld $tsp "pop"]
	set tspv [BuildAdd $bld $tspv [ConstInt $int32 -1 0] "pop"]
	BuildStore $bld $tspv $tsp
	set tsl [BuildGEP $bld $ts [list [ConstInt $int32 0 0] $tspv] "pop"]
	set valp [BuildLoad $bld $tsl "pop"]
	# Load value
	set pc [BuildPointerCast $bld $valp [PointerType $valt 0] "pop"]
	set rt [BuildLoad $bld $pc "pop"]
	return $rt
    }
    
    proc top {bld valt {offset 0}} {
	variable ts
	variable tsp
	variable int32
	# Get location from stack
	set tspv [BuildLoad $bld $tsp "top"]
	set tspv [BuildAdd $bld $tspv [ConstInt $int32 -1 0] "top"]
	set tsl [BuildGEP $bld $ts [list [ConstInt $int32 0 0] $tspv] "top"]
	set valp [BuildLoad $bld $tsl "top"]
	# Load value
	return [BuildLoad $bld \
		[BuildPointerCast $bld $valp [PointerType $valt 0] "top"] "top"]
    }



    proc optimise {args} {
	variable counter
	variable optimiseRounds
	variable int32

	set module [ModuleCreateWithName "module[incr counter] [uplevel 1 namespace current]"]
	AddUtils $module
	foreach p $args {
	    set cmd [uplevel 1 [list namespace which $p]]
	    lappend cmds $cmd
	    uplevel 1 [list [namespace which GenerateDeclaration] $module $p]
	}
	set funcs [lmap f $args {
	    uplevel 1 [list [namespace which BytecodeCompile] $module $f]
	}]

	variable dumpPre [DumpModule $module]

	lassign [VerifyModule $module LLVMReturnStatusAction] rt msg
	if {$rt} {
	    return -code error $msg
	}
	for {set i 0} {$i < $optimiseRounds} {incr i} {
	    Optimize $module $funcs
	}

	variable dumpPost [DumpModule $module]

	lassign [VerifyModule $module LLVMReturnStatusAction] rt msg
	if {$rt} {
	    return -code error $msg
	}
	lassign [CreateJITCompilerForModule $module 0] rt ee msg
	if {$rt} {
	    return -code error $msg
	}
	foreach cmd $cmds func $funcs {
	    CreateProcedureThunk ${cmd} $ee $func [info args $cmd]
	}
	return $module
    }
    proc pre {} {
	variable dumpPre
	return $dumpPre
    }
    proc post {} {
	variable dumpPost
	return $dumpPost
    }

    namespace export optimise pre post
    namespace ensemble create
}

# Example code
proc f n {
    set r 0
    for {set i 0} {$i<$n} {incr i} {
	incr r [expr {($r-$n*$n+$i) & 0xffffff}]
    }
    return $r
}
proc g n {
    expr {[f $n] & 0xffff}
}
proc fact n {expr {
    $n<2? 1: $n * [fact [incr n -1]]
}}
proc fib n {tailcall fibin $n 0 1}
proc fibin {n a b} {expr {
    $n<=0 ? $a : [fibin [expr {$n-1}] $b [expr {$a+$b}]]
}}
proc fib2 n {
    for {set a 0; set b 1} {$n > 0} {incr n -1} {
	set b [expr {$a + [set a $b]}]
    }
    return $a
}

# Baseline
puts tailrec:[time {fib 20} 100000]
puts iterate:[time {fib2 20} 100000]
puts [tcl::unsupported::disassemble proc fib2]
# Convert to optimised form
LLVM optimise f g fact fib fibin fib2
# Write out the generated code
puts [LLVM post]
# Compare with baseline
puts tailrec:[time {fib 20} 100000]
puts iterate:[time {fib2 20} 100000]
