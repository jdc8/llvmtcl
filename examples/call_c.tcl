lappend auto_path .
package require llvmtcl

llvmtcl LinkInJIT
llvmtcl InitializeNativeTarget

# Create a module, execution engine and builder
set m [llvmtcl ModuleCreateWithName "testmodule"]
lassign [llvmtcl CreateJITCompilerForModule $m 0] rt EE msg
llvmtcl AddLLVMTclCommands $EE $m
set bld [llvmtcl CreateBuilder]


# Create a function calling C functions
set pt [llvmtcl PointerType [llvmtcl Int8Type] 0]
set ft [llvmtcl FunctionType $pt [list $pt $pt $pt $pt $pt] 0]
set wtest [llvmtcl AddFunction $m "wrapped_test" $ft]

# Get C functions to be called
set test [llvmtcl GetNamedFunction $m "llvm_test"]
set add [llvmtcl GetNamedFunction $m "llvm_add"]
set sub [llvmtcl GetNamedFunction $m "llvm_sub"]

# Create the function
set entry [llvmtcl AppendBasicBlock $wtest entry]
llvmtcl PositionBuilderAtEnd $bld $entry
set rt1 [llvmtcl BuildCall $bld $add [list [llvmtcl GetParam $wtest 0] [llvmtcl GetParam $wtest 1] [llvmtcl GetParam $wtest 2]] "call"]
set rt2 [llvmtcl BuildCall $bld $add [list [llvmtcl GetParam $wtest 0] $rt1 [llvmtcl GetParam $wtest 3]] "call"]
set rt3 [llvmtcl BuildCall $bld $sub [list [llvmtcl GetParam $wtest 0] $rt2 [llvmtcl GetParam $wtest 4]] "call"]
#llvmtcl BuildCall $bld $test [list] "call"
llvmtcl BuildRet $bld $rt2

# Verify the function
puts [llvmtcl DumpModule $m]
lassign [llvmtcl VerifyModule $m LLVMReturnStatusAction] rt msg
if {$rt} {
    error $msg
}

set td [llvmtcl CreateTargetData ""]
llvmtcl OptimizeFunction $m $wtest 3 $td
llvmtcl OptimizeModule $m 3 $td
puts [llvmtcl DumpModule $m]

# Execute
set al {}
lappend al [llvmtcl CreateGenericValueOfTclInterp]
lappend al [llvmtcl CreateGenericValueOfTclObj 1]
lappend al [llvmtcl CreateGenericValueOfTclObj 2]
lappend al [llvmtcl CreateGenericValueOfTclObj 3]
lappend al [llvmtcl CreateGenericValueOfTclObj 4]
set res [llvmtcl RunFunction $EE $wtest $al]
puts "wrapped_test = [llvmtcl GenericValueToTclObj $res]"

# Cleanup
llvmtcl DisposeModule $m
