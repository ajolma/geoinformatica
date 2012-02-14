#!/bin/sh

rm -f configure depcomp install-sh libtool Makefile missing stamp-h* test config.guess Makefile.in libral.la config.log aclocal.m4 test.out ltmain.sh config.status config.sub config.h.in config.h
rm -f *.lo
rm -f *.o
rm -rf autom4te.cache
rm -rf .deps
rm -rf .libs

aclocal
#autoconf
autoheader
libtoolize --force
automake --add-missing --copy --force-missing
autoconf
