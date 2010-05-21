lappend auto_path .
package require llvmtcl

namespace import llvmtcl::*

set optimize 1
set procs {test2 test test3 test4 test5 fact facti fact10}

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

proc facti n {
    set rt 1
    while {$n > 1} {
	set rt [expr {$rt*$n}]
	incr n -1
    }
    return $rt
}

proc fact10 { } {
    return [fact 10]
}

# Initialize the JIT
LLVMLinkInJIT
LLVMInitializeNativeTarget

# Create a module
set m [LLVMModuleCreateWithName "atest"]

# Convert Tcl to LLVM
foreach nm $procs {
    set func($nm) [Tcl2LLVM $m $nm 1]
}
foreach nm $procs {
    set func($nm) [Tcl2LLVM $m $nm]
}

# Save module
set f [open tebc.ll w]
puts $f [LLVMDumpModule $m]
close $f

# Verify the module
lassign [LLVMVerifyModule $m LLVMReturnStatusAction] rt msg
if {$rt} {
    error $msg
}

# Optimize functions and module
if {$optimize} {
    set td [LLVMCreateTargetData ""]
    LLVMSetDataLayout $m [LLVMCopyStringRepOfTargetData $td]
    foreach {nm f} [array get func] {
	LLVMOptimizeFunction $m $f 3 $td
    }
    LLVMOptimizeModule $m 3 0 1 1 1 0 $td
}

# Some tests
set tclArgs {5 2 3 4 5}
set llvmArgs {}
foreach v $tclArgs {
    lappend llvmArgs [LLVMCreateGenericValueOfInt [LLVMInt32Type] $v 0]
}

lassign [LLVMCreateJITCompilerForModule $m 0] rt EE msg

puts "OK? Tcl        LLVM       Function"
puts "--- ---------- ---------- ------------------------------------"
foreach nm $procs {
    switch -glob -- $nm {
	"test*" {
	    set la $llvmArgs
	    set ta $tclArgs
	}
	"fact10" {
	    set la {}
	    set ta {}
	}
	"fact*" {
	    set la [lindex $llvmArgs 0]
	    set ta [lindex $tclArgs 0]
	}
    }
    set res [LLVMRunFunction $EE $func($nm) $la]
    set tr [$nm {*}$ta]
    set lr [expr {int([LLVMGenericValueToInt $res 0])}]
    puts "[expr {$tr==$lr?"OK ":"ERR"}] [format %10d $tr] [format %10d $lr] $nm"
}

set v [LLVMCreateGenericValueOfInt [LLVMInt32Type] 10 0]
puts ""
puts "tcl \[fact 10\]  : [time {fact 10} 10000]"
puts "tcl \[fact10\]   : [time {fact10} 10000]"
puts "llvm \[fact 10\] : [time {LLVMRunFunction $EE $func(fact) $v} 10000]"
puts "llvm \[fact10\]  : [time {LLVMRunFunction $EE $func(fact10) {}} 10000]"

