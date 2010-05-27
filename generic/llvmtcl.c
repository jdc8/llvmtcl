#include "tcl.h"
#include <iostream>
#include <sstream>
#include <map>
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/StandardPasses.h"
#include "llvm-c/Analysis.h"
#include "llvm-c/Core.h"
#include "llvm-c/ExecutionEngine.h"
#include "llvm-c/Target.h"
#include "llvm-c/BitWriter.h"
#include "llvm-c/Transforms/IPO.h"
#include "llvm-c/Transforms/Scalar.h"

static std::string GetRefName(std::string prefix)
{
    static int LLVMRef_id = 0;
    std::ostringstream os;
    os << prefix << LLVMRef_id;
    LLVMRef_id++;
    return os.str();
}

#include "llvmtcl-gen-map.c"

void LLVMDisposeBuilderTcl(LLVMBuilderRef builderRef)
{
    LLVMDisposeBuilder(builderRef);
    LLVMBuilderRef_map.erase(LLVMBuilderRef_refmap[builderRef]);
    LLVMBuilderRef_refmap.erase(builderRef);
}

void LLVMDisposeModuleTcl(LLVMModuleRef moduleRef)
{
    LLVMDisposeModule(moduleRef);
    LLVMModuleRef_map.erase(LLVMModuleRef_refmap[moduleRef]);
    LLVMModuleRef_refmap.erase(moduleRef);
}

void LLVMDisposePassManagerTcl(LLVMPassManagerRef passManagerRef)
{
    LLVMDisposePassManager(passManagerRef);
    LLVMPassManagerRef_map.erase(LLVMPassManagerRef_refmap[passManagerRef]);
    LLVMPassManagerRef_refmap.erase(passManagerRef);
}

int LLVMDeleteFunctionTcl(LLVMValueRef functionRef)
{
    LLVMDeleteFunction(functionRef);
    LLVMValueRef_map.erase(LLVMValueRef_refmap[functionRef]);
    LLVMValueRef_refmap.erase(functionRef);
    return TCL_OK;
}

void LLVMDeleteBasicBlockTcl(LLVMBasicBlockRef basicBlockRef)
{
    LLVMDeleteBasicBlock(basicBlockRef);
    LLVMBasicBlockRef_map.erase( LLVMBasicBlockRef_refmap[basicBlockRef]);
    LLVMBasicBlockRef_refmap.erase(basicBlockRef);
}

std::string LLVMDumpModuleTcl(LLVMModuleRef moduleRef)
{
    std::string s;
    llvm::raw_string_ostream os(s);
    os << *(reinterpret_cast<llvm::Module*>(moduleRef));
    return s;
}

LLVMGenericValueRef LLVMRunFunction(LLVMExecutionEngineRef EE, LLVMValueRef F, LLVMGenericValueRef *Args, unsigned NumArgs) 
{
    return LLVMRunFunction(EE, F, NumArgs, Args);
}

void LLVMCreateStandardFunctionPasses(LLVMPassManagerRef PM, unsigned OptimizationLevel)
{
    llvm::createStandardFunctionPasses(dynamic_cast<llvm::FunctionPassManager*>(llvm::unwrap(PM)),
				       OptimizationLevel);
}

void LLVMCreateStandardModulePasses(LLVMPassManagerRef PM,
				    unsigned OptimizationLevel,
				    bool OptimizeSize,
				    bool UnitAtATime,
				    bool UnrollLoops,
				    bool SimplifyLibCalls,
				    bool HaveExceptions)
{
    llvm::createStandardModulePasses(dynamic_cast<llvm::PassManager*>(llvm::unwrap(PM)),
				     OptimizationLevel,
				     OptimizeSize,
				     UnitAtATime,
				     UnrollLoops,
				     SimplifyLibCalls,
				     HaveExceptions,
				     llvm::createFunctionInliningPass());
}

void LLVMCreateStandardLTOPasses(LLVMPassManagerRef PM,
				 bool Internalize,
				 bool RunInliner,
				 bool VerifyEach)
{
    llvm::createStandardLTOPasses(dynamic_cast<llvm::PassManager*>(llvm::unwrap(PM)),
				  Internalize,
				  RunInliner,
				  VerifyEach);
}

#include "llvmtcl-gen.c"

#define LLVMObjCmd(tclName, cName) Tcl_CreateObjCommand(interp, tclName, (Tcl_ObjCmdProc*)cName, (ClientData)NULL, (Tcl_CmdDeleteProc*)NULL);

extern "C" DLLEXPORT int Llvmtcl_Init(Tcl_Interp *interp)
{
    if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_PkgRequire(interp, "Tcl", TCL_VERSION, 0) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_PkgProvide(interp, "llvmtcl", "0.1") != TCL_OK) {
	return TCL_ERROR;
    }
#include "llvmtcl-gen-cmddef.c"  
    return TCL_OK;
}
