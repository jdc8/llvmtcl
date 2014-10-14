lappend auto_path ..
package require llvmtcl

llvmtcl LinkInMCJIT
llvmtcl InitializeNativeTarget

set m [llvmtcl ModuleCreateWithName "testmodule"]
set bld [llvmtcl CreateBuilder]

# Create a function with an int32 argument returning an int32
set ft [llvmtcl FunctionType [llvmtcl Int32Type] [list [llvmtcl Int32Type]] 0]
set fac [llvmtcl AddFunction $m "fac" $ft]

# Create constants
set two [llvmtcl ConstInt [llvmtcl Int32Type] 2  0]
set one [llvmtcl ConstInt [llvmtcl Int32Type] 1  0]

# Create the basic blocks
set entry [llvmtcl AppendBasicBlock $fac entry]
set exit_lt_2 [llvmtcl AppendBasicBlock $fac exit_lt_2]
set recurse [llvmtcl AppendBasicBlock $fac recurse]

# Put arguments on the stack to avoid having to write select and/or phi nodes
llvmtcl PositionBuilderAtEnd $bld $entry
set arg0_1 [llvmtcl GetParam $fac 0]
set arg0_2 [llvmtcl BuildAlloca $bld [llvmtcl Int32Type] arg0]
set arg0_3 [llvmtcl BuildStore $bld $arg0_1 $arg0_2]

# Compare input < 2
set arg0_4 [llvmtcl BuildLoad $bld $arg0_2 "n"]
set cc [llvmtcl BuildICmp $bld LLVMIntSLT $arg0_4 $two "cc"]

# Branch
llvmtcl BuildCondBr $bld $cc $exit_lt_2 $recurse

# If n < 2, return 1
llvmtcl PositionBuilderAtEnd $bld $exit_lt_2
llvmtcl BuildRet $bld $one

# If >= 2, return n*fac(n-1)
llvmtcl PositionBuilderAtEnd $bld $recurse
set arg0_5 [llvmtcl BuildLoad $bld $arg0_2 "n"]
set arg0_minus_1 [llvmtcl BuildSub $bld $arg0_5 $one "arg0_minus_1"]
set fc [llvmtcl BuildCall $bld $fac [list $arg0_minus_1] "rec"]
set rt [llvmtcl BuildMul $bld $arg0_5 $fc "rt"]
llvmtcl BuildRet $bld $rt
# Done

# Create function returning fac(10)
set ft [llvmtcl FunctionType [llvmtcl Int32Type] [list] 0]
set fac10 [llvmtcl AddFunction $m "fac10" $ft]
set ten [llvmtcl ConstInt [llvmtcl Int32Type] 10 0]
set main [llvmtcl AppendBasicBlock $fac10 main]
llvmtcl PositionBuilderAtEnd $bld $main
set rt [llvmtcl BuildCall $bld $fac [list $ten] "rec"]
llvmtcl BuildRet $bld $rt

# Write llvmtcl  bit code to file
llvmtcl WriteBitcodeToFile $m fac.bc

# Write llvmtcl  textual representation to file
set f [open fac.ll w]
puts $f [llvmtcl DumpModule $m]
close $f

# Verify the module
lassign [llvmtcl VerifyModule $m LLVMReturnStatusAction] rt msg
if {$rt} {
    error $msg
}

# Run the fac and fac10 functions
llvmtcl SetTarget $m X86
set td [llvmtcl CreateTargetData "e"]
llvmtcl SetDataLayout $m [llvmtcl CopyStringRepOfTargetData $td]
lassign [llvmtcl CreateExecutionEngineForModule $m] rt EE msg
set i [llvmtcl CreateGenericValueOfInt [llvmtcl Int32Type] 10 0]
set res [llvmtcl RunFunction $EE $fac $i]
puts "res=$res=[llvmtcl GenericValueToInt $res 0]"
set res [llvmtcl RunFunction $EE $fac10 {}]
puts "res=$res=[llvmtcl GenericValueToInt $res 0]"

# Time runs of fac and fac10
puts [time {llvmtcl RunFunction $EE $fac $i} 1000]
puts [time {llvmtcl RunFunction $EE $fac10 {}} 1000]

# Optimize functions and module
set td [llvmtcl CreateTargetData ""]
llvmtcl SetDataLayout $m [llvmtcl CopyStringRepOfTargetData $td]
for {set t 0} {$t < 10} {incr t} {
    llvmtcl OptimizeFunction $m $fac 3 $td
    llvmtcl OptimizeFunction $m $fac10 3 $td
    llvmtcl OptimizeModule $m 3 $td
}

# Write llvmtcl  bit code to file
llvmtcl WriteBitcodeToFile $m fac-optimized.bc

# Write llvmtcl  textual representation to file
set f [open fac-optimized.ll w]
puts $f [llvmtcl PrintModuleToString $m]
close $f

# Time runs of fac and fac10
puts [time {llvmtcl RunFunction $EE $fac $i} 1000]
puts [time {llvmtcl RunFunction $EE $fac10 {}} 1000]
