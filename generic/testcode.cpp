#include "tcl.h"
#include "tclTomMath.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/ExecutionEngine/ExecutionEngine.h"

extern int GetEngineFromObj(Tcl_Interp *interp, Tcl_Obj *obj, llvm::ExecutionEngine *&engine);
extern int GetModuleFromObj(Tcl_Interp *interp, Tcl_Obj *obj, llvm::Module *&module);

using namespace llvm;

/*
 * ----------------------------------------------------------------------
 *
 * llvm_test, llvm_add, llvm_sub --
 *
 *	Functions to be mapped into an execution environment.
 *
 * ----------------------------------------------------------------------
 */

extern "C" {
void llvm_test() {}

Tcl_Obj *
llvm_add(
    Tcl_Interp *interp,
    Tcl_Obj *oa,
    Tcl_Obj *ob)
{
    mp_int big1, big2, bigResult;

    Tcl_GetBignumFromObj(interp, oa, &big1);
    Tcl_GetBignumFromObj(interp, ob, &big2);
    TclBN_mp_init(&bigResult);

    TclBN_mp_add(&big1, &big2, &bigResult);

    return Tcl_NewBignumObj(&bigResult);
}

Tcl_Obj *
llvm_sub(
    Tcl_Interp *interp,
    Tcl_Obj *oa,
    Tcl_Obj *ob)
{
    mp_int big1, big2, bigResult;

    Tcl_GetBignumFromObj(interp, oa, &big1);
    Tcl_GetBignumFromObj(interp, ob, &big2);
    TclBN_mp_init(&bigResult);

    TclBN_mp_sub(&big1, &big2, &bigResult);

    return Tcl_NewBignumObj(&bigResult);
}
} // extern "C"

static inline void
addFunction(
    ExecutionEngine *ee,
    Module *mod,
    std::string name,
    FunctionType *type,
    void *implementation)
{
    ee->addGlobalMapping(cast<Function>(
	    mod->getOrInsertFunction(name, type)),
	    implementation);
}

/*
 * ----------------------------------------------------------------------
 *
 * LLVMAddLLVMTclCommandsObjCmd --
 *
 *	Tcl Command Implementation: Maps three functions into the given
 *	execution environment and module.
 *
 * ----------------------------------------------------------------------
 */

MODULE_SCOPE int
LLVMAddLLVMTclCommandsObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "EE mod ");
        return TCL_ERROR;
    }

    ExecutionEngine *ee;
    if (GetEngineFromObj(interp, objv[1], ee) != TCL_OK)
        return TCL_ERROR;

    Module *mod;
    if (GetModuleFromObj(interp, objv[2], mod) != TCL_OK)
        return TCL_ERROR;

    auto void_type = Type::getVoidTy(getGlobalContext());
    auto ptr_type = Type::getInt8PtrTy(getGlobalContext());
    FunctionType *func_type;

    func_type = FunctionType::get(void_type, false);
    addFunction(ee, mod, "llvm_test", func_type, (void *) &llvm_test);

    Type *pta[3] = {ptr_type, ptr_type, ptr_type};
    func_type = FunctionType::get(ptr_type, pta, false);
    addFunction(ee, mod, "llvm_add", func_type, (void *) &llvm_add);
    addFunction(ee, mod, "llvm_sub", func_type, (void *) &llvm_sub);
    return TCL_OK;
}

/*
 * Local Variables:
 * mode: c++
 * c-basic-offset: 4
 * fill-column: 78
 * tab-width: 8
 * End:
 */
