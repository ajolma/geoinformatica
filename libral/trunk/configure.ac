#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)
VERSION=0.61
AC_INIT(libral, 0.61, ari.jolma_at_tkk.fi)
AM_INIT_AUTOMAKE
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile libral.pc ral/config.h])

AC_SUBST(REQUIRES)
AC_SUBST(PC_LIBS)
AC_SUBST(PC_CPPFLAGS)
AC_SUBST(LIBS)
AC_SUBST(CPPFLAGS)
AC_SUBST(HAVE_GDAL)
AC_SUBST(HAVE_GDK_PIXBUF)

# Checks for programs.
AC_PROG_CC
AC_PROG_MAKE_SET
AC_PROG_LIBTOOL

# Checks for byteorder, typedefs, structures, and compiler characteristics.
AC_C_BIGENDIAN
AC_C_CONST
AC_TYPE_SIZE_T

# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([float.h limits.h stddef.h stdlib.h string.h unistd.h math.h errno.h string.h stdarg.h],,
		 [AC_MSG_FAILURE(
			[One of required standard headers NOT found.])])

# Checks for library functions.
AC_FUNC_MALLOC
AC_FUNC_REALLOC
LIBS="$LIBS -lm"
AC_CHECK_FUNCS([floor pow sqrt strchr strerror],,
               [AC_MSG_FAILURE(
                   [One of required standard functions NOT found.])])
AC_CHECK_FUNCS([strdup])

AC_MSG_CHECKING([for local path])

AC_ARG_WITH(local,[  --with-local[[=DIR]]      the local path [[default=/usr/local]]],,)
if test "$with_local" != "no"; then
  if test "$with_local" = "yes" -o "$with_local" = ""; then
    ADD_PREFIX=/usr/local
  else
    ADD_PREFIX=$with_local
  fi
  LIBS="$LIBS -L$ADD_PREFIX/lib"
  CPPFLAGS="$CPPFLAGS -I$ADD_PREFIX/include"
  AC_MSG_RESULT(using $ADD_PREFIX)
else
  AC_MSG_RESULT([none])
fi

AC_ARG_WITH(gdk-pixbuf,[  --with-gdk-pixbuf       whether to use gdk-pixbuf [[default=yes]]],,)
if test "$with_gdk_pixbuf" != "no"; then
  PKG_CHECK_MODULES(GDK_PIXBUF, gdk-pixbuf-2.0, gdk=true)
  if test "$gdk" = "true"; then
    LIBS="$LIBS $GDK_PIXBUF_LIBS"
    CPPFLAGS="$CPPFLAGS $GDK_PIXBUF_CFLAGS"
    PC_CPPFLAGS=""
    HAVE_GDK_PIXBUF="#define"
    REQUIRES="gdk-pixbuf-2.0"
  else
    echo "gdk-pixbuf not found!"
    HAVE_GDK_PIXBUF="#undef"
  fi
else
  echo "not using gdk-pixbuf"
  HAVE_GDK_PIXBUF="#undef"
fi

AC_ARG_WITH(gdal,[  --with-gdal[[=DIR]]       whether to use GDAL [[default=yes]] [[from DIR]]],,)
if test "$with_gdal" != "no"; then
  if test "$with_gdal" != "yes" -a "$with_gdal" != "" ; then
    LIBS="$LIBS -L$with_gdal/lib"
    PC_LIBS="$PC_LIBS -L$with_gdal/lib"
    CPPFLAGS="$CPPFLAGS -I$with_gdal/include"
    PC_CPPFLAGS="$PC_CPPFLAGS -I$with_gdal/include"
  fi
  AC_CHECK_HEADER(gdal.h, gdal=true)
  if test "$gdal" = "true"; then
    LIBS="$LIBS -lgdal"
    PC_LIBS="$PC_LIBS -lgdal"
    CPPFLAGS="$CPPFLAGS"
    PC_CPPFLAGS="$PC_CPPFLAGS"
    HAVE_GDAL="#define"
    REQUIRES="$REQUIRES"
  else
    echo "GDAL not found!"
    HAVE_GDAL="#undef"
  fi
else
  echo "not using GDAL"
  HAVE_GDAL="#undef"
fi

AC_MSG_CHECKING([whether to add debugging support])
AC_ARG_WITH(debug,[  --with-debug            whether to add debug code [[default=no]]],,)
if test "$with_debug" = "yes"; then
  CPPFLAGS="-g $CPPFLAGS"
  AC_MSG_RESULT(yes)
else
  CPPFLAGS="-O2 $CPPFLAGS"
  AC_MSG_RESULT(no)
fi

AC_OUTPUT
