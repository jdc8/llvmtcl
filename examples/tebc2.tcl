lappend auto_path ..
package require llvmtcl

namespace eval LLVM {
    llvmtcl LinkInJIT
    llvmtcl InitializeNativeTarget
    variable counter 0
    variable optimiseRounds 10
    variable dumpPre {}
    variable dumpPost {}

    proc optimise {args} {
	variable counter
	variable optimiseRounds
	variable dumpPre
	variable dumpPost
	set module [llvmtcl ModuleCreateWithName module[incr counter]]
	foreach p $args {
	    set cmd [uplevel 1 [list namespace which $p]]
	    lappend cmds $cmd
	    llvmtcl Tcl2LLVM $module $cmd 1
	}
	set funcs [lmap f $cmds {llvmtcl Tcl2LLVM $module $f}]
	lassign [llvmtcl VerifyModule $module LLVMReturnStatusAction] rt msg
	if {$rt} {
	    return -code error $msg
	}
	variable dumpPre [llvmtcl DumpModule $module]
	for {set i 0} {$i < $optimiseRounds} {incr i} {
	    llvmtcl Optimize $module $funcs
	}
	variable dumpPost [llvmtcl DumpModule $module]
	lassign [llvmtcl CreateJITCompilerForModule $module 0] rt ee msg
	if {$rt} {
	    return -code error $msg
	}
	foreach cmd $cmds func $funcs {
	    set argc [llength [info args $cmd]]
	    set args [info args $cmd]
	    set type [llvmtcl Int32Type]
	    set argmap {}
	    foreach a $args {
		append argmap " \[llvmtcl CreateGenericValueOfInt $type \$$a 0\]"
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

    namespace export *
    namespace ensemble create
}

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

# Baseline
puts [f 50]
puts [time {f 50} 100]
# Convert to optimised form
puts [LLVM optimise f g]
# Write out the generated code
puts [LLVM post]
# Compare with baseline
puts [f 50]
puts [time {f 50} 100]
puts [f__test 50]
## Checks of what is done in the glue layer
#puts [info body f]
#puts [tcl::unsupported::disassemble proc f]
