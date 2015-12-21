#include "tcl.h"
#include "tclTomMath.h"
#include <iostream>
#include <sstream>
#include <map>
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/TargetRegistry.h"
#include "llvm/Support/Host.h"
#if (LLVM_VERSION_MAJOR >=3 && LLVM_VERSION_MINOR >= 7)
#include "llvm/IR/PassManager.h"
#else
#include "llvm/PassManager.h"
#endif
#include "llvm/Transforms/IPO/PassManagerBuilder.h"
#include "llvm/Transforms/IPO.h"
#include "llvm/IR/DIBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/DerivedTypes.h"
//#include "llvm/Function.h"
#include "llvm/Support/DynamicLibrary.h"
#include "llvm/ExecutionEngine/ExecutionEngine.h"
#include "llvm/ExecutionEngine/GenericValue.h"
#include "llvm/ExecutionEngine/SectionMemoryManager.h"
#include "llvm-c/Analysis.h"
#include "llvm-c/Core.h"
#include "llvm-c/ExecutionEngine.h"
#include "llvm-c/Target.h"
#include "llvm-c/BitWriter.h"
#include "llvm-c/BitReader.h"
#include "llvm-c/Transforms/PassManagerBuilder.h"
#include "llvm-c/Transforms/IPO.h"
#include "llvm-c/Transforms/Scalar.h"
#include "llvm-c/Transforms/Vectorize.h"

#define DECL_CMD(cName) \
    extern int cName(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
DECL_CMD(DefineCompileUnit);
DECL_CMD(DefineFile);
DECL_CMD(DefineNamespace);
DECL_CMD(DefineUnspecifiedType);
DECL_CMD(DefineBasicType);
DECL_CMD(DefinePointerType);
DECL_CMD(DefineStructType);
DECL_CMD(DefineFunctionType);
DECL_CMD(DefineFunction);
DECL_CMD(AttachToFunction);
DECL_CMD(LLVMAddLLVMTclCommandsObjCmd);

TCL_DECLARE_MUTEX(idLock)
std::string GetRefName(std::string prefix)
{
    static volatile int LLVMRef_id = 0;
    int id;
    Tcl_MutexLock(&idLock);
    id = LLVMRef_id++;
    Tcl_MutexUnlock(&idLock);
    std::ostringstream os;
    os << prefix << id;
    return os.str();
}

#include "llvmtcl-gen-map.c"

static const char *const intrinsicNames[] = {
#define GET_INTRINSIC_NAME_TABLE
#include "llvm/IR/Intrinsics.gen"
#undef GET_INTRINSIC_NAME_TABLE
};

static std::string
LLVMDumpModuleTcl(
    LLVMModuleRef moduleRef)
{
    std::string s;
    llvm::raw_string_ostream os(s);
    os << *(reinterpret_cast<llvm::Module*>(moduleRef));
    return s;
}

static std::string
LLVMPrintModuleToStringTcl(
    LLVMModuleRef moduleRef)
{
    char *p = LLVMPrintModuleToString(moduleRef);
    std::string s = p;
    LLVMDisposeMessage(p);
    return s;
}

static std::string
LLVMPrintTypeToStringTcl(
    LLVMTypeRef typeRef)
{
    char *p = LLVMPrintTypeToString(typeRef);
    std::string s = p;
    LLVMDisposeMessage(p);
    return s;
}

static std::string
LLVMPrintValueToStringTcl(
    LLVMValueRef valueRef)
{
    char *p = LLVMPrintValueToString(valueRef);
    std::string s = p;
    LLVMDisposeMessage(p);
    return s;
}

static LLVMGenericValueRef
LLVMRunFunction(
    LLVMExecutionEngineRef EE,
    LLVMValueRef F,
    LLVMGenericValueRef *Args,
    unsigned NumArgs)
{
    return LLVMRunFunction(EE, F, NumArgs, Args);
}

MODULE_SCOPE int
GetModuleFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *obj,
    llvm::Module *&module)
{
    LLVMModuleRef modref;
    if (GetLLVMModuleRefFromObj(interp, obj, modref) != TCL_OK)
	return TCL_ERROR;
    module = llvm::unwrap(modref);
    return TCL_OK;
}

MODULE_SCOPE int
GetValueFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *obj,
    llvm::Value *&value)
{
    LLVMValueRef valref;
    if (GetLLVMValueRefFromObj(interp, obj, valref) != TCL_OK)
	return TCL_ERROR;
    value = llvm::unwrap(valref);
    return TCL_OK;
}

MODULE_SCOPE int
GetEngineFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *obj,
    llvm::ExecutionEngine *&engine)
{
    LLVMExecutionEngineRef eeref;
    if (GetLLVMExecutionEngineRefFromObj(interp, obj, eeref) != TCL_OK)
	return TCL_ERROR;
    engine = llvm::unwrap(eeref);
    return TCL_OK;
}

static int search(const void *p1, const void *p2) {
  const char *s1 = (const char *) p1;
  const char *s2 = *(const char **) p2;
  return strcmp(s1, s2);
}

static int
GetLLVMIntrinsicIDFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *obj,
    llvm::Intrinsic::ID &id)
{
    const char *str = Tcl_GetString(obj);
    void *ptr = bsearch(str, (const void *) intrinsicNames,
	    sizeof(intrinsicNames)/sizeof(const char *),
	    sizeof(const char *), search);

    if (ptr == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"expected LLVMIntrinsic but got \"%s\"", str));
	return TCL_ERROR;
    }

    id = (llvm::Intrinsic::ID)((((const char**) ptr) - intrinsicNames) + 1);
    return TCL_OK;
}

static Tcl_Obj *
SetLLVMIntrinsicIDAsObj(
    unsigned id)
{
    if (id <= 0 || id > sizeof(intrinsicNames)/sizeof(const char *)) {
	return Tcl_NewStringObj("<unknown LLVMIntrinsic>", -1);
    }

    std::string s = intrinsicNames[id-1];
    return Tcl_NewStringObj(s.c_str(), -1);
}

static void
LLVMDisposeBuilderTcl(
    LLVMBuilderRef builderRef)
{
    LLVMDisposeBuilder(builderRef);
    LLVMBuilderRef_map.erase(LLVMBuilderRef_refmap[builderRef]);
    LLVMBuilderRef_refmap.erase(builderRef);
}

static void
LLVMDisposeModuleTcl(
    LLVMModuleRef moduleRef)
{
    LLVMDisposeModule(moduleRef);
    LLVMModuleRef_map.erase(LLVMModuleRef_refmap[moduleRef]);
    LLVMModuleRef_refmap.erase(moduleRef);
}

static void
LLVMDisposePassManagerTcl(
    LLVMPassManagerRef passManagerRef)
{
    LLVMDisposePassManager(passManagerRef);
    LLVMPassManagerRef_map.erase(LLVMPassManagerRef_refmap[passManagerRef]);
    LLVMPassManagerRef_refmap.erase(passManagerRef);
}

static int
LLVMDeleteFunctionTcl(
    LLVMValueRef functionRef)
{
    LLVMDeleteFunction(functionRef);
    LLVMValueRef_map.erase(LLVMValueRef_refmap[functionRef]);
    LLVMValueRef_refmap.erase(functionRef);
    return TCL_OK;
}

static void
LLVMDeleteBasicBlockTcl(
    LLVMBasicBlockRef basicBlockRef)
{
    LLVMDeleteBasicBlock(basicBlockRef);
    LLVMBasicBlockRef_map.erase( LLVMBasicBlockRef_refmap[basicBlockRef]);
    LLVMBasicBlockRef_refmap.erase(basicBlockRef);
}

static int
LLVMCreateGenericValueOfTclInterpObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, "");
        return TCL_ERROR;
    }

    LLVMGenericValueRef rt = LLVMCreateGenericValueOfPointer(interp);
    Tcl_SetObjResult(interp, SetLLVMGenericValueRefAsObj(interp, rt));
    return TCL_OK;
}

static int
LLVMCreateGenericValueOfTclObjObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "val");
        return TCL_ERROR;
    }

    Tcl_IncrRefCount(objv[1]);
    LLVMGenericValueRef rt = LLVMCreateGenericValueOfPointer(objv[1]);
    Tcl_SetObjResult(interp, SetLLVMGenericValueRefAsObj(interp, rt));
    return TCL_OK;
}

static int
LLVMGenericValueToTclObjObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "GenVal");
        return TCL_ERROR;
    }

    LLVMGenericValueRef arg1 = 0;
    if (GetLLVMGenericValueRefFromObj(interp, objv[1], arg1) != TCL_OK)
        return TCL_ERROR;

    Tcl_Obj *rt = (Tcl_Obj *) LLVMGenericValueToPointer(arg1);
    Tcl_SetObjResult(interp, rt);
    return TCL_OK;
}

static int
LLVMAddIncomingObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 4) {
        Tcl_WrongNumArgs(interp, 1, objv,
		"PhiNode IncomingValuesList IncomingBlocksList");
        return TCL_ERROR;
    }

    LLVMValueRef phiNode = 0;
    if (GetLLVMValueRefFromObj(interp, objv[1], phiNode) != TCL_OK)
        return TCL_ERROR;

    int ivobjc = 0;
    Tcl_Obj **ivobjv = 0;
    if (Tcl_ListObjGetElements(interp, objv[2], &ivobjc, &ivobjv) != TCL_OK) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"IncomingValuesList not specified as list", -1));
	return TCL_ERROR;
    }

    int ibobjc = 0;
    Tcl_Obj **ibobjv = 0;
    if (Tcl_ListObjGetElements(interp, objv[3], &ibobjc, &ibobjv) != TCL_OK) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"IncomingBlocksList not specified as list", -1));
	return TCL_ERROR;
    }

    if (ivobjc != ibobjc) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"IncomingValuesList and IncomingBlocksList have different length", -1));
	return TCL_ERROR;
    }

    std::vector<LLVMValueRef> incomingValues(ivobjc);
    std::vector<LLVMBasicBlockRef> incomingBlocks(ivobjc);

    for(int i = 0; i < ivobjc; i++) {
	if (GetLLVMValueRefFromObj(interp, ivobjv[i],
		incomingValues[i]) != TCL_OK)
	    return TCL_ERROR;
	if (GetLLVMBasicBlockRefFromObj(interp, ibobjv[i],
		incomingBlocks[i]) != TCL_OK)
	    return TCL_ERROR;
    }
    LLVMAddIncoming(phiNode, incomingValues.data(), incomingBlocks.data(),
	    ivobjc);
    return TCL_OK;
}

static int
LLVMBuildAggregateRetObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "BuilderRef RetValsList");
        return TCL_ERROR;
    }

    LLVMBuilderRef builder = 0;
    if (GetLLVMBuilderRefFromObj(interp, objv[1], builder) != TCL_OK)
        return TCL_ERROR;

    int rvobjc = 0;
    Tcl_Obj **rvobjv = 0;
    if (Tcl_ListObjGetElements(interp, objv[2], &rvobjc, &rvobjv) != TCL_OK) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"RetValsList not specified as list", -1));
	return TCL_ERROR;
    }

    std::vector<LLVMValueRef> returnValues(rvobjc);
    for(int i = 0; i < rvobjc; i++)
	if (GetLLVMValueRefFromObj(interp, rvobjv[i],
		returnValues[i]) != TCL_OK)
	    return TCL_ERROR;

    LLVMValueRef rt = LLVMBuildAggregateRet(builder, returnValues.data(),
	    rvobjc);

    Tcl_SetObjResult(interp, SetLLVMValueRefAsObj(interp, rt));
    return TCL_OK;
}

static int
LLVMBuildInvokeObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 7) {
        Tcl_WrongNumArgs(interp, 1, objv,
		"BuilderRef Fn ArgsList ThenBlock CatchBlock Name");
        return TCL_ERROR;
    }

    LLVMBuilderRef builder = 0;
    if (GetLLVMBuilderRefFromObj(interp, objv[1], builder) != TCL_OK)
        return TCL_ERROR;

    LLVMValueRef fn = 0;
    if (GetLLVMValueRefFromObj(interp, objv[2], fn) != TCL_OK)
        return TCL_ERROR;

    int aobjc = 0;
    Tcl_Obj **aobjv = 0;
    if (Tcl_ListObjGetElements(interp, objv[3], &aobjc, &aobjv) != TCL_OK) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"ArgsList not specified as list", -1));
	return TCL_ERROR;
    }

    LLVMBasicBlockRef thenBlock = 0;
    LLVMBasicBlockRef catchBlock = 0;
    std::string name = Tcl_GetStringFromObj(objv[6], 0);

    std::vector<LLVMValueRef> args(aobjc);
    for(int i = 0; i < aobjc; i++) {
	if (GetLLVMValueRefFromObj(interp, aobjv[i], args[i]) != TCL_OK)
	    return TCL_ERROR;
    }

    if (GetLLVMBasicBlockRefFromObj(interp, objv[4], thenBlock) != TCL_OK)
        return TCL_ERROR;
    if (GetLLVMBasicBlockRefFromObj(interp, objv[5], catchBlock) != TCL_OK)
        return TCL_ERROR;

    LLVMValueRef rt = LLVMBuildInvoke(builder, fn, args.data(), aobjc,
	    thenBlock, catchBlock, name.c_str());

    Tcl_SetObjResult(interp, SetLLVMValueRefAsObj(interp, rt));
    return TCL_OK;
}

static int
LLVMGetParamTypesObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "FunctionTy ");
        return TCL_ERROR;
    }

    LLVMTypeRef functionType = 0;
    if (GetLLVMTypeRefFromObj(interp, objv[1], functionType) != TCL_OK)
        return TCL_ERROR;

    unsigned nargs = LLVMCountParamTypes(functionType);
    std::vector<LLVMTypeRef> paramType(nargs);

    LLVMGetParamTypes(functionType, paramType.data());

    Tcl_Obj *rtl = Tcl_NewListObj(0, NULL);
    for(unsigned i = 0; i < nargs; i++)
	Tcl_ListObjAppendElement(interp, rtl,
		SetLLVMTypeRefAsObj(interp, paramType[i]));

    Tcl_SetObjResult(interp, rtl);
    return TCL_OK;
}

static int
LLVMGetParamsObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "Function ");
        return TCL_ERROR;
    }

    LLVMValueRef function = 0;
    if (GetLLVMValueRefFromObj(interp, objv[1], function) != TCL_OK)
        return TCL_ERROR;

    unsigned nargs = LLVMCountParams(function);
    std::vector<LLVMValueRef> paramValue(nargs);

    LLVMGetParams(function, paramValue.data());

    Tcl_Obj *rtl = Tcl_NewListObj(0, NULL);
    for(unsigned i = 0; i < nargs; i++)
	Tcl_ListObjAppendElement(interp, rtl,
		SetLLVMValueRefAsObj(interp, paramValue[i]));

    Tcl_SetObjResult(interp, rtl);
    return TCL_OK;
}

static int
LLVMGetStructElementTypesObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "StructTy ");
        return TCL_ERROR;
    }

    LLVMTypeRef structType = 0;
    if (GetLLVMTypeRefFromObj(interp, objv[1], structType) != TCL_OK)
        return TCL_ERROR;

    unsigned nelem = LLVMCountStructElementTypes(structType);
    std::vector<LLVMTypeRef> elemType(nelem);

    LLVMGetStructElementTypes(structType, elemType.data());

    Tcl_Obj *rtl = Tcl_NewListObj(0, NULL);
    for(unsigned i = 0; i < nelem; i++)
	Tcl_ListObjAppendElement(interp, rtl,
		SetLLVMTypeRefAsObj(interp, elemType[i]));

    Tcl_SetObjResult(interp, rtl);
    return TCL_OK;
}

static int
LLVMGetBasicBlocksObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "Function ");
        return TCL_ERROR;
    }

    LLVMValueRef function = 0;
    if (GetLLVMValueRefFromObj(interp, objv[1], function) != TCL_OK)
        return TCL_ERROR;

    unsigned nblocks = LLVMCountBasicBlocks(function);
    std::vector<LLVMBasicBlockRef> basicBlock(nblocks);

    LLVMGetBasicBlocks(function, basicBlock.data());

    Tcl_Obj *rtl = Tcl_NewListObj(0, NULL);
    for(unsigned i = 0; i < nblocks; i++)
	Tcl_ListObjAppendElement(interp, rtl,
		SetLLVMBasicBlockRefAsObj(interp, basicBlock[i]));

    Tcl_SetObjResult(interp, rtl);
    return TCL_OK;
}

#include "llvmtcl-gen.c"

static int
LLVMCallInitialisePackageFunction(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "EE F");
	return TCL_ERROR;
    }

    LLVMExecutionEngineRef engine;
    if (GetLLVMExecutionEngineRefFromObj(interp, objv[1], engine) != TCL_OK)
	return TCL_ERROR;
    LLVMValueRef func;
    if (GetLLVMValueRefFromObj(interp, objv[2], func) != TCL_OK)
	return TCL_ERROR;

    uint64_t address = llvm::unwrap(engine)->getFunctionAddress(
	    llvm::unwrap<llvm::Function>(func)->getName().str());

    int (*initFunction)(Tcl_Interp*) = (int(*)(Tcl_Interp*)) address;
    if (initFunction == NULL) {
	Tcl_AppendResult(interp, "no address for initialiser", NULL);
	return TCL_ERROR;
    }

    return initFunction(interp);
}

static int
LLVMGetIntrinsicDefinitionObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "M Name Ty...");
        return TCL_ERROR;
    }

    LLVMModuleRef mod = 0;
    if (GetLLVMModuleRefFromObj(interp, objv[1], mod) != TCL_OK)
        return TCL_ERROR;

    llvm::Intrinsic::ID id;
    if (GetLLVMIntrinsicIDFromObj(interp, objv[2], id) != TCL_OK)
        return TCL_ERROR;

    std::vector<llvm::Type *> arg_types;
    for (int i=3 ; i<objc ; i++) {
	LLVMTypeRef ty = 0;
	if (GetLLVMTypeRefFromObj(interp, objv[i], ty) != TCL_OK)
	    return TCL_ERROR;
	arg_types.push_back(llvm::unwrap(ty));
    }

    LLVMValueRef intrinsic = llvm::wrap(llvm::Intrinsic::getDeclaration(
	    llvm::unwrap(mod), id, arg_types));

    if (intrinsic == NULL) {
	Tcl_AppendResult(interp, "no such intrinsic", NULL);
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, SetLLVMValueRefAsObj(interp, intrinsic));
    return TCL_OK;
}

static int
LLVMGetIntrinsicIDObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "Fn ");
        return TCL_ERROR;
    }

    LLVMValueRef intrinsic = 0;
    if (GetLLVMValueRefFromObj(interp, objv[1], intrinsic) != TCL_OK)
        return TCL_ERROR;

    unsigned id = LLVMGetIntrinsicID(intrinsic);

    if (id != 0)
	Tcl_SetObjResult(interp, SetLLVMIntrinsicIDAsObj(id));
    return TCL_OK;
}

static int
NamedStructTypeObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "Name ElementTypes Packed");
        return TCL_ERROR;
    }

    std::string name = Tcl_GetString(objv[1]);
    int numTypes = 0;
    LLVMTypeRef *types = 0;
    if (GetListOfLLVMTypeRefFromObj(interp, objv[2], types,
	    numTypes) != TCL_OK)
        return TCL_ERROR;
    if (numTypes < 1) {
	Tcl_AppendResult(interp, "must supply at least one member", NULL);
	return TCL_ERROR;
    }

    llvm::ArrayRef<llvm::Type*> elements(llvm::unwrap(types),
	    (unsigned) numTypes);

    int packed = 0;
    if (Tcl_GetIntFromObj(interp, objv[3], &packed) != TCL_OK)
        return TCL_ERROR;

    LLVMTypeRef rt = llvm::wrap(
	    llvm::StructType::create(elements, name, packed));

    Tcl_SetObjResult(interp, SetLLVMTypeRefAsObj(interp, rt));
    return TCL_OK;
}

static int
CreateMCJITCompilerForModuleObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2 && objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "M ?OptLevel? ");
        return TCL_ERROR;
    }

    LLVMModuleRef mod = 0;
    if (GetLLVMModuleRefFromObj(interp, objv[1], mod) != TCL_OK)
        return TCL_ERROR;
    int level = 0;
    if (objc == 3 && Tcl_GetIntFromObj(interp, objv[2], &level) != TCL_OK)
	return TCL_ERROR;

    LLVMMCJITCompilerOptions options;
    LLVMInitializeMCJITCompilerOptions(&options, sizeof(options));
    options.OptLevel = (unsigned) level;

    LLVMExecutionEngineRef eeRef = 0; // output argument (engine)
    char *error = 0; // output argument (error message)
    LLVMBool failed = LLVMCreateMCJITCompilerForModule(&eeRef, mod,
	    &options, sizeof(options), &error);

    if (failed) {
	//llvm::TargetRegistry::printRegisteredTargetsForVersion();
	Tcl_SetObjResult(interp, Tcl_NewStringObj(error, -1));
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, SetLLVMExecutionEngineRefAsObj(interp, eeRef));
    return TCL_OK;
}

static int
GetHostTripleObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, "");
	return TCL_ERROR;
    }
    auto triple = llvm::sys::getProcessTriple();
    Tcl_SetObjResult(interp, Tcl_NewStringObj(triple.c_str(), -1));
    return TCL_OK;
}

static int
InitAllTargetsObjCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, "");
	return TCL_ERROR;
    }

    LLVMInitializeAllTargets();
    LLVMInitializeAllTargetMCs();
    LLVMInitializeAllAsmPrinters();
    LLVMInitializeAllAsmParsers();
    return TCL_OK;
}

static int
CreateModuleFromBitcodeCmd(
    ClientData clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "Filename");
	return TCL_ERROR;
    }

    char *msg;
    LLVMMemoryBufferRef buffer;
    if (LLVMCreateMemoryBufferWithContentsOfFile(Tcl_GetString(objv[1]),
	    &buffer, &msg))
	goto error;
    LLVMModuleRef module;
    if (LLVMParseBitcode(buffer, &module, &msg)) {
	LLVMDisposeMemoryBuffer(buffer);
	goto error;
    }
    LLVMDisposeMemoryBuffer(buffer);
    Tcl_SetObjResult(interp, SetLLVMModuleRefAsObj(NULL, module));
    return TCL_OK;

  error:
    Tcl_SetResult(interp, msg, TCL_VOLATILE);
    free(msg);
    return TCL_ERROR;
}

#define LLVMObjCmd(tclName, cName) \
  Tcl_CreateObjCommand(interp, tclName, (Tcl_ObjCmdProc*)cName, (ClientData)NULL, (Tcl_CmdDeleteProc*)NULL);

extern "C" {
DLLEXPORT int Llvmtcl_Init(Tcl_Interp *interp)
{
    if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_TomMath_InitStubs(interp, TCL_VERSION) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_PkgRequire(interp, "Tcl", TCL_VERSION, 0) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION) != TCL_OK) {
	return TCL_ERROR;
    }
#include "llvmtcl-gen-cmddef.c"
    LLVMObjCmd("llvmtcl::CreateGenericValueOfTclInterp", LLVMCreateGenericValueOfTclInterpObjCmd);
    LLVMObjCmd("llvmtcl::CreateGenericValueOfTclObj", LLVMCreateGenericValueOfTclObjObjCmd);
    LLVMObjCmd("llvmtcl::GenericValueToTclObj", LLVMGenericValueToTclObjObjCmd);
    LLVMObjCmd("llvmtcl::AddLLVMTclCommands", LLVMAddLLVMTclCommandsObjCmd);
    LLVMObjCmd("llvmtcl::AddIncoming", LLVMAddIncomingObjCmd);
    LLVMObjCmd("llvmtcl::BuildAggregateRet", LLVMBuildAggregateRetObjCmd);
    LLVMObjCmd("llvmtcl::BuildInvoke", LLVMBuildInvokeObjCmd);
    LLVMObjCmd("llvmtcl::GetParamTypes", LLVMGetParamTypesObjCmd);
    LLVMObjCmd("llvmtcl::GetParams", LLVMGetParamsObjCmd);
    LLVMObjCmd("llvmtcl::GetStructElementTypes", LLVMGetStructElementTypesObjCmd);
    LLVMObjCmd("llvmtcl::GetBasicBlocks", LLVMGetBasicBlocksObjCmd);
    LLVMObjCmd("llvmtcl::CallInitialisePackageFunction", LLVMCallInitialisePackageFunction);
    LLVMObjCmd("llvmtcl::GetIntrinsicDefinition",
	    LLVMGetIntrinsicDefinitionObjCmd);
    LLVMObjCmd("llvmtcl::GetIntrinsicID", LLVMGetIntrinsicIDObjCmd);
    LLVMObjCmd("llvmtcl::NamedStructType", NamedStructTypeObjCmd);
    LLVMObjCmd("llvmtcl::CreateMCJITCompilerForModule",
	    CreateMCJITCompilerForModuleObjCmd);
    LLVMObjCmd("llvmtcl::InitializeAllTargets", InitAllTargetsObjCmd);
    LLVMObjCmd("llvmtcl::GetHostTriple", GetHostTripleObjCmd);
    LLVMObjCmd("llvmtcl::CreateModuleFromBitcode", CreateModuleFromBitcodeCmd);
    // Debugging info support
    LLVMObjCmd("llvmtcl::DebugInfo::CompileUnit", DefineCompileUnit);
    LLVMObjCmd("llvmtcl::DebugInfo::File", DefineFile);
    LLVMObjCmd("llvmtcl::DebugInfo::Namespace", DefineNamespace);
    LLVMObjCmd("llvmtcl::DebugInfo::UnspecifiedType", DefineUnspecifiedType);
    LLVMObjCmd("llvmtcl::DebugInfo::BasicType", DefineBasicType);
    LLVMObjCmd("llvmtcl::DebugInfo::PointerType", DefinePointerType);
    LLVMObjCmd("llvmtcl::DebugInfo::StructType", DefineStructType);
    LLVMObjCmd("llvmtcl::DebugInfo::FunctionType", DefineFunctionType);
    LLVMObjCmd("llvmtcl::DebugInfo::Function", DefineFunction);
    LLVMObjCmd("llvmtcl::DebugInfo::AttachToFunction", AttachToFunction);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * Llvmtcl_StandardInput, Llvmtcl_StandardOutput, Llvmtcl_StandardError --
 *
 *	Helper functions to make it easier to get the standard stdio streams
 *	for debugging purposes. Since these "variables" are typically macros
 *	that are defined in platform-specific ways, we need these small
 *	functions to hide the details.
 *
 * Returns:
 *	Relevant stdio FILE* handle.
 *
 * Side effects:
 *	None.
 *
 * ----------------------------------------------------------------------
 */

DLLEXPORT FILE * Llvmtcl_StandardInput() {
    return stdin;
}

DLLEXPORT FILE * Llvmtcl_StandardOutput() {
    return stdout;
}

DLLEXPORT FILE * Llvmtcl_StandardError() {
    return stderr;
}

} /* extern "C" */

/*
 * Local Variables:
 * mode: c++
 * c-basic-offset: 4
 * fill-column: 78
 * tab-width: 8
 * End:
 */
