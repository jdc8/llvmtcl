#include "tcl.h"
#include <map>
#include "llvm/IR/DIBuilder.h"
#include "llvm-c/Core.h"
#include "llvmtcl.h"

using namespace llvm;

static std::map<std::string, MDNode*> Metadata_map;
static std::map<MDNode*, std::string> Metadata_refmap;
static std::map<std::string, DIBuilder*> Builder_map;
static std::map<DIBuilder*, std::string> Builder_refmap;

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
int
GetMetadataFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *obj,
    const char *typeName,
    T *&ref)
{
    ref = 0;
    std::string refName = Tcl_GetStringFromObj(obj, 0);
    auto it = Metadata_map.find(refName);
    if (it == Metadata_map.end()) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf("expected %s but got '%s'",
		typeName, refName.c_str()));
	return TCL_ERROR;
    }
    if (!(ref = dyn_cast<T>(it->second))) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"unexpected metadata type; was looking for %s", typeName));
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * NewMetadataObj --
 *
 *	Gets the Tcl_Obj that describes a particular DIScope handle.
 *
 * ----------------------------------------------------------------------
 */

static Tcl_Obj *
NewMetadataObj(
    MDNode *ref,
    const char *typeName)
{
    if (Metadata_refmap.find(ref) == Metadata_refmap.end()) {
	std::string nm = GetRefName(typeName);
	Metadata_map[nm] = ref;
	Metadata_refmap[ref] = nm;
    }
    return Tcl_NewStringObj(Metadata_refmap[ref].c_str(), -1);
}

/*
 * ----------------------------------------------------------------------
 *
 * GetDIBuilderFromObj --
 *
 *	Gets the DIBuilder handle that is described by a particular Tcl_Obj.
 *
 * ----------------------------------------------------------------------
 */

int
GetDIBuilderFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *obj,
    DIBuilder *&ref)
{
    std::string refName = Tcl_GetStringFromObj(obj, 0);
    auto it = Builder_map.find(refName);
    if (it == Builder_map.end()) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"expected DIBuilder but got '%s'", refName.c_str()));
	return TCL_ERROR;
    }
    ref = it->second;
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * NewDIBuilderObj --
 *
 *	Gets the Tcl_Obj that describes a particular DIBuilder handle.
 *
 * ----------------------------------------------------------------------
 */

static Tcl_Obj *
NewDIBuilderObj(
    DIBuilder *ref)
{
    if (Builder_refmap.find(ref) == Builder_refmap.end()) {
	std::string nm = GetRefName("DebugInfoBuilder");
	Builder_map[nm] = ref;
	Builder_refmap[ref] = nm;
    }
    return Tcl_NewStringObj(Builder_refmap[ref].c_str(), -1);
}

/*
 * ----------------------------------------------------------------------
 *
 * DeleteDIBuilder --
 *
 *	Nukes the mapping from Tcl_Obj to DIBuilder ref and deletes the
 *	DIBuilder itself.
 *
 * ----------------------------------------------------------------------
 */

static inline void
DeleteDIBuilder(
    DIBuilder *ref)
{
    if (Builder_refmap.find(ref) != Builder_refmap.end()) {
	Builder_map.erase(Builder_refmap[ref]);
	Builder_refmap.erase(ref);
    }
    delete ref;
}

/*
 * ----------------------------------------------------------------------
 *
 * CreateDebugBuilder, DisposeDebugBuilder --
 *
 *	Create and destroy a DebugInfoBuilder (DIBuilder).
 *
 * ----------------------------------------------------------------------
 */

int
CreateDebugBuilder(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "module");
	return TCL_ERROR;
    }

    Module *module;
    if (GetModuleFromObj(interp, objv[1], module) != TCL_OK)
	return TCL_ERROR;

    Tcl_SetObjResult(interp, NewDIBuilderObj(new DIBuilder(*module)));
    return TCL_OK;
}

int
DisposeDebugBuilder(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "DIBuilder");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;

    builder->finalize();
    DeleteDIBuilder(builder);
    return TCL_OK;
}

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

int
DefineCompileUnit(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 5) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"DIBuilder file directory producer");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    unsigned lang = dwarf::DW_LANG_lo_user;//No standard value for Tcl!
    std::string file = Tcl_GetString(objv[2]);
    std::string dir = Tcl_GetString(objv[3]);
    std::string producer = Tcl_GetString(objv[4]);
    std::string flags = "";
    unsigned runtimeVersion = 0;

    auto val = builder->createCompileUnit(lang, file, dir, producer, true,
	    flags, runtimeVersion);

    Tcl_SetObjResult(interp, NewMetadataObj(val, "CompileUnit"));
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

int
DefineFile(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "DIBuilder file directory");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    std::string file = Tcl_GetString(objv[2]);
    std::string dir = Tcl_GetString(objv[3]);

    auto val = builder->createFile(file, dir);

    Tcl_SetObjResult(interp, NewMetadataObj(val, "File"));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineLocation --
 *
 *	Defines a location.
 *
 * ----------------------------------------------------------------------
 */

int
DefineLocation(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "scope line column");
	return TCL_ERROR;
    }

    DILocalScope *scope;
    int line, column;
    if (GetMetadataFromObj(interp, objv[1], "scope", scope) != TCL_OK)
	return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[2], &line) != TCL_OK)
	return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[3], &column) != TCL_OK)
	return TCL_ERROR;

    auto val = DILocation::get(scope->getContext(),
	    (unsigned) line, (unsigned) column, scope);

    Tcl_SetObjResult(interp, NewMetadataObj(val, "Location"));
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

int
DefineNamespace(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 6) {
	Tcl_WrongNumArgs(interp, 1, objv, "DIBuilder scope name file line");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    DIScope *scope;
    if (GetMetadataFromObj(interp, objv[2], "scope", scope) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    DIFile *file;
    if (GetMetadataFromObj(interp, objv[4], "file", file) != TCL_OK)
	return TCL_ERROR;
    int line;
    if (Tcl_GetIntFromObj(interp, objv[5], &line) != TCL_OK)
	return TCL_ERROR;

    auto val = builder->createNameSpace(scope, name, file, line);

    Tcl_SetObjResult(interp, NewMetadataObj(val, "Namespace"));
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

int
DefineUnspecifiedType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "DIBuilder name");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[2]);

    auto val = builder->createUnspecifiedType(name);

    Tcl_SetObjResult(interp, NewMetadataObj(val, "VoidType"));
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

int
DefineBasicType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 5) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"DIBuilder name sizeInBits dwarfTypeCode");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[2]);
    int size, align = 0, dwarfTypeCode;
    if (Tcl_GetIntFromObj(interp, objv[3], &size) != TCL_OK)
	return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[4], &dwarfTypeCode) != TCL_OK)
	return TCL_ERROR;

    auto val = builder->createBasicType(name,
	    (uint64_t) size, (uint64_t) align, (unsigned) dwarfTypeCode);

    Tcl_SetObjResult(interp, NewMetadataObj(val, "BasicType"));
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

int
DefinePointerType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "DIBuilder pointee");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    DIType *pointee;
    if (GetMetadataFromObj(interp, objv[2], "type", pointee) != TCL_OK)
	return TCL_ERROR;
    size_t size = sizeof(pointee) * 8;

    auto val = builder->createPointerType(pointee, size);

    Tcl_SetObjResult(interp, NewMetadataObj(val, "PointerType"));
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

int
DefineStructType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc < 7) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"DIBuilder scope name file line size element...");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    DIScope *scope;
    if (GetMetadataFromObj(interp, objv[2], "scope", scope) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    DIFile *file;
    if (GetMetadataFromObj(interp, objv[4], "file", file) != TCL_OK)
	return TCL_ERROR;
    unsigned flags = 0, align = 0;
    int size, line;
    if (Tcl_GetIntFromObj(interp, objv[5], &line) != TCL_OK)
	return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[6], &size) != TCL_OK)
	return TCL_ERROR;
    std::vector<Metadata *> elements;
    for (int i=7 ; i<objc ; i++) {
	DIType *type;
	if (GetMetadataFromObj(interp, objv[i], "type", type) != TCL_OK)
	    return TCL_ERROR;
	elements.push_back(type);
    }

    auto val = builder->createStructType(scope, name, file, (unsigned) line,
	    (uint64_t) size, align, flags, nullptr,
	    builder->getOrCreateArray(elements));

    Tcl_SetObjResult(interp, NewMetadataObj(val, "StructType"));
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

int
DefineFunctionType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc < 4) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"DIBuilder file returnType argumentType...");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    DIFile *file;
    if (GetMetadataFromObj(interp, objv[2], "file", file) != TCL_OK)
	return TCL_ERROR;
    std::vector<Metadata *> elements;
    for (int i=3 ; i<objc ; i++) {
	DIType *type;
	if (GetMetadataFromObj(interp, objv[i], "type", type) != TCL_OK)
	    return TCL_ERROR;
	elements.push_back(type);
    }

    auto val = builder->createSubroutineType(file,
	    builder->getOrCreateTypeArray(elements));

    Tcl_SetObjResult(interp, NewMetadataObj(val, "FunctionType"));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineAliasType --
 *
 *	Defines a type alias (e.g., C typedef).
 *
 * ----------------------------------------------------------------------
 */

int
DefineAliasType(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 7) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"DIBuilder type name file line contextScope");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    DIType *type;
    if (GetMetadataFromObj(interp, objv[2], "type", type) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    DIFile *file;
    if (GetMetadataFromObj(interp, objv[4], "file", file) != TCL_OK)
	return TCL_ERROR;
    int line;
    if (Tcl_GetIntFromObj(interp, objv[5], &line) != TCL_OK)
	return TCL_ERROR;
    DIScope *context;
    if (GetMetadataFromObj(interp, objv[6], "context", context) != TCL_OK)
	return TCL_ERROR;

    auto val = builder->createTypedef(type, name, file, line, context);

    Tcl_SetObjResult(interp, NewMetadataObj(val, "AliasType"));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * DefineParameter --
 *
 *	Defines the arguments as parameter variables.
 *
 * ----------------------------------------------------------------------
 */

int
DefineParameter(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 8) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"DIBuilder scope name argIndex file line type");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    DIScope *scope;
    if (GetMetadataFromObj(interp, objv[2], "scope", scope) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    int argIndex, line;
    if (Tcl_GetIntFromObj(interp, objv[4], &argIndex) != TCL_OK)
	return TCL_ERROR;
    if (argIndex < 1) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"argument indices must be at least 1", -1));
	return TCL_ERROR;
    }
    DIFile *file;
    if (GetMetadataFromObj(interp, objv[5], "file", file) != TCL_OK)
	return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[6], &line) != TCL_OK)
	return TCL_ERROR;
    DIType *type;
    if (GetMetadataFromObj(interp, objv[7], "type", type) != TCL_OK)
	return TCL_ERROR;

#if (LLVM_VERSION_MAJOR >=3 && LLVM_VERSION_MINOR > 7)
    auto val = builder->createParameterVariable(scope, name,
	    (unsigned) argIndex, file, (unsigned) line, type);
#else
    // This API was deprecated (and made private) after 3.7
    auto val = builder->createLocalVariable(
	    llvm::dwarf::DW_TAG_arg_variable, scope, name, file,
	    (unsigned) line, type, false, 0, (unsigned) argIndex);
#endif

    Tcl_SetObjResult(interp, NewMetadataObj(val, "Variable"));
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

int
DefineFunction(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 8) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"DIBuilder scope name linkName file line subroutineType");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    DIScope *scope;
    if (GetMetadataFromObj(interp, objv[2], "scope", scope) != TCL_OK)
	return TCL_ERROR;
    std::string name = Tcl_GetString(objv[3]);
    std::string linkName = Tcl_GetString(objv[4]);
    DIFile *file;
    if (GetMetadataFromObj(interp, objv[5], "file", file) != TCL_OK)
	return TCL_ERROR;
    int line;
    if (Tcl_GetIntFromObj(interp, objv[6], &line) != TCL_OK)
	return TCL_ERROR;
    DISubroutineType *type;
    if (GetMetadataFromObj(interp, objv[7], "subroutine type", type) != TCL_OK)
	return TCL_ERROR;
    unsigned flags = 0;
    bool isOpt = true, isLocal = true, isDef = true;

    auto val = builder->createFunction(scope, name, linkName, file, line,
	    type, isLocal, isDef, line, flags, isOpt);

    Tcl_SetObjResult(interp, NewMetadataObj(val, "Function"));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * BuildDbgValue --
 *
 *	Creates a call to llvm.dbc.value and adds it the given basic block.
 *
 * ----------------------------------------------------------------------
 */

int
BuildDbgValue(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 6) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"dibuilder builder value location variableInfo");
	return TCL_ERROR;
    }

    DIBuilder *builder;
    if (GetDIBuilderFromObj(interp, objv[1], builder) != TCL_OK)
	return TCL_ERROR;
    IRBuilder<> *b;
    if (GetBuilderFromObj(interp, objv[2], b) != TCL_OK)
        return TCL_ERROR;
    Value *val;
    if (GetValueFromObj(interp, objv[3], val) != TCL_OK)
	return TCL_ERROR;
    DILocation *location;
    if (GetMetadataFromObj(interp, objv[4], "location", location) != TCL_OK)
	return TCL_ERROR;
    DILocalVariable *varInfo;
    if (GetMetadataFromObj(interp, objv[5], "variable", varInfo) != TCL_OK)
	return TCL_ERROR;

    auto expr = builder->createExpression(); // Dummy

    auto inst = builder->insertDbgValueIntrinsic(val, 0, varInfo, expr,
	    location, b->GetInsertBlock());

    Tcl_SetObjResult(interp, NewValueObj(inst));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * ClearFunctionVariables --
 *
 *	Removes the temporary metadata associated with a function's variables.
 *	This is critical because otherwise the validation of the module fails.
 *
 * ----------------------------------------------------------------------
 */

int
ReplaceFunctionVariables(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "function variable...");
	return TCL_ERROR;
    }

    DISubprogram *function;
    if (GetMetadataFromObj(interp, objv[1], "function", function) != TCL_OK)
	return TCL_ERROR;
    std::vector<Metadata*> variables;
    for (int i=2 ; i<objc ; i++) {
	DILocalVariable *var;
	if (GetMetadataFromObj(interp, objv[i], "variable", var) != TCL_OK)
	    return TCL_ERROR;
	variables.push_back(var);
    }

    auto vars = function->getVariables();
    if (!vars->isTemporary()) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"can only replace variable list when temporary", -1));
	return TCL_ERROR;
    }

    vars->replaceAllUsesWith(MDNode::get(vars->getContext(), variables));
    function->resolveCycles();
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * AttachToFunction --
 *
 *	Attaches a function definition to a function implementation.
 *
 * ----------------------------------------------------------------------
 */

int
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

    Function *value;
    if (GetValueFromObj(interp, objv[1],
	    "can only attach debug metadata to functions", value) != TCL_OK)
	return TCL_ERROR;
    DISubprogram *metadata;
    if (GetMetadataFromObj(interp, objv[2], "function", metadata) != TCL_OK)
	return TCL_ERROR;

    value->setMetadata("dbg", metadata);

    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * SetInstructionLocation --
 *
 *	Attaches location metadata to an instruction.
 *
 * ----------------------------------------------------------------------
 */

int
SetInstructionLocation(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "instruction location");
	return TCL_ERROR;
    }

    Value *value;
    if (GetValueFromObj(interp, objv[1], value) != TCL_OK)
	return TCL_ERROR;
    auto instr = dyn_cast<Instruction>(value);
    if (instr == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"can only set locations of instructions", -1));
	return TCL_ERROR;
    }
    DILocation *location;
    if (GetMetadataFromObj(interp, objv[2], "location", location) != TCL_OK)
	return TCL_ERROR;

    instr->setDebugLoc(location);

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
