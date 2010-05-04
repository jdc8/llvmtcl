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

extern "C" int llvmtcl(ClientData     clientData, 
		       Tcl_Interp*    interp,
		       int	    objc,
		       Tcl_Obj* const objv[]) 
{
    // objv[1] is llvm c function to be executed
    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?arg ...?");
	return TCL_ERROR;
    }
    static const char *subCommands[] = {
	"LLVMCreateBuilder",
	"LLVMDisposeBuilder",
	"LLVMDisposeModule",
	"LLVMInitializeNativeTarget",
	"LLVMLinkInJIT",
	"LLVMModuleCreateWithName",
        "help",
	NULL
    };
    enum SubCmds {
	LLVMTCL_LLVMCreateBuilder,
	LLVMTCL_LLVMDisposeBuilder,
	LLVMTCL_LLVMDisposeModule,
	LLVMTCL_LLVMInitializeNativeTarget,
	LLVMTCL_LLVMLinkInJIT,
	LLVMTCL_LLVMModuleCreateWithName,
        LLVMTCL_help
    };
    int index = -1;
    if (Tcl_GetIndexFromObj(interp, objv[1], subCommands, "subcommand", 0,
                            &index) != TCL_OK)
        return TCL_ERROR;
    switch((enum SubCmds)index) {
    case LLVMTCL_LLVMCreateBuilder:
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
	break;
    }
    case LLVMTCL_LLVMDisposeBuilder:
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
	break;
    }
    case LLVMTCL_LLVMDisposeModule:
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
	break;
    }
    case LLVMTCL_LLVMInitializeNativeTarget:
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, "");
	    return TCL_ERROR;
	}
	LLVMInitializeNativeTarget();
	break;
    case LLVMTCL_LLVMLinkInJIT:
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, "");
	    return TCL_ERROR;
	}
	LLVMLinkInJIT();
	break;
    case LLVMTCL_LLVMModuleCreateWithName:
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
	break;
    }
    case LLVMTCL_help:
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
	break;
    }
    return TCL_OK;
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
