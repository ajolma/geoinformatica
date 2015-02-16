PERL_MODULES = Geo-OGC-Geometry Gtk2-Ex-Geo Gtk2-Ex-Geo-Graph Geo-Raster Geo-Vector
LIBRAL = libral
MODULES = ${LIBRAL} ${PERL_MODULES}

all: libral perl

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

libral:
	cd libral
	sh autogen.sh
	./configure --prefix=${PREFIX} --with-gdal=${WITH-GDAL}
	make

libral-install:
	cd libral
	make install
	cd ..

perl:
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		perl Makefile.PL PREFIX=${PREFIX}; \
		make; \
		make test; \
		cd ..; \
	done;

perl-install:
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		make install; \
		cd ..; \
	done;

install: libral-install perl-install

dist:
	cd ${LIBRAL}; $(MAKE) dist; cp *.tar.gz ..; cd ..
	for m in ${PERL_MODULES}; do \
		cd $$m; \
		$(MAKE) dist; \
		cp *.tar.gz ..; \
		cd ..; \
	done;
