lappend auto_path [file join [file dirname [info script]] ..]

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
# This one triggers some weird bugs, some now fixed
proc itertest {n m} {
    set xx 0
    while {$n > $m} {
	incr xx [incr x]
	if {$x>$n*$m*$n} break
	if {[incr y $m] >= $n} {return $xx}
	if {[incr xx $y] > 100} continue
	incr x $m
    }
    return $xx
}
proc tadd {pp pq qp qq} {
    set topp [expr {$pp*$qq + $qp*$pq}]
    set topq [expr {$pq*$qq}]
    set prodp [expr {$pp*$qp}]
    set prodq [expr {$pq*$qq}]
    set lowp [expr {$prodp - $prodq}]
    set resultp [set gcd1 [expr {$topp * $prodq}]]
    set resultq [set gcd2 [expr {$topq * $lowp}]]
    # Critical! Normalize using the GCD
    while {$gcd2 != 0} {
	set gcd2 [expr {$gcd1 % [set gcd1 $gcd2]}]
    }
    set r [expr {$resultp - $resultq}]
    return [expr {($r<0?-$r:$r)/$gcd1}]
}
# This one will be for testing float types; crashes right now
proc typetest {a b} {
    set x 0.0
    for {set i 0} {$i < $a} {incr i} {
	set x [expr {$x + $x * $x + $b}]
    }
    return [expr {$x > 5.0}]
}

package require Tk
package require llvmopt 0.1a1

#########################
#### Basic GUI stuff ####

wm title . "Native Compilation with LLVM"
pack [ttk::notebook .nb]
proc pane {title content} {
    set f [ttk::frame .nb.f[incr ::nb]]
    .nb add $f -text $title
    text $f.text -yscroll "$f.scroll set" -wrap none
    ttk::scrollbar $f.scroll -command "$f.text yview"
    grid $f.text $f.scroll -sticky nsew
    grid column $f 0 -weight 1
    grid row $f 0 -weight 1
    $f.text insert 1.0 $content
}

##############################
#### The code of interest ####

proc fib2 n {
    for {set a 0; set b 1} {$n > 0} {incr n -1} {
	set b [expr {$a + [set a $b]}]
    }
    return $a
}
set test_script {
    fib2 28
}

#################################
#### Show the starting point ####

pane "Source Procedure" [list proc fib2 [info args fib2] [info body fib2]]
pane "Disassembled Source" [::tcl::unsupported::disassemble proc fib2]
pane "Original Timings (10k)" \
    "Test script:${test_script}Results: [eval $test_script]\nTiming: [time $test_script 10000]"

###################################
#### Convert to optimised form ####
try {
    LLVM optimise fib2
} on error {msg opt} {
    puts $msg\n[dict get $opt -errorinfo]
    puts [LLVM pre]
    exit 1
}

##########################################################################
#### Write out the generated code, both before and after optimization ####

pane "LLVM IR (unoptimised)" [LLVM pre]
pane "LLVM IR (optimised)" [LLVM post]

##############################################
#### Performance comparison with baseline ####

pane "New Timings (10k)" \
    "Test script:${test_script}Results: [eval $test_script]\nTiming: [time $test_script 10000]"

return
# Baseline
# puts tailrec:[time {fib 20} 100000]
# puts iterate:[time {fib2 20} 100000]
pane "Source Procedure" [list proc fib2 [info args fib2] [info body fib2]]
pane "Disassembled Source" [tcl::unsupported::disassemble proc fib2]
# set s {itertest 15 2}
# set s {tadd 78 2 3 69}
set s {fib2 28}
pane "Original Timings (10k)" \
    "Test script:\n\t${s}\nResults: [eval $s]\nTiming: [time $s 10000]"
# Convert to optimised form
try {
    LLVM optimise fib2
    # LLVM optimise f g fact fib fibin fib2
    # puts opt:[time {LLVM optimise itertest tadd}]
} on error {msg opt} {
    puts $msg\n[dict get $opt -errorinfo]
    exit 1
}
# Write out the generated code
pane "LLVM IR (unoptimised)" [LLVM pre]
pane "LLVM IR (optimised)" [LLVM post]
# Compare with baseline
# puts tailrec:[time {fib 20} 100000]
# puts iterate:[time {fib2 20} 100000]
pane "New Timings (10k)" \
    "Test script:\n\t${s}\nResults: [eval $s]\nTiming: [time $s 10000]"
