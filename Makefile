TCLDIR = /home/decoster/tcltk
TCLINCDIR = $(TCLDIR)/include
TCLLIBDIR = $(TCLDIR)/lib
TCLLIB = $(TCLLIBDIR)/libtcl8.6.so
TCLSH = $(TCLDIR)/bin/tclsh8.6

LLVMDIR = /home/decoster/llvm
LLVMCFLAGS = `$(LLVMDIR)/bin/llvm-config --cflags`
LLVMLFLAGS = `$(LLVMDIR)/bin/llvm-config --ldflags`
LLVMLIBS = `$(LLVMDIR)/bin/llvm-config --libs`

all: llvmtcl.so

llvmtcl.so : llvmtcl.o
	g++ -shared -o llvmtcl.so llvmtcl.o $(TCLLIB) $(LLVMLFLAGS) $(LLVMLIBS)

llvmtcl.o : llvmtcl.cpp
	g++ -fPIC -I$(TCLINCDIR) $(LLVMCFLAGS) llvmtcl.cpp -c -o llvmtcl.o

clean:
	- rm llvmtcl.o

distclean: clean
	- rm llvmtcl.so

test: llvmtcl.so
	$(TCLSH) test.tcl
