lappend auto_path .
package require tcltest
package require llvmtcl

# Main command
tcltest::test llvm-1.1 {check main command} -body {
    llvmtcl::llvmtcl
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl subcommand ?arg ...?"}

tcltest::test llvm-1.2 {check help sub command} -body {
    llvmtcl::llvmtcl help
} -returnCodes {ok return} -match glob -result {LLVM Tcl interface*}

tcltest::test llvm-1.3 {check unknown sub command} -body {
    llvmtcl::llvmtcl unknown_sub_command
} -returnCodes {error} -match glob -result {bad subcommand "unknown_sub_command": must be *}

# LLVMInitializeNativeTarget
tcltest::test llvm-2.1 {check LLVMInitializeNativeTarget sub command} -body {
    llvmtcl::llvmtcl LLVMInitializeNativeTarget
} -returnCodes {ok return} -match glob -result {}

tcltest::test llvm-2.2 {check LLVMInitializeNativeTarget sub command} -body {
    llvmtcl::llvmtcl LLVMInitializeNativeTarget a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMInitializeNativeTarget "}

# LLVMLinkInJIT
tcltest::test llvm-3.1 {check LLVMLinkInJIT sub command} -body {
    llvmtcl::llvmtcl LLVMLinkInJIT
} -returnCodes {ok return} -match glob -result {}

tcltest::test llvm-3.2 {check LLVMLinkInJIT sub command} -body {
    llvmtcl::llvmtcl LLVMLinkInJIT a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMLinkInJIT "}

# LLVMModuleCreateWithName
tcltest::test llvm-4.1 {check LLVMModuleCreateWithName sub command} -body {
    llvmtcl::llvmtcl LLVMModuleCreateWithName
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMModuleCreateWithName name"}

tcltest::test llvm-4.2 {check LLVMModuleCreateWithName sub command} -body {
    llvmtcl::llvmtcl LLVMModuleCreateWithName a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMModuleCreateWithName name"}

tcltest::test llvm-4.3 {check LLVMModuleCreateWithName sub command} -body {
    set m [llvmtcl::llvmtcl LLVMModuleCreateWithName test42]
} -cleanup {
    llvmtcl::llvmtcl LLVMDisposeModule $m
} -returnCodes {ok return} -match glob -result {LLVMModuleRef_*}

# LLVMDisposeModule
tcltest::test llvm-5.1 {check LLVMDisposeModule sub command} -body {
    llvmtcl::llvmtcl LLVMDisposeModule
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMDisposeModule module"}

tcltest::test llvm-5.2 {check LLVMDisposeModule sub command} -body {
    llvmtcl::llvmtcl LLVMDisposeModule a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMDisposeModule module"}

tcltest::test llvm-5.3 {check LLVMDisposeModule sub command} -body {
    llvmtcl::llvmtcl LLVMDisposeModule brol
} -returnCodes {error} -match glob -result {unknown module}

tcltest::test llvm-5.4 {check LLVMDisposeModule sub command} -setup {
    set m [llvmtcl::llvmtcl LLVMModuleCreateWithName test53]
} -body {
    llvmtcl::llvmtcl LLVMDisposeModule $m
} -returnCodes {ok return} -match glob -result {}

# LLVMCreateBuilder
tcltest::test llvm-6.2 {check LLVMCreateBuilder sub command} -body {
    llvmtcl::llvmtcl LLVMCreateBuilder a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMCreateBuilder "}

tcltest::test llvm-6.3 {check LLVMCreateBuilder sub command} -body {
    set b [llvmtcl::llvmtcl LLVMCreateBuilder]
} -cleanup {
    llvmtcl::llvmtcl LLVMDisposeBuilder $b
} -returnCodes {ok return} -match glob -result {LLVMBuilderRef_*}

# LLVMDisposeBuilder
tcltest::test llvm-7.1 {check LLVMDisposeBuilder sub command} -body {
    llvmtcl::llvmtcl LLVMDisposeBuilder
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMDisposeBuilder builder"}

tcltest::test llvm-7.2 {check LLVMDisposeBuilder sub command} -body {
    llvmtcl::llvmtcl LLVMDisposeBuilder a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMDisposeBuilder builder"}

tcltest::test llvm-7.3 {check LLVMDisposeBuilder sub command} -body {
    llvmtcl::llvmtcl LLVMDisposeBuilder brol
} -returnCodes {error} -match glob -result {unknown builder}

tcltest::test llvm-7.4 {check LLVMDisposeBuilder sub command} -setup {
    set b [llvmtcl::llvmtcl LLVMCreateBuilder]
} -body {
    llvmtcl::llvmtcl LLVMDisposeBuilder $b
} -returnCodes {ok return} -match glob -result {}

# LLVM<type>
tcltest::test llvm-8.1 {check LLVM<type> sub command} -body {
    set t [llvmtcl::llvmtcl LLVMDoubleType a b c d e f g]
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMDoubleType "}

tcltest::test llvm-8.2 {check LLVM<type> sub command} -body {
    lappend t [llvmtcl::llvmtcl LLVMDoubleType]
    lappend t [llvmtcl::llvmtcl LLVMFP128Type]
    lappend t [llvmtcl::llvmtcl LLVMFloatType]
    lappend t [llvmtcl::llvmtcl LLVMInt16Type]
    lappend t [llvmtcl::llvmtcl LLVMInt1Type]
    lappend t [llvmtcl::llvmtcl LLVMInt32Type]
    lappend t [llvmtcl::llvmtcl LLVMInt64Type]
    lappend t [llvmtcl::llvmtcl LLVMInt8Type]
    lappend t [llvmtcl::llvmtcl LLVMIntType 43]
    lappend t [llvmtcl::llvmtcl LLVMIntType 83]
    lappend t [llvmtcl::llvmtcl LLVMIntType 153]
    lappend t [llvmtcl::llvmtcl LLVMPPCFP128Type]
    lappend t [llvmtcl::llvmtcl LLVMX86FP80Type]
} -returnCodes {ok return} -match glob -result {LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_*}

tcltest::test llvm-8.3 {check LLVM<type> sub command} -body {
    set t [llvmtcl::llvmtcl LLVMIntType]
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::llvmtcl LLVMIntType width"}

tcltest::test llvm-8.4 {check LLVM<type> sub command} -body {
    set t [llvmtcl::llvmtcl LLVMIntType qwerty]
} -returnCodes {error} -match glob -result {expected integer but got "qwerty"}

::tcltest::cleanupTests
return

#puts [brol qwerty] ; exit

set m [LLVMModuleCreateWithName "testmodule"]
set bld [LLVMCreateBuilder]

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
set cc [LLVMBuildICmp $bld $LLVMIntSLT $arg0_4 $two "cc"]
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

# Function doing fac(10)
set ft [LLVMFunctionType [LLVMInt32Type] [list] 0]
set fac10 [LLVMAddFunction $m "fac10" $ft]
set ten [LLVMConstInt [LLVMInt32Type] 10 0]
set main [LLVMAppendBasicBlock $fac10 main]
LLVMPositionBuilderAtEnd $bld $main
set rt [LLVMBuildCall $bld $fac [list $ten] "rec"]
LLVMBuildRet $bld $rt




set vrt [LLVMTclVerifyModule $m $LLVMPrintMessageAction]
puts "Verify: $vrt"
puts "Input"
puts [LLVMModuleText $m]
#LLVMWriteBitcodeToFile $m fac.bc





#LLVMOptimizeModule $m
#LLVMOptimizeModule $m
#LLVMOptimizeModule $m
#LLVMOptimizeModule $m
#LLVMOptimizeModule $m
#LLVMOptimizeModule $m
#LLVMOptimizeModule $m
#puts "Optimized"
#puts [LLVMModuleText $m]


# puts "provider"
# set provider [LLVMCreateModuleProviderForExistingModule $m]
# puts "engine"
# set engine [LLVMCreateJITCompiler $provider 0]
# puts "int"
# set i [LLVMCreateGenericValueOfInt [LLVMInt32Type] 10 0]
# puts "run"
# set res [LLVMRunFunction $engine $fac [list $i]]
# puts "result"
# puts fac=[LLVMGenericValueToInt $res 0]
# puts "exit"
# exit

set EE [LLVMCreateJITCompilerForModule $m 0]
puts "EE=$EE"
set i [LLVMCreateGenericValueOfInt [LLVMInt32Type] 10 0]
puts "i=$i"
set res [LLVMRunFunction $EE $fac $i]
puts "res=$res"
