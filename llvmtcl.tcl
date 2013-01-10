namespace eval llvmtcl {
    namespace export *
    namespace ensemble create

    proc OptimizeModule {m optimizeLevel targetDataRef} {
	set pm [llvmtcl CreatePassManager]
	llvmtcl AddTargetData $targetDataRef $pm
	llvmtcl CreateStandardModulePasses $pm $optimizeLevel 
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
	llvmtcl OptimizeModule $m 3 $td
    }

    proc Execute {EE m f args} {
	set largs [list [llvmtcl CreateGenericValueOfTclInterp]]
	foreach arg $args {
	    lappend largs [llvmtcl CreateGenericValueOfTclObj $arg]
	}
	set rt [llvmtcl GenericValueToTclObj [llvmtcl RunFunction $EE $f $largs]]
    }

    proc Tcl2LLVM {EE m procName {functionDeclarationOnly 0}} {
	variable tclts {}
	variable ts
	variable tsp
	variable funcar
	variable utils_added
	variable TclObjPtr
	variable TclInterpPtr
	if {![info exists utils_added($m)] || !$utils_added($m)} {
	    llvmtcl AddTcl2LLVMCommands $EE $m
	    AddTcl2LLVMUtils $m
	}
	# Disassemble the proc
	set dasm [split [tcl::unsupported::disassemble proc $procName] \n]
	# Create builder
	set bld [llvmtcl CreateBuilder]
	# Create strings
	if {!$functionDeclarationOnly} {
	    foreach l $dasm {
		set l [string trim $l]
		if {![string match "(*" $l]} { continue }
		regexp {\((\d+)\) (\S+)} $l -> pc opcode
		if {$opcode eq "push1"} {
		    set s [lindex $l 4]
		    puts "Need to create string for: $s"
		    set st [llvmtcl ArrayType [llvmtcl Int8Type] [expr {[string length $s]+1}]]
		    set gv [llvmtcl AddGlobal $m $st $s]
		    llvmtcl SetInitializer $gv [llvmtcl ConstString $s [string length $s] 0]
		    llvmtcl SetGlobalConstant $gv 1
		    set strings($s) $gv
		}
	    }
	}
	# Create function
	if {![info exists funcar($m,$procName)]} {
	    set argl [list $TclInterpPtr]
	    foreach l $dasm {
		set l [string trim $l]
		if {[regexp {slot \d+, .*arg, \"} $l]} {
		    lappend argl $TclObjPtr
		}
	    }
	    set ft [llvmtcl FunctionType $TclObjPtr $argl 0]
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

	# Get pointers to Tcl functions
	set LLVMBuilder2(add) [llvmtcl GetNamedFunction $m "llvm_add"]
	set LLVMBuilder2(append) [llvmtcl GetNamedFunction $m "llvm_append"]

	set LLVMBuilder2(bitor) [llvmtcl GetNamedFunction $m "llvm_or"]
	set LLVMBuilder2(bitxor) [llvmtcl GetNamedFunction $m "llvm_xor"]
	set LLVMBuilder2(bitand) [llvmtcl GetNamedFunction $m "llvm_and"]
	set LLVMBuilder2(lshift) [llvmtcl GetNamedFunction $m "llvm_lshd"]
	set LLVMBuilder2(rshift) [llvmtcl GetNamedFunction $m "llvm_rshd"]
	set LLVMBuilder2(sub) [llvmtcl GetNamedFunction $m "llvm_sub"]
	set LLVMBuilder2(mult) [llvmtcl GetNamedFunction $m "llvm_mul"]
	set LLVMBuilder2(div) [llvmtcl GetNamedFunction $m "llvm_div"]
	set LLVMBuilder2(mod) [llvmtcl GetNamedFunction $m "llvm_mod"]

	set LLVMBuilder1(uminus) [llvmtcl GetNamedFunction $m "llvm_neg"]
	set LLVMBuilder1(bitnot) [llvmtcl GetNamedFunction $m "llvm_not"]
	set LLVMBuilder1(to_int) [llvmtcl GetNamedFunction $m "llvm_to_int"]
	set LLVMBuilder1(from_int) [llvmtcl GetNamedFunction $m "llvm_from_int"]
	set LLVMBuilder1(from_string) [llvmtcl GetNamedFunction $m "llvm_from_string"]
	set LLVMBuilder1(new_obj) [llvmtcl GetNamedFunction $m "llvm_new_obj"]

	set LLVMBuilderICmp(eq) [llvmtcl GetNamedFunction $m "llvm_eq"]
	set LLVMBuilderICmp(neq) [llvmtcl GetNamedFunction $m "llvm_neq"]
	set LLVMBuilderICmp(lt) [llvmtcl GetNamedFunction $m "llvm_lt"]
	set LLVMBuilderICmp(gt) [llvmtcl GetNamedFunction $m "llvm_gt"]
	set LLVMBuilderICmp(le) [llvmtcl GetNamedFunction $m "llvm_le"]
	set LLVMBuilderICmp(ge) [llvmtcl GetNamedFunction $m "llvm_ge"]

	set LLVMBuilder1(eval) [llvmtcl GetNamedFunction $m "llvm_eval"]

	# Create stack and stack pointer
	set interp [llvmtcl GetParam $func 0]
	set at [llvmtcl ArrayType $TclObjPtr 100]
	set ts [llvmtcl BuildArrayAlloca $bld $at [llvmtcl ConstInt [llvmtcl Int32Type] 1 0] ""]
	set tsp [llvmtcl BuildAlloca $bld [llvmtcl Int32Type] ""]
	llvmtcl BuildStore $bld [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] $tsp

	# Load arguments into llvm, allocate space for slots
	set n 0
	foreach l $dasm {
	    set l [string trim $l]
	    if {[regexp {slot \d+, .*arg, \"} $l]} {
		set arg_1 [llvmtcl GetParam $func [expr {$n+1}]] ;# Skip first, it's a pointer to the interp
		set arg_2 [llvmtcl BuildAlloca $bld $TclObjPtr ""]
		set arg_3 [llvmtcl BuildStore $bld $arg_1 $arg_2]
		set vars($n) $arg_2
		incr n
	    } elseif {[string match "slot *" $l]} {
		set arg_2 [llvmtcl BuildAlloca $bld $TclObjPtr ""]
		set vars($n) $arg_2
	    }
	}

	# Convert Tcl parse output
	set done_done 0
	puts [join $dasm \n]
	foreach l $dasm {
	    set l [string trim $l]
	    if {![string match "(*" $l]} { continue }
	    puts $l
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
		lassing [pop $bld $TclObjPtr] top0 tclval0
		push $bld [llvmtcl BuildCall $bld $LLVMBuilder1($opcode) [list $interp $top0] ""] 
	    } elseif {[info exists LLVMBuilder2($opcode)]} {
		lassign [pop $bld $TclObjPtr] top0 tclval0
		lassign [pop $bld $TclObjPtr] top1 tclval1
		push $bld [llvmtcl BuildCall $bld $LLVMBuilder2($opcode) [list $interp $top1 $top0] ""]
	    } elseif {[info exists LLVMBuilderICmp($opcode)]} {
		lassign [pop $bld $TclObjPtr] top0 tclval0
		lassign [pop $bld $TclObjPtr] top1 tclval1
		push $bld [llvmtcl BuildCall $bld $LLVMBuilderICmp($opcode) [list $interp $top1 $top0] ""]
	    } else {
		switch -exact -- $opcode {
		    "loadScalar1" {
			set tclval [string range [lindex $l 2] 2 end]
			set var $vars($tclval)
			push $bld [llvmtcl BuildLoad $bld $var ""]
		    }
		    "storeScalar1" {
			lassign [top $bld $TclObjPtr] var_1 tclval1
			set idx [string range [lindex $l 2] 2 end]
			if {[info exists vars($idx)]} {
			    set var_2 $vars($idx)
			} else {
			    set var_2 [llvmtcl BuildAlloca $bld $TclObjPtr ""]
			}
			set var_3 [llvmtcl BuildStore $bld $var_1 $var_2]
			set vars($idx) $var_2
		    }
		    "appendScalar1" {
			set var $vars([string range [lindex $l 2] 2 end])
			lassign [pop $bld $TclObjPtr] top0 tclval0
			llvmtcl BuildStore $bld [llvmtcl BuildCall $bld $LLVMBuilder2(append) [list $interp [llvmtcl BuildLoad $bld $var ""] $top0] ""] $var
		    }
		    "incrScalar1" {
			set var $vars([string range [lindex $l 2] 2 end])
			lassign [pop $bld $TclObjPtr] top0 tclval0
			llvmtcl BuildStore $bld [llvmtcl BuildCall $bld $LLVMBuilder2(add)    [list $interp [llvmtcl BuildLoad $bld $var ""] $top0] ""] $var
		    }
		    "incrScalar1Imm" {
			set tclval [string range [lindex $l 2] 2 end]
			set var $vars($tclval)
			set i [lindex $l 3]
			set imm [llvmtcl BuildCall $bld $LLVMBuilder1(from_int) [list $interp [llvmtcl ConstInt [llvmtcl Int32Type] $i 0]] ""]
			set s [llvmtcl BuildCall $bld $LLVMBuilder2(add) [list $interp [llvmtcl BuildLoad $bld $var ""] $imm] ""]
			push $bld $s $tclval
			llvmtcl BuildStore $bld $s $var
		    }
		    "push1" {
			set tval [lindex $l 4]
			if {[string is integer -strict $tval]} {
			    set val [llvmtcl BuildCall $bld $LLVMBuilder1(from_int) [list $interp [llvmtcl ConstInt [llvmtcl Int32Type] $tval 0]] ""]
			} elseif {[info exists funcar($m,$tval)]} {
			    set val $funcar($m,$tval)
			} elseif {[info exists strings($tval)]} {
			    set val [llvmtcl GetInitializer $strings($tval)]
			    #set val [llvmtcl BuildCall $bld $LLVMBuilder1(from_string) [list $interp $cs] ""]
			} else {
			    set val [llvmtcl BuildCall $bld $LLVMBuilder1(from_int) [list $interp [llvmtcl ConstInt [llvmtcl Int32Type] 0 0]] ""]
			}
			push $bld $val $tval
		    }
		    "jumpTrue4" -
		    "jumpTrue1" {
			lassign [pop $bld $TclObjPtr] top tclval
			set top_cond [llvmtcl BuildCall $bld $LLVMBuilder1(to_int) [list $interp $top] ""]
			set cond [llvmtcl BuildICmp $bld LLVMIntNE $top_cond [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] ""]
			llvmtcl BuildCondBr $bld $cond $block($tgt) $block($ipath($pc))
			set ends_with_jump($curr_block) 1
		    }
		    "jumpFalse4" -
		    "jumpFalse1" {
			lassign [pop $bld $TclObjPtr] top tclval
			set top_cond [llvmtcl BuildCall $bld $LLVMBuilder1(to_int) [list $interp $top] ""]
			set cond [llvmtcl BuildICmp $bld LLVMIntNE $top_cond [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] ""]
			llvmtcl BuildCondBr $bld $cond $block($ipath($pc)) $block($tgt)
			set ends_with_jump($curr_block) 1
		    }
		    "tryCvtToNumeric" {
			lassign [pop $bld $TclObjPtr] top tclval
			push $bld $top
		    }
		    "startCommand" {
		    }
		    "jump4" -
		    "jump1" {
			llvmtcl BuildBr $bld $block($tgt)
			set ends_with_jump($curr_block) 1
		    }
		    "invokeStk1" {
			if {0} {
			    set objc [lindex $l 2]
			    set objv {}
			    set tclobjv {}
			    set argl [list $TclInterpPtr]
			    for {set i 0} {$i < ($objc-1)} {incr i} {
				lassign [pop $bld $TclObjPtr] top $tclval
				lappend objv $top
				lappend objv $tclval
				lappend argl $TclObjPtr
			    }
			    lappend objv $interp
			    set objv [lreverse $objv]
			    set tclobjv [lreverse $tclobjv]
			    set ft [llvmtcl PointerType [llvmtcl FunctionType $TclObjPtr $argl 0] 0]
			    lassign [pop $bld $ft] fptr tclfptr
			    push $bld [llvmtcl BuildCall $bld $fptr $objv ""]
			} else {
			    set objc [lindex $l 2]
			    set objv {}
			    set tclobjv {}
			    for {set i 0} {$i < $objc} {incr i} {
				lassign [pop $bld $TclObjPtr] top tclval
				lappend objv $top
				lappend tclobjv $tclval
			    }
			    lappend objv [llvmtcl ConstInt [llvmtcl Int32Type] [llength $objv] 0]
			    lappend objv $interp
			    lappend tclobjv interp
			    set objv [lreverse $objv]
			    set tclobjv [lreverse $tclobjv]
			    puts "invoke: $objv"
			    puts "      : $tclobjv"
			    parray vars
			    switch -exact -- [lindex $tclobjv 1] {
				"append" {
				    set varnm [lindex $tclobjv 2]
				    puts "Append to var '$varnm' [info exists vars($varnm)]"
				    if {![info exists vars($varnm)]} {
					set var_1 [llvmtcl BuildCall $bld $LLVMBuilder1(new_obj) [list $interp] ""]
					set var_2 [llvmtcl BuildAlloca $bld $TclObjPtr ""]
					set var_3 [llvmtcl BuildStore $bld $var_1 $var_2]
					set vars($varnm) $var_2
				    }
				    lset objv 2 [llvmtcl BuildLoad $bld $vars($varnm) ""]
				}
			    }
			    puts "invoke: $objv"
			    push $bld [llvmtcl BuildCall $bld $LLVMBuilder1(eval) $objv ""]
			}
		    }
		    "pop" {
			pop $bld $TclObjPtr
		    }
		    "done" {
			if {!$done_done} {
			    lassign [top $bld $TclObjPtr] top tclval
			    llvmtcl BuildRet $bld $top
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

    proc push {bld val {tclval ""}} {
	variable tclts
	variable ts
	variable tsp
	variable TclObjPtr
	# Allocate space for value
	set valt [llvmtcl TypeOf $val]
	set valp [llvmtcl BuildAlloca $bld $valt "push"]
	llvmtcl BuildStore $bld $val $valp
	# Store location on stack
	set tspv [llvmtcl BuildLoad $bld $tsp "push"]
	set tsl [llvmtcl BuildGEP $bld $ts [list [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] $tspv] "push"]
	llvmtcl BuildStore $bld [llvmtcl BuildPointerCast $bld $valp $TclObjPtr ""] $tsl
	# Update stack pointer
	set tspv [llvmtcl BuildAdd $bld $tspv [llvmtcl ConstInt [llvmtcl Int32Type] 1 0] "push"]
	llvmtcl BuildStore $bld $tspv $tsp
	lappend tclts $tclval
    }

    proc pop {bld valt} {
	variable tclts
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
	set tclval [lindex $tclts end]
	set tclts [lrange $tclts 0 end-1]
	return [list $rt $tclval]
    }

    proc top {bld valt {offset 0}} {
	variable tclts
	variable ts
	variable tsp
	# Get location from stack
	set tspv [llvmtcl BuildLoad $bld $tsp "top"]
	set tspv [llvmtcl BuildAdd $bld $tspv [llvmtcl ConstInt [llvmtcl Int32Type] -1 0] "top"]
	set tsl [llvmtcl BuildGEP $bld $ts [list [llvmtcl ConstInt [llvmtcl Int32Type] 0 0] $tspv] "top"]
	set valp [llvmtcl BuildLoad $bld $tsl "top"]
	# Load value
	set rt [llvmtcl BuildLoad $bld [llvmtcl BuildPointerCast $bld $valp [llvmtcl PointerType $valt 0] "top"] "top"]
	set tclval [lindex $tclts end]
	return [list $rt $tclval]
    }

    variable TclObjPtr [llvmtcl PointerType [llvmtcl Int8Type] 0]
    variable TclInterpPtr [llvmtcl PointerType [llvmtcl Int8Type] 0]
}
