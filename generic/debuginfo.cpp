static std::map<std::string, llvm::MDNode*> Metadata_map;
static std::map<llvm::MDNode*, std::string> Metadata_refmap;

/*
 * ----------------------------------------------------------------------
 *
 * GetMetadataFromObj --
 *
 *	Gets the DIScope handle that is described by a particular Tcl_Obj.
 *
 * ----------------------------------------------------------------------
 */

template<typename T>
static int
GetMetadataFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *obj,
    const char *typeName,
    T *&ref)
{
    ref = 0;
    std::string refName = Tcl_GetStringFromObj(obj, 0);
    if (Metadata_map.find(refName) == Metadata_map.end()) {
        std::ostringstream os;
        os << "expected " << typeName << " but got '" << refName << "'";
        Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));
        return TCL_ERROR;
    }
    llvm::MDNode *mdn = Metadata_map[refName];
    if (!llvm::isa<T>(mdn)) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"unexpected metadata type; was looking for %s", typeName));
	return TCL_ERROR;
    }
    ref = llvm::cast<T>(mdn);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * SetMetadataAsObj --
 *
 *	Gets the Tcl_Obj that describes a particular DIScope handle.
 *
 * ----------------------------------------------------------------------
 */

static Tcl_Obj *
SetMetadataAsObj(
    llvm::DIScope *ref,
    const char *typeName)
{
    if (Metadata_refmap.find(ref) == Metadata_refmap.end()) {
        std::string nm = GetRefName(typeName);
        Metadata_map[nm] = ref;
        Metadata_refmap[ref] = nm;
    }
    return Tcl_NewStringObj(Metadata_refmap[ref].c_str(), -1);
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

    Tcl_SetObjResult(interp, SetMetadataAsObj(val, "CompileUnit"));
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

    Tcl_SetObjResult(interp, SetMetadataAsObj(val, "File"));
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
    if (GetMetadataFromObj(interp, objv[2], "scope", scope) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    llvm::DIFile *file;
    if (GetMetadataFromObj(interp, objv[4], "file", file) != TCL_OK)
	return TCL_ERROR;
    int line;
    if (Tcl_GetIntFromObj(interp, objv[5], &line) != TCL_OK)
	return TCL_ERROR;

    auto val = builder.createNameSpace(scope, name, file, line);

    Tcl_SetObjResult(interp, SetMetadataAsObj(val, "Namespace"));
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

    Tcl_SetObjResult(interp, SetMetadataAsObj(val, "VoidType"));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineBasicType --
 *
 *	Defines a basic type. See the DWARF docs for meaning of the
 *	'dwarfTypeCode' argument, but note that floats are 0x04 (DW_ATE_float)
 *	and ints are 0x05 (DW_ATE_signed).
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
        Tcl_WrongNumArgs(interp, 1, objv,
		"Module name sizeInBits dwarfTypeCode");
        return TCL_ERROR;
    }

    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    std::string name = Tcl_GetString(objv[2]);
    int size, align = 0, dwarfTypeCode;
    if (Tcl_GetIntFromObj(interp, objv[3], &size) != TCL_OK)
	return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[4], &dwarfTypeCode) != TCL_OK)
	return TCL_ERROR;

    auto val = builder.createBasicType(name,
	    (uint64_t) size, (uint64_t) align, (unsigned) dwarfTypeCode);

    Tcl_SetObjResult(interp, SetMetadataAsObj(val, "BasicType"));
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
    llvm::DIType *pointee;
    if (GetMetadataFromObj(interp, objv[2], "type", pointee) != TCL_OK)
	return TCL_ERROR;
    size_t size = sizeof(pointee) * 8;

    auto val = builder.createPointerType(pointee, size);

    Tcl_SetObjResult(interp, SetMetadataAsObj(val, "PointerType"));
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
    if (GetMetadataFromObj(interp, objv[2], "scope", scope) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    llvm::DIFile *file;
    if (GetMetadataFromObj(interp, objv[4], "file", file) != TCL_OK)
	return TCL_ERROR;
    unsigned flags = 0, align = 0;
    int size, line;
    if (Tcl_GetIntFromObj(interp, objv[5], &line) != TCL_OK)
	return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[6], &size) != TCL_OK)
	return TCL_ERROR;
    std::vector<llvm::Metadata *> elements;
    for (int i=7 ; i<objc ; i++) {
	llvm::DIType *type;
	if (GetMetadataFromObj(interp, objv[i], "type", type) != TCL_OK)
	    return TCL_ERROR;
	elements.push_back(type);
    }

    auto val = builder.createStructType(scope, name, file, (unsigned) line,
	    (uint64_t) size, align, flags, nullptr,
	    builder.getOrCreateArray(elements));

    Tcl_SetObjResult(interp, SetMetadataAsObj(val, "StructType"));
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
    llvm::DIFile *file;
    if (GetMetadataFromObj(interp, objv[2], "file", file) != TCL_OK)
	return TCL_ERROR;
    std::vector<llvm::Metadata *> elements;
    for (int i=3 ; i<objc ; i++) {
	llvm::DIType *type;
	if (GetMetadataFromObj(interp, objv[i], "type", type) != TCL_OK)
	    return TCL_ERROR;
	elements.push_back(type);
    }

    auto val = builder.createSubroutineType(file,
	    builder.getOrCreateTypeArray(elements));

    Tcl_SetObjResult(interp, SetMetadataAsObj(val, "FunctionType"));
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
    if (objc != 8) {
        Tcl_WrongNumArgs(interp, 1, objv,
		"Module scope name linkName file line subroutineType");
        return TCL_ERROR;
    }

    LLVMModuleRef module;
    if (GetLLVMModuleRefFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;
    llvm::DIBuilder builder(*llvm::unwrap(module));
    llvm::DIScope *scope;
    if (GetMetadataFromObj(interp, objv[2], "scope", scope) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    std::string linkName = Tcl_GetString(objv[4]);
    llvm::DIFile *file;
    if (GetMetadataFromObj(interp, objv[5], "file", file) != TCL_OK)
	return TCL_ERROR;
    int line;
    if (Tcl_GetIntFromObj(interp, objv[6], &line) != TCL_OK)
	return TCL_ERROR;
    llvm::DISubroutineType *type;
    if (GetMetadataFromObj(interp, objv[7], "subroutine type", type) != TCL_OK)
	return TCL_ERROR;
    unsigned flags = 0;
    bool isOpt = true, isLocal = true, isDef = true;

    auto val = builder.createFunction(scope, name, linkName, file, line,
	    type, isLocal, isDef, line, flags, isOpt);

    Tcl_SetObjResult(interp, SetMetadataAsObj(val, "Function"));
    return TCL_OK;
}

static int
AttachToFunction(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "functionHandle functionMetadata");
        return TCL_ERROR;
    }

    LLVMValueRef functionRef = 0;
    if (GetLLVMValueRefFromObj(interp, objv[1], functionRef) != TCL_OK)
        return TCL_ERROR;
    llvm::Value *value = llvm::unwrap(functionRef);
    if (!llvm::isa<llvm::Function>(value)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"can only attach debug metadata to functions", -1));
	return TCL_ERROR;
    }
    llvm::DISubprogram *metadata;
    if (GetMetadataFromObj(interp, objv[2], "function", metadata) != TCL_OK)
	return TCL_ERROR;

    llvm::cast<llvm::Function>(value)->setMetadata("dbg", metadata);

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
