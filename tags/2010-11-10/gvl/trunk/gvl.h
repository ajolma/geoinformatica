#ifndef GVL_H
#define GVL_H

#include <cairo.h>
#include <librsvg/rsvg.h>
#include <librsvg/rsvg-cairo.h>
#include <pango/pango.h>
#include <gdal.h>
#include <ogr_api.h>

/**\file gvl.h
   \brief Geovisualization Library
*/

/**\brief status codes */
typedef enum {

    GVL_STATUS_SUCCESS,
    GVL_STATUS_FAILURE,
    GVL_STATUS_OUT_OF_MEMORY,
    GVL_STATUS_EMPTY_SYMBOLIZER_TABLE,
    GVL_STATUS_NEED_TWO_SYMBOLIZERS_TO_INTERPOLATE

} gvl_status;

/**\brief a color */
typedef struct {

    double red;
    double green;
    double blue;
    double alpha;

} gvl_color;

gvl_color gvl_color_init(double red, double green, double blue, double alpha);

/**\brief hard-coded marks for points and vertices in linestrings */
typedef enum {

    GVL_MARK_CROSS

} gvl_mark_type;

/**\brief mark and its styling */
typedef struct _gvl_mark gvl_mark;

gvl_mark *gvl_mark_create(gvl_mark_type type,
			  double size,
			  gvl_color stroke,
			  double stroke_width);

gvl_mark *gvl_mark_create_filled(gvl_mark_type type,
				 double size,
				 gvl_color stroke,
				 double stroke_width,
				 gvl_color fill);

void gvl_mark_destroy(gvl_mark **mark);

gvl_mark_type gvl_mark_get_type(gvl_mark *mark);
void gvl_mark_set_type(gvl_mark *mark, gvl_mark_type type);
double gvl_mark_get_size(gvl_mark *mark);
void gvl_mark_set_size(gvl_mark *mark, double size);
gvl_color gvl_mark_get_stroke(gvl_mark *mark);
void gvl_mark_set_stroke(gvl_mark *mark, gvl_color stroke);
double gvl_mark_get_stroke_width(gvl_mark *mark);
void gvl_mark_set_stroke_width(gvl_mark *mark, double stroke_width);
gvl_color gvl_mark_get_fill(gvl_mark *mark);
void gvl_mark_set_fill(gvl_mark *mark, gvl_color fill);
void gvl_mark_set_no_fill(gvl_mark *mark);

/**\brief draw mark at (x,y), which must be in cairo surface coordinates */
void gvl_draw_mark(cairo_t *cr, gvl_mark *mark, double x, double y);

/**\brief dashes styling */
typedef struct _gvl_dashes gvl_dashes;

gvl_dashes *gvl_dashes_create(int num_dashes);

gvl_dashes *gvl_dashes_clone(gvl_dashes *dashes);

void gvl_dashes_destroy(gvl_dashes **dashes);

double *gvl_dashes_get_dashes(gvl_dashes *dashes, int *num_dashes);
void gvl_dashes_set_dashes(gvl_dashes *dashes, double *gvl_dashes, int num_dashes);
double gvl_dashes_get_offset(gvl_dashes *dashes);
void gvl_dashes_set_offset(gvl_dashes *dashes, double offset);

/**\brief line style */
typedef struct _gvl_line_style gvl_line_style;

gvl_line_style *gvl_line_style_create(gvl_color color,
				      double width,
				      cairo_line_join_t line_join,
				      cairo_line_cap_t line_cap,
				      double miter_limit,
				      gvl_dashes *dashes);

gvl_line_style *gvl_line_style_create_plain(gvl_color color);

gvl_line_style *gvl_line_style_clone(gvl_line_style *style);

void gvl_line_style_destroy(gvl_line_style **line_style);

gvl_color gvl_line_style_get_color(gvl_line_style *line_style);
void gvl_line_style_set_color(gvl_line_style *line_style, gvl_color color);

double gvl_line_style_get_width(gvl_line_style *line_style);
void gvl_line_style_set_width(gvl_line_style *line_style, double width);

cairo_line_join_t gvl_line_style_get_line_join(gvl_line_style *line_style);
void gvl_line_style_set_line_join(gvl_line_style *line_style, cairo_line_join_t line_join);

cairo_line_cap_t gvl_line_style_get_line_cap(gvl_line_style *line_style);
void gvl_line_style_set_line_cap(gvl_line_style *line_style, cairo_line_cap_t line_cap);

double gvl_line_style_get_miter_limit(gvl_line_style *line_style);
void gvl_line_style_set_miter_limit(gvl_line_style *line_style, double miter_limit);

gvl_dashes *gvl_line_style_get_dashes(gvl_line_style *line_style);
void gvl_line_style_set_dashes(gvl_line_style *line_style, gvl_dashes *dashes);

gvl_line_style *gvl_line_style_get_next(gvl_line_style *line_style);

/**\brief the validity of next is not checked */
void gvl_line_style_add_style(gvl_line_style *line_style, 
			      gvl_line_style *next);

void gvl_set_line_style(cairo_t *cr, gvl_line_style *style);

typedef enum {

    GVL_SYMBOLIZER_POINT,
    GVL_SYMBOLIZER_LINE,
    GVL_SYMBOLIZER_POLYGON,
    GVL_SYMBOLIZER_TEXT,
    GVL_SYMBOLIZER_RASTER

} gvl_symbolizer_class;


/**\brief symbolizer base class */
typedef struct _gvl_symbolizer gvl_symbolizer;

gvl_symbolizer *gvl_symbolizer_create(gvl_symbolizer_class symbolizer_class);
gvl_symbolizer *gvl_symbolizer_clone(gvl_symbolizer *symbolizer);
void gvl_symbolizer_destroy(gvl_symbolizer **symbolizer);


/**\brief line symbolizer */
typedef struct _gvl_line_symbolizer gvl_line_symbolizer;

gvl_line_style *gvl_line_symbolizer_get_line_style(gvl_line_symbolizer *sr);
void gvl_line_symbolizer_set_line_style(gvl_line_symbolizer *sr, gvl_line_style *style);

gvl_mark *gvl_line_symbolizer_get_mark(gvl_line_symbolizer *sr);
void gvl_line_symbolizer_set_mark(gvl_line_symbolizer *sr, gvl_mark *mark);


/**\brief polygon symbolizer */
typedef struct _gvl_polygon_symbolizer gvl_polygon_symbolizer;

gvl_color *gvl_polygon_symbolizer_get_color(gvl_polygon_symbolizer *sr);
void gvl_polygon_symbolizer_set_color(gvl_polygon_symbolizer *sr, gvl_color color);

cairo_pattern_t gvl_polygon_symbolizer_get_pattern(gvl_polygon_symbolizer *sr);
void gvl_polygon_symbolizer_set_pattern(gvl_polygon_symbolizer *sr, cairo_pattern_t *pattern);

gvl_line_symbolizer *gvl_polygon_symbolizer_get_border(gvl_polygon_symbolizer *sr);
void gvl_polygon_symbolizer_set_border(gvl_polygon_symbolizer *sr, gvl_line_symbolizer *border);


/**\brief point symbolizer, either a SVG symbol or a hard-coded mark.
   could be extended for complex symbols that utilize several attributes (pie charts etc)
 */
typedef struct _gvl_point_symbolizer gvl_point_symbolizer;

RsvgHandle *gvl_point_symbolizer_get_graphic(gvl_point_symbolizer *sr);
void gvl_point_symbolizer_set_graphic(gvl_point_symbolizer *sr, RsvgHandle *graphic);

gvl_mark *gvl_point_symbolizer_get_mark(gvl_point_symbolizer *sr);
void gvl_point_symbolizer_set_mark(gvl_point_symbolizer *sr, gvl_mark *mark);

double gvl_point_symbolizer_get_rotation(gvl_point_symbolizer *sr);
void gvl_point_symbolizer_set_rotation(gvl_point_symbolizer *sr, double rotation);

void gvl_point_symbolizer_get_anchor_point(gvl_point_symbolizer *sr, double *x, double *y);
void gvl_point_symbolizer_set_anchor_point(gvl_point_symbolizer *sr, double x, double y);

void gvl_point_symbolizer_get_displacement(gvl_point_symbolizer *sr, double *x, double *y);
void gvl_point_symbolizer_set_displacement(gvl_point_symbolizer *sr, double x, double y);


/**\brief text symbolizer */
typedef struct _gvl_text_symbolizer gvl_text_symbolizer;

char *gvl_text_symbolizer_get_label(gvl_text_symbolizer *sr);
void gvl_text_symbolizer_set_label(gvl_text_symbolizer *sr, char *label);

PangoFontDescription *gvl_text_symbolizer_get_font(gvl_text_symbolizer *sr);
void gvl_text_symbolizer_set_font(gvl_text_symbolizer *sr, PangoFontDescription *font);

gvl_color gvl_text_symbolizer_get_color(gvl_text_symbolizer *sr);
void gvl_text_symbolizer_set_color(gvl_text_symbolizer *sr, gvl_color color);

double gvl_text_symbolizer_get_rotation(gvl_text_symbolizer *sr);
void gvl_text_symbolizer_set_rotation(gvl_text_symbolizer *sr, double rotation);

void gvl_text_symbolizer_get_anchor_point(gvl_text_symbolizer *sr, double *x, double *y);
void gvl_text_symbolizer_set_anchor_point(gvl_text_symbolizer *sr, double x, double y);

void gvl_text_symbolizer_get_displacement(gvl_text_symbolizer *sr, double *x, double *y);
void gvl_text_symbolizer_set_displacement(gvl_text_symbolizer *sr, double x, double y);


typedef enum {

    GVL_INT,
    GVL_FLOAT,
    GVL_DOUBLE,
    GVL_STRING,
    GVL_GEOMETRY,
    GVL_OTHER

} gvl_data_type;

typedef struct {

    char **column_names;
    gvl_data_type *data_types;
    void **data;

} gvl_feature;

char *gvl_label(char *label_mark_up, OGRFeatureH feature);

void gvl_set_polygon_symbolizer(cairo_t *cr, gvl_polygon_symbolizer *sr);

void gvl_set_point_symbolizer(cairo_t *cr, gvl_point_symbolizer *sr);

void gvl_set_text_symbolizer(cairo_t *cr, gvl_text_symbolizer *sr);

/**\brief raster symbolizer */
typedef struct _gvl_raster_symbolizer gvl_raster_symbolizer;


typedef struct {

    int has_int;
    int i_value;
    float f_value;

} gvl_raster_feature;

typedef int gvl_classification_function_type(void *feature, void *user);

typedef double gvl_value_function_type(void *feature, void *user);

/**\brief use-for-all symbolizer table */
typedef struct _gvl_symbolizer_table gvl_symbolizer_table;

gvl_symbolizer_table *gvl_symbolizer_table_create();

gvl_symbolizer_table *gvl_symbolizer_table_create_with_classes(gvl_classification_function_type *classification_function);

gvl_symbolizer_table *gvl_symbolizer_table_create_with_continuous(gvl_value_function_type *value_function,
								  double value_min,
								  double value_max);
void gvl_symbolizer_table_destroy(gvl_symbolizer_table **table);

gvl_status gvl_symbolizer_table_add(gvl_symbolizer_table *table, gvl_symbolizer *sr);

/**\brief canvas info, width and height must be the same as in the cairo surface
 */
typedef struct _gvl_canvas gvl_canvas;

gvl_canvas *gvl_canvas_create(cairo_surface_t *surface,
			      double width,
			      double height,
			      double map_min_x,
			      double map_min_y,
			      double map_max_x,
			      double map_max_y);

void gvl_canvas_destroy(gvl_canvas **canvas);

void gvl_canvas_rectangle(gvl_canvas *canvas, double x, double y, double width, double height);

typedef struct {

    double x;
    double y;
    double z;

} gvl_vertex;

typedef enum {

    GVL_MULTI_POINT,
    GVL_MULTI_LINE_STRING,
    GVL_MULTI_POLYGON

} gvl_geometry_type;

typedef struct {

    gvl_vertex *points; /** all points are here, others are just pointers into this */
    int n_points;
    gvl_vertex **parts; /** parts[i] points into points */
    int *n_of_part;
    int n_parts;
    gvl_geometry_type type;

} gvl_geometry;

void gvl_canvas_geometry(gvl_canvas *canvas, gvl_geometry *geometry);

void gvl_canvas_ogr_geometry(gvl_canvas *canvas, OGRGeometryH geometry);

void gvl_canvas_geometry_mark_vertices(gvl_canvas *canvas, gvl_geometry *geometry, gvl_mark *mark);

void gvl_canvas_ogr_geometry_mark_vertices(gvl_canvas *canvas, OGRGeometryH geometry, gvl_mark *mark);

void gvl_canvas_stroke_line(gvl_canvas *canvas, gvl_geometry *geometry, gvl_line_symbolizer *sr);

void gvl_canvas_stroke_ogr_line(gvl_canvas *canvas, OGRGeometryH geometry, gvl_line_symbolizer *sr);

typedef struct {

    gvl_feature *features;

} gvl_layer;

gvl_status gvl_canvas_render_layer(gvl_canvas *canvas, gvl_layer *layer, gvl_symbolizer_table *table, void *user);

gvl_status gvl_canvas_render_ogr_layer(gvl_canvas *canvas, OGRLayerH layer, gvl_symbolizer_table *table, void *user);

typedef struct {
    int *data;
    int has_nodata;
    int nodata;
    int width; 
    int height;
    double x_min;
    double y_max;
    double dx;
    double dy;
} gvl_int_raster;

gvl_status gvl_canvas_render_int_raster(gvl_canvas *canvas, gvl_int_raster, gvl_symbolizer_table *table, void *user);

typedef struct {
    float *data;
    int has_nodata;
    float nodata;
    int width; 
    int height;
    double x_min;
    double y_max;
    double dx;
    double dy;
} gvl_float_raster;

gvl_status gvl_canvas_render_float_raster(gvl_canvas *canvas, gvl_float_raster, gvl_symbolizer_table *table, void *user);

gvl_status gvl_canvas_render_gdal_raster(gvl_canvas *canvas, GDALDatasetH dataset, gvl_symbolizer_table *table, void *user);

#endif
