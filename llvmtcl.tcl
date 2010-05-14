namespace eval llvmtcl {
    namespace export *

    proc LLVMOptimizeModule {m} {
	set pm [LLVMCreatePassManager]
	
	LLVMAddAggressiveDCEPass $pm
	LLVMAddCFGSimplificationPass $pm
	LLVMAddDeadStoreEliminationPass $pm
	LLVMAddGVNPass $pm
	LLVMAddIndVarSimplifyPass $pm
	LLVMAddInstructionCombiningPass $pm
	LLVMAddJumpThreadingPass $pm
	LLVMAddLICMPass $pm
	LLVMAddLoopDeletionPass $pm
	LLVMAddLoopIndexSplitPass $pm
	LLVMAddLoopRotatePass $pm
	LLVMAddLoopUnrollPass $pm
	LLVMAddLoopUnswitchPass $pm
	LLVMAddMemCpyOptPass $pm
	LLVMAddPromoteMemoryToRegisterPass $pm
	LLVMAddReassociatePass $pm
	LLVMAddSCCPPass $pm
	LLVMAddScalarReplAggregatesPass $pm
	LLVMAddSimplifyLibCallsPass $pm
	LLVMAddTailCallEliminationPass $pm
	LLVMAddConstantPropagationPass $pm
	LLVMAddDemoteMemoryToRegisterPass $pm
	
	LLVMAddArgumentPromotionPass $pm
	LLVMAddConstantMergePass $pm
	LLVMAddDeadArgEliminationPass $pm
	LLVMAddDeadTypeEliminationPass $pm
	LLVMAddFunctionAttrsPass $pm
	LLVMAddFunctionInliningPass $pm
	LLVMAddGlobalDCEPass $pm
	LLVMAddGlobalOptimizerPass $pm
	LLVMAddIPConstantPropagationPass $pm
	LLVMAddLowerSetJmpPass $pm
	LLVMAddPruneEHPass $pm
	LLVMAddStripDeadPrototypesPass $pm
	LLVMAddStripSymbolsPass $pm
	
	LLVMRunPassManager $pm $m
	LLVMDisposePassManager $pm
    }
}
