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

proc fact n {expr {$n<2? 1: $n * [fact [incr n -1]]}}

# Initialize the JIT
LLVMLinkInJIT
LLVMInitializeNativeTarget

# Create a module and builder
set m [LLVMModuleCreateWithName "atest"]

# Convert Tcl to LLVM
foreach nm {test2 test test3 test4 test5} { ;# test2 test test3 test4 test5 fact
    set func($nm) [Tcl2LLVM $m $nm 1]
}
foreach nm {test2 test test3 test4 test5} { ;# test2 test test3 test4 test5 fact
    set func($nm) [Tcl2LLVM $m $nm]
}

puts "----- Input --------------------------------------------------"
puts [LLVMDumpModule $m]

# puts "----- Optimized ----------------------------------------------"
foreach {nm f} [array get func] {
    LLVMOptimizeFunction $m $f 3
}
LLVMOptimizeModule $m 3 0 1 1 1 0

puts [LLVMDumpModule $m]

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
    switch -glob -- $nm {
	"test*" {
	    set la $llvmArgs
	    set ta $tclArgs
	}
	"fact" {
	    set la [lindex $llvmArgs 0]
	    set ta [lindex $tclArgs 0]
	}
    }
    set res [LLVMRunFunction $EE $f $la]
    set tr [$nm {*}$ta]
    set lr [expr {int([LLVMGenericValueToInt $res 0])}]
    puts "[expr {$tr==$lr?"OK ":"ERR"}] [format %10d $tr] [format %10d $lr] $nm"
}

