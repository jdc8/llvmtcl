package require llvmtcl
source ../llvmtcl.tcl

set optimize 1
set procs {test2 test test3 test4 facti low_pass test5 fact fact10 factmp filter test_append}
set procs "test_append"
set timings {low_pass filter}
set timing_count 10

package require tcltest

proc test_append {a b} {
    append x $a $b $b $b $b $b $a
    return $x
}

proc test {a b c d e} {
    if {$a <= 66 && $a > 50} {
	set rt 100
    } else {
	set rt 0
    }
    return $rt
}

proc test2 {a b c d e} {
    return [expr {4+$a+6}]
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
    return [facti 10]
}

proc factmp { } {
    return [facti 40]
}

proc low_pass {x x1 x2 y1 y2 C0 C1 C2 C3 C4} {
    return [expr {$x*$C0 + $x1*$C1 + $x2*$C2 + $y1*$C3 + $y2*$C4}]
}

proc filter { } {
    set y 0
    set x1 0
    set x2 0
    set y1 0
    set y2 0
    for {set i 0} {$i < 1000} {incr i} {
	set y [low_pass $i $x1 $x2 $y1 $y2 1 3 -2 4 -5]
	# Messing with the result to stay within 32 bit
	if {$y > 1000 || $y < -1000} {
	    set y 1
	} else {
	    set y1 $y
	}
	set y2 $y1
	set y1 $y
	set x2 $x1
	set x1 $i
    }
    return $y
}

# Initialize the JIT
llvmtcl LinkInJIT
llvmtcl InitializeNativeTarget

# Create a module
set m [llvmtcl ModuleCreateWithName "atest"]
lassign [llvmtcl CreateJITCompilerForModule $m 0] rt EE msg

# Convert Tcl to llvmtcl 
foreach nm $procs {
    set func($nm) [llvmtcl Tcl2LLVM $EE $m $nm 1]
}
set all_funcs {}
foreach nm $procs {
    lappend all_funcs [set func($nm) [set f [llvmtcl Tcl2LLVM $EE $m $nm]]]
}

# Save module
set f [open tebc.ll w]
puts $f [llvmtcl DumpModule $m]
close $f

# Verify the module
lassign [llvmtcl VerifyModule $m LLVMReturnStatusAction] rt msg
if {$rt} {
    error $msg
}

# Optimize functions and module
if {$optimize} {
    for {set i 0} {$i < 10} {incr i} {
	llvmtcl Optimize $m $all_funcs
    }
}

set f [open tebc-optimized.ll w]
puts $f [llvmtcl DumpModule $m]
close $f

# Some tests

puts "OK? Tcl        llvmtcl        Function"
puts "--- ---------- ---------- ------------------------------------"
foreach nm $procs {
    set ta($nm) {}
    set la($nm) [list [llvmtcl CreateGenericValueOfTclInterp]]
    switch -glob -- $nm {
	"filter*" -
	"fact10" -
	"factmp" {
	}
	"fact*" {
	    set ta($nm) 5
	    lappend la($nm) [llvmtcl CreateGenericValueOfTclObj 5]
	}
	"low_pass*" {
	    set ta($nm) {500 1000 2000 1234 5678 1341 2682 1341 16607 -5591}
	    foreach v $ta($nm) {
		lappend la($nm) [llvmtcl CreateGenericValueOfTclObj $v]
	    }
	}
	"test_append" {
	    set ta($nm) {foo bar}
	    lappend la($nm) [llvmtcl CreateGenericValueOfTclObj foo]
	    lappend la($nm) [llvmtcl CreateGenericValueOfTclObj bar]
	}
	default {
	    set ta($nm) {5 2 3 4 5}
	    foreach v $ta($nm) {
		lappend la($nm) [llvmtcl CreateGenericValueOfTclObj $v]
	    }
	}
    }
    set res [llvmtcl RunFunction $EE $func($nm) $la($nm)]
    set tr [$nm {*}$ta($nm)]
    set lr [llvmtcl GenericValueToTclObj $res]
    puts "[expr {$tr==$lr?"OK ":"ERR"}] [format %10s $tr] [format %10s $lr] $nm"
}

foreach nm $timings {
    if {$nm in $procs} {
	puts "tcl \[$nm\]: [time {$nm {*}$ta($nm)} $timing_count]"
	puts "llvm \[$nm\]: [time {llvmtcl RunFunction $EE $func($nm) $la($nm)} $timing_count]"
    }
}


