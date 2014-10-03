lappend auto_path ..
package require llvmtcl

namespace eval LLVM {
    llvmtcl LinkInJIT
    llvmtcl InitializeNativeTarget
    variable counter 0
    variable optimiseRounds 1;#10
    variable dumpPre {}
    variable dumpPost {}
    variable int32 [llvmtcl Int32Type]

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

    proc GenerateDeclaration {m procName} {
	variable tstp
	variable ts
	variable tsp
	variable funcar
	variable int32
	# Disassemble the proc
	set dasm [split [uplevel 1 [list \
	    ::tcl::unsupported::disassemble proc $procName
	]] \n]
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
	set ft [llvmtcl FunctionType $int32 $argl 0]
	set func [llvmtcl AddFunction $m $procName $ft]
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
	set dasm [split [uplevel 1 [list \
	    ::tcl::unsupported::disassemble proc $procName
	]] \n]
	# Create builder
	set bld [llvmtcl CreateBuilder]
	# Create function
	if {![info exists funcar($m,$procName)]} {
	    error "Undeclared $procName"
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
	set ts [llvmtcl BuildArrayAlloca $bld $at [llvmtcl ConstInt $int32 1 0] ""]
	set tsp [llvmtcl BuildAlloca $bld $int32 ""]
	llvmtcl BuildStore $bld [llvmtcl ConstInt $int32 0 0] $tsp
	# Load arguments into llvm, allocate space for slots
	set n 0
	foreach l $dasm {
	    set l [string trim $l]
	    if {[regexp {slot \d+, .*arg, [""]} $l]} {
		set arg_1 [llvmtcl GetParam $func $n]
		set arg_2 [llvmtcl BuildAlloca $bld $int32 ""]
		set arg_3 [llvmtcl BuildStore $bld $arg_1 $arg_2]
		set vars($n) $arg_2
		incr n
	    } elseif {[string match "slot *" $l]} {
		set arg_2 [llvmtcl BuildAlloca $bld $int32 ""]
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
		llvmtcl PositionBuilderAtEnd $bld $block($pc)
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
		push $bld [llvmtcl $unaryOpcode($opcode) $bld [pop $bld $int32] ""]
	    } elseif {[info exists binaryOpcode($opcode)]} {
		set top0 [pop $bld $int32]
		set top1 [pop $bld $int32]
		push $bld [llvmtcl $binaryOpcode($opcode) $bld $top1 $top0 ""]
	    } elseif {[info exists comparison($opcode)]} {
		set top0 [pop $bld $int32]
		set top1 [pop $bld $int32]
		push $bld [llvmtcl BuildIntCast $bld [llvmtcl BuildICmp $bld $comparison($opcode) $top1 $top0 ""] $int32 ""]
	    } else {
		switch -exact -- $opcode {
		    "loadScalar1" {
			set var $vars([string range [lindex $l 2] 2 end])
			push $bld [llvmtcl BuildLoad $bld $var ""]
		    }
		    "storeScalar1" {
			set var_1 [top $bld $int32]
			set idx [string range [lindex $l 2] 2 end]
			if {[info exists vars($idx)]} {
			    set var_2 $vars($idx)
			} else {
			    set var_2 [llvmtcl BuildAlloca $bld $int32 ""]
			}
			set var_3 [llvmtcl BuildStore $bld $var_1 $var_2]
			set vars($idx) $var_2
		    }
		    "incrScalar1" {
			set var $vars([string range [lindex $l 2] 2 end])
			llvmtcl BuildStore $bld [llvmtcl BuildAdd $bld [llvmtcl BuildLoad $bld $var ""] [top $bld $int32] ""] $var
		    }
		    "incrScalar1Imm" {
			set var $vars([string range [lindex $l 2] 2 end])
			set i [lindex $l 3]
			set s [llvmtcl BuildAdd $bld [llvmtcl BuildLoad $bld $var ""] [llvmtcl ConstInt $int32 $i 0] ""]
			push $bld $s
			llvmtcl BuildStore $bld $s $var
		    }
		    "push1" - "push4" {
			set tval [lindex $l 4]
			if {[string is integer -strict $tval]} {
			    set val [llvmtcl ConstInt $int32 $tval 0]
			} elseif {[info exists funcar($m,$tval)]} {
			    set val $funcar($m,$tval)
			} elseif {$tval eq "tailcall"} {
			    ### HACK! HACK! HACK! ###
			    continue
			} else {
			    set val [llvmtcl ConstInt $int32 0 0]
			}
			push $bld $val
		    }
		    "jumpTrue4" -
		    "jumpTrue1" {
			set top [pop $bld $int32]
			if {[llvmtcl GetIntTypeWidth [llvmtcl TypeOf $top]] == 1} {
			    set cond $top
			} else {
			    set cond [llvmtcl BuildICmp $bld LLVMIntNE $top [llvmtcl ConstInt $int32 0 0] ""]
			}
			llvmtcl BuildCondBr $bld $cond $block($tgt) $block($ipath($pc))
			set ends_with_jump($curr_block) 1
		    }
		    "jumpFalse4" -
		    "jumpFalse1" {
			set top [pop $bld $int32]
			if {[llvmtcl GetIntTypeWidth [llvmtcl TypeOf $top]] == 1} {
			    set cond $top
			} else {
			    set cond [llvmtcl BuildICmp $bld LLVMIntNE $top [llvmtcl ConstInt $int32 0 0] ""]
			}
			llvmtcl BuildCondBr $bld $cond $block($ipath($pc)) $block($tgt)
			set ends_with_jump($curr_block) 1
		    }
		    "tryCvtToNumeric" {
			push $bld [pop $bld $int32]
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
			    lappend objv [pop $bld $int32]
			    lappend argl $int32
			}
			set objv [lreverse $objv]
			set ft [llvmtcl PointerType [llvmtcl FunctionType $int32 $argl 0] 0]
			set fptr [pop $bld $ft]
			push $bld [llvmtcl BuildCall $bld $fptr $objv ""]
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
			set ft [llvmtcl PointerType [llvmtcl FunctionType $int32 $argl 0] 0]
			set fptr [pop $bld $ft]
			set tc [llvmtcl BuildCall $bld $fptr $objv ""]
			# MAGIC! Requires a recent-enough LLVM to really work
			llvmtcl SetTailCall $tc 2
			push $bld $tc
			llvmtcl BuildRet $bld [top $bld $int32]
			set ends_with_jump($curr_block) 1
			set done_done 1
		    }
		    "pop" {
			pop $bld $int32
		    }
		    "done" {
			if {!$done_done} {
			    llvmtcl BuildRet $bld [top $bld $int32]
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
	    llvmtcl PositionBuilderAtEnd $bld $block($pc)
	    if {!$ends_with_jump($block($pc))} {
		for {set tpc [expr {$pc+1}]} {$tpc < 1000} {incr tpc} {
		    if {[info exists block($tpc)]} {
			llvmtcl BuildBr $bld $block($tpc)
			break
		    }
		}
	    }
	}

	# Cleanup and return
	llvmtcl DisposeBuilder $bld
	return $func
    }

    # Helper functions, should not be called directly

    proc AddUtils {m} {
	variable funcar
	variable int32
	set bld [llvmtcl CreateBuilder]
	set ft [llvmtcl FunctionType $int32 [list $int32] 0]
	set func [llvmtcl AddFunction $m "llvm_mathfunc_int" $ft]
	set funcar($m,tcl::mathfunc::int) $func
	set block [llvmtcl AppendBasicBlock $func "block"]
	llvmtcl PositionBuilderAtEnd $bld $block
	llvmtcl BuildRet $bld [llvmtcl GetParam $func 0]
	llvmtcl DisposeBuilder $bld
    }

    proc push {bld val} {
	variable tstp
	variable ts
	variable tsp
	variable int32
	# Allocate space for value
	set valt [llvmtcl TypeOf $val]
	set valp [llvmtcl BuildAlloca $bld $valt "push"]
	llvmtcl BuildStore $bld $val $valp
	# Store location on stack
	set tspv [llvmtcl BuildLoad $bld $tsp "push"]
	set tsl [llvmtcl BuildGEP $bld $ts \
		[list [llvmtcl ConstInt $int32 0 0] $tspv] "push"]
	llvmtcl BuildStore $bld [llvmtcl BuildPointerCast $bld $valp $tstp ""] $tsl
	# Update stack pointer
	set tspv [llvmtcl BuildAdd $bld $tspv \
		[llvmtcl ConstInt $int32 1 0] "push"]
	llvmtcl BuildStore $bld $tspv $tsp
    }
    
    proc pop {bld valt} {
	variable ts
	variable tsp
	variable int32
	# Get location from stack and decrement the stack pointer
	set tspv [llvmtcl BuildLoad $bld $tsp "pop"]
	set tspv [llvmtcl BuildAdd $bld $tspv \
		[llvmtcl ConstInt $int32 -1 0] "pop"]
	llvmtcl BuildStore $bld $tspv $tsp
	set tsl [llvmtcl BuildGEP $bld $ts \
		[list [llvmtcl ConstInt $int32 0 0] $tspv] "pop"]
	set valp [llvmtcl BuildLoad $bld $tsl "pop"]
	# Load value
	set pc [llvmtcl BuildPointerCast $bld $valp \
		[llvmtcl PointerType $valt 0] "pop"]
	set rt [llvmtcl BuildLoad $bld $pc "pop"]
	return $rt
    }
    
    proc top {bld valt {offset 0}} {
	variable ts
	variable tsp
	variable int32
	# Get location from stack
	set tspv [llvmtcl BuildLoad $bld $tsp "top"]
	set tspv [llvmtcl BuildAdd $bld $tspv \
		[llvmtcl ConstInt $int32 -1 0] "top"]
	set tsl [llvmtcl BuildGEP $bld $ts \
		[list [llvmtcl ConstInt $int32 0 0] $tspv] "top"]
	set valp [llvmtcl BuildLoad $bld $tsl "top"]
	# Load value
	return [llvmtcl BuildLoad $bld \
		[llvmtcl BuildPointerCast $bld $valp [llvmtcl PointerType $valt 0] "top"] "top"]
    }



    proc optimise {args} {
	variable counter
	variable optimiseRounds
	variable int32

	set module [llvmtcl ModuleCreateWithName "module[incr counter] [uplevel 1 namespace current]"]
	AddUtils $module
	foreach p $args {
	    set cmd [uplevel 1 [list namespace which $p]]
	    lappend cmds $cmd
	    uplevel 1 [list [namespace which GenerateDeclaration] $module $p]
	}
	set funcs [lmap f $args {
	    uplevel 1 [list [namespace which BytecodeCompile] $module $f]
	}]

	variable dumpPre [llvmtcl DumpModule $module]

	lassign [llvmtcl VerifyModule $module LLVMReturnStatusAction] rt msg
	if {$rt} {
	    return -code error $msg
	}
	for {set i 0} {$i < $optimiseRounds} {incr i} {
	    llvmtcl Optimize $module $funcs
	}

	variable dumpPost [llvmtcl DumpModule $module]

	lassign [llvmtcl VerifyModule $module LLVMReturnStatusAction] rt msg
	if {$rt} {
	    return -code error $msg
	}
	lassign [llvmtcl CreateJITCompilerForModule $module 0] rt ee msg
	if {$rt} {
	    return -code error $msg
	}
	foreach cmd $cmds func $funcs {
	    set argc [llength [info args $cmd]]
	    set args [info args $cmd]
	    set argmap {}
	    foreach a $args {
		append argmap " \[llvmtcl CreateGenericValueOfInt $int32 \$$a 0\]"
	    }
	    set body [string map [list EE $ee FF $func AA $argmap] {
		return [llvmtcl GenericValueToInt [llvmtcl RunFunction EE FF [list AA]] 0]
	    }]
	    # Define an alternate tester to get a better handle on the
	    # overhead associated with the argument wrapping
	    set body2 [string map [list EE $ee FF $func AA $argmap] {
		set ___a [list AA]
		puts [time {llvmtcl RunFunction EE FF $___a} 1000]
		set ___r [llvmtcl RunFunction EE FF $___a]
		return [llvmtcl GenericValueToInt $___r 0]
	    }]
	    proc $cmd $args $body
	    proc ${cmd}__test $args $body2
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

# Baseline
puts [fib 20]
puts [time {fib 20} 10000]
# Convert to optimised form
LLVM optimise f g fact fib fibin
# Write out the generated code
puts [LLVM post]
# Compare with baseline
puts [fib 20]
puts [time {fib 20} 10000]
puts [fib__test 20]
## Checks of what is done in the glue layer
#puts [info body fib]
#puts [tcl::unsupported::disassemble proc fib]
