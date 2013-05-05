#ifndef RAL_BACKEND_H
#define RAL_BACKEND_H

/**\file ral/backend.h
   \brief A system for rendering geospatial data onto a graphics backend.
*/

GDALColorEntry RAL_CALL ral_hsv2rgb(GDALColorEntry hsv);

#define RAL_PIXELSIZE 4
#define RAL_PIXBUF_PIXELSIZE 3

/**\brief a cairo image canvas and a gdk style pixbuf 

The idea is to first draw to the cairo image and then convert it into
a gdk pixbuf for GUI.

*/
typedef struct _ral_pixbuf ral_pixbuf;
typedef ral_pixbuf *ral_pixbuf_handle;

ral_pixbuf_handle RAL_CALL ral_pixbuf_create(int width, int height,
					     double minX, double maxY, double pixel_size, 
					     GDALColorEntry background);

ral_pixbuf_handle RAL_CALL ral_pixbuf_create_from_grid(ral_grid *gd);

void RAL_CALL ral_pixbuf_destroy(ral_pixbuf **pb);

int RAL_CALL ral_cairo_to_pixbuf(ral_pixbuf *pb);

#ifdef RAL_HAVE_GDK_PIXBUF
typedef GdkPixbuf *GdkPixbufH;
GdkPixbufH RAL_CALL ral_gdk_pixbuf(ral_pixbuf *pb);
#endif

void ral_pixbuf_copy(ral_pixbuf *pb,
		     unsigned char *image,
		     int image_rowstride,
		     guchar *pixbuf,
		     GdkPixbufDestroyNotify destroy_fn,
		     GdkColorspace colorspace,
		     gboolean has_alpha,
		     int rowstride,
		     int bits_per_sample,
		     int width,
		     int height,
		     double world_min_x,
		     double world_max_y,
		     double pixel_size);

int RAL_CALL ral_render_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *l);
int RAL_CALL ral_render_real_grid(ral_pixbuf *pb, ral_real_grid_layer *l);

int RAL_CALL ral_render_rectangles(ral_pixbuf *pb, ral_geometry *g, int symbol_size, GDALColorEntry color);
int RAL_CALL ral_render_crosses(ral_pixbuf *pb, ral_geometry *g, int symbol_size, GDALColorEntry color);
int RAL_CALL ral_render_dots(ral_pixbuf *pb, ral_geometry *g, int r, GDALColorEntry color);

int RAL_CALL ral_render_polylines(ral_pixbuf *pb, ral_geometry *g, GDALColorEntry color);

int RAL_CALL ral_render_polygons(ral_pixbuf *pb, ral_geometry *g, GDALColorEntry color);

#ifdef RAL_HAVE_GDAL

int RAL_CALL ral_render_visual_layer(ral_pixbuf *pb, ral_visual_layer *l);

int RAL_CALL ral_render_visual_feature_table(ral_pixbuf *pb, ral_visual_feature_table *t);

/** returns OGRFieldType */
int RAL_CALL ral_get_field_type(OGRLayerH layer, int field, OGRFieldType *field_type);

#endif

#endif
