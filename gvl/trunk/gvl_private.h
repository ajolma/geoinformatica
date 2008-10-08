#ifndef GVL_PRIVATE_H
#define GVL_PRIVATE_H

#include "gvl.h"

#define GVL_MALLOC(type) (type*)malloc(sizeof(type))
#define GVL_CALLOC(count, type) (type*)calloc((count), sizeof(type))
#define GVL_REALLOC(pointer, count, type) (type*)realloc((pointer), (count)*sizeof(type))
#define GVL_FREE(pointer) { if(pointer){ free(pointer); pointer = NULL; } }
#define GVL_TEST_POINTER(pointer) { if (!(pointer)){ goto fail; } }

#define GVL_TEST_SUCCESS(ret) { if ((ret) != GVL_STATUS_SUCCESS){ goto fail; } }

/**\brief a point, either in map or in surface coordinates */
typedef struct {

    double x;
    double y;

} gvl_point;

static inline gvl_point gvl_point_init(double x, double y);

/**\brief a rectangle */
typedef struct {

    gvl_point min;
    gvl_point max;

} gvl_rectangle;

struct _gvl_mark {

    gvl_mark_type  type;
    double         size; /* in cairo surface units */
    gvl_color      stroke;
    double         stroke_width;
    int            filled;
    gvl_color      fill;
    
};

struct _gvl_dashes {

    double  *dashes;
    int      num_dashes;
    double   offset;

};

struct _gvl_line_style {

    gvl_color          color;
    double             width;
    cairo_line_join_t  line_join;
    cairo_line_cap_t   line_cap;
    double             miter_limit;
    gvl_dashes        *dashes;

    gvl_line_style    *next;

};

struct _gvl_symbolizer {

    gvl_symbolizer_class my_class;
    char *name;
    struct _gvl_symbolizer *next;
    
};

struct _gvl_line_symbolizer {

    struct _gvl_symbolizer base;
    gvl_line_style *style;
    gvl_mark       *mark;
    
};

struct _gvl_polygon_symbolizer {

    struct _gvl_symbolizer base;
    gvl_color             color;
    cairo_pattern_t      *pattern; /* is used if non-null */
    gvl_line_symbolizer  *border;
    
};

struct _gvl_point_symbolizer {

    struct _gvl_symbolizer base;
    RsvgHandle  *graphic; /* this and mark are mutually exclusive */
    gvl_mark    *mark;

    double       rotation;
    gvl_point    anchor_point;
    gvl_point    displacement;
    
};


struct _gvl_text_symbolizer {

    struct _gvl_symbolizer base;
    char                   *label; /* mark up consisting of literal text and attributes */

    PangoFontDescription   *font;

    gvl_color               color;

    double                  rotation;
    gvl_point               anchor_point;
    gvl_point               displacement;

    double                  perpendicular_offset;
    int                     is_repeated;
    double                  initial_gap;
    int                     is_aligned;
    int                     generalize_line;

    double                  halo_radius;
    gvl_polygon_symbolizer  *halo;
    
};

struct _gvl_raster_symbolizer {
    struct _gvl_symbolizer  base;
    gvl_color               color;
};

/* from map coordinates to surface coordinates */ 
gvl_point gvl_transform(gvl_canvas *canvas, double x, double y);

struct _gvl_symbolizer_table {

    int                                size;
    int                                n;
    struct _gvl_symbolizer           **symbolizers;

    gvl_classification_function_type  *classification_function; /* for classified symbolization */

    gvl_value_function_type           *value_function; /* for interpolated symbolization */

    double                             value_min; /* lower bound, use symbolizer 1 */
    double                             value_max; /* upper bound, use symbolizer 2 */
    
};

struct _gvl_canvas {

    cairo_surface_t              *surface;
    cairo_t                      *cr;

    double                        width; /* of cairo surface */
    double                        height; /* of cairo surface */
    double                        scale; /* surface unit / map unit */

    gvl_rectangle                 viewport; /* in map coordinates */
    double                        cell_width;
    
};

#endif
