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
a gdal pixbuf for GUI.

*/
typedef struct {

    /** cairo image, each pixel is 4 bytes XRGB (BGRX if little endian) */
    unsigned char *image;

    /** rowstride of the cairo image */
    int image_rowstride;

    /** pixbuf data, each pixel is 3 bytes RGB, freed in pixbuf_destroy_notify */
    guchar *pixbuf;

    /** needed for gdk pixbuf */
    GdkPixbufDestroyNotify destroy_fn;

    /** needed for gdk pixbuf */
    GdkColorspace colorspace;

    /** needed for gdk pixbuf */
    gboolean has_alpha;

    /** needed for gdk pixbuf */
    int rowstride;
    
    /** needed for gdk pixbuf */
    int bits_per_sample;

    /** width, N is used so that ral_pixbuf's can be used in macros */
    int N;
    /** height, M is used so that ral_pixbuf's can be used in macros */
    int M;

    /** geographic world */
    ral_rectangle world;

    /** size of pixel in geographic space */
    double pixel_size;

} ral_pixbuf;

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

#define RAL_PIXBUF_INDEX(pb,i,j) (i)*(pb)->image_rowstride+(j)*RAL_PIXELSIZE

#define RAL_PIXBUF_SET_PIXEL(pb,i,j,R,G,B)			\
    {	(pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+3] = 255;          \
        (pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+2] = (R);		\
	(pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+1] = (G);		\
	(pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+0] = (B);	}

#define RAL_PIXBUF_SET_PIXEL_COLOR(pb,i,j,c)				\
    {   (pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+3] = 255;                  \
        (pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+2] =			\
	    min(max(((255-((c).c4))*(pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+2]+((c).c4)*((c).c1))/255,0),255); \
	(pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+1] =			\
	    min(max(((255-((c).c4))*(pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+1]+((c).c4)*((c).c2))/255,0),255); \
	(pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+0] =			\
	    min(max(((255-((c).c4))*(pb->image)[RAL_PIXBUF_INDEX(pb,i,j)+0]+((c).c4)*((c).c3))/255,0),255);}

#define RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i,j,c) \
    if ((i) >= 0 AND (i) < (pb)->M AND (j) >= 0 AND (j) < (pb)->N) \
        RAL_PIXBUF_SET_PIXEL_COLOR((pb),(i),(j),(c))

#define RAL_PIXBUF_ASSIGN_PIXEL_COLOR(pb, pixel, color) RAL_PIXBUF_SET_PIXEL_COLOR(pb,pixel.i,pixel.j,color)

#define RAL_PIXBUF_GET_PIXEL_COLOR(pb, pixel, color) \
    {(color).c1 = (pb->image)[RAL_PIXBUF_INDEX(pb, (pixel).i, (pixel).j)+2]; \
     (color).c2 = (pb->image)[RAL_PIXBUF_INDEX(pb, (pixel).i, (pixel).j)+1]; \
     (color).c3 = (pb->image)[RAL_PIXBUF_INDEX(pb, (pixel).i, (pixel).j)+0];}

/** pixbuf coords to grid coords */
#define RAL_PBi2GDi(pb, i, gd) (floor((((gd)->world.max.y -		\
  (pb->world.max.y - (double)(i)*pb->pixel_size)))/(gd)->cell_size))

/** pixbuf coords to grid coords */
#define RAL_PBj2GDj(pb, j, gd) (floor(((pb->world.min.x +		\
  (double)(j)*pb->pixel_size) - (gd)->world.min.x)/(gd)->cell_size))

/** grid coordinates to pixbuf coords */
#define RAL_GDi2PBi(gd, i, pb)						\
    (floor((pb->world.max.y - (gd)->world.max.y + (gd)->cell_size * ((double)(i)+0.5))/pb->pixel_size))

/** grid coordinates to pixbuf coords */
#define RAL_GDj2PBj(gd, j, pb)						\
    (floor(((gd)->world.min.x - pb->world.min.x + (gd)->cell_size * ((double)(j)+0.5))/pb->pixel_size))

/** pixbuf coords to grid coords */
#define RAL_PIXEL2CELL(pixel, gd, cell)			\
    (cell).i = RAL_PBi2GDi(pb, (pixel).i, (gd));	\
    (cell).j = RAL_PBj2GDj(pb, (pixel).j, (gd))

int RAL_CALL ral_render_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *l);
int RAL_CALL ral_render_real_grid(ral_pixbuf *pb, ral_real_grid_layer *l);

int RAL_CALL ral_render_rectangles(ral_pixbuf *pb, ral_geometry *g, int symbol_size, GDALColorEntry color);
int RAL_CALL ral_render_crosses(ral_pixbuf *pb, ral_geometry *g, int symbol_size, GDALColorEntry color);
int RAL_CALL ral_render_dots(ral_pixbuf *pb, ral_geometry *g, int r, GDALColorEntry color);

int RAL_CALL ral_render_polylines(ral_pixbuf *pb, ral_geometry *g, GDALColorEntry color);

int RAL_CALL ral_render_polygons(ral_pixbuf *pb, ral_geometry *g, GDALColorEntry color);

/**\brief linear interpolation made easier */
typedef struct {
    ral_double_range x;
    ral_double_range y;
    ral_double_range bound;
    double delta_x;
    double delta_y;
    double k;
} ral_interpolator;

#define RAL_INTERPOLATOR_SETUP(interpolator, x_range, y_range) \
    (interpolator).x.min = (x_range).min;					\
    (interpolator).x.max = (x_range).max;					\
    (interpolator).y.min = (y_range).min;					\
    (interpolator).y.max = (y_range).max;					\
    (interpolator).delta_x = (interpolator).x.max - (interpolator).x.min; \
    (interpolator).delta_y = (interpolator).y.max - (interpolator).y.min; \
    (interpolator).bound.min = min((interpolator).y.max, (interpolator).y.min); \
    (interpolator).bound.max = max((interpolator).y.max, (interpolator).y.min); \
    (interpolator).k = (interpolator).delta_x == 0 ? 0 : (interpolator).delta_y / (interpolator).delta_x;

#define RAL_INTERPOLATE(interpolator, x_value)				\
    max(min((interpolator).y.min + (interpolator).k*((x_value) - (interpolator).x.min), \
	    (interpolator).bound.max), (interpolator).bound.min)

#ifdef RAL_HAVE_GDAL
/** information that is needed besides ral_visual to visualize a feature */
typedef struct {
    OGRFeatureH feature;
    OGRGeometryH geometry;
    int destroy_geometry;  /** true if the geometry is _not_ a reference to the feature */
    int geometry_type;
    ral_geometry *ral_geom;
    int render_as;         /** points, lines, and/or polygons */
    OGRFieldType symbol_size_field_type;
    OGRFieldType color_field_type;
    ral_interpolator nv2c; /* from the value in the field to a color */
    GDALColorEntry color;
    ral_interpolator nv2ss; /** from the value in the field to a symbol size */
} ral_feature;

#define RAL_FEATURE_SET_COLOR(feature, c1_value, c2_value, c3_value, c4_value) { \
    (feature).color.c1 = (c1_value); \
    (feature).color.c2 = (c2_value); \
    (feature).color.c3 = (c3_value); \
    (feature).color.c4 = (c4_value);} \

int RAL_CALL ral_render_feature(ral_pixbuf *pb, ral_feature *feature, ral_visual *visual);

int RAL_CALL ral_render_visual_layer(ral_pixbuf *pb, ral_visual_layer *l);

int RAL_CALL ral_render_visual_feature_table(ral_pixbuf *pb, ral_visual_feature_table *t);

/** returns OGRFieldType */
int RAL_CALL ral_get_field_type(OGRLayerH layer, int field, OGRFieldType *field_type);
#endif

#endif
