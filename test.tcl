lappend auto_path .
package require tcltest
package require llvmtcl

# LLVMInitializeNativeTarget
tcltest::test llvm-2.1 {check LLVMInitializeNativeTarget sub command} -body {
    llvmtcl::LLVMInitializeNativeTarget
} -returnCodes {ok return} -match glob -result {}

tcltest::test llvm-2.2 {check LLVMInitializeNativeTarget sub command} -body {
    llvmtcl::LLVMInitializeNativeTarget a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMInitializeNativeTarget "}

# LLVMLinkInJIT
tcltest::test llvm-3.1 {check LLVMLinkInJIT sub command} -body {
    llvmtcl::LLVMLinkInJIT
} -returnCodes {ok return} -match glob -result {}

tcltest::test llvm-3.2 {check LLVMLinkInJIT sub command} -body {
    llvmtcl::LLVMLinkInJIT a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMLinkInJIT "}

# LLVMModuleCreateWithName
tcltest::test llvm-4.1 {check LLVMModuleCreateWithName sub command} -body {
    llvmtcl::LLVMModuleCreateWithName
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMModuleCreateWithName name"}

tcltest::test llvm-4.2 {check LLVMModuleCreateWithName sub command} -body {
    llvmtcl::LLVMModuleCreateWithName a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMModuleCreateWithName name"}

tcltest::test llvm-4.3 {check LLVMModuleCreateWithName sub command} -body {
    set m [llvmtcl::LLVMModuleCreateWithName test43]
} -cleanup {
    llvmtcl::LLVMDisposeModule $m
} -returnCodes {ok return} -match glob -result {LLVMModuleRef_*}

# LLVMDisposeModule
tcltest::test llvm-5.1 {check LLVMDisposeModule sub command} -body {
    llvmtcl::LLVMDisposeModule
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMDisposeModule moduleRef"}

tcltest::test llvm-5.2 {check LLVMDisposeModule sub command} -body {
    llvmtcl::LLVMDisposeModule a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMDisposeModule moduleRef"}

tcltest::test llvm-5.3 {check LLVMDisposeModule sub command} -body {
    llvmtcl::LLVMDisposeModule brol
} -returnCodes {error} -match glob -result {expected module but got "brol"}

tcltest::test llvm-5.4 {check LLVMDisposeModule sub command} -setup {
    set m [llvmtcl::LLVMModuleCreateWithName test54]
} -body {
    llvmtcl::LLVMDisposeModule $m
} -returnCodes {ok return} -match glob -result {}

# LLVMCreateBuilder
tcltest::test llvm-6.2 {check LLVMCreateBuilder sub command} -body {
    llvmtcl::LLVMCreateBuilder a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMCreateBuilder "}

tcltest::test llvm-6.3 {check LLVMCreateBuilder sub command} -body {
    set b [llvmtcl::LLVMCreateBuilder]
} -cleanup {
    llvmtcl::LLVMDisposeBuilder $b
} -returnCodes {ok return} -match glob -result {LLVMBuilderRef_*}

# LLVMDisposeBuilder
tcltest::test llvm-7.1 {check LLVMDisposeBuilder sub command} -body {
    llvmtcl::LLVMDisposeBuilder
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMDisposeBuilder builderRef"}

tcltest::test llvm-7.2 {check LLVMDisposeBuilder sub command} -body {
    llvmtcl::LLVMDisposeBuilder a b c d e f g
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMDisposeBuilder builderRef"}

tcltest::test llvm-7.3 {check LLVMDisposeBuilder sub command} -body {
    llvmtcl::LLVMDisposeBuilder brol
} -returnCodes {error} -match glob -result {expected builder but got "brol"}

tcltest::test llvm-7.4 {check LLVMDisposeBuilder sub command} -setup {
    set b [llvmtcl::LLVMCreateBuilder]
} -body {
    llvmtcl::LLVMDisposeBuilder $b
} -returnCodes {ok return} -match glob -result {}

# LLVM<type>>
tcltest::test llvm-8.1 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMDoubleType a b c d e f g]
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMDoubleType "}

tcltest::test llvm-8.2 {check LLVM type sub command} -body {
    lappend t [llvmtcl::LLVMDoubleType]
    lappend t [llvmtcl::LLVMFP128Type]
    lappend t [llvmtcl::LLVMFloatType]
    lappend t [llvmtcl::LLVMInt16Type]
    lappend t [llvmtcl::LLVMInt1Type]
    lappend t [llvmtcl::LLVMInt32Type]
    lappend t [llvmtcl::LLVMInt64Type]
    lappend t [llvmtcl::LLVMInt8Type]
    lappend t [llvmtcl::LLVMIntType 43]
    lappend t [llvmtcl::LLVMIntType 83]
    lappend t [llvmtcl::LLVMIntType 153]
    lappend t [llvmtcl::LLVMPPCFP128Type]
    lappend t [llvmtcl::LLVMX86FP80Type]
    lappend t [llvmtcl::LLVMArrayType [llvmtcl::LLVMInt32Type] 10]
    lappend t [llvmtcl::LLVMPointerType [llvmtcl::LLVMInt32Type] 10]
    lappend t [llvmtcl::LLVMVectorType [llvmtcl::LLVMInt32Type] 10]
    lappend t [llvmtcl::LLVMStructType [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 10]
    lappend t [llvmtcl::LLVMUnionType [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]]]
    lappend t [llvmtcl::LLVMFunctionType [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 0]
    lappend t [llvmtcl::LLVMFunctionType [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 1]
    lappend t [llvmtcl::LLVMFunctionType [llvmtcl::LLVMInt32Type] {} 0]
    lappend t [llvmtcl::LLVMFunctionType [llvmtcl::LLVMInt32Type] {} 1]
    lappend t [llvmtcl::LLVMLabelType]
    lappend t [llvmtcl::LLVMOpaqueType]
    lappend t [llvmtcl::LLVMVoidType]
} -returnCodes {ok return} -match glob -result {LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_* LLVMTypeRef_*}

tcltest::test llvm-8.3 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMIntType]
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMIntType width"}

tcltest::test llvm-8.4 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMIntType qwerty]
} -returnCodes {error} -match glob -result {expected integer but got "qwerty"}

tcltest::test llvm-8.5 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMArrayType]
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMArrayType elementTypeRef elementCount"}

tcltest::test llvm-8.6 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMArrayType [llvmtcl::LLVMInt32Type] qwerty]
} -returnCodes {error} -match glob -result {expected integer but got "qwerty"}

tcltest::test llvm-8.7 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMArrayType qwerty 12]
} -returnCodes {error} -match glob -result {expected type but got "qwerty"}

tcltest::test llvm-8.8 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMPointerType]
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMPointerType elementTypeRef addressSpace"}

tcltest::test llvm-8.9 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMPointerType [llvmtcl::LLVMInt32Type] qwerty]
} -returnCodes {error} -match glob -result {expected integer but got "qwerty"}

tcltest::test llvm-8.10 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMPointerType qwerty 12]
} -returnCodes {error} -match glob -result {expected type but got "qwerty"}

tcltest::test llvm-8.11 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMVectorType]
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMVectorType elementTypeRef elementCount"}

tcltest::test llvm-8.12 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMVectorType [llvmtcl::LLVMInt32Type] qwerty]
} -returnCodes {error} -match glob -result {expected integer but got "qwerty"}

tcltest::test llvm-8.13 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMVectorType qwerty 12]
} -returnCodes {error} -match glob -result {expected type but got "qwerty"}

tcltest::test llvm-8.14 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMStructType]
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMStructType listOfElementTypeRefs packed"}

tcltest::test llvm-8.15 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMStructType {} 0]
} -returnCodes {error} -match glob -result {no element types specified}

tcltest::test llvm-8.16 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMStructType [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] brol]
} -returnCodes {error} -match glob -result {expected boolean value but got "brol"}

tcltest::test llvm-8.17 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMStructType {a b c d e f g} 0]
} -returnCodes {error} -match glob -result {expected type but got "a"}

tcltest::test llvm-8.18 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMStructType "a b c \{ d e f g" 0]
} -returnCodes {error} -match glob -result "expected list of types but got \"a b c \{ d e f g\""

tcltest::test llvm-8.19 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMUnionType]
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMUnionType listOfElementTypeRefs"}

tcltest::test llvm-8.20 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMUnionType {}]
} -returnCodes {error} -match glob -result {no element types specified}

tcltest::test llvm-8.21 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMUnionType {a b c d e f g}]
} -returnCodes {error} -match glob -result {expected type but got "a"}

tcltest::test llvm-8.22 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMUnionType "a b c \{ d e f g"]
} -returnCodes {error} -match glob -result "expected list of types but got \"a b c \{ d e f g\""

tcltest::test llvm-8.23 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMFunctionType]
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMFunctionType returnTypeRef listOfArgumentTypeRefs isVarArg"}

tcltest::test llvm-8.24 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMFunctionType brol {} 0]
} -returnCodes {error} -match glob -result {expected type but got "brol"}

tcltest::test llvm-8.25 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMFunctionType [llvmtcl::LLVMInt32Type] {brol} 0]
} -returnCodes {error} -match glob -result {expected type but got "brol"}

tcltest::test llvm-8.26 {check LLVM type sub command} -body {
    set t [llvmtcl::LLVMFunctionType [llvmtcl::LLVMInt32Type] {} brol]
} -returnCodes {error} -match glob -result {expected boolean value but got "brol"}

# Function
tcltest::test llvm-9.1 {check LLVM function sub command} -body {
    llvmtcl::LLVMAddFunction
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMAddFunction moduleRef functionName functionTypeRef"}

tcltest::test llvm-9.2 {check LLVM function sub command} -body {
    llvmtcl::LLVMAddFunction module function92 type
} -returnCodes {error} -match glob -result {expected module but got "module"}

tcltest::test llvm-9.3 {check LLVM function sub command} -setup {
    set m [llvmtcl::LLVMModuleCreateWithName test93]
} -body {
    llvmtcl::LLVMAddFunction $m function93 type
} -cleanup {
    llvmtcl::LLVMDisposeModule $m
} -returnCodes {error} -match glob -result {expected type but got "type"}

tcltest::test llvm-9.4 {check LLVM function sub command} -setup {
    set m [llvmtcl::LLVMModuleCreateWithName test94]
    set t [llvmtcl::LLVMFunctionType  [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 0]
} -body {
    set f [llvmtcl::LLVMAddFunction $m function94 $t]
} -cleanup {
    llvmtcl::LLVMDeleteFunction $f
    llvmtcl::LLVMDisposeModule $m
} -returnCodes {ok return} -match glob -result {LLVMValueRef_*}

tcltest::test llvm-9.5 {check LLVM function sub command} -setup {
    set m [llvmtcl::LLVMModuleCreateWithName test94]
    set t [llvmtcl::LLVMFunctionType  [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 0]
    set f [llvmtcl::LLVMAddFunction $m function94 $t]
} -body {
    llvmtcl::LLVMDeleteFunction $f
} -cleanup {
    llvmtcl::LLVMDisposeModule $m
} -returnCodes {ok return} -match glob -result {}

tcltest::test llvm-9.5 {check LLVM function sub command} -body {
    llvmtcl::LLVMDeleteFunction
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMDeleteFunction functionRef"}

tcltest::test llvm-9.6 {check LLVM function sub command} -body {
    llvmtcl::LLVMDeleteFunction brol
} -returnCodes {error} -match glob -result {expected value but got "brol"}

# Constants
# Int
tcltest::test llvm-10.1.1 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstInt
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMConstInt typeRef value signExtended"}

tcltest::test llvm-10.1.2 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstInt brol 1 0
} -returnCodes {error} -match glob -result {expected type but got "brol"}

tcltest::test llvm-10.1.3 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstInt [llvmtcl::LLVMInt32Type]  brol 0
} -returnCodes {error} -match glob -result {expected integer but got "brol"}

tcltest::test llvm-10.1.4 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstInt [llvmtcl::LLVMInt32Type]  10 0
} -returnCodes {ok return} -match glob -result {LLVMValueRef_*}

# Can't test, LLVM has assert, would need to check type compatibility in C
#tcltest::test llvm-10.1.5 {check LLVM const sub command} -body {
#    llvmtcl::LLVMConstInt [llvmtcl::LLVMFloatType]  10 0
#} -returnCodes {error} -match glob -result {}

tcltest::test llvm-10.1.6 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstInt [llvmtcl::LLVMInt32Type]  10 brol
} -returnCodes {error} -match glob -result {expected boolean value but got "brol"}

# IntOfString
tcltest::test llvm-10.2.1 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstIntOfString
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMConstIntOfString typeRef value radix"}

tcltest::test llvm-10.2.2 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstIntOfString brol 1 10
} -returnCodes {error} -match glob -result {expected type but got "brol"}

# Can't test, LLVM has assert, would need to check digits in C
#tcltest::test llvm-10.2.3 {check LLVM const sub command} -body {
#    llvmtcl::LLVMConstIntOfString [llvmtcl::LLVMInt32Type] brol 10
#} -returnCodes {error} -match glob -result {}

tcltest::test llvm-10.2.4 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstIntOfString [llvmtcl::LLVMInt32Type] 1 brol
} -returnCodes {error} -match glob -result {expected integer but got "brol"}

tcltest::test llvm-10.2.5 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstIntOfString [llvmtcl::LLVMInt32Type] 1 111
} -returnCodes {error} -match glob -result {radix should be 2, 8, 10, or 16}

# Can't test, LLVM has assert, would need to check type compatibility in C
#tcltest::test llvm-10.2.6 {check LLVM const sub command} -body {
#    llvmtcl::LLVMConstIntOfString [llvmtcl::LLVMFloatType] 111 16
#} -returnCodes {error} -match glob -result {}

tcltest::test llvm-10.2.7 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstIntOfString [llvmtcl::LLVMInt32Type] 111 16
} -returnCodes {ok return} -match glob -result {LLVMValueRef_*}

# Real
tcltest::test llvm-10.3.1 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstReal
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMConstReal typeRef value"}

tcltest::test llvm-10.3.2 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstReal brol 1
} -returnCodes {error} -match glob -result {expected type but got "brol"}

tcltest::test llvm-10.3.3 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstReal [llvmtcl::LLVMFloatType] brol
} -returnCodes {error} -match glob -result {expected floating-point number but got "brol"}

tcltest::test llvm-10.3.4 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstReal [llvmtcl::LLVMFloatType] 1.234
} -returnCodes {ok return} -match glob -result {LLVMValueRef_*}

# Can't test, LLVM has assert, would need to check type compatibility in C
#tcltest::test llvm-10.3.4 {check LLVM const sub command} -body {
#    llvmtcl::LLVMConstReal [llvmtcl::LLVMInt32Type] 1.234
#} -returnCodes {ok return} -match glob -result {LLVMValueRef_*}

# RealOfString
tcltest::test llvm-10.4.1 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstRealOfString
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMConstRealOfString typeRef value"}

tcltest::test llvm-10.4.2 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstRealOfString brol 1
} -returnCodes {error} -match glob -result {expected type but got "brol"}

# Can't test, LLVM has assert, would need to check type compatibility in C
#tcltest::test llvm-10.4.2 {check LLVM const sub command} -body {
#    llvmtcl::LLVMConstRealOfString [llvmtcl::LLVMInt32Type] 1.2345
#} -returnCodes {error} -match glob -result {expected type but got "brol"}

# Can't test, LLVM has assert, would need to check digits in C
#tcltest::test llvm-10.4.3 {check LLVM const sub command} -body {
#    llvmtcl::LLVMConstRealOfString [llvmtcl::LLVMFloatType] brol
#} -returnCodes {error} -match glob -result {}

tcltest::test llvm-10.4.5 {check LLVM const sub command} -body {
    llvmtcl::LLVMConstRealOfString [llvmtcl::LLVMFloatType] 1.3579
} -returnCodes {ok return} -match glob -result {LLVMValueRef_*}

# Basic blocks
tcltest::test llvm-11.1.1 {check LLVM basic block sub command} -body {
    llvmtcl::LLVMAppendBasicBlock
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMAppendBasicBlock functionRef name"}

tcltest::test llvm-11.1.2 {check LLVM basic block sub command} -body {
    llvmtcl::LLVMAppendBasicBlock function name
} -returnCodes {error} -match glob -result {expected value but got "function"}

tcltest::test llvm-11.1.3 {check LLVM basic block sub command} -setup {
    set m [llvmtcl::LLVMModuleCreateWithName test113]
    set t [llvmtcl::LLVMFunctionType  [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 0]
    set f [llvmtcl::LLVMAddFunction $m function113 $t]
} -body {
    set b [llvmtcl::LLVMAppendBasicBlock $f name]
} -cleanup {
    llvmtcl::LLVMDeleteBasicBlock $b
    llvmtcl::LLVMDeleteFunction $f
    llvmtcl::LLVMDisposeModule $m
} -returnCodes {ok return} -match glob -result {LLVMBasicBlockRef_*}

tcltest::test llvm-11.2.1 {check LLVM basic block sub command} -body {
    llvmtcl::LLVMInsertBasicBlock
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMInsertBasicBlock beforeBasicBlockRef name"}

tcltest::test llvm-11.2.2 {check LLVM basic block sub command} -body {
    llvmtcl::LLVMInsertBasicBlock basicBlock name
} -returnCodes {error} -match glob -result {expected basic block but got "basicBlock"}

tcltest::test llvm-11.2.3 {check LLVM basic block sub command} -setup {
    set m [llvmtcl::LLVMModuleCreateWithName test113]
    set t [llvmtcl::LLVMFunctionType  [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 0]
    set f [llvmtcl::LLVMAddFunction $m function113 $t]
    set bb [llvmtcl::LLVMAppendBasicBlock $f name]
} -body {
    set b [llvmtcl::LLVMInsertBasicBlock $bb name]
} -cleanup {
    llvmtcl::LLVMDeleteBasicBlock $b
    llvmtcl::LLVMDeleteBasicBlock $bb
    llvmtcl::LLVMDeleteFunction $f
    llvmtcl::LLVMDisposeModule $m
} -returnCodes {ok return} -match glob -result {LLVMBasicBlockRef_*}

tcltest::test llvm-11.3.1 {check LLVM basic block sub command} -body {
    llvmtcl::LLVMDeleteBasicBlock
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMDeleteBasicBlock basicBlockRef"}

tcltest::test llvm-11.3.2 {check LLVM basic block sub command} -body {
    llvmtcl::LLVMDeleteBasicBlock basicBlock
} -returnCodes {error} -match glob -result {expected basic block but got "basicBlock"}

tcltest::test llvm-11.3.3 {check LLVM basic block sub command} -setup {
    set m [llvmtcl::LLVMModuleCreateWithName test113]
    set t [llvmtcl::LLVMFunctionType  [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 0]
    set f [llvmtcl::LLVMAddFunction $m function113 $t]
    set b [llvmtcl::LLVMAppendBasicBlock $f name]
} -body {
    llvmtcl::LLVMDeleteBasicBlock $b
} -cleanup {
    llvmtcl::LLVMDeleteFunction $f
    llvmtcl::LLVMDisposeModule $m
} -returnCodes {ok return} -match glob -result {}

# Position builder
tcltest::test llvm-12.1.1 {check LLVM position builder sub command} -body {
    llvmtcl::LLVMPositionBuilder
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMPositionBuilder builderRef basicBlockRef instrRef"}

tcltest::test llvm-12.1.2 {check LLVM position builder sub command} -body {
    llvmtcl::LLVMPositionBuilder builder block instr
} -returnCodes {error} -match glob -result {expected builder but got "builder"}

tcltest::test llvm-12.1.3 {check LLVM position builder sub command} -setup {
    set b [llvmtcl::LLVMCreateBuilder]
} -body {
    llvmtcl::LLVMPositionBuilder $b block instr
} -cleanup {
    llvmtcl::LLVMDisposeBuilder $b
} -returnCodes {error} -match glob -result {expected basic block but got "block"}

tcltest::test llvm-12.1.4 {check LLVM position builder sub command} -setup {
    set m [llvmtcl::LLVMModuleCreateWithName test113]
    set t [llvmtcl::LLVMFunctionType  [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 0]
    set f [llvmtcl::LLVMAddFunction $m function113 $t]
    set bb [llvmtcl::LLVMAppendBasicBlock $f name]
    set b [llvmtcl::LLVMCreateBuilder]
} -body {
    llvmtcl::LLVMPositionBuilder $b $bb instr
} -cleanup {
    llvmtcl::LLVMDeleteBasicBlock $bb
    llvmtcl::LLVMDeleteFunction $f
    llvmtcl::LLVMDisposeBuilder $b
    llvmtcl::LLVMDisposeModule $m
} -returnCodes {error} -match glob -result {expected value but got "instr"}

# Can't run until instructions can be generated
puts "Complete test llvm-12.1.5"
# tcltest::test llvm-12.1.5 {check LLVM position builder sub command} -setup {
#     set m [llvmtcl::LLVMModuleCreateWithName test113]
#     set t [llvmtcl::LLVMFunctionType  [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 0]
#     set f [llvmtcl::LLVMAddFunction $m function113 $t]
#     set bb [llvmtcl::LLVMAppendBasicBlock $f name]
#     set b [llvmtcl::LLVMCreateBuilder]
#     set i [?????]
# } -body {
#     llvmtcl::LLVMPositionBuilder $b $bb $i
# } -cleanup {
#     llvmtcl::LLVMDeleteBasicBlock $bb
#     llvmtcl::LLVMDeleteFunction $f
#     llvmtcl::LLVMDisposeBuilder $b
#     llvmtcl::LLVMDisposeModule $m
# } -returnCodes {op return} -match glob -result {}

tcltest::test llvm-12.2.1 {check LLVM position builder sub command} -body {
    llvmtcl::LLVMPositionBuilderAtEnd
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMPositionBuilderAtEnd builderRef basicBlockRef"}

tcltest::test llvm-12.2.2 {check LLVM position builder sub command} -body {
    llvmtcl::LLVMPositionBuilderAtEnd builder block
} -returnCodes {error} -match glob -result {expected builder but got "builder"}

tcltest::test llvm-12.2.3 {check LLVM position builder sub command} -setup {
    set b [llvmtcl::LLVMCreateBuilder]
} -body {
    llvmtcl::LLVMPositionBuilderAtEnd $b block
} -cleanup {
    llvmtcl::LLVMDisposeBuilder $b
} -returnCodes {error} -match glob -result {expected basic block but got "block"}

tcltest::test llvm-12.2.4 {check LLVM position builder sub command} -setup {
    set m [llvmtcl::LLVMModuleCreateWithName test113]
    set t [llvmtcl::LLVMFunctionType  [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 0]
    set f [llvmtcl::LLVMAddFunction $m function113 $t]
    set bb [llvmtcl::LLVMAppendBasicBlock $f name]
    set b [llvmtcl::LLVMCreateBuilder]
} -body {
    llvmtcl::LLVMPositionBuilderAtEnd $b $bb
} -cleanup {
    llvmtcl::LLVMDeleteBasicBlock $bb
    llvmtcl::LLVMDeleteFunction $f
    llvmtcl::LLVMDisposeBuilder $b
    llvmtcl::LLVMDisposeModule $m
} -returnCodes {ok return} -match glob -result {}

tcltest::test llvm-12.3.1 {check LLVM position builder sub command} -body {
    llvmtcl::LLVMPositionBuilderBefore
} -returnCodes {error} -match glob -result {wrong # args: should be "llvmtcl::LLVMPositionBuilderBefore builderRef instrRef"}

tcltest::test llvm-12.3.2 {check LLVM position builder sub command} -body {
    llvmtcl::LLVMPositionBuilderBefore builder instr
} -returnCodes {error} -match glob -result {expected builder but got "builder"}

tcltest::test llvm-12.3.3 {check LLVM position builder sub command} -setup {
    set b [llvmtcl::LLVMCreateBuilder]
} -body {
    llvmtcl::LLVMPositionBuilderBefore $b instr
} -cleanup {
    llvmtcl::LLVMDisposeBuilder $b
} -returnCodes {error} -match glob -result {expected value but got "instr"}

# Can't run until instructions can be generated
puts "Complete test llvm-12.3.4"
# tcltest::test llvm-12.3.4 {check LLVM position builder sub command} -setup {
#     set m [llvmtcl::LLVMModuleCreateWithName test113]
#     set t [llvmtcl::LLVMFunctionType  [llvmtcl::LLVMInt32Type] [list [llvmtcl::LLVMInt32Type] [llvmtcl::LLVMInt32Type]] 0]
#     set f [llvmtcl::LLVMAddFunction $m function113 $t]
#     set b [llvmtcl::LLVMCreateBuilder]
#     set i [????]
# } -body {
#     llvmtcl::LLVMPositionBuilderBefore $b $i
# } -cleanup {
#     llvmtcl::LLVMDeleteBasicBlock $bb
#     llvmtcl::LLVMDeleteFunction $f
#     llvmtcl::LLVMDisposeBuilder $b
#     llvmtcl::LLVMDisposeModule $m
# } -returnCodes {ok return} -match glob -result {}

::tcltest::cleanupTests
return

#puts [brol qwerty] ; exit

namespace eval llvmtcl {
    namespace export *
}

namespace import llvmtcl::*

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
