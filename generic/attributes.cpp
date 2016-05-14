#include "llvmtcl.h"
#include "llvm/IR/CallSite.h"

using namespace llvm;

/*
 * ----------------------------------------------------------------------
 *
 * Definition of the mapping between attribute names and their kinds.
 * There's no simple two-way functions for this.
 *
 * ----------------------------------------------------------------------
 */

struct AttributeMapper {
    const char *name;
    const Attribute::AttrKind kind;
};

#define ATTRDEF(a, b) {#b, Attribute::a}
static const AttributeMapper attrMap[] = {
    ATTRDEF(Alignment,		align),
    ATTRDEF(StackAlignment,	alignstack),
    ATTRDEF(AlwaysInline,	alwaysinline),
    ATTRDEF(ArgMemOnly,		argmemonly),
    ATTRDEF(Builtin,		builtin),
    ATTRDEF(ByVal,		byval),
    ATTRDEF(Cold,		cold),
    ATTRDEF(Convergent,		convergent),
    ATTRDEF(Dereferenceable,	dereferenceable),
    ATTRDEF(DereferenceableOrNull, dereferenceable_or_null),
    ATTRDEF(InAlloca,		inalloca),
    ATTRDEF(InReg,		inreg),
    ATTRDEF(InlineHint,		inlinehint),
    ATTRDEF(JumpTable,		jumptable),
    ATTRDEF(MinSize,		minsize),
    ATTRDEF(Naked,		naked),
    ATTRDEF(Nest,		nest),
    ATTRDEF(NoAlias,		noalias),
    ATTRDEF(NoBuiltin,		nobuiltin),
    ATTRDEF(NoCapture,		nocapture),
    ATTRDEF(NoDuplicate,	noduplicate),
    ATTRDEF(NoImplicitFloat,	noimplicitfloat),
    ATTRDEF(NoInline,		noinline),
    ATTRDEF(NonLazyBind,	nonlazybind),
    ATTRDEF(NonNull,		nonnull),
    ATTRDEF(NoRedZone,		noredzone),
    ATTRDEF(NoReturn,		noreturn),
    ATTRDEF(NoUnwind,		nounwind),
    ATTRDEF(OptimizeNone,	optnone),
    ATTRDEF(OptimizeForSize,	optsize),
    ATTRDEF(ReadNone,		readnone),
    ATTRDEF(ReadOnly,		readonly),
    ATTRDEF(Returned,		returned),
    ATTRDEF(ReturnsTwice,	returns_twice),
    ATTRDEF(SafeStack,		safestack),
    ATTRDEF(SanitizeAddress,	sanitize_address),
    ATTRDEF(SanitizeMemory,	sanitize_memory),
    ATTRDEF(SanitizeThread,	sanitize_thread),
    ATTRDEF(SExt,		signext),
    ATTRDEF(StructRet,		sret),
    ATTRDEF(StackProtect,	ssp),
    ATTRDEF(StackProtectReq,	sspreq),
    ATTRDEF(StackProtectStrong,	sspstrong),
    ATTRDEF(UWTable,		uwtable),
    ATTRDEF(ZExt,		zeroext),
    {NULL}
};
#undef ATTRDEF

/*
 * ----------------------------------------------------------------------
 *
 * GetAttrFromObj --
 *
 *	Gets the kind of attribute that is described by a particular
 *	Tcl_Obj.
 *
 * ----------------------------------------------------------------------
 */

static int
GetAttrFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *obj,
    Attribute::AttrKind &attr)
{
    int index;
    if (Tcl_GetIndexFromObjStruct(interp, obj, (const void *) attrMap,
	    sizeof(AttributeMapper), "attribute", TCL_EXACT,
	    &index) != TCL_OK)
	return TCL_ERROR;
    attr = attrMap[index].kind;
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DescribeAttributes --
 *
 *	Converts a set of attributes into the list of descriptions of
 *	attributes that apply to a particular slot.
 *
 * ----------------------------------------------------------------------
 */

static Tcl_Obj *
DescribeAttributes(
    AttributeSet attrs,
    unsigned slot)
{
    auto list = Tcl_NewObj();
    for (auto map = &attrMap[0] ; map->name ; map++)
	if (attrs.hasAttribute(slot, map->kind))
	    Tcl_ListObjAppendElement(NULL, list,
		    Tcl_NewStringObj(map->name, -1));
    return list;
}

/*
 * ----------------------------------------------------------------------
 *
 * LLVMAddFunctionAttrObjCmd --
 *
 *	Command implementation for [llvm::AddFunctionAttr].
 *
 * ----------------------------------------------------------------------
 */

int
LLVMAddFunctionAttrObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "Fn PA");
	return TCL_ERROR;
    }
    Function *func;
    if (GetValueFromObj(interp, objv[1], "expected function",
	    func) != TCL_OK)
        return TCL_ERROR;
    Attribute::AttrKind attr;
    if (GetAttrFromObj(interp, objv[2], attr) != TCL_OK)
	return TCL_ERROR;
    func->addFnAttr(attr);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * LLVMRemoveFunctionAttrObjCmd --
 *
 *	Command implementation for [llvm::RemoveFunctionAttr].
 *
 * ----------------------------------------------------------------------
 */

int
LLVMRemoveFunctionAttrObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "Fn PA");
	return TCL_ERROR;
    }
    Function *func;
    if (GetValueFromObj(interp, objv[1], "expected function",
	    func) != TCL_OK)
        return TCL_ERROR;
    Attribute::AttrKind attr;
    if (GetAttrFromObj(interp, objv[2], attr) != TCL_OK)
	return TCL_ERROR;
    func->removeFnAttr(attr);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * LLVMGetFunctionAttrObjCmd --
 *
 *	Command implementation for [llvm::GetFunctionAttr].
 *
 * ----------------------------------------------------------------------
 */

int
LLVMGetFunctionAttrObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "Fn");
	return TCL_ERROR;
    }
    Function *func;
    if (GetValueFromObj(interp, objv[1], "expected function",
	    func) != TCL_OK)
        return TCL_ERROR;
    auto attrs = func->getAttributes();
    Tcl_SetObjResult(interp,
	    DescribeAttributes(attrs, AttributeSet::FunctionIndex));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * LLVMAddAttributeObjCmd --
 *
 *	Command implementation for [llvm::AddArgumentAttribute].
 *
 * ----------------------------------------------------------------------
 */

int
LLVMAddAttributeObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "FnArg PA");
	return TCL_ERROR;
    }
    Argument *arg;
    if (GetValueFromObj(interp, objv[1], "expected function argument",
	    arg) != TCL_OK)
        return TCL_ERROR;
    Attribute::AttrKind attr;
    if (GetAttrFromObj(interp, objv[2], attr) != TCL_OK)
	return TCL_ERROR;
    arg->addAttr(AttributeSet::get(arg->getContext(),
	    arg->getArgNo(), attr));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * LLVMRemoveAttributeObjCmd --
 *
 *	Command implementation for [llvm::RemoveArgumentAttribute].
 *
 * ----------------------------------------------------------------------
 */

int
LLVMRemoveAttributeObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "FnArg PA");
	return TCL_ERROR;
    }
    Argument *arg;
    if (GetValueFromObj(interp, objv[1], "expected function argument",
	    arg) != TCL_OK)
        return TCL_ERROR;
    Attribute::AttrKind attr;
    if (GetAttrFromObj(interp, objv[2], attr) != TCL_OK)
	return TCL_ERROR;
    arg->removeAttr(AttributeSet::get(arg->getContext(),
	    arg->getArgNo(), attr));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * LLVMGetAttributeObjCmd --
 *
 *	Command implementation for [llvm::GetArgumentAttribute].
 *
 * ----------------------------------------------------------------------
 */

int
LLVMGetAttributeObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "FnArg");
	return TCL_ERROR;
    }
    Argument *arg;
    if (GetValueFromObj(interp, objv[1], "expected function argument",
	    arg) != TCL_OK)
        return TCL_ERROR;
    auto func = arg->getParent();
    auto attrs = func->getAttributes();
    Tcl_SetObjResult(interp,
	    DescribeAttributes(attrs, arg->getArgNo()));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * LLVMAddInstrAttributeObjCmd --
 *
 *	Command implementation for [llvm::AddCallAttribute].
 *
 * ----------------------------------------------------------------------
 */

int
LLVMAddInstrAttributeObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "Instr index PA");
	return TCL_ERROR;
    }
    Instruction *instr;
    if (GetValueFromObj(interp, objv[1], "expected function argument",
	    instr) != TCL_OK)
        return TCL_ERROR;
    CallSite call(instr);
    if (!instr) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"expected call or invoke instruction", -1));
	return TCL_ERROR;
    }
    int iarg2 = 0;
    if (Tcl_GetIntFromObj(interp, objv[2], &iarg2) != TCL_OK)
        return TCL_ERROR;
    unsigned index = (unsigned)iarg2;
    Attribute::AttrKind attr;
    if (GetAttrFromObj(interp, objv[3], attr) != TCL_OK)
	return TCL_ERROR;
    call.setAttributes(call.getAttributes().addAttribute(
	    instr->getContext(), index, attr));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * LLVMRemoveInstrAttributeObjCmd --
 *
 *	Command implementation for [llvm::RemoveCallAttribute].
 *
 * ----------------------------------------------------------------------
 */

int
LLVMRemoveInstrAttributeObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "Instr index PA");
	return TCL_ERROR;
    }
    Instruction *instr;
    if (GetValueFromObj(interp, objv[1], "expected function argument",
	    instr) != TCL_OK)
        return TCL_ERROR;
    CallSite call(instr);
    if (!instr) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"expected call or invoke instruction", -1));
	return TCL_ERROR;
    }
    int iarg2 = 0;
    if (Tcl_GetIntFromObj(interp, objv[2], &iarg2) != TCL_OK)
        return TCL_ERROR;
    unsigned index = (unsigned)iarg2;
    Attribute::AttrKind attr;
    if (GetAttrFromObj(interp, objv[3], attr) != TCL_OK)
	return TCL_ERROR;
    call.setAttributes(call.getAttributes().removeAttribute(
	    instr->getContext(), index, attr));
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
