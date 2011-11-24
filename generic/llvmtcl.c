#include "tcl.h"
#include <iostream>
#include <sstream>
#include <map>
#include "llvm/Support/raw_ostream.h"
#include "llvm/PassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"
#include "llvm/Transforms/IPO.h"
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

// Code taken from tools/opt/opt.cpp

void LLVMCreateStandardFunctionPasses(LLVMPassManagerRef PM, unsigned OptimizationLevel)
{
    llvm::PassManagerBuilder Builder;
    Builder.OptLevel = OptimizationLevel;
    if (OptimizationLevel == 0) {
	// No inlining pass
    } else if (OptimizationLevel > 1) {
	unsigned Threshold = 225;
	if (OptimizationLevel > 2)
	    Threshold = 275;
	Builder.Inliner = llvm::createFunctionInliningPass(Threshold);
    } else {
	Builder.Inliner = llvm::createAlwaysInlinerPass();
    }
    Builder.DisableUnrollLoops = OptimizationLevel == 0;
    Builder.populateFunctionPassManager(*(dynamic_cast<llvm::FunctionPassManager*>(llvm::unwrap(PM))));
}

void LLVMCreateStandardModulePasses(LLVMPassManagerRef PM,
				    unsigned OptimizationLevel)
{
    llvm::PassManagerBuilder Builder;
    Builder.OptLevel = OptimizationLevel;
    if (OptimizationLevel == 0) {
	// No inlining pass
    } else if (OptimizationLevel > 1) {
	unsigned Threshold = 225;
	if (OptimizationLevel > 2)
	    Threshold = 275;
	Builder.Inliner = llvm::createFunctionInliningPass(Threshold);
    } else {
	Builder.Inliner = llvm::createAlwaysInlinerPass();
    }
    Builder.DisableUnrollLoops = OptimizationLevel == 0;
    Builder.populateModulePassManager(*(dynamic_cast<llvm::PassManagerBase*>(llvm::unwrap(PM))));
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
    if (Tcl_PkgProvide(interp, "llvmtcl", "3.0") != TCL_OK) {
	return TCL_ERROR;
    }
#include "llvmtcl-gen-cmddef.c"  
    return TCL_OK;
}
