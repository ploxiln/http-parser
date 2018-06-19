# Copyright Joyent, Inc. and other Node contributors. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

PLATFORM ?= $(shell sh -c 'uname -s | tr "[A-Z]" "[a-z]"')
HELPER ?=
BINEXT ?=
SOLIBNAME = libhttp_parser
SOMAJOR = 3
SOMINOR = 0
SOREV   = 0
ifeq (darwin,$(PLATFORM))
SOEXT ?= dylib
SONAME ?= $(SOLIBNAME).$(SOMAJOR).$(SOMINOR).$(SOEXT)
LIBNAME ?= $(SOLIBNAME).$(SOMAJOR).$(SOMINOR).$(SOREV).$(SOEXT)
else ifeq (wine,$(PLATFORM))
CC = winegcc
BINEXT = .exe.so
HELPER = wine
else
SOEXT ?= so
SONAME ?= $(SOLIBNAME).$(SOEXT).$(SOMAJOR).$(SOMINOR)
LIBNAME ?= $(SOLIBNAME).$(SOEXT).$(SOMAJOR).$(SOMINOR).$(SOREV)
endif

CC?=gcc
AR?=ar

CPPFLAGS ?=
LDFLAGS ?=

CPPFLAGS += -I.
CPPFLAGS_DEBUG = $(CPPFLAGS) -DHTTP_PARSER_STRICT=1
CPPFLAGS_DEBUG += $(CPPFLAGS_DEBUG_EXTRA)
CPPFLAGS_FAST = $(CPPFLAGS) -DHTTP_PARSER_STRICT=0
CPPFLAGS_FAST += $(CPPFLAGS_FAST_EXTRA)
CPPFLAGS_BENCH = $(CPPFLAGS_FAST)

CFLAGS += -Wall -Wextra -Wshadow
CFLAGS_DEBUG = $(CFLAGS) -O0 -g $(CFLAGS_DEBUG_EXTRA)
CFLAGS_FAST = $(CFLAGS) -O3 $(CFLAGS_FAST_EXTRA)
CFLAGS_BENCH = $(CFLAGS_FAST) -Wno-unused-parameter
CFLAGS_LIB = $(CFLAGS_FAST) -fPIC

LDFLAGS_LIB = $(LDFLAGS) -shared

INSTALL ?= install
PREFIX ?= /usr/local
LIBDIR     = $(DESTDIR)$(PREFIX)/lib
INCLUDEDIR = $(DESTDIR)$(PREFIX)/include

ifeq (darwin,$(PLATFORM))
LDFLAGS_LIB += -Wl,-install_name,$(LIBDIR)/$(SONAME)
else
# TODO(bnoordhuis) The native SunOS linker expects -h rather than -soname...
LDFLAGS_LIB += -Wl,-soname=$(SONAME)
endif

all: library package

test: test_g test_fast
	$(HELPER) ./test_g$(BINEXT)
	$(HELPER) ./test_fast$(BINEXT)

test_g: http_parser_g.o test_g.o
	$(CC) $(CFLAGS_DEBUG) $(LDFLAGS) http_parser_g.o test_g.o -o $@

test_g.o: test.c http_parser.h Makefile
	$(CC) $(CPPFLAGS_DEBUG) $(CFLAGS_DEBUG) -Wno-shadow -c test.c -o $@

http_parser_g.o: http_parser.c http_parser.h Makefile
	$(CC) $(CPPFLAGS_DEBUG) $(CFLAGS_DEBUG) -c http_parser.c -o $@

test_fast: http_parser.o test.o http_parser.h
	$(CC) $(CFLAGS_FAST) $(LDFLAGS) http_parser.o test.o -o $@

test.o: test.c http_parser.h Makefile
	$(CC) $(CPPFLAGS_FAST) $(CFLAGS_FAST) -Wno-shadow -c test.c -o $@

bench: http_parser.o bench.o
	$(CC) $(CFLAGS_BENCH) $(LDFLAGS) http_parser.o bench.o -o $@

bench.o: bench.c http_parser.h Makefile
	$(CC) $(CPPFLAGS_BENCH) $(CFLAGS_BENCH) -c bench.c -o $@

http_parser.o: http_parser.c http_parser.h Makefile
	$(CC) $(CPPFLAGS_FAST) $(CFLAGS_FAST) -c http_parser.c

test-run-timed: test_fast
	while(true) do time $(HELPER) ./test_fast$(BINEXT) > /dev/null; done

test-valgrind: test_g
	valgrind ./test_g

libhttp_parser.o: http_parser.c http_parser.h Makefile
	$(CC) $(CPPFLAGS_FAST) $(CFLAGS_LIB) -c http_parser.c -o libhttp_parser.o

library: $(LIBNAME)
$(LIBNAME): libhttp_parser.o
	$(CC) $(LDFLAGS_LIB) -o $@ $<

package: libhttp_parser.a
libhttp_parser.a: http_parser.o
	$(AR) rcs libhttp_parser.a http_parser.o

url_parser: http_parser.o contrib/url_parser.c
	$(CC) $(CPPFLAGS_FAST) $(CFLAGS_FAST) $^ -o $@

url_parser_g: http_parser_g.o contrib/url_parser.c
	$(CC) $(CPPFLAGS_DEBUG) $(CFLAGS_DEBUG) $^ -o $@

parsertrace: http_parser.o contrib/parsertrace.c
	$(CC) $(CPPFLAGS_FAST) $(CFLAGS_FAST) $^ -o parsertrace$(BINEXT)

parsertrace_g: http_parser_g.o contrib/parsertrace.c
	$(CC) $(CPPFLAGS_DEBUG) $(CFLAGS_DEBUG) $^ -o parsertrace_g$(BINEXT)

tags: http_parser.c http_parser.h test.c
	ctags $^

install: library package
	$(INSTALL) -d $(INCLUDEDIR)
	$(INSTALL) -m 0644 http_parser.h $(INCLUDEDIR)/http_parser.h
	$(INSTALL) -d $(LIBDIR)
	$(INSTALL) -m 0644 $(LIBNAME) $(LIBDIR)/$(LIBNAME)
	ln -sf $(LIBNAME) $(LIBDIR)/$(SONAME)
	ln -sf $(LIBNAME) $(LIBDIR)/$(SOLIBNAME).$(SOEXT)
	$(INSTALL) -m 0644 $(SOLIBNAME).a $(LIBDIR)/$(SOLIBNAME).a

install-strip: library package
	$(INSTALL) -d $(INCLUDEDIR)
	$(INSTALL) -m 0644 http_parser.h $(INCLUDEDIR)/http_parser.h
	$(INSTALL) -d $(LIBDIR)
	$(INSTALL) -m 0644 -s $(LIBNAME) $(LIBDIR)/$(LIBNAME)
	ln -sf $(LIBNAME) $(LIBDIR)/$(SONAME)
	ln -sf $(LIBNAME) $(LIBDIR)/$(SOLIBNAME).$(SOEXT)
	$(INSTALL) -m 0644 $(SOLIBNAME).a $(LIBDIR)/$(SOLIBNAME).a

uninstall:
	rm -f $(INCLUDEDIR)/http_parser.h
	rm -f $(LIBDIR)/$(LIBNAME)
	rm -f $(LIBDIR)/$(SONAME)
	rm -f $(LIBDIR)/$(SOLIBNAME).$(SOEXT)
	rm -f $(LIBDIR)/$(SOLIBNAME).a

clean:
	rm -f *.o *.a tags \
		test_fast$(BINEXT) test_g$(BINEXT) bench \
		http_parser.tar libhttp_parser.* \
		url_parser url_parser_g parsertrace parsertrace_g \
		*.exe *.exe.so

contrib/url_parser.c:	http_parser.h
contrib/parsertrace.c:	http_parser.h

.PHONY: clean package test-run test-run-timed test-valgrind install install-strip uninstall
