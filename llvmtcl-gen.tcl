proc gen_api_call {cf of l} {
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
	    } elseif {[set idx [string last "*" $farg]] >= 0} {
		set fargtype [string range [split $farg] 0 $idx]
		set fargname [string range [split $farg] [expr {$idx+1}] end]
	    } else {
		set fargtype [lrange [split $farg] 0 end-1]
		set fargname [lindex [split $farg] end]
	    }
	    lappend fargsl $fargtype $fargname
	}
    }
    # Group types
    set pointer_types {"LLVMValueRef *" "LLVMTypeRef *" "LLVMGenericValueRef *"}
    # Check number of arguments
    set n 1
    set an 1
    set skip_next 0
    foreach {fargtype fargname} $fargsl {
	if {[string match "Out*" $fargname]} {
	} else {
	    if {$skip_next} {
		set skip_next 0
	    } else {
		if {$fargtype in $pointer_types} {
		    if {[lindex $fargsl [expr {$n*2}]] eq "unsigned"} {
			set skip_next 1
		    } else {
			error "Unknown type '$fargtype' in '$l'"
		    }
		}
		incr an
	    }
	}
	incr n
    }
    puts $cf "    if (objc != $an) \{"
    puts -nonewline $cf "        Tcl_WrongNumArgs(interp, 1, objv, \""
    set n 1
    set skip_next 0
    foreach {fargtype fargname} $fargsl {
	if {[string match "Out*" $fargname]} {
	} else {
	    if {$skip_next} {
		set skip_next 0
	    } else {
		if {$fargtype in $pointer_types} {
		    if {[lindex $fargsl [expr {$n*2}]] eq "unsigned"} {
			if {[string length $fargname]} {
			    puts -nonewline $cf "$fargname " 
			} else {
			    puts -nonewline $cf "$fargtype " 
			}
			set skip_next 1
		    } else {
			error "Unknown type '$fargtype' in '$l'"
		    }
		} else {
		    if {[string length $fargname]} {
			puts -nonewline $cf "$fargname " 
		    } else {
			puts -nonewline $cf "$fargtype " 
		    }
		}
	    }
	}
	incr n
    }
    puts $cf "\");"
    puts $cf "        return TCL_ERROR;"
    puts $cf "    \}"
    # Read arguments
    set n 1
    set on 1
    set skip_next 0
    set delete_args {}
    set out_args {}
    foreach {fargtype fargname} $fargsl {
	if {[string match "Out*" $fargname]} {
	    lappend out_args arg$n $fargtype
	    switch -exact -- $fargtype {
		"LLVMExecutionEngineRef *" {
		    puts $cf "    [string trim $fargtype { *}] arg$n = 0; // output argument"
		}
		"char **" {
		    puts $cf "    char* arg$n = 0;"
		}
		default {
		    error "Unknown type '$fargtype' in '$l'"
		}
	    }
	} else {
	    if {$skip_next} {
		set skip_next 0
	    } else {
		switch -exact -- $fargtype {
		    "LLVMExecutionEngineRef" -
		    "LLVMBuilderRef" -
		    "LLVMContextRef" -
		    "LLVMGenericValueRef" -
		    "LLVMValueRef" -
		    "LLVMBasicBlockRef" -
		    "LLVMTypeHandleRef" -
		    "LLVMTypeRef" -
		    "LLVMUseRef" -
		    "LLVMPassManagerRef" -
		    "LLVMModuleRef" {
			puts $cf "    $fargtype arg$n = 0;"
			puts $cf "    if (Get${fargtype}FromObj(interp, objv\[$on\], arg$n) != TCL_OK)"
			puts $cf "        return TCL_ERROR;"
		    }
		    "LLVMTypeKind" -
		    "LLVMOpcode" -
		    "LLVMVisibility" -
		    "LLVMCallConv" -
		    "LLVMIntPredicate" -
		    "LLVMRealPredicate" -
		    "LLVMLinkage" -
		    "LLVMAttribute" {
			puts $cf "    $fargtype arg$n;"
			puts $cf "    if (Get${fargtype}FromObj(interp, objv\[$on\], arg$n) != TCL_OK)"
			puts $cf "        return TCL_ERROR;"
		    }
		    "LLVMGenericValueRef *" -
		    "LLVMValueRef *" -
		    "LLVMTypeRef *" {
			if {[lindex $fargsl [expr {$n*2}]] eq "unsigned"} {
			    puts $cf "    int iarg[expr {$n+1}] = 0;"
			    puts $cf "    $fargtype arg$n = 0;"
			    puts $cf "    if (GetListOf[string trim $fargtype { *}]FromObj(interp, objv\[$on\], arg$n, iarg[expr {$n+1}]) != TCL_OK)"
			    puts $cf "        return TCL_ERROR;"
			    puts $cf "    unsigned arg[expr {$n+1}] = (unsigned)iarg[expr {$n+1}];"
			    set skip_next 1
			    lappend delete_args $n
			} else {
			    error "Unknown type '$fargtype' in '$l'"
			}
		    }
		    "std::string" -
		    "const char *" {
			puts $cf "    std::string arg$n = Tcl_GetStringFromObj(objv\[$on\], 0);"
		    }
		    "LLVMBool" -
		    "bool" -
		    "int" {
			puts $cf "    int arg$n = 0;"
			puts $cf "    if (Tcl_GetIntFromObj(interp, objv\[$on\], &arg$n) != TCL_OK)"
			puts $cf "        return TCL_ERROR;"
		    }
		    "uint8_t" -
		    "unsigned" {
			puts $cf "    int iarg$n = 0;"
			puts $cf "    if (Tcl_GetIntFromObj(interp, objv\[$on\], &iarg$n) != TCL_OK)"
			puts $cf "        return TCL_ERROR;"
			puts $cf "    $fargtype arg$n = ($fargtype)iarg$n;"
		    }
		    "long long" {
			puts $cf "    long long arg$n = 0;"
			puts $cf "    if (Tcl_GetWideIntFromObj(interp, objv\[$on\], &arg$n) != TCL_OK)"
			puts $cf "        return TCL_ERROR;"
		    }
		    "unsigned long long" {
			puts $cf "    long long iarg$n = 0;"
			puts $cf "    if (Tcl_GetWideIntFromObj(interp, objv\[$on\], &iarg$n) != TCL_OK)"
			puts $cf "        return TCL_ERROR;"
			puts $cf "    unsigned long long arg$n = (unsigned long long)iarg$n;"
		    }
		    "double" {
			puts $cf "    double arg$n = 0;"
			puts $cf "    if (Tcl_GetDoubleFromObj(interp, objv\[$on\], &arg$n) != TCL_OK)"
			puts $cf "        return TCL_ERROR;"
		    }
		    "void" {
		    }
		    default {
			error "Unknown type '$fargtype' in '$l'"
		    }
		}
		incr on
	    }
	}
	incr n
    }
    # Variable for return value
    puts -nonewline $cf "    "
    switch -exact -- $rt {
	"LLVMBuilderRef" -
	"LLVMBasicBlockRef" -
	"LLVMValueRef" -
	"LLVMContextRef" -
	"LLVMTypeKind" -
	"LLVMVisibility" -
	"LLVMCallConv" -
	"LLVMOpcode" -
	"LLVMLinkage" -
	"LLVMIntPredicate" -
	"LLVMRealPredicate" -
	"LLVMAttribute" -
	"LLVMTypeHandleRef" -
	"LLVMTypeRef" -
	"LLVMBool" -
	"bool" -
	"LLVMModuleRef" -
	"LLVMGenericValueRef" -
	"LLVMPassManagerRef" -
	"LLVMUseRef" -
	"int" -
	"long long" -
	"unsigned" -
	"unsigned long long" -
	"std::string" {
	    puts -nonewline $cf "$rt rt = "
	}
	"void" {
	}
	default {
	    error "Unknown return type '$rt' in '$l'"
	}
    }
    # Call function
    if {[info exists ::rename($nm)]} {
	puts -nonewline $cf "$::rename($nm) ("
    } else {
	puts -nonewline $cf "$nm ("
    }
    set n 1
    foreach {fargtype fargname} $fargsl {
	if {$n > 1} {
	    puts -nonewline $cf ","
	}
	if {[string match "Out*" $fargname]} {
	    switch -exact -- $fargtype {
		"char **" -
		"LLVMExecutionEngineRef *" {
		    puts -nonewline $cf "&arg$n"
		}
		default {
		    error "Unknown type '$fargtype' in '$l'"
		}
	    }
	} else {
	    switch -exact -- $fargtype {
		"const char *" {
		    puts -nonewline $cf "arg$n.c_str()"
		}
		default {
		    puts -nonewline $cf "arg$n"
		}
	    }
	}
	incr n
    }
    puts $cf ");"
    # Return result
    if {[llength $out_args]} {
	puts $cf "    Tcl_Obj* rtl = Tcl_NewListObj(0, NULL);"
	foreach {rnm rtp} [list rt $rt {*}$out_args] {
	    switch -exact -- $rtp {
		"LLVMBuilderRef" -
		"LLVMContextRef" -
		"LLVMBasicBlockRef" -
		"LLVMValueRef" -
		"LLVMTypeKind" -
		"LLVMVisibility" -
		"LLVMCallConv" -
		"LLVMOpcode" -
		"LLVMLinkage" -
		"LLVMIntPredicate" -
		"LLVMRealPredicate" -
		"LLVMAttribute" -
		"LLVMTypeHandleRef" -
		"LLVMTypeRef" -
		"LLVMPassManagerRef" -
		"LLVMUseRef" -
		"LLVMGenericValueRef" -
		"LLVMModuleRef" {
		    puts $cf "    Tcl_ListObjAppendElement(interp, rtl, Set${rtp}AsObj(interp, $rnm));"
		}
		"LLVMExecutionEngineRef *" {
		    puts $cf "    Tcl_ListObjAppendElement(interp, rtl, Set[string trim $rtp { *}]AsObj(interp, $rnm));"
		}
		"char **" {
		    puts $cf "    Tcl_ListObjAppendElement(interp, rtl, Tcl_NewStringObj($rnm, -1));"
		}
		"LLVMBool" -
		"bool" -
		"int" -
		"unsigned" {
		    puts $cf "    Tcl_ListObjAppendElement(interp, rtl, Tcl_NewIntObj($rnm));"
		}
		"long long" -
		"unsigned long long" {
		    puts $cf "    Tcl_ListObjAppendElement(interp, rtl, Tcl_NewWideIntObj($rnm));"
		}
		"void" {
		}
		default {
		    error "Unknown return type '$rtp' for '$rnm' in '$l'"
		}
	    }
	}
	puts $cf "    Tcl_SetObjResult(interp, rtl);"
    } else {
	switch -exact -- $rt {
	    "LLVMBuilderRef" -
	    "LLVMContextRef" -
	    "LLVMBasicBlockRef" -
	    "LLVMValueRef" -
	    "LLVMTypeKind" -
	    "LLVMVisibility" -
	    "LLVMCallConv" -
	    "LLVMOpcode" -
	    "LLVMLinkage" -
	    "LLVMIntPredicate" -
	    "LLVMRealPredicate" -
	    "LLVMAttribute" -
	    "LLVMTypeHandleRef" -
	    "LLVMTypeRef" -
	    "LLVMPassManagerRef" -
	    "LLVMUseRef" -
	    "LLVMGenericValueRef" -
	    "LLVMModuleRef" {
		puts $cf "    Tcl_SetObjResult(interp, Set${rt}AsObj(interp, rt));"
	    }
	    "LLVMBool" -
	    "int" -
	    "bool" -
	    "unsigned" {
		puts $cf "    Tcl_SetObjResult(interp, Tcl_NewIntObj(rt));"
	    }
	    "long long" -
	    "unsigned long long" {
		puts $cf "    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(rt));"
	    }
	    "std::string" {
		puts $cf "    Tcl_SetObjResult(interp, Tcl_NewStringObj(rt.c_str(), -1));"
	    }
	    "void" {
	    }
	    default {
		error "Unknown return type '$rt' in '$l'"
	    }
	}
    }
    puts $cf "    return TCL_OK;"
    puts $cf "\}"
    puts $cf ""

    puts $of "    LLVMObjCmd(\"llvmtcl::$nm\", ${nm}ObjCmd);"
}

proc gen_enum {cf l} {
    set idx1 [string first \{ $l]
    set idx2 [string last \} $l]
    set vals [split [string trim [string range $l [expr {$idx1 + 1}] [expr {$idx2 - 1}]]] ,]
    set nm [string trim [string trim [string trim [string range $l [expr {$idx2+1}] end]] \;]]
    puts $cf "int Get${nm}FromObj(Tcl_Interp* interp, Tcl_Obj* obj, $nm& e) \{"
    puts $cf "    static std::map<std::string, $nm> s2e;"
    puts $cf "    if (s2e.size() == 0) \{"
    foreach val $vals {
	set val [string trim $val]
	puts $cf "        s2e\[\"$val\"\] = $val;"
    }
    puts $cf "    \}"
    puts $cf "    std::string s = Tcl_GetStringFromObj(obj, 0);"
    puts $cf "    if (s2e.find(s) == s2e.end()) \{"
    puts $cf "        std::ostringstream os;"
    puts $cf "        os << \"expected $nm but got '\" << s << \"'\";"
    puts $cf "        Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));"
    puts $cf "        return TCL_ERROR;"
    puts $cf "    \}"
    puts $cf "    e = s2e\[s\];"
    puts $cf "    return TCL_OK;"
    puts $cf "\}"
    puts $cf "Tcl_Obj* Set${nm}AsObj(Tcl_Interp* interp, $nm e) \{"
    puts $cf "    static std::map<$nm, std::string> e2s;"
    puts $cf "    if (e2s.size() == 0) \{"
    foreach val $vals {
	set val [string trim $val]
	puts $cf "        e2s\[$val\] = \"$val\";"
    }
    puts $cf "    \}"
    puts $cf "    std::string s;"
    puts $cf "    if (e2s.find(e) == e2s.end())"
    puts $cf "        s = \"<unknown $nm>\";"
    puts $cf "    else"
    puts $cf "        s = e2s\[e\];"
    puts $cf "    return Tcl_NewStringObj(s.c_str(), -1);"
    puts $cf "\}"
}

proc gen_map {mf l} {
    set tp [lindex [string trim $l] end]
    puts $mf "static std::map<std::string, $tp> ${tp}_map;"
    puts $mf "static std::map<$tp, std::string> ${tp}_refmap;"
    puts $mf "int Get${tp}FromObj(Tcl_Interp* interp, Tcl_Obj* obj, $tp& ref) \{"
    puts $mf "    ref = 0;"
    puts $mf "    std::string refName = Tcl_GetStringFromObj(obj, 0);"
    puts $mf "    if (${tp}_map.find(refName) == ${tp}_map.end()) \{"
    puts $mf "        std::ostringstream os;"
    puts $mf "        os << \"expected $tp but got '\" << refName << \"'\";"
    puts $mf "        Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));"
    puts $mf "        return TCL_ERROR;"
    puts $mf "    \}"
    puts $mf "    ref = ${tp}_map\[refName\];"
    puts $mf "    return TCL_OK;"
    puts $mf "\}"
    puts $mf "int GetListOf${tp}FromObj(Tcl_Interp* interp, Tcl_Obj* obj, $tp*& refs, int& count) \{"
    puts $mf "    refs = 0;"
    puts $mf "    count = 0;"
    puts $mf "    Tcl_Obj** objs = 0;"
    puts $mf "    if (Tcl_ListObjGetElements(interp, obj, &count, &objs) != TCL_OK) \{"
    puts $mf "        std::ostringstream os;"
    puts $mf "        os << \"expected list of types but got \\\"\" << Tcl_GetStringFromObj(obj, 0) << \"\\\"\";"
    puts $mf "        Tcl_SetObjResult(interp, Tcl_NewStringObj(os.str().c_str(), -1));"
    puts $mf "        return TCL_ERROR;"
    puts $mf "    \}"
    puts $mf "    if (count == 0)"
    puts $mf "        return TCL_OK;"
    puts $mf "    refs = new $tp\[count\];"
    puts $mf "    for(int i =0; i < count; i++) \{"
    puts $mf "        if (Get${tp}FromObj(interp, objs\[i\], refs\[i\])) \{"
    puts $mf "            delete [] refs;"
    puts $mf "            return TCL_ERROR;"
    puts $mf "        \}"
    puts $mf "    \}"
    puts $mf "    return TCL_OK;"
    puts $mf "\}"
    puts $mf "Tcl_Obj* Set${tp}AsObj(Tcl_Interp* interp, $tp ref) \{"
    puts $mf "    if (${tp}_refmap.find(ref) == ${tp}_refmap.end()) \{"
    puts $mf "        std::string nm = GetRefName(\"${tp}_\");"
    puts $mf "        ${tp}_map\[nm\] = ref;"
    puts $mf "        ${tp}_refmap\[ref\] = nm;"
    puts $mf "    \}"
    puts $mf "    return Tcl_NewStringObj(${tp}_refmap\[ref\].c_str(), -1);"
    puts $mf "\}"
}

set f [open llvmtcl-gen.inp r]
set ll [split [read $f] \n]
close $f

set cf [open llvmtcl-gen.cpp w]
set of [open llvmtcl-gen-cmddef.cpp w]
set mf [open llvmtcl-gen-map.cpp w]

foreach l $ll {
    set l [string trim $l]
    if {[llength $l] == 0} continue
    switch -glob -- $l {
	"//*" { continue }
	"rename *" { set rename([lindex $l 1]) [lindex $l 2] }
	"enum *" { gen_enum $cf $l }
	"typedef *" { gen_map $mf $l }
	default { gen_api_call $cf $of $l }
    }
}

close $cf
close $of
close $mf
