#include "tcl.h"
#include <iostream>
#include <sstream>
#include <map>
#include "llvm-c/Analysis.h"
#include "llvm-c/Core.h"
#include "llvm-c/ExecutionEngine.h"
#include "llvm-c/Target.h"

static std::string GetRefName(std::string prefix)
{
    static int LLVMRef_id = 0;
    std::ostringstream os;
    os << prefix << LLVMRef_id;
    LLVMRef_id++;
    return os.str();
}

#include "llvmtcl-gen-map.cpp"

static int GetListOfLLVMTypeRefFromObj(Tcl_Interp* interp, Tcl_Obj* obj, LLVMTypeRef*& typeList, int& typeCount)
{
    typeCount = 0;
    typeList = 0;
    Tcl_Obj** typeObjs = 0;
    if (Tcl_ListObjGetElements(interp, obj, &typeCount, &typeObjs) != TCL_OK) {
	std::ostringstream os;
	os << "expected list of types but got \"" << Tcl_GetStringFromObj(obj, 0) << "\"";
	Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	return TCL_ERROR;
    }
    if (typeCount == 0)
	return TCL_OK;
    typeList = new LLVMTypeRef[typeCount];
    for(int i = 0; i < typeCount; i++) {
	if (GetLLVMTypeRefFromObj(interp, typeObjs[i], typeList[i]) != TCL_OK) {
	    delete [] typeList;
	    return TCL_ERROR;
	}
    }
    return TCL_OK;
}

int LLVMDisposeBuilderObjCmd(ClientData clientData,
			     Tcl_Interp* interp,
			     int objc,
			     Tcl_Obj* const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "builderRef");
	return TCL_ERROR;
    }
    LLVMBuilderRef builderRef = 0;
    if (GetLLVMBuilderRefFromObj(interp, objv[1], builderRef) != TCL_OK)
	return TCL_ERROR;
    LLVMDisposeBuilder(builderRef);
    LLVMBuilderRef_map.erase(Tcl_GetStringFromObj(objv[1], 0));
    LLVMBuilderRef_refmap.erase(builderRef);
    return TCL_OK;
}

int LLVMDisposeModuleObjCmd(ClientData clientData,
			    Tcl_Interp* interp,
			    int objc,
			    Tcl_Obj* const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "moduleRef");
	return TCL_ERROR;
    }
    LLVMModuleRef moduleRef = 0;
    if (GetLLVMModuleRefFromObj(interp, objv[1], moduleRef) != TCL_OK)
	return TCL_ERROR;
    LLVMDisposeModule(moduleRef);
    LLVMModuleRef_map.erase(Tcl_GetStringFromObj(objv[1], 0));
    return TCL_OK;
}

int LLVMDeleteFunctionObjCmd(ClientData clientData,
			     Tcl_Interp* interp,
			     int objc,
			     Tcl_Obj* const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "functionRef");
	return TCL_ERROR;
    }
    LLVMValueRef functionRef = 0;
    if (GetLLVMValueRefFromObj(interp, objv[1], functionRef) != TCL_OK)
	return TCL_ERROR;
    LLVMDeleteFunction(functionRef);
    LLVMValueRef_map.erase(Tcl_GetStringFromObj(objv[1], 0));
    LLVMValueRef_refmap.erase(functionRef);
    return TCL_OK;
}

int LLVMDeleteBasicBlockObjCmd(ClientData clientData,
				Tcl_Interp* interp,
				int objc,
				Tcl_Obj* const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "basicBlockRef");
	return TCL_ERROR;
    }
    LLVMBasicBlockRef basicBlockRef = 0;
    if (GetLLVMBasicBlockRefFromObj(interp, objv[1], basicBlockRef) != TCL_OK)
	return TCL_ERROR;
    LLVMDeleteBasicBlock(basicBlockRef);
    LLVMBasicBlockRef_map.erase(Tcl_GetStringFromObj(objv[1], 0));
    return TCL_OK;
}

#include "llvmtcl-gen.cpp"

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
    LLVMObjCmd("llvmtcl::LLVMDeleteBasicBlock", LLVMDeleteBasicBlockObjCmd);
    LLVMObjCmd("llvmtcl::LLVMDeleteFunction", LLVMDeleteFunctionObjCmd);
    LLVMObjCmd("llvmtcl::LLVMDisposeBuilder", LLVMDisposeBuilderObjCmd);
    LLVMObjCmd("llvmtcl::LLVMDisposeModule", LLVMDisposeModuleObjCmd);
#include "llvmtcl-gen-cmddef.cpp"  
    return TCL_OK;
}
