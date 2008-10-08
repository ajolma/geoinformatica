#!/bin/sh

PUBLISHER=jolma@map.hut.fi
MAP_WWW=/var/www/html
HOME=/home/ajolma/dev
PREFIX=/home/ajolma/usr

export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib/pkgconfig:$PREFIX/lib/pkgconfig
export PATH=$PATH:/usr/local/bin
export PERL5LIB=$PREFIX/lib/perl5:$PREFIX/lib/perl5/site_perl/5.8.8:$PREFIX/lib/perl5/i386-linux-thread-multi
export LD_LIBRARY_PATH=$HOME/gdal/.libs:$HOME/geoinformatica/libral/trunk/.libs
export PROJSO=/usr/local/lib/libproj.so


cd $HOME

rm -rf gdal
svn checkout https://svn.osgeo.org/gdal/trunk/gdal gdal

cd gdal
./configure --prefix=$PREFIX --with-pic --with-libtiff=internal
make
make install

cd swig/perl
rm *wrap*
make generate
perl Makefile.PL PREFIX=$PREFIX
make build
make test
make install
doxygen
cd html
scp * $PUBLISHER:$MAP_WWW/doc/Geo-GDAL/html

cd $HOME
rm -rf geoinformatica
svn co https://svn.osgeo.org/geoinformatica/

cd geoinformatica/libral/trunk
sh autogen.sh
./configure --prefix=$PREFIX --with-gdal=$PREFIX/bin/gdal-config
make
make install
make dist
scp *.tar.gz $PUBLISHER:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz
doxygen
cd html
scp * $PUBLISHER:$MAP_WWW/doc/libral/html
cd ..

# perl modules

cd ../../IPC-Gnuplot/trunk/
perl Makefile.PL PREFIX=$PREFIX
make
make test
make install
make dist
scp *.tar.gz $PUBLISHER:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz

cd ../../Geo-OGC-Geometry/trunk/
perl Makefile.PL PREFIX=$PREFIX
make
make test
make install
make dist
scp *.tar.gz $PUBLISHER:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz

cd ../../Geo-Raster/trunk/
perl Makefile.PL PREFIX=$PREFIX
make
make test
make install
make dist
scp *.tar.gz $PUBLISHER:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz
doxygen
cd html
scp * $PUBLISHER:$MAP_WWW/doc/Geoinformatica/html
cd ..

cd ../../Geo-Vector/trunk/
perl Makefile.PL PREFIX=$PREFIX
make
make test
make install
make dist
scp *.tar.gz $PUBLISHER:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz

cd ../../Gtk2-Ex-Geo/trunk/
perl Makefile.PL PREFIX=$PREFIX
make
make test
make install
make dist
scp *.tar.gz $PUBLISHER:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz

