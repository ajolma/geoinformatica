MAKE = make

PERL_MODULES = Graphics-ColorUtils-0.17 Geo-OGC-Geometry-0.04 Gtk2-Ex-Geo-0.62 Gtk2-Ex-Geo-Graph-0.01 Geo-Raster-0.62 Geo-Vector-0.52
LIBRAL = libral-0.63
MODULES = ${LIBRAL} ${PERL_MODULES}

all:
	cd ${LIBRAL}; ./configure; make; cd ..
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		perl Makefile.PL; \
		make; \
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
	cd ${LIBRAL}; make distclean; cd ..
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		rm -f Makefile.old Files.pm const-c.inc const-xs.inc; \
		cd ..; \
	done;
