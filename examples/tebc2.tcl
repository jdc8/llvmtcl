lappend auto_path ..
package require llvmtcl

namespace eval ::LLVM {
    llvmtcl LinkInJIT
    llvmtcl InitializeNativeTarget
    variable counter 0
    variable optimiseRounds 10;#10
    variable dumpPre {}
    variable dumpPost {}
    variable int32 [llvmtcl Int32Type]

    proc DisassembleTclBytecode {procName} {
	lmap line [split [::tcl::unsupported::disassemble proc $procName] \n] {
	    string trim $line
	}
    }

    proc GenerateDeclaration {module procName} {
	variable int32
	# Disassemble the proc
	set dasm [DisassembleTclBytecode $procName]
	# Create function
	if {[$module function.defined $procName]} {
	    error "duplicate $procName"
	}
	set argl {}
	foreach l $dasm {
	    if {[regexp {slot \d+, .*arg, [""]} $l]} {
		lappend argl $int32
	    }
	}
	set ft [llvmtcl FunctionType $int32 $argl 0]
	return [$module function.create $procName $ft]
    }

    proc Const {number} {
	return [llvmtcl ConstInt [llvmtcl Int32Type] $number 0]
    }

    proc BytecodeCompile {module procName} {
	variable tstp
	variable ts
	variable tsp
	variable int32

	if {![$module function.defined $procName]} {
	    error "Undeclared $procName"
	}

	# Disassemble the proc
	set dasm [DisassembleTclBytecode $procName]
	# Create builder
	set b [Builder new]
	# Get the function declaration
	set func [$module function.get $procName]

	# Create basic blocks
	set block(0) [$func block]
	set next_is_ipath -1
	foreach l $dasm {
	    if {[regexp {stkDepth (\d+), code} $l -> s]} {
		set stackDepth $s
	    }
	    if {![string match "(*" $l]} { continue }
	    set opcode [lindex $l 1]
	    if {$next_is_ipath >= 0} {
		regexp {\((\d+)\) } $l -> pc
		if {![info exists block($pc)]} {
		    set block($pc) [$func block]
		}
		set ipath($next_is_ipath) $pc
		set next_is_ipath -1
	    }
	    if {[string match {jump*[14]} $opcode] || "startCommand" eq $opcode} {
		# (pc) opcode offset
		regexp {\((\d+)\) (jump\S*[14]|startCommand) ([-+]\d+)} $l -> pc cmd offset
		set tgt [expr {$pc + $offset}]
		if {![info exists block($tgt)]} {
		    set block($tgt) [$func block]
		}
		set next_is_ipath $pc
	    }
	}
	$b @end $block(0)
	set curr_block $block(0)

	# Create stack and stack pointer
	set stack [Stack new $b $stackDepth]

	# Load arguments into llvm, allocate space for slots
	foreach l $dasm {
	    if {[regexp {slot (\d+), .*arg.*, [""]} $l -> n]} {
		set vars($n) [$b alloc $int32]
		$b store [$func param $n] $vars($n)
	    } elseif {[regexp {slot (\d+), .*scalar.*, [""]} $l -> n]} {
		set vars($n) [$b alloc $int32]
	    }
	}

	# Convert Tcl parse output
	set done_done 0
	set maxpc 0
	foreach l $dasm {
	    if {![string match "(*" $l]} {
		continue
	    }
	    regexp {\((\d+)\) (\S+)} $l -> pc opcode
	    set maxpc $pc
	    if {[info exists block($pc)]} {
		$b @end $block($pc)
		set curr_block $block($pc)
		set done_done 0
	    }
	    set ends_with_jump($curr_block) 0
	    unset -nocomplain tgt
	    if {[string match {jump*[14]} $opcode]} {
		regexp {\(\d+\) (jump\S*[14]|startCommand) ([-+]\d+)} $l -> cmd offset
		set tgt [expr {$pc + $offset}]
	    }

	    switch -exact -- $opcode {
		"bitor" - "bitxor" - "bitand" - "lshift" - "rshift" -
		"add" - "sub" - "mult" - "div" - "mod" {
		    set top0 [$stack pop $int32]
		    set top1 [$stack pop $int32]
		    $stack push [$b $opcode $top1 $top0]
		}
		"uminus" - "bitnot" {
		    $stack push [$b $opcode [$stack pop $int32]]
		}
		"eq" - "neq" - "lt" - "gt" - "le" - "ge" {
		    set top0 [$stack pop $int32]
		    set top1 [$stack pop $int32]
		    $stack push [$b intCast [$b $opcode $top1 $top0] $int32]
		}
		"loadScalar1" - "loadScalar4" {
		    set var $vars([string range [lindex $l 2] 2 end])
		    $stack push [$b load $var]
		}
		"storeScalar1" - "storeScalar4" {
		    set var_1 [$stack top $int32]
		    set idx [string range [lindex $l 2] 2 end]
		    if {[info exists vars($idx)]} {
			set var_2 $vars($idx)
		    } else {
			set var_2 [$b alloc $int32]
		    }
		    $b store $var_1 $var_2
		    set vars($idx) $var_2
		}
		"incrScalar1" - "incrScalar4" {
		    set var $vars([string range [lindex $l 2] 2 end])
		    $b store [$b add [$b load $var] [$stack top $int32]] $var
		}
		"incrScalar1Imm" - "incrScalar4Imm" {
		    set var $vars([string range [lindex $l 2] 2 end])
		    set i [lindex $l 3]
		    set s [$b add [$b load $var] [Const $i]]
		    $stack push $s
		    $b store $s $var
		}
		"push1" - "push4" {
		    set tval [lindex $l 4]
		    if {[string is integer -strict $tval]} {
			set val [Const $tval]
		    } elseif {[$module function.defined $tval]} {
			set val [[$module function.get $tval] ref]
		    } elseif {$tval eq "tailcall"} {
			### HACK! HACK! HACK! ###
			continue
		    } else {
			set val [Const 0]
		    }
		    $stack push $val
		}
		"jumpTrue1" - "jumpTrue4" {
		    set top [$stack pop $int32]
		    if {[llvmtcl GetIntTypeWidth [llvmtcl TypeOf $top]] == 1} {
			set cond $top
		    } else {
			set cond [$b neq $top [Const 0]]
		    }
		    $b condBr $cond $block($tgt) $block($ipath($pc))
		    set ends_with_jump($curr_block) 1
		}
		"jumpFalse1" - "jumpFalse4" {
		    set top [$stack pop $int32]
		    if {[llvmtcl GetIntTypeWidth [llvmtcl TypeOf $top]] == 1} {
			set cond $top
		    } else {
			set cond [$b neq $top [Const 0]]
		    }
		    $b condBr $cond $block($ipath($pc)) $block($tgt)
		    set ends_with_jump($curr_block) 1
		}
		"tryCvtToNumeric" {
		    $stack push [$stack pop $int32]
		}
		"startCommand" {
		}
		"jump1" - "jump4" {
		    $b br $block($tgt)
		    set ends_with_jump($curr_block) 1
		}
		"invokeStk1" {
		    set objc [lindex $l 2]
		    set objv {}
		    set argl {}
		    for {set i 0} {$i < ($objc-1)} {incr i} {
			lappend objv [$stack pop $int32]
			lappend argl $int32
		    }
		    set objv [lreverse $objv]
		    set ft [llvmtcl PointerType [llvmtcl FunctionType $int32 $argl 0] 0]
		    set fptr [$stack pop $ft]
		    $stack push [$b call $fptr $objv]
		}
		"tailcall" {
		    set objc [lindex $l 2]
		    set objv {}
		    set argl {}
		    for {set i 0} {$i < ($objc-2)} {incr i} {
			lappend objv [$stack pop $int32]
			lappend argl $int32
		    }
		    set objv [lreverse $objv]
		    set ft [llvmtcl PointerType [llvmtcl FunctionType $int32 $argl 0] 0]
		    set fptr [$stack pop $ft]
		    set tc [$b call $fptr $objv]
		    # MAGIC! Requires a recent-enough LLVM to really work
		    # llvmtcl SetTailCall $tc 2
		    $stack push $tc
		    $b ret [$stack top $int32]
		    set ends_with_jump($curr_block) 1
		    set done_done 1
		}
		"pop" {
		    $stack pop $int32
		}
		"done" {
		    if {!$done_done} {
			$b ret [$stack top $int32]
			set ends_with_jump($curr_block) 1
			set done_done 1
		    }
		}
		"nop" {
		}
		"unsetScalar" {
		    # Do nothing; it's not *right* but it's OK with ints
		}
		"reverse" {
		    set objc [lindex $l 2]
		    set objv {}
		    for {set i 0} {$i < $objc} {incr i} {
			lappend objv [$stack pop $int32]
		    }
		    foreach val $objv {
			$stack push $val
		    }
		}
		"over" {
		    $stack push [$stack top $int32 [lindex $l 2]]
		}
		default {
		    error "unknown bytecode '$opcode' in '$l'"
		}
	    }
	}

	# Set increment paths
	foreach {pc blk} [array get block] {
	    $b @end $blk
	    if {$ends_with_jump($blk)} continue
	    while {[incr pc] <= $maxpc} {
		if {[info exists block($pc)]} {
		    $b br $block($pc)
		    break
		}
	    }
	}

	# Cleanup and return
	$stack destroy
	$b destroy
	return [$func ref]
    }

    # Helper functions, should not be called directly

    proc AddUtils {module} {
	variable int32
	set b [Builder new]
	set ft [llvmtcl FunctionType $int32 [list $int32] 0]
	set func [$module function.create tcl::mathfunc::int $ft]
	$b @end [$func block]
	$b ret [$func param 0]
	$b destroy
    }

    oo::class create Module {
	variable module counter funcs
	constructor {name} {
	    set module [llvmtcl ModuleCreateWithName $name]
	    set funcs {}
	}
	method function.create {name type} {
	    set f [::LLVM::Function create f[incr counter] $module $name $type]
	    dict set funcs $name $f
	    return $f
	}
	method function.defined {name} {
	    dict exists $funcs $name
	}
	method function.get {name} {
	    dict get $funcs $name
	}
	method dump {} {
	    llvmtcl DumpModule $module
	}
	method verify {} {
	    lassign [llvmtcl VerifyModule $module LLVMReturnStatusAction] rt msg
	    if {$rt} {
		return -code error $msg
	    }
	}
	method optimize {{rounds 1}} {
	    for {set i 0} {$i < $rounds} {incr i} {
		llvmtcl Optimize $module [lmap f [dict values $funcs] {$f ref}]
	    }
	}
	method ref {} {
	    return $module
	}
	method jit {} {
	    lassign [llvmtcl CreateJITCompilerForModule $module 0] rt ee msg
	    if {$rt} {
		return -code error $msg
	    }
	    return $ee
	}
    }

    oo::class create Function {
	variable func counter
	constructor {module name type} {
	    set func [llvmtcl AddFunction $module $name $type]
	    set counter -1
	}
	method ref {} {
	    return $func
	}
	method block {} {
	    return [llvmtcl AppendBasicBlock $func block[incr counter]]
	}
	method param {index} {
	    return [llvmtcl GetParam $func $index]
	}
    }

    oo::class create Stack {
	variable ts tsp tstp b i32
	constructor {builder {size 100}} {
	    namespace path [list {*}[namespace path] ::llvmtcl]
	    set b $builder
	    set i32 [llvmtcl Int32Type]
	    set tstp [llvmtcl PointerType [llvmtcl Int8Type] 0]
	    set at [llvmtcl ArrayType [llvmtcl PointerType [llvmtcl Int8Type] 0] $size]
	    set ts [$b arrayAlloc $at [::LLVM::Const 1]]
	    set tsp [$b alloc $i32]
	    $b store [::LLVM::Const 0] $tsp
	}

	method push {val} {
	    # Allocate space for value
	    set valp [$b alloc [llvmtcl TypeOf $val] "push"]
	    $b store $val $valp
	    # Store location on stack
	    set tspv [$b load $tsp "push"]
	    set tsl [$b gep $ts [list [::LLVM::Const 0] $tspv] "push"]
	    $b store [$b pointerCast $valp $tstp ""] $tsl
	    # Update stack pointer
	    set tspv [$b add $tspv [::LLVM::Const 1] "push"]
	    $b store $tspv $tsp
	    return
	}
	method pop {valt} {
	    # Get location from stack and decrement the stack pointer
	    set tspv [$b load $tsp "pop"]
	    set tspv [$b add $tspv [::LLVM::Const -1] "pop"]
	    $b store $tspv $tsp
	    set tsl [$b gep $ts [list [::LLVM::Const 0] $tspv] "pop"]
	    set valp [$b load $tsl "pop"]
	    set pvalt [llvmtcl PointerType $valt 0]
	    # Load value
	    return [$b load [$b pointerCast $valp $pvalt "pop"] "pop"]
	}
	method top {valt {offset 0}} {
	    # Get location from stack
	    set tspv [$b load $tsp "top"]
	    set tspv [$b add $tspv [::LLVM::Const [expr {-1-$offset}]] "top"]
	    set tsl [$b gep $ts [list [::LLVM::Const 0] $tspv] "top"]
	    set valp [$b load $tsl "top"]
	    set pvalt [llvmtcl PointerType $valt 0]
	    # Load value
	    return [$b load [$b pointerCast $valp $pvalt "top"] "top"]
	}
    }

    oo::class create Builder {
	variable b dispose
	constructor {{builder ""}} {
	    set dispose [expr {$builder eq ""}]
	    if {$dispose} {
		set b [llvmtcl CreateBuilder]
	    } else {
		set b $builder
	    }
	}
	destructor {
	    if {$dispose} {
		llvmtcl DisposeBuilder $b
	    }
	}

	method add {left right {name ""}} {
	    llvmtcl BuildAdd $b $left $right $name
	}
	method alloc {type {name ""}} {
	    llvmtcl BuildAlloca $b $type $name
	}
	method arrayAlloc {type value {name ""}} {
	    llvmtcl BuildArrayAlloca $b $type $value $name
	}
	method bitand {left right {name ""}} {
	    llvmtcl BuildAnd $b $left $right $name
	}
	method bitnot {value {name ""}} {
	    llvmtcl BuildNot $b $value $name
	}
	method bitor {left right {name ""}} {
	    llvmtcl BuildXor $b $left $right $name
	}
	method bitxor {left right {name ""}} {
	    llvmtcl BuildOr $b $left $right $name
	}
	method br target {
	    llvmtcl BuildBr $b $target
	}
	method call {function arguments {name ""}} {
	    llvmtcl BuildCall $b $function $arguments $name
	}
	method condBr {cond true false} {
	    llvmtcl BuildCondBr $b $cond $true $false
	}
	method div {left right {name ""}} {
	    llvmtcl BuildSDiv $b $left $right $name
	}
	method eq {leftValue rightValue {name ""}} {
	    llvmtcl BuildICmp $b LLVMIntEQ $leftValue $rightValue $name
	}
	method ge {leftValue rightValue {name ""}} {
	    llvmtcl BuildICmp $b LLVMIntGE $leftValue $rightValue $name
	}
	method gep {var indices {name ""}} {
	    llvmtcl BuildGEP $b $var $indices $name
	}
	method gt {leftValue rightValue {name ""}} {
	    llvmtcl BuildICmp $b LLVMIntSGT $leftValue $rightValue $name
	}
	method intCast {value type {name ""}} {
	    llvmtcl BuildIntCast $b $value $type $name
	}
	method le {leftValue rightValue {name ""}} {
	    llvmtcl BuildICmp $b LLVMIntSLE $leftValue $rightValue $name
	}
	method load {var {name ""}} {
	    llvmtcl BuildLoad $b $var $name
	}
	method lshift {left right {name ""}} {
	    llvmtcl BuildShl $b $left $right $name
	}
	method lt {leftValue rightValue {name ""}} {
	    llvmtcl BuildICmp $b LLVMIntSLT $leftValue $rightValue $name
	}
	method mod {left right {name ""}} {
	    llvmtcl BuildSRem $b $left $right $name
	}
	method mult {left right {name ""}} {
	    llvmtcl BuildMul $b $left $right $name
	}
	method neq {leftValue rightValue {name ""}} {
	    llvmtcl BuildICmp $b LLVMIntNE $leftValue $rightValue $name
	}
	method pointerCast {value type {name ""}} {
	    llvmtcl BuildPointerCast $b $value $type $name
	}
	method ret value {
	    llvmtcl BuildRet $b $value
	}
	method rshift {left right {name ""}} {
	    llvmtcl BuildAShr $b $left $right $name
	}
	method store {value var} {
	    llvmtcl BuildStore $b $value $var
	}
	method sub {left right {name ""}} {
	    llvmtcl BuildSub $b $left $right $name
	}
	method uminus {value {name ""}} {
	    llvmtcl BuildNeg $b $value $name
	}

	method @end block {
	    llvmtcl PositionBuilderAtEnd $b $block
	}
	export @end
    }

    proc optimise {args} {
	variable counter
	variable optimiseRounds

	set module [Module new "module[incr counter] [uplevel 1 namespace current]"]
	AddUtils $module
	foreach p $args {
	    set cmd [uplevel 1 [list namespace which $p]]
	    lappend cmds $cmd
	    uplevel 1 [list [namespace which GenerateDeclaration] $module $p]
	}
	set funcs [lmap f $args {
	    uplevel 1 [list [namespace which BytecodeCompile] $module $f]
	}]

	variable dumpPre [$module dump]

	$module verify
	$module optimize $optimiseRounds

	variable dumpPost [$module dump]

	$module verify
	set ee [$module jit]
	foreach cmd $cmds func $funcs {
	    llvmtcl CreateProcedureThunk $cmd $ee $func [info args $cmd]
	}
	try {
	    return [$module ref]
	} finally {
	    $module destroy
	}
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
puts [tcl::unsupported::disassemble proc f]
# Convert to optimised form
try {
    LLVM optimise f g fact fib fibin fib2
} on error {msg opt} {
    puts [dict get $opt -errorinfo]
    exit 1
}
# Write out the generated code
puts [LLVM post]
# Compare with baseline
puts tailrec:[time {fib 20} 100000]
puts iterate:[time {fib2 20} 100000]
