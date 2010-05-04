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
	Tcl_SetObjResult(interp, Tcl_NewStringObj("unknown builder", -1));
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
	Tcl_SetObjResult(interp, Tcl_NewStringObj("unknown module", -1));
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

int LLVMTypeObjCmd(ClientData clientData, 
		   Tcl_Interp* interp,
		   int objc,
		   Tcl_Obj* const objv[])
{
    static const char *subCommands[] = {
	"LLVMDoubleType",
	"LLVMFP128Type",
	"LLVMFloatType",
	"LLVMInt16Type",
	"LLVMInt1Type",
	"LLVMInt32Type",
	"LLVMInt64Type",
	"LLVMInt8Type",
	"LLVMIntType",
	"LLVMPPCFP128Type",
	"LLVMX86FP80Type",
	NULL
    };
    enum SubCmds {
	eLLVMDoubleType,
	eLLVMFP128Type,
	eLLVMFloatType,
	eLLVMInt16Type,
	eLLVMInt1Type,
	eLLVMInt32Type,
	eLLVMInt64Type,
	eLLVMInt8Type,
	eLLVMIntType,
	eLLVMPPCFP128Type,
	eLLVMX86FP80Type  
    };
    int index = -1;
    if (Tcl_GetIndexFromObj(interp, objv[1], subCommands, "type", 0, &index) != TCL_OK)
        return TCL_ERROR;
    // Check number of arguments
    switch ((enum SubCmds) index) {
    case eLLVMDoubleType:
    case eLLVMFP128Type:
    case eLLVMFloatType:
    case eLLVMInt16Type:
    case eLLVMInt1Type:
    case eLLVMInt32Type:
    case eLLVMInt64Type:
    case eLLVMInt8Type:
    case eLLVMPPCFP128Type:
    case eLLVMX86FP80Type:
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, "");
	    return TCL_ERROR;
	}
	break;
    case eLLVMIntType:
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "width");
	    return TCL_ERROR;
	}
	break;
    }
    // Create the requested type
    LLVMTypeRef tref = 0;
    switch ((enum SubCmds) index) {
    case eLLVMDoubleType: tref = LLVMDoubleType(); break;
    case eLLVMFP128Type: tref = LLVMFP128Type(); break;
    case eLLVMFloatType: tref = LLVMFloatType(); break;
    case eLLVMInt16Type: tref = LLVMInt16Type(); break;
    case eLLVMInt1Type: tref = LLVMInt1Type(); break;
    case eLLVMInt32Type: tref = LLVMInt32Type(); break;
    case eLLVMInt64Type: tref = LLVMInt64Type(); break;
    case eLLVMInt8Type: tref = LLVMInt8Type(); break;
    case eLLVMIntType:
    {
	int width = 0;
	if (Tcl_GetIntFromObj(interp, objv[2], &width) != TCL_OK)
	    return TCL_ERROR;
	tref = LLVMIntType(width);
	break;
    }
    case eLLVMPPCFP128Type: tref = LLVMPPCFP128Type(); break;
    case eLLVMX86FP80Type: tref = LLVMX86FP80Type(); break;
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
	"LLVMCreateBuilder",
	"LLVMDisposeBuilder",
	"LLVMDisposeModule",
	"LLVMDoubleType",
	"LLVMFP128Type",
	"LLVMFloatType",
	"LLVMInitializeNativeTarget",
	"LLVMInt16Type",
	"LLVMInt1Type",
	"LLVMInt32Type",
	"LLVMInt64Type",
	"LLVMInt8Type",
	"LLVMIntType",
	"LLVMLinkInJIT",
	"LLVMModuleCreateWithName",
	"LLVMPPCFP128Type",
	"LLVMX86FP80Type",
	NULL
    };
    static LLVMObjCmdPtr subObjCmds[] = {
	&HelpObjCmd,
	&LLVMCreateBuilderObjCmd,
	&LLVMDisposeBuilderObjCmd,
	&LLVMDisposeModuleObjCmd,
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
	&LLVMLinkInJITObjCmd,
	&LLVMModuleCreateWithNameObjCmd,
	&LLVMTypeObjCmd,
	&LLVMTypeObjCmd,
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
