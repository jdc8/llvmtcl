#include "tcl.h"
#include "tclTomMath.h"
#include <iostream>
#include <sstream>
#include <map>
#include "llvm/Support/raw_ostream.h"
#include "llvm/PassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"
#include "llvm/Transforms/IPO.h"
#include "llvm/IR/Module.h"
//#include "llvm/DerivedTypes.h"
//#include "llvm/Function.h"
#include "llvm/Support/DynamicLibrary.h"
#include "llvm/ExecutionEngine/GenericValue.h"
#include "llvm-c/Analysis.h"
#include "llvm-c/Core.h"
#include "llvm-c/ExecutionEngine.h"
#include "llvm-c/Target.h"
#include "llvm-c/BitWriter.h"
#include "llvm-c/Transforms/PassManagerBuilder.h"
#include "llvm-c/Transforms/IPO.h"
#include "llvm-c/Transforms/Scalar.h"
#include "llvm-c/Transforms/Vectorize.h"

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

std::string LLVMPrintModuleToStringTcl(LLVMModuleRef moduleRef)
{
    char* p = LLVMPrintModuleToString(moduleRef);
    std::string s = p;
    LLVMDisposeMessage(p);
    return s;
}

std::string LLVMPrintTypeToStringTcl(LLVMTypeRef typeRef)
{
    char* p = LLVMPrintTypeToString(typeRef);
    std::string s = p;
    LLVMDisposeMessage(p);
    return s;
}

std::string LLVMPrintValueToStringTcl(LLVMValueRef valueRef)
{
    char* p = LLVMPrintValueToString(valueRef);
    std::string s = p;
    LLVMDisposeMessage(p);
    return s;
}

LLVMGenericValueRef LLVMRunFunction(LLVMExecutionEngineRef EE, LLVMValueRef F, LLVMGenericValueRef *Args, unsigned NumArgs)
{
    return LLVMRunFunction(EE, F, NumArgs, Args);
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

int LLVMAddIncomingObjCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "PhiNode IncomingValuesList IncomingBlocksList");
        return TCL_ERROR;
    }
    LLVMValueRef phiNode = 0;
    if (GetLLVMValueRefFromObj(interp, objv[1], phiNode) != TCL_OK)
        return TCL_ERROR;
    int ivobjc = 0;
    Tcl_Obj** ivobjv = 0;
    if (Tcl_ListObjGetElements(interp, objv[2], &ivobjc, &ivobjv) != TCL_OK) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("IncomingValuesList not specified as list", -1));
	return TCL_ERROR;
    }
    int ibobjc = 0;
    Tcl_Obj** ibobjv = 0;
    if (Tcl_ListObjGetElements(interp, objv[3], &ibobjc, &ibobjv) != TCL_OK) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("IncomingBlocksList not specified as list", -1));
	return TCL_ERROR;
    }
    if (ivobjc != ibobjc) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("IncomingValuesList and IncomingBlocksList have different length", -1));
	return TCL_ERROR;
    }
    LLVMValueRef* incomingValues = (LLVMValueRef*)ckalloc(sizeof(LLVMValueRef) * ivobjc);
    LLVMBasicBlockRef* incomingBlocks = (LLVMBasicBlockRef*)ckalloc(sizeof(LLVMBasicBlockRef) * ivobjc);
    for(int i = 0; i < ivobjc; i++) {
	if (GetLLVMValueRefFromObj(interp, ivobjv[i], incomingValues[i]) != TCL_OK) {
	    ckfree((void*)incomingValues);
	    ckfree((void*)incomingBlocks);
	    return TCL_ERROR;
	}
	if (GetLLVMBasicBlockRefFromObj(interp, ibobjv[i], incomingBlocks[i]) != TCL_OK) {
	    ckfree((void*)incomingValues);
	    ckfree((void*)incomingBlocks);
	    return TCL_ERROR;
	}
    }
    LLVMAddIncoming(phiNode, incomingValues, incomingBlocks, ivobjc);
    ckfree((void*)incomingValues);
    ckfree((void*)incomingBlocks);
    return TCL_OK;
}

int LLVMBuildAggregateRetObjCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "BuilderRef RetValsList");
        return TCL_ERROR;
    }
    LLVMBuilderRef builder = 0;
    if (GetLLVMBuilderRefFromObj(interp, objv[1], builder) != TCL_OK)
        return TCL_ERROR;
    int rvobjc = 0;
    Tcl_Obj** rvobjv = 0;
    if (Tcl_ListObjGetElements(interp, objv[2], &rvobjc, &rvobjv) != TCL_OK) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("RetValsList not specified as list", -1));
	return TCL_ERROR;
    }
    LLVMValueRef* returnValues = (LLVMValueRef*)ckalloc(sizeof(LLVMValueRef) * rvobjc);
    for(int i = 0; i < rvobjc; i++) {
	if (GetLLVMValueRefFromObj(interp, rvobjv[i], returnValues[i]) != TCL_OK) {
	    ckfree((void*)returnValues);
	    return TCL_ERROR;
	}
    }
    LLVMValueRef rt = LLVMBuildAggregateRet(builder, returnValues, rvobjc);
    ckfree((void*)returnValues);
    Tcl_SetObjResult(interp, SetLLVMValueRefAsObj(interp, rt));
    return TCL_OK;
}

int LLVMBuildInvokeObjCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 7) {
        Tcl_WrongNumArgs(interp, 1, objv, "BuilderRef Fn ArgsList ThenBlock CatchBlock Name");
        return TCL_ERROR;
    }
    LLVMBuilderRef builder = 0;
    if (GetLLVMBuilderRefFromObj(interp, objv[1], builder) != TCL_OK)
        return TCL_ERROR;
    LLVMValueRef fn = 0;
    if (GetLLVMValueRefFromObj(interp, objv[2], fn) != TCL_OK)
        return TCL_ERROR;
    int aobjc = 0;
    Tcl_Obj** aobjv = 0;
    if (Tcl_ListObjGetElements(interp, objv[3], &aobjc, &aobjv) != TCL_OK) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("ArgsList not specified as list", -1));
	return TCL_ERROR;
    }
    LLVMValueRef* args = (LLVMValueRef*)ckalloc(sizeof(LLVMValueRef) * aobjc);
    for(int i = 0; i < aobjc; i++) {
	if (GetLLVMValueRefFromObj(interp, aobjv[i], args[i]) != TCL_OK) {
	    ckfree((void*)args);
	    return TCL_ERROR;
	}
    }
    LLVMBasicBlockRef thenBlock  = 0;
    if (GetLLVMBasicBlockRefFromObj(interp, objv[4], thenBlock) != TCL_OK)
        return TCL_ERROR;
    LLVMBasicBlockRef catchBlock  = 0;
    if (GetLLVMBasicBlockRefFromObj(interp, objv[5], catchBlock) != TCL_OK)
        return TCL_ERROR;
    std::string name = Tcl_GetStringFromObj(objv[6], 0);
    LLVMValueRef rt = LLVMBuildInvoke(builder, fn, args, aobjc, thenBlock, catchBlock, name.c_str());
    ckfree((void*)args);
    Tcl_SetObjResult(interp, SetLLVMValueRefAsObj(interp, rt));
    return TCL_OK;
}

int LLVMGetParamTypesObjCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "FunctionTy ");
        return TCL_ERROR;
    }
    LLVMTypeRef functionType = 0;
    if (GetLLVMTypeRefFromObj(interp, objv[1], functionType) != TCL_OK)
        return TCL_ERROR;
    unsigned nargs = LLVMCountParamTypes(functionType);
    LLVMTypeRef* paramType = (LLVMTypeRef*)ckalloc(sizeof(LLVMTypeRef) * nargs);
    LLVMGetParamTypes(functionType, paramType);
    Tcl_Obj* rtl = Tcl_NewListObj(0, NULL);
    for(unsigned i = 0; i < nargs; i++)
	Tcl_ListObjAppendElement(interp, rtl, SetLLVMTypeRefAsObj(interp, paramType[i]));
    ckfree((void*)paramType);
    Tcl_SetObjResult(interp, rtl);
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
    LLVMObjCmd("llvmtcl::AddIncoming", LLVMAddIncomingObjCmd);
    LLVMObjCmd("llvmtcl::BuildAggregateRet", LLVMBuildAggregateRetObjCmd);
    LLVMObjCmd("llvmtcl::BuildInvoke", LLVMBuildInvokeObjCmd);
    LLVMObjCmd("llvmtcl::GetParamTypes", LLVMGetParamTypesObjCmd);
    return TCL_OK;
}
