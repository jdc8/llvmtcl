lappend auto_path ..
package require llvmtcl

# Initialize the JIT
llvmtcl LinkInJIT
llvmtcl InitializeNativeTarget

# Create a module and builder
set m [llvmtcl ModuleCreateWithName "testmodule"]
set bld [llvmtcl CreateBuilder]

# Create a plus10 function, taking one argument and adding 6 and 4 to it
set ft [llvmtcl FunctionType [llvmtcl Int32Type] [list [llvmtcl Int32Type]] 0]
set plus10 [llvmtcl AddFunction $m "plus10" $ft]

# Create constants
set c6 [llvmtcl ConstInt [llvmtcl Int32Type] 6 0]
set c4 [llvmtcl ConstInt [llvmtcl Int32Type] 4 0]

# Create the basic blocks
set entry [llvmtcl AppendBasicBlock $plus10 entry]

# Put arguments on the stack to avoid having to write select and/or phi nodes
llvmtcl PositionBuilderAtEnd $bld $entry
set arg0_1 [llvmtcl GetParam $plus10 0]
set arg0_2 [llvmtcl BuildAlloca $bld [llvmtcl Int32Type] arg0]
set arg0_3 [llvmtcl BuildStore $bld $arg0_1 $arg0_2]

# Do add 10 in two steps to see the optimizer @ work

# Add 6
set arg0_4 [llvmtcl BuildLoad $bld $arg0_2 "arg0"]
set add6 [llvmtcl BuildAdd $bld $arg0_4 $c6 "add6"]

# Add 4
set add4 [llvmtcl BuildAdd $bld $add6 $c4 "add4"]

# Set return
llvmtcl BuildRet $bld $add4

# Show input
puts "----- Input --------------------------------------------------"
puts [llvmtcl DumpModule $m]

# Verify the module
lassign [llvmtcl VerifyModule $m LLVMReturnStatusAction] rt msg
if {$rt} {
    error $msg
}

# Execute
lassign [llvmtcl CreateJITCompilerForModule $m 0] rt EE msg
set i [llvmtcl CreateGenericValueOfInt [llvmtcl Int32Type] 4 0]
set res [llvmtcl RunFunction $EE $plus10 $i]
puts "plus10(4) = [llvmtcl GenericValueToInt $res 0]\n"

# Optimize
llvmtcl Optimize $m $plus10
puts "----- Optimized ----------------------------------------------"
puts [llvmtcl DumpModule $m]

# Execute optimized code
set res [llvmtcl RunFunction $EE $plus10 $i]
puts "plus10(4) = [llvmtcl GenericValueToInt $res 0]\n"
