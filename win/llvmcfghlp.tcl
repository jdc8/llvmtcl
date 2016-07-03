package require Tcl 8.6

set LLVMComponents {
    core engine codegen all-targets native bitwriter bitreader mcjit linker
    interpreter ipo
}

proc normalizelibs {libs} {
    set nl {}
    foreach lib $libs {
	if {[regexp {^-l(.*)$} $lib -> name]} {
	    set lib $name.lib
	}
	append nl "$lib "
    }
    return [string trimright $nl]
}

set llvmconfig [file join [lindex $argv 0] llvm-config.exe]
proc llvmconfig {option args} {
    global llvmconfig
    set c [open |[list $llvmconfig $option {*}$args] r]
    try {
	return [gets $c]
    } finally {
	catch {close $c}
    }
}

set cxxflags [llvmconfig --cxxflags]
set ldflags [llvmconfig --ldflags]
set libs [llvmconfig --libs {*}$LLVMComponents]
set syslibs [llvmconfig --system-libs {*}$LLVMComponents]

set outf [open llvmcfgmake.vc w]
puts $outf "LLVMCFLAGS = \\\n$cxxflags"
# -Llibfolder -> /libpath:libfolder
puts $outf "LLVMLFLAGS = \\\n[string map {-L /LIBPATH:} $ldflags]"
# -llibname -> libname.lib
puts $outf "LLVMLIBS = \\\n[normalizelibs $libs]"
# -llibname -> libname.lib
puts $outf "LLVMSYSTEMLIBS = \\\n[normalizelibs $syslibs]"
close $outf
# return 1 for !if in makefile.vc
exit 1
