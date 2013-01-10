#include "tcl.h"
#include "tclTomMath.h"
#include <iostream>
#include <sstream>
#include <map>
#include "llvm/Support/raw_ostream.h"
#include "llvm/PassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"
#include "llvm/Transforms/IPO.h"
#include "llvm/DerivedTypes.h"
#include "llvm/Function.h"
#include "llvm/Support/DynamicLibrary.h"
#include "llvm/ExecutionEngine/GenericValue.h"
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
    Builder.populateFunctionPassManager(*(reinterpret_cast<llvm::FunctionPassManager*>(PM)));
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
    Builder.populateModulePassManager(*(llvm::unwrap(PM)));
}

int LLVMCreateGenericValueOfTclInterpObjCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, " ");
        return TCL_ERROR;
    }
    LLVMGenericValueRef rt = LLVMCreateGenericValueOfPointer(interp);
    Tcl_SetObjResult(interp, SetLLVMGenericValueRefAsObj(interp, rt));
    return TCL_OK;
}

int LLVMCreateGenericValueOfTclObjObjCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "val ");
        return TCL_ERROR;
    }
    Tcl_IncrRefCount(objv[1]);
    LLVMGenericValueRef rt = LLVMCreateGenericValueOfPointer(objv[1]);
    Tcl_SetObjResult(interp, SetLLVMGenericValueRefAsObj(interp, rt));
    return TCL_OK;
}

int LLVMGenericValueToTclObjObjCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "GenVal");
        return TCL_ERROR;
    }
    LLVMGenericValueRef arg1 = 0;
    if (GetLLVMGenericValueRefFromObj(interp, objv[1], arg1) != TCL_OK)
        return TCL_ERROR;
    Tcl_Obj* rt = (Tcl_Obj*)LLVMGenericValueToPointer(arg1);
    Tcl_SetObjResult(interp, rt);
    return TCL_OK;
}
extern "C" void llvm_test() {}

extern "C" Tcl_Obj* llvm_add(Tcl_Interp* interp, Tcl_Obj* oa, Tcl_Obj* ob)
{
    mp_int big1, big2, bigResult;
    Tcl_GetBignumFromObj(interp, oa, &big1);
    Tcl_GetBignumFromObj(interp, ob, &big2);
    TclBN_mp_init(&bigResult);
    TclBN_mp_add(&big1, &big2, &bigResult);
    Tcl_Obj* oc = Tcl_NewBignumObj(&bigResult);
    return oc;
}
extern "C" Tcl_Obj* llvm_sub(Tcl_Interp* interp, Tcl_Obj* oa, Tcl_Obj* ob)
{
    mp_int big1, big2, bigResult;
    Tcl_GetBignumFromObj(interp, oa, &big1);
    Tcl_GetBignumFromObj(interp, ob, &big2);
    TclBN_mp_init(&bigResult);
    TclBN_mp_sub(&big1, &big2, &bigResult);
    Tcl_Obj* oc = Tcl_NewBignumObj(&bigResult);
    return oc;
}

int LLVMAddLLVMTclCommandsObjCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "EE mod ");
        return TCL_ERROR;
    }
    LLVMExecutionEngineRef ee = 0;
    if (GetLLVMExecutionEngineRefFromObj(interp, objv[1], ee) != TCL_OK)
        return TCL_ERROR;
    LLVMModuleRef mod = 0;
    if (GetLLVMModuleRefFromObj(interp, objv[2], mod) != TCL_OK)
        return TCL_ERROR;
    {
	LLVMTypeRef func_type = LLVMFunctionType(LLVMVoidType(), 0, 0, 0);
	LLVMValueRef func = LLVMAddFunction(mod, "llvm_test", func_type);
	LLVMAddGlobalMapping(ee, func, (void*)&llvm_test);
    }
    {
	LLVMTypeRef pt = LLVMPointerType(LLVMInt8Type(), 0);
	LLVMTypeRef pta[3] = {pt, pt, pt};
	LLVMTypeRef func_type = LLVMFunctionType(pt, pta, 3, 0);
	LLVMValueRef func = LLVMAddFunction(mod, "llvm_add", func_type);
	LLVMAddGlobalMapping(ee, func, (void*)&llvm_add);
    }
    {
	LLVMTypeRef pt = LLVMPointerType(LLVMInt8Type(), 0);
	LLVMTypeRef pta[3] = {pt, pt, pt};
	LLVMTypeRef func_type = LLVMFunctionType(pt, pta, 3, 0);
	LLVMValueRef func = LLVMAddFunction(mod, "llvm_sub", func_type);
	LLVMAddGlobalMapping(ee, func, (void*)&llvm_sub);
    }
    return TCL_OK;
}

#include "llvmtcl-gen.c"

#define LLVMObjCmd(tclName, cName) Tcl_CreateObjCommand(interp, tclName, (Tcl_ObjCmdProc*)cName, (ClientData)NULL, (Tcl_CmdDeleteProc*)NULL);

extern "C" DLLEXPORT int Llvmtcl_Init(Tcl_Interp *interp)
{
    if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_TomMath_InitStubs(interp, TCL_VERSION) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_PkgRequire(interp, "Tcl", TCL_VERSION, 0) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION) != TCL_OK) {
	return TCL_ERROR;
    }
#include "llvmtcl-gen-cmddef.c"
    LLVMObjCmd("llvmtcl::CreateGenericValueOfTclInterp", LLVMCreateGenericValueOfTclInterpObjCmd);
    LLVMObjCmd("llvmtcl::CreateGenericValueOfTclObj", LLVMCreateGenericValueOfTclObjObjCmd);
    LLVMObjCmd("llvmtcl::GenericValueToTclObj", LLVMGenericValueToTclObjObjCmd);
    LLVMObjCmd("llvmtcl::AddLLVMTclCommands", LLVMAddLLVMTclCommandsObjCmd);
    return TCL_OK;
}
