lappend auto_path ..
package require llvmtcl

llvmtcl LinkInJIT
llvmtcl InitializeNativeTarget

set m [llvmtcl ModuleCreateWithName "testmodule"]
set bld [llvmtcl CreateBuilder]

# Create a function with an int32 argument returning an int32
set ft [llvmtcl FunctionType [llvmtcl Int32Type] [list [llvmtcl Int32Type]] 0]
set test [llvmtcl AddFunction $m "test" $ft]

# Get argument
set arg [llvmtcl GetParam $test 0]

# Create constants
set zero [llvmtcl ConstInt [llvmtcl Int32Type] 0  0]
set one [llvmtcl ConstInt [llvmtcl Int32Type] 1  0]
set two [llvmtcl ConstInt [llvmtcl Int32Type] 2  0]

# Create basic blocks
set entry [llvmtcl AppendBasicBlock $test entry]
set then [llvmtcl AppendBasicBlock $test then]
set else [llvmtcl AppendBasicBlock $test else]
set exit [llvmtcl AppendBasicBlock $test exit]

# Test input value
llvmtcl PositionBuilderAtEnd $bld $entry
set cc [llvmtcl BuildICmp $bld LLVMIntSLT $arg $zero "cc"]

# Branch
llvmtcl BuildCondBr $bld $cc $then $else

# Build then branch
llvmtcl PositionBuilderAtEnd $bld $then
set rt_then [llvmtcl BuildAdd $bld $arg $one "add1"]
llvmtcl BuildBr $bld $exit

# Build else branch
llvmtcl PositionBuilderAtEnd $bld $else
set rt_else [llvmtcl BuildAdd $bld $arg $two "add2"]
llvmtcl BuildBr $bld $exit

# Build exit block
llvmtcl PositionBuilderAtEnd $bld $exit
set return [llvmtcl BuildPhi $bld [llvmtcl Int32Type] "return"]
llvmtcl AddIncoming $return [list $rt_then $rt_else] [list $then $else]
llvmtcl BuildRet $bld $return

# Write llvmtcl bit code to file
llvmtcl WriteBitcodeToFile $m test.bc

# Write llvmtcl textual representation to file
set f [open test.ll w]
puts $f [llvmtcl DumpModule $m]
close $f

# Verify the module
lassign [llvmtcl VerifyModule $m LLVMReturnStatusAction] rt msg
if {$rt} {
    error $msg
}

# Run the test function
lassign [llvmtcl CreateJITCompilerForModule $m 0] rt EE msg
foreach v {10 -10} {
    set i [llvmtcl CreateGenericValueOfInt [llvmtcl Int32Type] $v 0]
    set res [llvmtcl RunFunction $EE $test $i]
    puts "v=$v, res=$res=[expr {int([llvmtcl GenericValueToInt $res 0])}]"
}

# Optimize functions and module
set td [llvmtcl CreateTargetData ""]
llvmtcl SetDataLayout $m [llvmtcl CopyStringRepOfTargetData $td]
llvmtcl OptimizeFunction $m $test 3 $td
llvmtcl OptimizeModule $m 3 $td

# Write llvmtcl bit code to file
llvmtcl WriteBitcodeToFile $m test-optimized.bc

# Write llvmtcl textual representation to file
set f [open test-optimized.ll w]
puts $f [llvmtcl DumpModule $m]
close $f

# Run the optimized test function
lassign [llvmtcl CreateJITCompilerForModule $m 0] rt EE msg
foreach v {20 -20} {
    set i [llvmtcl CreateGenericValueOfInt [llvmtcl Int32Type] $v 0]
    set res [llvmtcl RunFunction $EE $test $i]
    puts "v=$v, res=$res=[expr {int([llvmtcl GenericValueToInt $res 0])}]"
}
