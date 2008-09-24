#!/bin/sh

export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib/pkgconfig
export PATH=$PATH:/usr/local/bin

MAP_WWW=/var/www/html

cd /home/ajolma
rm -rf gdal
svn checkout https://svn.osgeo.org/gdal/trunk/gdal gdal
cd gdal
./configure --with-pic --with-libtiff=internal
make 
make install
cd swig/perl
rm *wrap*
make generate
make build
make test
make install
doxygen
cd html
scp * jolma@map.hut.fi:$MAP_WWW/doc/Geo-GDAL/html
cd ..

cd /home/ajolma/hoslab
rm -rf svngeoinformatica
svn co svn+ssh://ajolma@hoslab.cs.helsinki.fi/svngeoinformatica

cd svngeoinformatica/libral/trunk
sh autogen.sh
./configure
make
make install
make dist
scp *.tar.gz jolma@map.hut.fi:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz
doxygen
cd html
scp * jolma@map.hut.fi:$MAP_WWW/doc/libral/html
cd ..

cd ../../IPC-Gnuplot/trunk/
perl Makefile.PL
make
make test
make install
make dist
scp *.tar.gz jolma@map.hut.fi:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz

cd ../../Geo-OGC-Geometry/trunk/
perl Makefile.PL
make
make test
make install
make dist
scp *.tar.gz jolma@map.hut.fi:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz

cd ../../Geo-Raster/trunk/
perl Makefile.PL
make
make test
make install
make dist
scp *.tar.gz jolma@map.hut.fi:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz
doxygen
cd html
scp * jolma@map.hut.fi:$MAP_WWW/doc/Geoinformatica/html
cd ..

cd ../../Geo-Vector/trunk/
perl Makefile.PL
make
make test
make install
make dist
scp *.tar.gz jolma@map.hut.fi:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz

cd ../../Gtk2-Ex-Geo/trunk/
perl Makefile.PL
make
make test
make install
make dist
scp *.tar.gz jolma@map.hut.fi:$MAP_WWW/files/Geoinformatica/snapshots
cp -f *.tar.gz ../../..
rm *.tar.gz

cd ../../..

cp -f svngeoinformatica/Geoinformatica/trunk/gui.pl /usr/local/bin/gis.pl
chmod ugo+x /usr/local/bin/gis.pl
