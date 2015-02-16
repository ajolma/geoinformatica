PERL_MODULES = Geo-OGC-Geometry Gtk2-Ex-Geo Gtk2-Ex-Geo-Graph Geo-Raster Geo-Vector
LIBRAL = libral
MODULES = ${LIBRAL} ${PERL_MODULES}

doc:
	doxygen

check-out:
	for m in ${MODULES}; do \
		svn co https://github.com/ajolma/$$m/trunk $$m; \
	done;

up:
	for m in ${MODULES}; do \
		cd $$m; \
		svn up; \
		cd ..; \
	done;

remove-modules:
	for m in ${MODULES}; do \
		rm -rf $$m; \
	done;

x-libral:
	for m in ${LIBRAL}; do \
		cd $$m; \
		sh autogen.sh; \
		./configure --prefix=${PREFIX} --with-gdal=${WITH_GDAL}; \
		make; \
		make install; \
		cd ..; \
	done;

perl:
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		perl Makefile.PL PREFIX=${PREFIX}; \
		make; \
		make test; \
		make install; \
		cd ..; \
	done;

dist:
	cd ${LIBRAL}; $(MAKE) dist; cp *.tar.gz ..; cd ..
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		$(MAKE) dist; \
		cp *.tar.gz ..; \
		cd ..; \
	done;
