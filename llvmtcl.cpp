#include "tcl.h"
#include <iostream>
#include <sstream>
#include <map>
#include "llvm-c/Analysis.h"
#include "llvm-c/Core.h"
#include "llvm-c/ExecutionEngine.h"
#include "llvm-c/Target.h"

static std::map<std::string, LLVMModuleRef> LLVMModuleRef_map;
static std::map<std::string, LLVMBuilderRef> LLVMBuilderRef_map;
static std::map<std::string, LLVMTypeRef> LLVMTypeRef_map;
static std::map<std::string, LLVMValueRef> LLVMValueRef_map;
static std::map<std::string, LLVMBasicBlockRef> LLVMBasicBlockRef_map;

static std::string GetRefName(std::string prefix)
{
    static int LLVMRef_id = 0;
    std::ostringstream os;
    os << prefix << LLVMRef_id;
    LLVMRef_id++;
    return os.str();
}

static int GetLLVMModuleRefFromObj(Tcl_Interp* interp, Tcl_Obj* obj, LLVMModuleRef& moduleRef)
{
    moduleRef = 0;
    std::string moduleName = Tcl_GetStringFromObj(obj, 0);
    if (LLVMModuleRef_map.find(moduleName) == LLVMModuleRef_map.end()) {
	std::ostringstream os;
	os << "expected module but got \"" << moduleName << "\"";
	Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	return TCL_ERROR;
    }
    moduleRef = LLVMModuleRef_map[moduleName];
    return TCL_OK;
}

static int GetLLVMTypeRefFromObj(Tcl_Interp* interp, Tcl_Obj* obj, LLVMTypeRef& typeRef)
{
    typeRef = 0;
    std::string typeName = Tcl_GetStringFromObj(obj, 0);
    if (LLVMTypeRef_map.find(typeName) == LLVMTypeRef_map.end()) {
	std::ostringstream os;
	os << "expected type but got \"" << typeName << "\"";
	Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	return TCL_ERROR;
    }
    typeRef = LLVMTypeRef_map[typeName];
    return TCL_OK;
}

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

static int GetLLVMValueRefFromObj(Tcl_Interp* interp, Tcl_Obj* obj, LLVMValueRef& valueRef)
{
    valueRef = 0;
    std::string valueName = Tcl_GetStringFromObj(obj, 0);
    if (LLVMValueRef_map.find(valueName) == LLVMValueRef_map.end()) {
	std::ostringstream os;
	os << "expected value but got \"" << valueName << "\"";
	Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	return TCL_ERROR;
    }
    valueRef = LLVMValueRef_map[valueName];
    return TCL_OK;
}

static int GetLLVMBuilderRefFromObj(Tcl_Interp* interp, Tcl_Obj* obj, LLVMBuilderRef& builderRef)
{
    builderRef = 0;
    std::string builderName = Tcl_GetStringFromObj(obj, 0);
    if (LLVMBuilderRef_map.find(builderName) == LLVMBuilderRef_map.end()) {
	std::ostringstream os;
	os << "expected builder but got \"" << builderName << "\"";
	Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	return TCL_ERROR;
    }
    builderRef = LLVMBuilderRef_map[builderName];
    return TCL_OK;
}

static int GetLLVMBasicBlockRefFromObj(Tcl_Interp* interp, Tcl_Obj* obj, LLVMBasicBlockRef& basicBlockRef)
{
    basicBlockRef = 0;
    std::string basicBlockName = Tcl_GetStringFromObj(obj, 0);
    if (LLVMBasicBlockRef_map.find(basicBlockName) == LLVMBasicBlockRef_map.end()) {
	std::ostringstream os;
	os << "expected basic but got \"" << basicBlockName << "\"";
	Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	return TCL_ERROR;
    }
    basicBlockRef = LLVMBasicBlockRef_map[basicBlockName];
    return TCL_OK;
}

int LLVMCreateBuilderObjCmd(ClientData clientData,
			    Tcl_Interp* interp,
			    int objc,
			    Tcl_Obj* const objv[])
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, "");
	return TCL_ERROR;
    }
    LLVMBuilderRef builder = LLVMCreateBuilder();
    if (!builder) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("failed to create new builder", -1));
	return TCL_ERROR;
    }
    std::string builderName = GetRefName("LLVMBuilderRef_");
    LLVMBuilderRef_map[builderName] = builder;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(builderName.c_str(), -1));
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

int LLVMInitializeNativeTargetObjCmd(ClientData clientData,
				     Tcl_Interp* interp,
				     int objc,
				     Tcl_Obj* const objv[])
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, "");
	return TCL_ERROR;
    }
    LLVMInitializeNativeTarget();
    return TCL_OK;
}

int LLVMLinkInJITObjCmd(ClientData clientData,
			Tcl_Interp* interp,
			int objc,
			Tcl_Obj* const objv[])
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, "");
	return TCL_ERROR;
    }
    LLVMLinkInJIT();
    return TCL_OK;
}

int LLVMModuleCreateWithNameObjCmd(ClientData clientData,
				   Tcl_Interp* interp,
				   int objc,
				   Tcl_Obj* const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    std::string name = Tcl_GetStringFromObj(objv[1], 0);
    LLVMModuleRef module = LLVMModuleCreateWithName(name.c_str());
    if (!module) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("failed to create new module", -1));
	return TCL_ERROR;
    }
    std::string moduleName = GetRefName("LLVMModuleRef_");
    LLVMModuleRef_map[moduleName] = module;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(moduleName.c_str(), -1));
    return TCL_OK;
}

int LLVMAddFunctionObjCmd(ClientData clientData,
			  Tcl_Interp* interp,
			  int objc,
			  Tcl_Obj* const objv[])
{
    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "moduleRef functionName functionTypeRef");
	return TCL_ERROR;
    }
    LLVMModuleRef moduleRef = 0;
    if (GetLLVMModuleRefFromObj(interp, objv[1], moduleRef) != TCL_OK)
	return TCL_ERROR;
    std::string functionName = Tcl_GetStringFromObj(objv[2], 0);
    LLVMTypeRef functionType = 0;
    if (GetLLVMTypeRefFromObj(interp, objv[3], functionType) != TCL_OK)
	return TCL_ERROR;
    LLVMValueRef functionRef = LLVMAddFunction(moduleRef, functionName.c_str(), functionType);
    std::string functionRefName = GetRefName("LLVMValueRef_");
    LLVMValueRef_map[functionRefName] = functionRef;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(functionRefName.c_str(), -1));
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
    return TCL_OK;
}

int LLVMConstIntObjCmd(ClientData clientData,
		       Tcl_Interp* interp,
		       int objc,
		       Tcl_Obj* const objv[])
{
    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "typeRef value signExtended");
	return TCL_ERROR;
    }
    LLVMTypeRef constType = 0;
    if (GetLLVMTypeRefFromObj(interp, objv[1], constType) != TCL_OK)
	return TCL_ERROR;
    Tcl_WideInt value = 0;
    if (Tcl_GetWideIntFromObj(interp, objv[2], &value) != TCL_OK)
	return TCL_ERROR;
    int signExtend = 0;
    if (Tcl_GetBooleanFromObj(interp, objv[3], &signExtend) != TCL_OK)
	return TCL_ERROR;
    LLVMValueRef valueRef = LLVMConstInt(constType, value, signExtend);
    std::string valueName = GetRefName("LLVMValueRef_");
    LLVMValueRef_map[valueName] = valueRef;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(valueName.c_str(), -1));
    return TCL_OK;
}

int LLVMConstIntOfStringObjCmd(ClientData clientData,
			       Tcl_Interp* interp,
			       int objc,
			       Tcl_Obj* const objv[])
{
    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "typeRef value radix");
	return TCL_ERROR;
    }
    LLVMTypeRef constType = 0;
    if (GetLLVMTypeRefFromObj(interp, objv[1], constType) != TCL_OK)
	return TCL_ERROR;
    std::string value = Tcl_GetStringFromObj(objv[2], 0);
    int radix = 0;
    if (Tcl_GetIntFromObj(interp, objv[3], &radix) != TCL_OK)
	return TCL_ERROR;
    if (radix != 2 && radix != 8 && radix != 10 && radix != 16) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("radix should be 2, 8, 10, or 16", -1));
	return TCL_ERROR;
    }
    LLVMValueRef valueRef = LLVMConstIntOfString(constType, value.c_str(), radix);
    std::string valueName = GetRefName("LLVMValueRef_");
    LLVMValueRef_map[valueName] = valueRef;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(valueName.c_str(), -1));
    return TCL_OK;
}

int LLVMConstRealObjCmd(ClientData clientData,
			Tcl_Interp* interp,
			int objc,
			Tcl_Obj* const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "typeRef value");
	return TCL_ERROR;
    }
    LLVMTypeRef constType = 0;
    if (GetLLVMTypeRefFromObj(interp, objv[1], constType) != TCL_OK)
	return TCL_ERROR;
    double value = 0.0;
    if (Tcl_GetDoubleFromObj(interp, objv[2], &value) != TCL_OK)
	return TCL_ERROR;
    LLVMValueRef valueRef = LLVMConstReal(constType, value);
    std::string valueName = GetRefName("LLVMValueRef_");
    LLVMValueRef_map[valueName] = valueRef;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(valueName.c_str(), -1));
    return TCL_OK;
}

int LLVMConstRealOfStringObjCmd(ClientData clientData,
				Tcl_Interp* interp,
				int objc,
				Tcl_Obj* const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "typeRef value");
	return TCL_ERROR;
    }
    LLVMTypeRef constType = 0;
    if (GetLLVMTypeRefFromObj(interp, objv[1], constType) != TCL_OK)
	return TCL_ERROR;
    std::string value = Tcl_GetStringFromObj(objv[2], 0);
    LLVMValueRef valueRef = LLVMConstRealOfString(constType, value.c_str());
    std::string valueName = GetRefName("LLVMValueRef_");
    LLVMValueRef_map[valueName] = valueRef;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(valueName.c_str(), -1));
    return TCL_OK;
}
    
int LLVMAppendBasicBlockObjCmd(ClientData clientData,
			       Tcl_Interp* interp,
			       int objc,
			       Tcl_Obj* const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "functionRef name");
	return TCL_ERROR;
    }	
    LLVMValueRef functionRef = 0;
    if (GetLLVMValueRefFromObj(interp, objv[1], functionRef) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetStringFromObj(objv[2], 0);
    LLVMBasicBlockRef basicBlockRef = LLVMAppendBasicBlock(functionRef, name.c_str());
    if (!basicBlockRef) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("failed to append new basic block", -1));
	return TCL_ERROR;
    }
    std::string basicBlockName = GetRefName("LLVMBasicBlockRef_");
    LLVMBasicBlockRef_map[basicBlockName] = basicBlockRef;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(basicBlockName.c_str(), -1));
    return TCL_OK;
}

int LLVMInsertBasicBlockObjCmd(ClientData clientData,
				Tcl_Interp* interp,
				int objc,
				Tcl_Obj* const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "beforeBasicBlockRef name");
	return TCL_ERROR;
    }
    LLVMBasicBlockRef beforeBasicBlockRef = 0;
    if (GetLLVMBasicBlockRefFromObj(interp, objv[1], beforeBasicBlockRef) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetStringFromObj(objv[2], 0);
    LLVMBasicBlockRef basicBlockRef = LLVMInsertBasicBlock(beforeBasicBlockRef, name.c_str());
    if (!basicBlockRef) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("failed to insert new basic block", -1));
	return TCL_ERROR;
    }
    std::string basicBlockName = GetRefName("LLVMBasicBlockRef_");
    LLVMBasicBlockRef_map[basicBlockName] = basicBlockRef;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(basicBlockName.c_str(), -1));    
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

int LLVMTypeObjCmd(ClientData clientData,
		   Tcl_Interp* interp,
		   int objc,
		   Tcl_Obj* const objv[])
{
    static const char *subCommands[] = {
	"llvmtcl::LLVMArrayType",
	"llvmtcl::LLVMDoubleType",
	"llvmtcl::LLVMFP128Type",
	"llvmtcl::LLVMFloatType",
	"llvmtcl::LLVMFunctionType",
	"llvmtcl::LLVMInt16Type",
	"llvmtcl::LLVMInt1Type",
	"llvmtcl::LLVMInt32Type",
	"llvmtcl::LLVMInt64Type",
	"llvmtcl::LLVMInt8Type",
	"llvmtcl::LLVMIntType",
	"llvmtcl::LLVMLabelType",
	"llvmtcl::LLVMOpaqueType",
	"llvmtcl::LLVMPPCFP128Type",
	"llvmtcl::LLVMPointerType",
	"llvmtcl::LLVMStructType",
	"llvmtcl::LLVMUnionType",
	"llvmtcl::LLVMVectorType",
	"llvmtcl::LLVMVoidType",
	"llvmtcl::LLVMX86FP80Type",
	NULL
    };
    enum SubCmds {
	eLLVMArrayType,
	eLLVMDoubleType,
	eLLVMFP128Type,
	eLLVMFloatType,
	eLLVMFunctionType,
	eLLVMInt16Type,
	eLLVMInt1Type,
	eLLVMInt32Type,
	eLLVMInt64Type,
	eLLVMInt8Type,
	eLLVMIntType,
	eLLVMLabelType,
	eLLVMOpaqueType,
	eLLVMPPCFP128Type,
	eLLVMPointerType,
	eLLVMStructType,
	eLLVMUnionType,
	eLLVMVectorType,
	eLLVMVoidType,
	eLLVMX86FP80Type
    };
    int index = -1;
    if (Tcl_GetIndexFromObj(interp, objv[0], subCommands, "type", 0, &index) != TCL_OK)
        return TCL_ERROR;
    // Check number of arguments
    switch ((enum SubCmds) index) {
    // 2 arguments
    case eLLVMDoubleType:
    case eLLVMFP128Type:
    case eLLVMFloatType:
    case eLLVMInt16Type:
    case eLLVMInt1Type:
    case eLLVMInt32Type:
    case eLLVMInt64Type:
    case eLLVMInt8Type:
    case eLLVMLabelType:
    case eLLVMOpaqueType:
    case eLLVMPPCFP128Type:
    case eLLVMVoidType:
    case eLLVMX86FP80Type:
	if (objc != 1) {
	    Tcl_WrongNumArgs(interp, 1, objv, "");
	    return TCL_ERROR;
	}
	break;
    // 3 arguments
    case eLLVMIntType:
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 1, objv, "width");
	    return TCL_ERROR;
	}
	break;
    case eLLVMUnionType:
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 1, objv, "listOfElementTypeRefs");
	    return TCL_ERROR;
	}
	break;
    // 4 arguments
    case eLLVMArrayType:
    case eLLVMVectorType:
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 1, objv, "elementTypeRef elementCount");
	    return TCL_ERROR;
	}
	break;
    case eLLVMPointerType:
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 1, objv, "elementTypeRef addressSpace");
	    return TCL_ERROR;
	}
	break;
    case eLLVMStructType:
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 1, objv, "listOfElementTypeRefs packed");
	    return TCL_ERROR;
	}
	break;
    // 5 arguments
    case eLLVMFunctionType:
	if (objc != 4) {
	    Tcl_WrongNumArgs(interp, 1, objv, "returnTypeRef listOfArgumentTypeRefs isVarArg");
	    return TCL_ERROR;
	}
	break;
    }
    // Create the requested type
    LLVMTypeRef tref = 0;
    switch ((enum SubCmds) index) {
    case eLLVMArrayType:
    {
	LLVMTypeRef elementType = 0;
	if (GetLLVMTypeRefFromObj(interp, objv[1], elementType) != TCL_OK)
	    return TCL_ERROR;
	int elementCount = 0;
	if (Tcl_GetIntFromObj(interp, objv[2], &elementCount) != TCL_OK)
	    return TCL_ERROR;
	tref = LLVMArrayType(elementType, elementCount);
	break;
    }
    case eLLVMDoubleType:
	tref = LLVMDoubleType();
	break;
    case eLLVMFP128Type:
	tref = LLVMFP128Type();
	break;
    case eLLVMFloatType:
	tref = LLVMFloatType();
	break;
    case eLLVMFunctionType:
    {
	LLVMTypeRef returnType = 0;
	if (GetLLVMTypeRefFromObj(interp, objv[1], returnType) != TCL_OK)
	    return TCL_ERROR;
	int isVarArg = 0;
	if (Tcl_GetBooleanFromObj(interp, objv[3], &isVarArg) != TCL_OK)
	    return TCL_ERROR;
	int argumentCount = 0;
	LLVMTypeRef* argumentTypes = 0;
	if (GetListOfLLVMTypeRefFromObj(interp, objv[2], argumentTypes, argumentCount) != TCL_OK)
	    return TCL_ERROR;
	tref = LLVMFunctionType(returnType, argumentTypes, argumentCount, isVarArg);
	if (argumentCount)
	    delete [] argumentTypes;
	break;
    }
    case eLLVMInt16Type:
	tref = LLVMInt16Type();
	break;
    case eLLVMInt1Type:
	tref = LLVMInt1Type();
	break;
    case eLLVMInt32Type:
	tref = LLVMInt32Type();
	break;
    case eLLVMInt64Type:
	tref = LLVMInt64Type();
	break;
    case eLLVMInt8Type:
	tref = LLVMInt8Type();
	break;
    case eLLVMIntType:
    {
	int width = 0;
	if (Tcl_GetIntFromObj(interp, objv[1], &width) != TCL_OK)
	    return TCL_ERROR;
	tref = LLVMIntType(width);
	break;
    }
    case eLLVMLabelType:
	tref = LLVMLabelType();
	break;
    case eLLVMOpaqueType:
	tref = LLVMOpaqueType();
	break;
    case eLLVMPPCFP128Type:
	tref = LLVMPPCFP128Type();
	break;
    case eLLVMPointerType:
    {
	LLVMTypeRef elementType = 0;
	if (GetLLVMTypeRefFromObj(interp, objv[1], elementType) != TCL_OK)
	    return TCL_ERROR;
	int addressSpace = 0;
	if (Tcl_GetIntFromObj(interp, objv[2], &addressSpace) != TCL_OK)
	    return TCL_ERROR;
	tref = LLVMPointerType(elementType, addressSpace);
	break;
    }
    case eLLVMStructType:
    {
	int elementCount = 0;
	LLVMTypeRef* elementTypes = 0;
	if (GetListOfLLVMTypeRefFromObj(interp, objv[1], elementTypes, elementCount) != TCL_OK)
	    return TCL_ERROR;
	if (!elementCount) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj("no element types specified", -1));
	    return TCL_ERROR;
	}
	int packed = 0;
	if (Tcl_GetBooleanFromObj(interp, objv[2], &packed) != TCL_OK)
	    return TCL_ERROR;
	tref = LLVMStructType(elementTypes, elementCount, packed);
	delete [] elementTypes;
	break;
    }
    case eLLVMUnionType:
    {
	int elementCount = 0;
	LLVMTypeRef* elementTypes = 0;
	if (GetListOfLLVMTypeRefFromObj(interp, objv[1], elementTypes, elementCount) != TCL_OK)
	    return TCL_ERROR;
	if (!elementCount) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj("no element types specified", -1));
	    return TCL_ERROR;
	}
	tref = LLVMUnionType(elementTypes, elementCount);
	delete [] elementTypes;
	break;
    }
    case eLLVMVectorType:
    {
	LLVMTypeRef elementType = 0;
	if (GetLLVMTypeRefFromObj(interp, objv[1], elementType) != TCL_OK)
	    return TCL_ERROR;
	int elementCount = 0;
	if (Tcl_GetIntFromObj(interp, objv[2], &elementCount) != TCL_OK)
	    return TCL_ERROR;
	tref = LLVMVectorType(elementType, elementCount);
	break;
    }
    case eLLVMVoidType:
	tref = LLVMVoidType();
	break;
    case eLLVMX86FP80Type:
	tref = LLVMX86FP80Type();
	break;
    }
    if (!tref) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("failed to create new type", -1));
	return TCL_ERROR;
    }
    std::string typeRefName = GetRefName("LLVMTypeRef_");
    LLVMTypeRef_map[typeRefName] = tref;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(typeRefName.c_str(), -1));
    return TCL_OK;
}

typedef int (*LLVMObjCmdPtr)(ClientData clientData,
			     Tcl_Interp* interp,
			     int objc,
			     Tcl_Obj* const objv[]);

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
    std::map<std::string, LLVMObjCmdPtr> subObjCmds;
    subObjCmds["llvmtcl::LLVMAppendBasicBlock"] = &LLVMAppendBasicBlockObjCmd;
    subObjCmds["llvmtcl::LLVMInsertBasicBlock"] = &LLVMInsertBasicBlockObjCmd;
    subObjCmds["llvmtcl::LLVMDeleteBasicBlock"] = &LLVMDeleteBasicBlockObjCmd;
    subObjCmds["llvmtcl::LLVMAddFunction"] = &LLVMAddFunctionObjCmd;
    subObjCmds["llvmtcl::LLVMArrayType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMConstInt"] = &LLVMConstIntObjCmd;
    subObjCmds["llvmtcl::LLVMConstIntOfString"] = &LLVMConstIntOfStringObjCmd;
    subObjCmds["llvmtcl::LLVMConstReal"] = &LLVMConstRealObjCmd;
    subObjCmds["llvmtcl::LLVMConstRealOfString"] = &LLVMConstRealOfStringObjCmd;
    subObjCmds["llvmtcl::LLVMCreateBuilder"] = &LLVMCreateBuilderObjCmd;
    subObjCmds["llvmtcl::LLVMDeleteFunction"] = &LLVMDeleteFunctionObjCmd;
    subObjCmds["llvmtcl::LLVMDisposeBuilder"] = &LLVMDisposeBuilderObjCmd;
    subObjCmds["llvmtcl::LLVMDisposeModule"] = &LLVMDisposeModuleObjCmd;
    subObjCmds["llvmtcl::LLVMDoubleType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMFP128Type"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMFloatType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMFunctionType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMInitializeNativeTarget"] = &LLVMInitializeNativeTargetObjCmd;
    subObjCmds["llvmtcl::LLVMInt16Type"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMInt1Type"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMInt32Type"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMInt64Type"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMInt8Type"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMIntType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMLabelType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMLinkInJIT"] = &LLVMLinkInJITObjCmd;
    subObjCmds["llvmtcl::LLVMModuleCreateWithName"] = &LLVMModuleCreateWithNameObjCmd;
    subObjCmds["llvmtcl::LLVMOpaqueType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMPPCFP128Type"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMPointerType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMStructType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMUnionType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMVectorType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMVoidType"] = &LLVMTypeObjCmd;
    subObjCmds["llvmtcl::LLVMX86FP80Type"] = &LLVMTypeObjCmd;
    for(std::map<std::string, LLVMObjCmdPtr>::const_iterator i = subObjCmds.begin(); i !=  subObjCmds.end(); i++)
	Tcl_CreateObjCommand(interp, i->first.c_str() ,
			     (Tcl_ObjCmdProc*)i->second,
			     (ClientData)NULL, (Tcl_CmdDeleteProc*)NULL);

    return TCL_OK;
}
