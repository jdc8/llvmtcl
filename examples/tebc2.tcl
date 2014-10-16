lappend auto_path ..
source optimise.tcl

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
# This one tickles some weird bugs
proc itertest {n m} {
    while 1 {
	incr xx [incr x]
	if {[incr y $m] >= $n} break
	if {[incr xx $y] > 100} continue
	incr x $m
    }
    return $xx
}
proc typetest {a b} {
    set x 0
    for {set i 0} {$i < $a} {incr i} {
	set x [expr {$x + $x * $x + $b}]
    }
    return [expr {int($x) > 5}]
}

# Baseline
puts tailrec:[time {fib 20} 100000]
puts iterate:[time {fib2 20} 100000]
# puts [tcl::unsupported::disassemble proc itertest]
puts [itertest 15 2]
# Convert to optimised form
try {
    LLVM optimise f g fact fib fibin fib2
    puts opt:[time {LLVM optimise itertest typetest}]
} on error {msg opt} {
    puts [dict get $opt -errorinfo]
    exit 1
}
# Write out the generated code
puts [LLVM post]
# Compare with baseline
puts tailrec:[time {fib 20} 100000]
puts iterate:[time {fib2 20} 100000]
puts [itertest 15 2]
