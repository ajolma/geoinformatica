MAKE = make
PREFIX=/usr/local

PERL_MODULES = Geo-OGC-Geometry Gtk2-Ex-Geo Gtk2-Ex-Geo-Graph Geo-Raster Geo-Vector
LIBRAL = libral
MODULES = ${LIBRAL} ${PERL_MODULES}

all:
	cd ${LIBRAL}; sh autogen.sh; ./configure --prefix=${PREFIX}; make; cd ..
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		perl Makefile.PL INSTALL_BASE=${PREFIX}; \
		make; \
		cd ..; \
	done;

perl:
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		perl Makefile.PL; make; \
		cd ..; \
	done;

install-perl:
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		make install; \
		cd ..; \
	done;

make:
	for m in ${MODULES}; do \
		cd $$m; \
		$(MAKE); \
		cd ..; \
	done;

install:
	for m in ${MODULES}; do \
		cd $$m; \
		$(MAKE) install; \
		cd ..; \
	done;

clean:
	for m in ${MODULES}; do \
		cd $$m; \
		$(MAKE) clean; \
		cd ..; \
	done;

distclean:
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		$(MAKE) clean; \
		rm -f Makefile.old Files.pm const-c.inc const-xs.inc; \
		cd ..; \
	done;
	cd ${LIBRAL}; $(MAKE) distclean; cd ..

dist:
	cd ${LIBRAL}; $(MAKE) dist; cd ..
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		$(MAKE) dist; \
		cd ..; \
	done;
