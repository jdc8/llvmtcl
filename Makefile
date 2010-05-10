TCLDIR = /home/decoster/tcltk
TCLINCDIR = $(TCLDIR)/include
TCLLIBDIR = $(TCLDIR)/lib
TCLLIB = $(TCLLIBDIR)/libtcl8.6.so
TCLSH = $(TCLDIR)/bin/tclsh8.6

LLVMDIR = /home/decoster/llvm
LLVMCFLAGS = `$(LLVMDIR)/bin/llvm-config --cflags`
LLVMLFLAGS = `$(LLVMDIR)/bin/llvm-config --ldflags`
LLVMLIBS = `$(LLVMDIR)/bin/llvm-config --libs`

#CFLAGS = -fprofile-arcs -ftest-coverage

all: llvmtcl.so

llvmtcl.so : llvmtcl.o
	g++ -shared $(CFLAGS) -o llvmtcl.so llvmtcl.o $(TCLLIB) $(LLVMLFLAGS) $(LLVMLIBS)

llvmtcl.o : llvmtcl.cpp llvmtcl-gen.cpp llvmtcl-gen-cmddef.cpp
	g++ -fPIC $(CFLAGS) -I$(TCLINCDIR) $(LLVMCFLAGS) llvmtcl.cpp -c -o llvmtcl.o

llvmtcl-gen.cpp llvmtcl-gen-cmddef.cpp : llvmtcl-gen.tcl llvmtcl-gen.inp
	$(TCLSH) llvmtcl-gen.tcl

clean:
	- rm llvmtcl.o llvmtcl-gen.cpp llvmtcl-gen-cmddef.cpp

distclean: clean
	- rm llvmtcl.so

test: llvmtcl.so
	$(TCLSH) test.tcl
