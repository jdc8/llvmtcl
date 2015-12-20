static std::map<std::string, llvm::DIScope*> LLVMDIScope_map;
static std::map<llvm::DIScope*, std::string> LLVMDIScope_refmap;

static int
GetLLVMDIScopeFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *obj,
    llvm::DIScope *&ref)
{
    ref = 0;
    std::string refName = Tcl_GetStringFromObj(obj, 0);
    if (LLVMDIScope_map.find(refName) == LLVMDIScope_map.end()) {
        std::ostringstream os;
        os << "expected LLVM.DIScope but got '" << refName << "'";
        Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
        return TCL_ERROR;
    }
    ref = LLVMDIScope_map[refName];
    return TCL_OK;
}

static Tcl_Obj *
SetLLVMDIScopeAsObj(
    llvm::DIScope *ref)
{
    if (LLVMDIScope_refmap.find(ref) == LLVMDIScope_refmap.end()) {
        std::string nm = GetRefName("LLVM.DIScope_");
        LLVMDIScope_map[nm] = ref;
        LLVMDIScope_refmap[ref] = nm;
    }
    return Tcl_NewStringObj(LLVMDIScope_refmap[ref].c_str(), -1);
}

extern "C" {
/*
 * ----------------------------------------------------------------------
 *
 * DefineCompileUnit --
 *
 *	Defines an overall compilation unit, i.e., an LLVM Module. This is a
 *	scope.
 *
 * ----------------------------------------------------------------------
 */

static int
DefineCompileUnit(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 6) {
        Tcl_WrongNumArgs(interp, 1, objv,
		"Module file directory producer runtimeVersion");
        return TCL_ERROR;
    }
	
    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    int runtimeVersion = 0;
    if (Tcl_GetIntFromObj(interp, objv[5], &runtimeVersion) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    unsigned lang = llvm::dwarf::DW_LANG_lo_user;//No standard value for Tcl!
    std::string file = Tcl_GetString(objv[2]);
    std::string dir = Tcl_GetString(objv[3]);
    std::string producer = Tcl_GetString(objv[4]);
    std::string flags = "";

    auto val = builder.createCompileUnit(lang, file, dir, producer, true,
	flags, (unsigned) runtimeVersion);

    Tcl_SetObjResult(interp, SetLLVMDIScopeAsObj(val));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineFile --
 *
 *	Defines a source file. This is a scope.
 *
 * ----------------------------------------------------------------------
 */

static int
DefineFile(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "Module file directory");
        return TCL_ERROR;
    }

    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    std::string file = Tcl_GetString(objv[2]);
    std::string dir = Tcl_GetString(objv[3]);

    auto val = builder.createFile(file, dir);

    Tcl_SetObjResult(interp, SetLLVMDIScopeAsObj(val));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineNamespace --
 *
 *	Defines a namespace. This is a scope.
 *
 * ----------------------------------------------------------------------
 */

static int
DefineNamespace(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 6) {
        Tcl_WrongNumArgs(interp, 1, objv, "Module scope name file line");
        return TCL_ERROR;
    }

    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    llvm::DIScope *scope;
    if (GetLLVMDIScopeFromObj(interp, objv[2], scope) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    llvm::DIScope *sval;
    if (GetLLVMDIScopeFromObj(interp, objv[4], sval) != TCL_OK)
	return TCL_ERROR;
    auto file = llvm::dyn_cast<llvm::DIFile>(sval);
    int line;
    if (Tcl_GetIntFromObj(interp, objv[5], &line) != TCL_OK)
	return TCL_ERROR;

    auto val = builder.createNameSpace(scope, name, file, line);

    Tcl_SetObjResult(interp, SetLLVMDIScopeAsObj(val));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineUnspecifiedType --
 *
 *	Defines an unspecified type. Corresponds to C 'void'.
 *
 * ----------------------------------------------------------------------
 */

static int
DefineUnspecifiedType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "Module name");
        return TCL_ERROR;
    }

    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    std::string name = Tcl_GetString(objv[2]);

    auto val = builder.createUnspecifiedType(name);

    Tcl_SetObjResult(interp, SetLLVMDIScopeAsObj(val));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineBasicType --
 *
 *	Defines a basic type.
 *
 * ----------------------------------------------------------------------
 */

static int
DefineBasicType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 5) {
        Tcl_WrongNumArgs(interp, 1, objv, "Module name size encoding");
        return TCL_ERROR;
    }

    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    std::string name = Tcl_GetString(objv[2]);
    int size, align = 0, encoding;
    if (Tcl_GetIntFromObj(interp, objv[3], &size) != TCL_OK)
	return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[4], &encoding) != TCL_OK)
	return TCL_ERROR;

    auto val = builder.createBasicType(name,
	    (uint64_t) size, (uint64_t) align, (unsigned) encoding);

    Tcl_SetObjResult(interp, SetLLVMDIScopeAsObj(val));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefinePointerType --
 *
 *	Defines a pointer type.
 *
 * ----------------------------------------------------------------------
 */

static int
DefinePointerType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "Module pointee");
        return TCL_ERROR;
    }

    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    llvm::DIScope *sval;
    if (GetLLVMDIScopeFromObj(interp, objv[2], sval) != TCL_OK)
	return TCL_ERROR;
    auto pointee = llvm::dyn_cast<llvm::DIType>(sval);
    size_t size = sizeof(pointee) * 8;

    auto val = builder.createPointerType(pointee, size);

    Tcl_SetObjResult(interp, SetLLVMDIScopeAsObj(val));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineStructType --
 *
 *	Defines a structure type.
 *
 * ----------------------------------------------------------------------
 */

static int
DefineStructType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc < 7) {
        Tcl_WrongNumArgs(interp, 1, objv,
		"Module scope name file line size element...");
        return TCL_ERROR;
    }

    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    llvm::DIScope *scope;
    if (GetLLVMDIScopeFromObj(interp, objv[2], scope) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    llvm::DIScope *sval;
    if (GetLLVMDIScopeFromObj(interp, objv[4], sval) != TCL_OK)
	return TCL_ERROR;
    auto file = llvm::dyn_cast<llvm::DIFile>(sval);
    unsigned flags = 0;
    int size;
    unsigned align = 0;
    int line;
    if (Tcl_GetIntFromObj(interp, objv[5], &line) != TCL_OK)
	return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[6], &size) != TCL_OK)
	return TCL_ERROR;
    std::vector<llvm::Metadata *> els;
    for (int i=7 ; i<objc ; i++) {
	if (GetLLVMDIScopeFromObj(interp, objv[i], sval) != TCL_OK)
	    return TCL_ERROR;
	els.push_back(sval);
    }
    llvm::ArrayRef<llvm::Metadata *> elements(els);

    auto val = builder.createStructType(scope, name, file, (unsigned) line,
	    (uint64_t) size, align, flags, nullptr,
	    builder.getOrCreateArray(elements));

    Tcl_SetObjResult(interp, SetLLVMDIScopeAsObj(val));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineFunctionType --
 *
 *	Defines a function type.
 *
 * ----------------------------------------------------------------------
 */

static int
DefineFunctionType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc < 4) {
        Tcl_WrongNumArgs(interp, 1, objv,
		"Module file returnType argumentType...");
        return TCL_ERROR;
    }

    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    std::vector<llvm::Metadata *> els;
    llvm::DIScope *sval;
    if (GetLLVMDIScopeFromObj(interp, objv[5], sval) != TCL_OK)
	return TCL_ERROR;
    auto file = llvm::dyn_cast<llvm::DIFile>(sval);
    for (int i=3 ; i<objc ; i++) {
	if (GetLLVMDIScopeFromObj(interp, objv[i], sval) != TCL_OK)
	    return TCL_ERROR;
	els.push_back(sval);
    }
    llvm::ArrayRef<llvm::Metadata *> elements(els);

    auto val = builder.createSubroutineType(file,
	    builder.getOrCreateTypeArray(elements));

    Tcl_SetObjResult(interp, SetLLVMDIScopeAsObj(val));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineFunction --
 *
 *	Defines a function definition.
 *
 * ----------------------------------------------------------------------
 */

static int
DefineFunction(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv,
		"Module returnType argumentType...");
        return TCL_ERROR;
    }

    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    llvm::DIScope *scope;
    if (GetLLVMDIScopeFromObj(interp, objv[2], scope) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    std::string linkName = Tcl_GetString(objv[4]);
    llvm::DIScope *sval;
    if (GetLLVMDIScopeFromObj(interp, objv[5], sval) != TCL_OK)
	return TCL_ERROR;
    auto file = llvm::dyn_cast<llvm::DIFile>(sval);
    int line;
    if (Tcl_GetIntFromObj(interp, objv[6], &line) != TCL_OK)
	return TCL_ERROR;
    if (GetLLVMDIScopeFromObj(interp, objv[7], sval) != TCL_OK)
	return TCL_ERROR;
    auto type = llvm::dyn_cast<llvm::DISubroutineType>(sval);
    unsigned flags = 0;
    bool isOpt = true, isLocal = true, isDef = true;

    auto val = builder.createFunction(scope, name, linkName, file, line,
	    type, isLocal, isDef, line, flags, isOpt);

    Tcl_SetObjResult(interp, SetLLVMDIScopeAsObj(val));
    return TCL_OK;
}

}
/*
 * Local Variables:
 * mode: c++
 * c-basic-offset: 4
 * fill-column: 78
 * tab-width: 8
 * End:
 */
