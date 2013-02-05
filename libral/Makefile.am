ACLOCAL_AMFLAGS = -I m4
AM_CFLAGS = -fno-builtin -Wall -std=c99 -pedantic

test: all test.c
	$(COMPILE) -o test test.c -L.libs -lm -lral ${LIBS}
	export LD_LIBRARY_PATH='.libs'; ./test

lib_LTLIBRARIES = libral.la

libral_la_HEADERFILES = ral/ral.h ral/config.h ral/hash.h ral/vector.h ral/grid.h ral/dem.h ral/visual.h ral/backend.h ral/statistics.h

libral_la_SOURCES = ral_hash.c ral_vd.c ral_visual.c ral_pixbuf.c ral_grid.c ral_grid_rw.c ral_catchment.c ral_statistics.c ${libral_la_HEADERFILES}

libral_la_LDFLAGS = -version-info 1:0:0 -module

EXTRA_DIST = test.c interface.c autogen.sh lesser.txt ral/config.h.in msg.h config.h index.dox Makefile.MinGW Makefile.VC71 libral.pc.in libral.pc

nobase_include_HEADERS = ${libral_la_HEADERFILES}

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libral.pc

clean-local:
	rm -f test
