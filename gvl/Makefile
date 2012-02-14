INSTALL = /bin/install

INSTALL_DIR = /local

DLL_NAME = libgvl.dll

CC = gcc

DEFINES =

GTK_DIR = /c/GTK

GDAL_DIR = /local

INCLUDES = -I. -I$(GDAL_DIR)/include -I$(GTK_DIR)/include/gtk-2.0 -I$(GTK_DIR)/include/glib-2.0 -I$(GTK_DIR)/lib/glib-2.0/include -I$(GTK_DIR)/include/cairo -I$(GTK_DIR)/include/librsvg-2 -I$(GTK_DIR)/include/pango-1.0

CFLAGS = -g -O2 $(INCLUDES) $(DEFINES)

LIBS = -L$(GDAL_DIR)/bin -L$(GTK_DIR)/bin -lglib-2.0-0 -lgobject-2.0-0 -lgdk_pixbuf-2.0 -lcairo-2 -lrsvg-2 -lpango-1.0-0 -lpangocairo-1.0-0 -lgdal-1

HEADERS = gvl_private.h gvl.h

SOURCES = gvl.c

OBJS := $(patsubst %.c,%.o,$(SOURCES))

DEPS := $(patsubst %.o,%.d,$(OBJS))

all: $(OBJS) $(DLL_NAME)

$(DLL_NAME): $(HEADERS) $(OBJS)
	gcc -shared $(OBJS) $(LIBS) -Wl,-soname -Wl,crap.dll -Wl,--out-implib=$(DLL_NAME).a -o $(DLL_NAME)

dep:
	$(CC) $(CFLAGS) -MD -E $(SOURCES) > /dev/null

clean:
	rm -f $(OBJS) $(DEPS) $(DLL_NAME) $(DLL_NAME).a

install: all
	$(INSTALL) $(DLL_NAME) $(INSTALL_DIR)/bin
	$(INSTALL) $(DLL_NAME).a $(INSTALL_DIR)/lib
#	$(INSTALL) libgvl.pc $(INSTALL_DIR)/lib/pkgconfig
#	$(INSTALL) ral.h $(INSTALL_DIR)/include
#	$(INSTALL) ral/*.h $(INSTALL_DIR)/include/ral

test:
	$(CC) $(CFLAGS) $(LIBS) test.c *.o -o test
	export PATH=/C/GTK/bin:/usr/local/bin:/mingw/bin:/bin:/c/Progra~1/PostgreSQL/8.2/bin:/c/WINDOWS/system32:/c/WINDOWS;export GDAL_DATA=c:/msys/1.0/local/share/gdal; export PROJSO=libproj.dll; ./test

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

.PHONY: dep clean test

-include $(DEPS)
