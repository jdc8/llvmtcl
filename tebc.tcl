lappend auto_path .
package require llvmtcl

namespace import llvmtcl::*

proc test {a b c d e} {
    return [expr {(22*$a+$c)+$b*34}]
}
set dasm [split [tcl::unsupported::disassemble proc test] \n]

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
    if {[string match "slot*" $l]} { 
	lappend argl [LLVMInt32Type]
    }
}

set ft [LLVMFunctionType [LLVMInt32Type] $argl 0]
set func [LLVMAddFunction $m "test" $ft]
set block [LLVMAppendBasicBlock $func block]
LLVMPositionBuilderAtEnd $bld $block

# Load arguments into llvm stack
set n 0
foreach l $dasm {
    set l [string trim $l]
    if {[string match "slot*" $l]} {
	set arg_1 [LLVMGetParam $func $n]
	set arg_2 [LLVMBuildAlloca $bld [LLVMInt32Type] ""]
	set arg_3 [LLVMBuildStore $bld $arg_1 $arg_2]
	set vars($n) $arg_2
	incr n
    }
}

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

set tcl_stack {}
puts "----- Tcl Disassemble ----------------------------------------"
foreach l $dasm {
    set l [string trim $l]
    if {![string match "(*" $l]} { continue }
    puts $l
    set opcode [lindex $l 1]
    if {[info exists LLVMBuilder1($opcode)]} {
	set rt [$LLVMBuilder1($opcode) $bld [lindex $tcl_stack end] ""]
	set tcl_stack [list {*}[lrange $tcl_stack 0 end-1] $rt]
    } elseif {[info exists LLVMBuilder2($opcode)]} {
	set rt [$LLVMBuilder2($opcode) $bld [lindex $tcl_stack end-1] [lindex $tcl_stack end] ""]
	set tcl_stack [list {*}[lrange $tcl_stack 0 end-2] $rt]
    } else {
	switch -exact -- $opcode {
	    "loadScalar1" {
		lappend tcl_stack [LLVMBuildLoad $bld $vars([string range [lindex $l 2] 2 end]) ""]
	    }
	    "push1" {
		lappend tcl_stack [LLVMConstInt [LLVMInt32Type] [lindex $l 4] 0]
	    }
	    "done" {
		LLVMBuildRet $bld [lindex $tcl_stack end]
	    }
	    default {
		error "unknown bytecode: $l"
	    }
	}
    }
}

puts "----- Input --------------------------------------------------"
puts [LLVMModuleDump $m]
puts "----- Optimized ----------------------------------------------"
LLVMOptimizeModule $m
puts [LLVMModuleDump $m]

lassign [LLVMCreateJITCompilerForModule $m 0] rt EE msg
set i0 [LLVMCreateGenericValueOfInt [LLVMInt32Type] 1 0]
set i1 [LLVMCreateGenericValueOfInt [LLVMInt32Type] 2 0]
set i2 [LLVMCreateGenericValueOfInt [LLVMInt32Type] 3 0]
set i3 [LLVMCreateGenericValueOfInt [LLVMInt32Type] 4 0]
set i4 [LLVMCreateGenericValueOfInt [LLVMInt32Type] 5 0]
set res [LLVMRunFunction_Tcl $EE $func [list $i0 $i1 $i2 $i3 $i4]]
puts "test = [test 1 2 3 4 5] = [expr {int([LLVMGenericValueToInt $res 0])}]\n"

puts [time {test 1 2 3 4 5} 1000]
puts [time {LLVMRunFunction_Tcl $EE $func [list $i0 $i1 $i2 $i3 $i4]} 1000]
