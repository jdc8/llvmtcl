lappend auto_path ..
package require llvmtcl

set optimize 1
set procs {test2} ;#{ test test3 test4 test5 fact facti fact10 low_pass filter}
set timings {low_pass filter}
set timing_count 10

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
    return [fact 10]
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

# Convert Tcl to llvmtcl 
foreach nm $procs {
    set func($nm) [llvmtcl Tcl2LLVM  $m $nm 1]
}
set all_funcs {}
foreach nm $procs {
    lappend all_funcs [set func($nm) [set f [llvmtcl Tcl2LLVM  $m $nm]]]
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

lassign [llvmtcl CreateJITCompilerForModule $m 0] rt EE msg

puts "OK? Tcl        llvmtcl        Function"
puts "--- ---------- ---------- ------------------------------------"
foreach nm $procs {
    switch -glob -- $nm {
	"filter*" -
	"fact10" {
	    set la($nm) {}
	    set ta($nm) {}
	}
	"fact*" {
	    set ta($nm) 5
	    set la($nm) [llvmtcl CreateGenericValueOfInt [llvmtcl Int32Type] 5 0]
	}
	"low_pass*" {
	    set ta($nm) {500 1000 2000 1234 5678 1341 2682 1341 16607 -5591}
	    set la($nm) {}
	    foreach v $ta($nm) {
		lappend la($nm) [llvmtcl CreateGenericValueOfInt [llvmtcl Int32Type] $v 0]
	    }
	}
	default {
	    set ta($nm) {5 2 3 4 5}
	    set la($nm) {}
	    foreach v $ta($nm) {
		lappend la($nm) [llvmtcl CreateGenericValueOfInt [llvmtcl Int32Type] $v 0]
	    }
	}
    }
    set res [llvmtcl RunFunction $EE $func($nm) $la($nm)]
    set tr [$nm {*}$ta($nm)]
    set lr [expr {int([llvmtcl GenericValueToInt $res 0])}]
    puts "[expr {$tr==$lr?"OK ":"ERR"}] [format %10d $tr] [format %10d $lr] $nm"
}

foreach nm $timings {
    puts "tcl \[$nm\]: [time {$nm {*}$ta($nm)} $timing_count]"
    puts "llvm \[$nm\]: [time {llvmtcl RunFunction $EE $func($nm) $la($nm)} $timing_count]"
}


