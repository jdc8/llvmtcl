lappend auto_path .
package require llvmtcl

namespace import llvmtcl::*

# Initialize the JIT
LLVMLinkInJIT
LLVMInitializeNativeTarget

# Create a module and builder
set m [LLVMModuleCreateWithName "testmodule"]
set bld [LLVMCreateBuilder]

# Create a plus10 function, taking one argument and adding 6 and 4 to it
set ft [LLVMFunctionType [LLVMInt32Type] [list [LLVMInt32Type]] 0]
set plus10 [LLVMAddFunction $m "plus10" $ft]

# Create constants
set c6 [LLVMConstInt [LLVMInt32Type] 6 0]
set c4 [LLVMConstInt [LLVMInt32Type] 4 0]

# Create the basic blocks
set entry [LLVMAppendBasicBlock $plus10 entry]

# Put arguments on the stack to avoid having to write select and/or phi nodes
LLVMPositionBuilderAtEnd $bld $entry
set arg0_1 [LLVMGetParam $plus10 0]
set arg0_2 [LLVMBuildAlloca $bld [LLVMInt32Type] arg0]
set arg0_3 [LLVMBuildStore $bld $arg0_1 $arg0_2]

# Do add 10 in two steps to see the optimizer @ work

# Add 6
set arg0_4 [LLVMBuildLoad $bld $arg0_2 "arg0"]
set add6 [LLVMBuildAdd $bld $arg0_4 $c6 "add6"]

# Add 4
set add4 [LLVMBuildAdd $bld $add6 $c4 "add4"]

# Set return
LLVMBuildRet $bld $add4

# Show input
puts "----- Input --------------------------------------------------"
puts [LLVMDumpModule $m]

# Write function as bit code
LLVMWriteBitcodeToFile $m plus10.bc

#set vrt [LLVMTclVerifyModule $m LLVMPrintMessageAction]
#puts "Verify: $vrt"

# Execute
lassign [LLVMCreateJITCompilerForModule $m 0] rt EE msg
set i [LLVMCreateGenericValueOfInt [LLVMInt32Type] 4 0]
set res [LLVMRunFunction $EE $plus10 $i]
puts "plus10(4) = [LLVMGenericValueToInt $res 0]\n"
LLVMOptimizeFunction $m $plus10 3
LLVMOptimizeModule $m 3 0 1 1 1 0
puts "----- Optimized ----------------------------------------------"
puts [LLVMDumpModule $m]
LLVMWriteBitcodeToFile $m plus10-optimized.bc

set res [LLVMRunFunction $EE $plus10 $i]
puts "plus10(4) = [LLVMGenericValueToInt $res 0]\n"
