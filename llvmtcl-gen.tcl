set f [open llvmtcl-gen.inp r]
set ll [split [read $f] \n]
close $f

set cf [open llvmtcl-gen.cpp w]
set of [open llvmtcl-gen-cmddef.cpp w]

foreach l $ll {
    set l [string trim $l]
    if {[llength $l] == 0} continue
    if {[string match "//*" $l]} continue
    lassign [split $l (] rtnm fargs
    set rtnm [string trim $rtnm]
    set fargs [string trim $fargs]
    set rt [join [lrange [split $rtnm] 0 end-1] " "]
    set nm [lindex [split $rtnm] end]
    set fargs [string range $fargs 0 [expr {[string first ")" $fargs]-1}]]
# \
)
    puts $cf "int ${nm}ObjCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv\[\]) \{"
    set fargsl {}
    if {[string trim $fargs] ne "void"} {
	foreach farg [split $fargs ,] {
	    set farg [string trim $farg]
	    # Last part is name of argument, unless there is only one part.
	    if {[llength $farg] == 1} {
		set fargtype $farg
		set fargname ""
	    } else {
		set fargtype [lrange [split $farg] 0 end-1]
		set fargname [lindex [split $farg] end]
	    }
	    lappend fargsl $fargtype $fargname
	}
    }
    # Check number of arguments
    puts $cf "    if (objc != [expr {[llength $fargsl]/2+1}]) \{"
    puts -nonewline $cf "        Tcl_WrongNumArgs(interp, 1, objv, \""
    foreach {fargtype fargname} $fargsl {
	if {[string length $fargname]} {
	    puts -nonewline $cf "$fargname " 
	} else {
	    puts -nonewline $cf "$fargtype " 
	}
    }
    puts $cf "\");"
    puts $cf "        return TCL_ERROR;"
    puts $cf "    \}"
    # Read arguments
    set n 1
    foreach {fargtype fargname} $fargsl {
	switch -exact -- $fargtype {
	    "LLVMBuilderRef" {
		puts $cf "    LLVMBuilderRef arg$n = 0;"
		puts $cf "    if (GetLLVMBuilderRefFromObj(interp, objv\[$n\], arg$n) != TCL_OK)"
		puts $cf "        return TCL_ERROR;"
	    }
	    "LLVMValueRef" {
		puts $cf "    LLVMValueRef arg$n = 0;"
		puts $cf "    if (GetLLVMValueRefFromObj(interp, objv\[$n\], arg$n) != TCL_OK)"
		puts $cf "        return TCL_ERROR;"
	    }
	    "void" {
	    }
	    "LLVMBasicBlockRef" {
		puts $cf "    LLVMBasicBlockRef arg$n = 0;"
		puts $cf "    if (GetLLVMBasicBlockRefFromObj(interp, objv\[$n\], arg$n) != TCL_OK)"
		puts $cf "        return TCL_ERROR;"
	    }
	    "const char *" {
		puts $cf "    std::string arg$n = Tcl_GetStringFromObj(objv\[$n\], 0);"
	    }
	    "int" {
		puts $cf "    int arg$n = 0;"
		puts $cf "    if (Tcl_GetIntFromObj(interp, objv\[$n\], &arg$n) != TCL_OK)"
		puts $cf "        return TCL_ERROR;"
	    }
	    "unsigned" {
		puts $cf "    int iarg$n = 0;"
		puts $cf "    if (Tcl_GetIntFromObj(interp, objv\[$n\], &iarg$n) != TCL_OK)"
		puts $cf "        return TCL_ERROR;"
		puts $cf "    unsigned arg$n = (unsigned)iarg$n;"
	    }
	    "LLVMTypeRef" {
		puts $cf "    LLVMTypeRef arg$n = 0;"
		puts $cf "    if (GetLLVMTypeRefFromObj(interp, objv\[$n\], arg$n) != TCL_OK)"
		puts $cf "        return TCL_ERROR;"
	    }
	    default {
		error "Unknown type '$fargtype'"
	    }
	}
	incr n
    }
    # Variable for return value
    puts -nonewline $cf "    "
    switch -exact -- $rt {
	"LLVMBuilderRef" {
	    puts -nonewline $cf "LLVMBuilderRef rt = "
	}
	"void" {
	}
	"LLVMBasicBlockRef" {
	    puts -nonewline $cf "LLVMBasicBlockRef rt = "
	}
	"LLVMValueRef" {
	    puts -nonewline $cf "LLVMValueRef rt = "
	}
	default {
	    error "Unknown return type '$rt'"
	}
    }
    # Call function
    puts -nonewline $cf "$nm ("
    set n 1
    foreach {fargtype fargname} $fargsl {
	if {$n > 1} {
	    puts -nonewline $cf ","
	}
	switch -exact -- $fargtype {
	    "const char *" {
		puts -nonewline $cf "arg$n.c_str()"
	    }
	    default {
		puts -nonewline $cf "arg$n"
	    }
	}
	incr n
    }
    puts $cf ");"
    # Return result
    switch -exact -- $rt {
	"LLVMBuilderRef" {
	    puts $cf "    SetLLVMBuilderRefAsResultObj(interp, rt);"
	}
	"void" {
	}
	"LLVMBasicBlockRef" {
	    puts $cf "    SetLLVMBasicBlockRefAsResultObj(interp, rt);"
	}
	"LLVMValueRef" {
	    puts $cf "    SetLLVMValueRefAsResultObj(interp, rt);"
	}
	default {
	    error "Unknown return type '$rt'"
	}
    }
    puts $cf "    return TCL_OK;"
    puts $cf "\}"
    puts $cf ""

    puts $of "    LLVMObjCmd(\"llvmtcl::$nm\", ${nm}ObjCmd);"
}

close $cf
close $of
