lappend auto_path .
package require llvmtcl

namespace import llvmtcl::*

LLVMLinkInJIT
LLVMInitializeNativeTarget

set m [LLVMModuleCreateWithName "testmodule"]
set bld [LLVMCreateBuilder]

# Create a function with an int32 argument returning an int32
set ft [LLVMFunctionType [LLVMInt32Type] [list [LLVMInt32Type]] 0]
set fac [LLVMAddFunction $m "fac" $ft]

# Create constants
set two [LLVMConstInt [LLVMInt32Type] 2  0]
set one [LLVMConstInt [LLVMInt32Type] 1  0]

# Create the basic blocks
set entry [LLVMAppendBasicBlock $fac entry]
set exit_lt_2 [LLVMAppendBasicBlock $fac exit_lt_2]
set recurse [LLVMAppendBasicBlock $fac recurse]

# Put arguments on the stack to avoid having to write select and/or phi nodes
LLVMPositionBuilderAtEnd $bld $entry
set arg0_1 [LLVMGetParam $fac 0]
set arg0_2 [LLVMBuildAlloca $bld [LLVMInt32Type] arg0]
set arg0_3 [LLVMBuildStore $bld $arg0_1 $arg0_2]

# Compare input < 2
set arg0_4 [LLVMBuildLoad $bld $arg0_2 "n"]
set cc [LLVMBuildICmp $bld LLVMIntSLT $arg0_4 $two "cc"]

# Branch
LLVMBuildCondBr $bld $cc $exit_lt_2 $recurse

# If n < 2, return 1
LLVMPositionBuilderAtEnd $bld $exit_lt_2
LLVMBuildRet $bld $one

# If >= 2, return n*fac(n-1)
LLVMPositionBuilderAtEnd $bld $recurse
set arg0_5 [LLVMBuildLoad $bld $arg0_2 "n"]
set arg0_minus_1 [LLVMBuildSub $bld $arg0_5 $one "arg0_minus_1"]
set fc [LLVMBuildCall $bld $fac [list $arg0_minus_1] "rec"]
set rt [LLVMBuildMul $bld $arg0_5 $fc "rt"]
LLVMBuildRet $bld $rt
# Done

# Create function returning fac(10)
set ft [LLVMFunctionType [LLVMInt32Type] [list] 0]
set fac10 [LLVMAddFunction $m "fac10" $ft]
set ten [LLVMConstInt [LLVMInt32Type] 10 0]
set main [LLVMAppendBasicBlock $fac10 main]
LLVMPositionBuilderAtEnd $bld $main
set rt [LLVMBuildCall $bld $fac [list $ten] "rec"]
LLVMBuildRet $bld $rt

# Write LLVM bit code to file
LLVMWriteBitcodeToFile $m fac.bc

# Write LLVM textual representation to file
set f [open fac.ll w]
puts $f [LLVMDumpModule $m]
close $f

# Verify the module
lassign [LLVMVerifyModule $m LLVMReturnStatusAction] rt msg
if {$rt} {
    error $msg
}

# Run the fac and fac10 functions
lassign [LLVMCreateJITCompilerForModule $m 0] rt EE msg
set i [LLVMCreateGenericValueOfInt [LLVMInt32Type] 10 0]
set res [LLVMRunFunction $EE $fac $i]
puts "res=$res=[LLVMGenericValueToInt $res 0]"
set res [LLVMRunFunction $EE $fac10 {}]
puts "res=$res=[LLVMGenericValueToInt $res 0]"

# Time runs of fac and fac10
puts [time {LLVMRunFunction $EE $fac $i} 1000]
puts [time {LLVMRunFunction $EE $fac10 {}} 1000]

# Optimize functions and module
set td [LLVMCreateTargetData ""]
LLVMSetDataLayout $m [LLVMCopyStringRepOfTargetData $td]
for {set t 0} {$t < 10} {incr t} {
    LLVMOptimizeFunction $m $fac 3 $td
    LLVMOptimizeFunction $m $fac10 3 $td
    LLVMOptimizeModule $m 3 0 1 1 1 0  $td
}

# Write LLVM bit code to file
LLVMWriteBitcodeToFile $m fac-optimized.bc

# Write LLVM textual representation to file
set f [open fac-optimized.ll w]
puts $f [LLVMDumpModule $m]
close $f

# Time runs of fac and fac10
puts [time {LLVMRunFunction $EE $fac $i} 1000]
puts [time {LLVMRunFunction $EE $fac10 {}} 1000]
