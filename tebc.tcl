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

# Initialize the JIT
LLVMLinkInJIT
LLVMInitializeNativeTarget

# Create a module and builder
set m [LLVMModuleCreateWithName "atest"]

# Convert Tcl to LLVM
foreach nm {test test2 test3 test4 test5} {
    set func($nm) [Tcl2LLVM $m $nm]
}

puts "----- Input --------------------------------------------------"
puts [LLVMModuleDump $m]
puts "----- Optimized ----------------------------------------------"
LLVMOptimizeModule $m
puts [LLVMModuleDump $m]
puts "--------------------------------------------------------------"

set tclArgs {5 2 3 4 5}
set llvmArgs {}
foreach v $tclArgs {
    lappend llvmArgs [LLVMCreateGenericValueOfInt [LLVMInt32Type] $v 0]
}

lassign [LLVMCreateJITCompilerForModule $m 0] rt EE msg

puts "OK? Tcl        LLVM       Function"
puts "--- ---------- ---------- ------------------------------------"
foreach {nm f} [array get func] {
    set res [LLVMRunFunction_Tcl $EE $f $llvmArgs]
    set tr [$nm {*}$tclArgs]
    set lr [expr {int([LLVMGenericValueToInt $res 0])}]
    puts "[expr {$tr==$lr?"OK ":"ERR"}] [format %10d $tr] [format %10d $lr] $nm"
}

