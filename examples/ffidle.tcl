# Example showing how to call library function

lappend auto_path .
package require llvmtcl

# Initialize the JIT
llvmtcl LinkInMCJIT
llvmtcl InitializeNativeTarget

# Create a module and builder
set m [llvmtcl ModuleCreateWithName "testmodule"]
set bld [llvmtcl CreateBuilder]

# Create a sin function calling math lib's 'double sin(double)'
set ft [llvmtcl FunctionType [llvmtcl DoubleType] [list [llvmtcl DoubleType]] 0]
set wsin [llvmtcl AddFunction $m "wrapped_sin" $ft]
set sin [llvmtcl AddFunction $m "sin" $ft]
set entry [llvmtcl AppendBasicBlock $wsin entry]
llvmtcl PositionBuilderAtEnd $bld $entry

# Call a c function
set rt [llvmtcl BuildCall $bld $sin [list [llvmtcl GetParam $wsin 0]] "call"]

# Set return
llvmtcl BuildRet $bld $rt

# Create a function to calculate sqrt(a^2+b^2)
set ft2 [llvmtcl FunctionType [llvmtcl DoubleType] [list [llvmtcl DoubleType] [llvmtcl DoubleType]] 0]
set pyth [llvmtcl AddFunction $m "pyth" $ft2]
set pow [llvmtcl AddFunction $m "pow" $ft2]
set sqrt [llvmtcl AddFunction $m "sqrt" $ft]
set entry [llvmtcl AppendBasicBlock $pyth entry]
llvmtcl PositionBuilderAtEnd $bld $entry
set a2 [llvmtcl BuildCall $bld $pow [list [llvmtcl GetParam $pyth 0] [llvmtcl ConstReal [llvmtcl DoubleType] 2]] "a2"]
set b2 [llvmtcl BuildCall $bld $pow [list [llvmtcl GetParam $pyth 1] [llvmtcl ConstReal [llvmtcl DoubleType] 2]] "b2"]
set c2 [llvmtcl BuildFAdd $bld $a2 $b2 "c2"]
set c [llvmtcl BuildCall $bld $sqrt [list $c2] "c"]
llvmtcl BuildRet $bld $c

# Verify the module
puts [llvmtcl DumpModule $m]
lassign [llvmtcl VerifyModule $m LLVMReturnStatusAction] rt msg
if {$rt} {
    error $msg
}

# Optimize
llvmtcl Optimize $m [list $wsin $pyth]
puts [llvmtcl DumpModule $m]

# Execute 'wsin'
llvmtcl SetTarget $m x86
set td [llvmtcl CreateTargetData "e"]
llvmtcl SetDataLayout $m [llvmtcl CopyStringRepOfTargetData $td]
lassign [llvmtcl CreateExecutionEngineForModule $m] rt EE msg
set i [llvmtcl CreateGenericValueOfFloat [llvmtcl DoubleType] 0.5]
set res [llvmtcl RunFunction $EE $wsin $i]
puts "sin(0.5) = [llvmtcl GenericValueToFloat [llvmtcl DoubleType] $res]"

# Execute 'pyth'
set a [llvmtcl CreateGenericValueOfFloat [llvmtcl DoubleType] 3]
set b [llvmtcl CreateGenericValueOfFloat [llvmtcl DoubleType] 4]
set res [llvmtcl RunFunction $EE $pyth [list $a $b]]
puts "sqrt(pow(3,2)+pow(4,2)) = [llvmtcl GenericValueToFloat [llvmtcl DoubleType] $res]"


# Cleanup
llvmtcl DisposeModule $m
