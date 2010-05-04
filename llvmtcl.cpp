#include "tcl.h"
#include <iostream>
#include <sstream>
#include "llvm-c/Analysis.h"
#include "llvm-c/Core.h"
#include "llvm-c/ExecutionEngine.h"
#include "llvm-c/Target.h"

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
	"LLVMInitializeNativeTarget",
	"LLVMLinkInJIT",
        "help",
	NULL
    };
    enum SubCmds {
	LLVMTCL_LLVMInitializeNativeTarget,
	LLVMTCL_LLVMLinkInJIT,
        LLVMTCL_help
    };
    int index = -1;
    if (Tcl_GetIndexFromObj(interp, objv[1], subCommands, "subcommand", 0,
                            &index) != TCL_OK)
        return TCL_ERROR;
    switch((enum SubCmds)index) {
    case LLVMTCL_LLVMInitializeNativeTarget:
	LLVMInitializeNativeTarget();
	break;
    case LLVMTCL_LLVMLinkInJIT:
	LLVMLinkInJIT();
	break;
    case LLVMTCL_help:
	std::ostringstream os;
	os << "LLVM Tcl interface\n"
	   << "\n"
	   << "Available commands:\n"
	   << "\n"
	   << "    llvmtcl::llvmtcl LLVMInitializeNativeTarget\n"
	   << "    llvmtcl::llvmtcl LLVMLinkInJit\n"
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
