#include "tcl.h"
#include <iostream>
#include <sstream>
#include <map>
#include "llvm-c/Analysis.h"
#include "llvm-c/Core.h"
#include "llvm-c/ExecutionEngine.h"
#include "llvm-c/Target.h"

static int LLVMRef_id = 0;
static std::map<std::string, LLVMModuleRef> LLVMModuleRef_map;
static std::map<std::string, LLVMBuilderRef> LLVMBuilderRef_map;
static std::map<std::string, LLVMTypeRef> LLVMTypeRef_map;

int LLVMCreateBuilderObjCmd(ClientData clientData,
			    Tcl_Interp* interp,
			    int objc,
			    Tcl_Obj* const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 2, objv, "");
	return TCL_ERROR;
    }
    LLVMBuilderRef builder = LLVMCreateBuilder();
    if (!builder) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("failed to create new builder", -1));
	return TCL_ERROR;
    }
    std::ostringstream os;
    os << "LLVMBuilderRef_" << LLVMRef_id;
    LLVMRef_id++;
    LLVMBuilderRef_map[os.str().c_str()] = builder;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
    return TCL_OK;
}

int LLVMDisposeBuilderObjCmd(ClientData clientData,
			     Tcl_Interp* interp,
			     int objc,
			     Tcl_Obj* const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 2, objv, "builder");
	return TCL_ERROR;
    }
    std::string builder = Tcl_GetStringFromObj(objv[2], 0);
    if (LLVMBuilderRef_map.find(builder) == LLVMBuilderRef_map.end()) {
	std::ostringstream os;
	os << "expected builder but got \"" << builder << "\"";
	Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	return TCL_ERROR;
    }
    LLVMDisposeBuilder(LLVMBuilderRef_map[builder]);
    LLVMBuilderRef_map.erase(builder);
    return TCL_OK;
}

int LLVMDisposeModuleObjCmd(ClientData clientData,
			    Tcl_Interp* interp,
			    int objc,
			    Tcl_Obj* const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 2, objv, "module");
	return TCL_ERROR;
    }
    std::string module = Tcl_GetStringFromObj(objv[2], 0);
    if (LLVMModuleRef_map.find(module) == LLVMModuleRef_map.end()) {
	std::ostringstream os;
	os << "expected module but got \"" << module << "\"";
	Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	return TCL_ERROR;
    }
    LLVMDisposeModule(LLVMModuleRef_map[module]);
    LLVMModuleRef_map.erase(module);
    return TCL_OK;
}

int LLVMInitializeNativeTargetObjCmd(ClientData clientData,
				     Tcl_Interp* interp,
				     int objc,
				     Tcl_Obj* const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 2, objv, "");
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
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 2, objv, "");
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
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 2, objv, "name");
	return TCL_ERROR;
    }
    std::string name = Tcl_GetStringFromObj(objv[2], 0);
    LLVMModuleRef module = LLVMModuleCreateWithName(name.c_str());
    if (!module) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("failed to create new module", -1));
	return TCL_ERROR;
    }
    std::ostringstream os;
    os << "LLVMModuleRef_" << LLVMRef_id;
    LLVMRef_id++;
    LLVMModuleRef_map[os.str().c_str()] = module;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
    return TCL_OK;
}

int HelpObjCmd(ClientData clientData,
	       Tcl_Interp* interp,
	       int objc,
	       Tcl_Obj* const objv[])
{
    std::ostringstream os;
    os << "LLVM Tcl interface\n"
       << "\n"
       << "Available commands:\n"
       << "\n"
       << "    llvmtcl::llvmtcl LLVMCreateBuilder\n"
       << "    llvmtcl::llvmtcl LLVMDisposeBuilder builder\n"
       << "    llvmtcl::llvmtcl LLVMDisposeModule module\n"
       << "    llvmtcl::llvmtcl LLVMInitializeNativeTarget\n"
       << "    llvmtcl::llvmtcl LLVMLinkInJit\n"
       << "    llvmtcl::llvmtcl LLVMModuleCreateWithName name\n"
       << "    llvmtcl::llvmtcl help : this message\n"
       << "\n";
    Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
    return TCL_OK;
}

static LLVMTypeRef GetLLVMTypeRef(Tcl_Interp* interp, Tcl_Obj* obj)
{
    std::string elementTypeName = Tcl_GetStringFromObj(obj, 0);
    if (LLVMTypeRef_map.find(elementTypeName) == LLVMTypeRef_map.end()) {
	std::ostringstream os;
	os << "expected type but got \"" << elementTypeName << "\"";
	Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	return 0;
    }
    return LLVMTypeRef_map[elementTypeName];
}

int LLVMTypeObjCmd(ClientData clientData,
		   Tcl_Interp* interp,
		   int objc,
		   Tcl_Obj* const objv[])
{
    static const char *subCommands[] = {
	"LLVMArrayType",
	"LLVMDoubleType",
	"LLVMFP128Type",
	"LLVMFloatType",
	"LLVMFunctionType",
	"LLVMInt16Type",
	"LLVMInt1Type",
	"LLVMInt32Type",
	"LLVMInt64Type",
	"LLVMInt8Type",
	"LLVMIntType",
	"LLVMLabelType",
	"LLVMOpaqueType",
	"LLVMPPCFP128Type",
	"LLVMPointerType",
	"LLVMStructType",
	"LLVMUnionType",
	"LLVMVectorType",
	"LLVMVoidType",
	"LLVMX86FP80Type",
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
    if (Tcl_GetIndexFromObj(interp, objv[1], subCommands, "type", 0, &index) != TCL_OK)
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
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, "");
	    return TCL_ERROR;
	}
	break;
    // 3 arguments
    case eLLVMIntType:
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "width");
	    return TCL_ERROR;
	}
	break;
    case eLLVMUnionType:
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "listOfElementTypes");
	    return TCL_ERROR;
	}
	break;
    // 4 arguments
    case eLLVMArrayType:
    case eLLVMVectorType:
	if (objc != 4) {
	    Tcl_WrongNumArgs(interp, 2, objv, "elementType elementCount");
	    return TCL_ERROR;
	}
	break;
    case eLLVMPointerType:
	if (objc != 4) {
	    Tcl_WrongNumArgs(interp, 2, objv, "elementType addressSpace");
	    return TCL_ERROR;
	}
	break;
    case eLLVMStructType:
	if (objc != 4) {
	    Tcl_WrongNumArgs(interp, 2, objv, "listOfElementTypes packed");
	    return TCL_ERROR;
	}
	break;
    // 5 arguments
    case eLLVMFunctionType:
	if (objc != 5) {
	    Tcl_WrongNumArgs(interp, 2, objv, "returnType listOfArgumentTypes isVarArg");
	    return TCL_ERROR;
	}
	break;
    }
    // Create the requested type
    LLVMTypeRef tref = 0;
    switch ((enum SubCmds) index) {
    case eLLVMArrayType:
    {
	LLVMTypeRef elementType = GetLLVMTypeRef(interp, objv[2]);
	if (!elementType)
	    return TCL_ERROR;
	int elementCount = 0;
	if (Tcl_GetIntFromObj(interp, objv[3], &elementCount) != TCL_OK)
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
	LLVMTypeRef returnType = GetLLVMTypeRef(interp, objv[2]);
	if (!returnType)
	    return TCL_ERROR;
	int isVarArg = 0;
	if (Tcl_GetBooleanFromObj(interp, objv[4], &isVarArg) != TCL_OK)
	    return TCL_ERROR;
	int argumentCount = 0;
	Tcl_Obj** argumentTypeObjs = 0;
	if (Tcl_ListObjGetElements(interp, objv[3], &argumentCount, &argumentTypeObjs) != TCL_OK) {
	    std::ostringstream os;
	    os << "expected list of types but got \"" << Tcl_GetStringFromObj(objv[3], 0) << "\"";
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	    return TCL_ERROR;
	}
	LLVMTypeRef* argumentTypes = 0;
	if (argumentCount)
	    argumentTypes = new LLVMTypeRef[argumentCount];
	for(int i = 0; i < argumentCount; i++) {
	    argumentTypes[i] = GetLLVMTypeRef(interp, argumentTypeObjs[i]);
	    if (!argumentTypes[i]) {
		delete [] argumentTypes;
		return TCL_ERROR;
	    }
	}
	tref = LLVMFunctionType(returnType, argumentTypes, argumentCount, isVarArg);
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
	if (Tcl_GetIntFromObj(interp, objv[2], &width) != TCL_OK)
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
	LLVMTypeRef elementType = GetLLVMTypeRef(interp, objv[2]);
	if (!elementType)
	    return TCL_ERROR;
	int addressSpace = 0;
	if (Tcl_GetIntFromObj(interp, objv[3], &addressSpace) != TCL_OK)
	    return TCL_ERROR;
	tref = LLVMPointerType(elementType, addressSpace);
	break;
    }
    case eLLVMStructType:
    {
	int packed = 0;
	if (Tcl_GetBooleanFromObj(interp, objv[3], &packed) != TCL_OK)
	    return TCL_ERROR;
	int elementCount = 0;
	Tcl_Obj** elementTypeObjs = 0;
	if (Tcl_ListObjGetElements(interp, objv[2], &elementCount, &elementTypeObjs) != TCL_OK) {
	    std::ostringstream os;
	    os << "expected list of types but got \"" << Tcl_GetStringFromObj(objv[2], 0) << "\"";
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	    return TCL_ERROR;
	}
	if (elementCount == 0) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj("no element types found", -1));
	    return TCL_ERROR;
	}
	LLVMTypeRef* elementTypes = new LLVMTypeRef[elementCount];
	for(int i = 0; i < elementCount; i++) {
	    elementTypes[i] = GetLLVMTypeRef(interp, elementTypeObjs[i]);
	    if (!elementTypes[i]) {
		delete [] elementTypes;
		return TCL_ERROR;
	    }
	}
	tref = LLVMStructType(elementTypes, elementCount, packed);
	delete [] elementTypes;
	break;
    }
    case eLLVMUnionType:
    {
	int elementCount = 0;
	Tcl_Obj** elementTypeObjs = 0;
	if (Tcl_ListObjGetElements(interp, objv[2], &elementCount, &elementTypeObjs) != TCL_OK) {
	    std::ostringstream os;
	    os << "expected list of types but got \"" << Tcl_GetStringFromObj(objv[2], 0) << "\"";
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
	    return TCL_ERROR;
	}
	if (elementCount == 0) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj("no element types found", -1));
	    return TCL_ERROR;
	}
	LLVMTypeRef* elementTypes = new LLVMTypeRef[elementCount];
	for(int i = 0; i < elementCount; i++) {
	    elementTypes[i] = GetLLVMTypeRef(interp, elementTypeObjs[i]);
	    if (!elementTypes[i]) {
		delete [] elementTypes;
		return TCL_ERROR;
	    }
	}
	tref = LLVMUnionType(elementTypes, elementCount);
	delete [] elementTypes;
	break;
    }
    case eLLVMVectorType:
    {
	LLVMTypeRef elementType = GetLLVMTypeRef(interp, objv[2]);
	if (!elementType)
	    return TCL_ERROR;
	int elementCount = 0;
	if (Tcl_GetIntFromObj(interp, objv[3], &elementCount) != TCL_OK)
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
    std::ostringstream os;
    os << "LLVMTypeRef_" << LLVMRef_id;
    LLVMRef_id++;
    LLVMTypeRef_map[os.str().c_str()] = tref;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
    return TCL_OK;
}

typedef int (*LLVMObjCmdPtr)(ClientData clientData,
			     Tcl_Interp* interp,
			     int objc,
			     Tcl_Obj* const objv[]);

extern "C" int llvmtcl(ClientData clientData,
		       Tcl_Interp* interp,
		       int objc,
		       Tcl_Obj* const objv[])
{
    // objv[1] is llvm c function to be executed
    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?arg ...?");
	return TCL_ERROR;
    }
    static const char *subCommands[] = {
	"help",
	"LLVMArrayType",
	"LLVMCreateBuilder",
	"LLVMDisposeBuilder",
	"LLVMDisposeModule",
	"LLVMDoubleType",
	"LLVMFP128Type",
	"LLVMFloatType",
	"LLVMFunctionType",
	"LLVMInitializeNativeTarget",
	"LLVMInt16Type",
	"LLVMInt1Type",
	"LLVMInt32Type",
	"LLVMInt64Type",
	"LLVMInt8Type",
	"LLVMIntType",
	"LLVMLabelType",
	"LLVMLinkInJIT",
	"LLVMModuleCreateWithName",
	"LLVMOpaqueType",
	"LLVMPPCFP128Type",
	"LLVMPointerType",
	"LLVMStructType",
	"LLVMUnionType",
	"LLVMVectorType",
	"LLVMVoidType",
	"LLVMX86FP80Type",
	NULL
    };
    static LLVMObjCmdPtr subObjCmds[] = {
	&HelpObjCmd,
	&LLVMTypeObjCmd,
	&LLVMCreateBuilderObjCmd,
	&LLVMDisposeBuilderObjCmd,
	&LLVMDisposeModuleObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMInitializeNativeTargetObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMLinkInJITObjCmd,
	&LLVMModuleCreateWithNameObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd
    };
    int index = -1;
    if (Tcl_GetIndexFromObj(interp, objv[1], subCommands, "subcommand", 0,
			    &index) != TCL_OK)
	return TCL_ERROR;
    return subObjCmds[index](clientData, interp, objc, objv);
}

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

    Tcl_CreateObjCommand(interp, "llvmtcl::llvmtcl",
			 (Tcl_ObjCmdProc*)llvmtcl,
			 (ClientData)NULL, (Tcl_CmdDeleteProc*)NULL);

    return TCL_OK;
}
