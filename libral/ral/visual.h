#ifndef RAL_VISUAL_H
#define RAL_VISUAL_H

/**\file ral/visual.h
   \brief A definition of a visual geospatial feature and layer.
*/

/**\brief a range defined by two integers */
typedef struct {
    int min;
    int max;
} ral_int_range;

/**\brief a range defined by two real numbers */
typedef struct {
    double min;
    double max;
} ral_double_range;

#define RAL_PALETTE_SINGLE_COLOR 0
#define RAL_PALETTE_GRAYSCALE 1
#define RAL_PALETTE_RAINBOW 2
#define RAL_PALETTE_COLOR_TABLE 3
#define RAL_PALETTE_COLOR_BINS 4
#define RAL_PALETTE_RED_CHANNEL 5
#define RAL_PALETTE_GREEN_CHANNEL 6
#define RAL_PALETTE_BLUE_CHANNEL 7

#define RAL_SCALE_GRAY 0
#define RAL_SCALE_HUE 1
#define RAL_SCALE_SATURATION 2
#define RAL_SCALE_VALUE 3
#define RAL_SCALE_OPACITY 4

#define RAL_SCALE_NORMAL 0
#define RAL_SCALE_INVERTED 1

/* red->green->blue rainbow */
#define RAL_RGB_HUE 0
/* red->blue->green rainbow */
#define RAL_RBG_HUE 1

#define RAL_SYMBOL_FLOW_DIRECTION 1
#define RAL_SYMBOL_SQUARE 2
#define RAL_SYMBOL_DOT 3
#define RAL_SYMBOL_CROSS 4
#define RAL_SYMBOL_ARROW_IN_ANGLE 5
#define RAL_SYMBOL_WIND_ROSE 6

#define RAL_DEFAULT_SYMBOL_PIXEL_SIZE 5

#define RAL_RAINBOW_HUE_AT_MIN 235
#define RAL_RAINBOW_HUE_AT_MAX 0

/**\brief a hash, where the keys are long ints and values are colors */
typedef struct {
    int n;
    long *keys;
    GDALColorEntry *colors;
} ral_color_table;

typedef ral_color_table *ral_color_table_handle;

ral_color_table_handle RAL_CALL ral_color_table_create(int n);
void RAL_CALL ral_color_table_destroy(ral_color_table **table);

#define RAL_COLOR_TABLE_GET(table, key, color)			\
    {								\
	int i;							\
	if (table) for (i = 0; i < (table)->n; i++)		\
		       if ((table)->keys[i] == (key)) {		\
			   (color) = (table)->colors[i];	\
			   break;				\
		       }					\
    }

/**\brief a hash, where the keys are strings and values are colors */
typedef struct {
    int n;
    char **keys;
    GDALColorEntry *colors;
} ral_string_color_table;

typedef ral_string_color_table *ral_string_color_table_handle;

ral_string_color_table_handle RAL_CALL ral_string_color_table_create(int n);
void RAL_CALL ral_string_color_table_destroy(ral_string_color_table **table);
int RAL_CALL ral_string_color_table_set(ral_string_color_table *table, char *key, int i, GDALColorEntry color);

#define RAL_STRING_COLOR_TABLE_GET(table, key, color)			\
    {									\
	int i;								\
	if (table) for (i = 0; i < (table)->n; i++) {			\
		if ((table)->keys[i] AND strcmp((table)->keys[i], (key)) == 0) { \
		    (color) = (table)->colors[i];			\
		    break;						\
		}							\
	    }								\
    }

/**\brief a hash, where the keys are bins defined with RAL_INTEGERs and values are colors */
typedef struct {
    int n;
    /** a bin is a < x <= b, the (n-1) b's are in this array */
    RAL_INTEGER *bins;
    /** n colors */
    GDALColorEntry *colors;
} ral_integer_color_bins;

typedef ral_integer_color_bins *ral_integer_color_bins_handle;

ral_integer_color_bins_handle RAL_CALL ral_integer_color_bins_create(int n);
void RAL_CALL ral_integer_color_bins_destroy(ral_integer_color_bins **bins);

/**\brief a hash, where the keys are bins defined with RAL_REALs and values are colors */
typedef struct {
    int n;
    RAL_REAL *bins;
    GDALColorEntry *colors;
} ral_real_color_bins;

typedef ral_real_color_bins *ral_real_color_bins_handle;

ral_real_color_bins_handle RAL_CALL ral_real_color_bins_create(int n);
void RAL_CALL ral_real_color_bins_destroy(ral_real_color_bins **bins);

/**\brief a hash, where the keys are bins defined with ints and values are colors */
typedef struct {
    int n;
    int *bins;
    GDALColorEntry *colors;
} ral_int_color_bins;

typedef ral_int_color_bins *ral_int_color_bins_handle;

ral_int_color_bins_handle RAL_CALL ral_int_color_bins_create(int n);
void RAL_CALL ral_int_color_bins_destroy(ral_int_color_bins **bins);

/**\brief a hash, where the keys are bins defined with doubles and values are colors */
typedef struct {
    int n;
    double *bins;
    GDALColorEntry *colors;
} ral_double_color_bins;

typedef ral_double_color_bins *ral_double_color_bins_handle;

ral_double_color_bins_handle RAL_CALL ral_double_color_bins_create(int n);
void RAL_CALL ral_double_color_bins_destroy(ral_double_color_bins **bins);

/** This can be used for all bin types. */
#define RAL_COLOR_BINS_GET(color_bins, value, color)			\
    {									\
	int i = 0;							\
	if (color_bins) {						\
            while ( (value) > (color_bins)->bins[i] AND i < (color_bins)->n - 1 ) \
	        i++;							\
	    (color) = (color_bins)->colors[i];}				\
    }

/**\brief a RAL_INTEGER grid and visualization information */
typedef struct {
    short alpha;
    ral_grid *alpha_grid;
    ral_grid *gd;
    int palette_type;
    GDALColorEntry single_color;
    int symbol;
    int symbol_pixel_size;
    ral_int_range symbol_size_scale;
    ral_color_table *color_table;
    ral_string_color_table *string_color_table;
    ral_int_color_bins *color_bins;
    ral_int_range color_scale; /* if valid, this is not computed */
    GDALColorEntry grayscale_base_color;
    int scale; /* 0 = Grayscale (0-255)
		  1 = Hue scale (0-360)
		  2 = Saturation scale (0-100)
		  3 = Value scale (0-100)
		  4 = Opacity scale (0-255) */
    ral_int_range hue_at; /* for rainbow */
    int invert; /* & 1: 0 = do not invert, 1 invert
		   do not invert means rainbow is red->green->blue, invert means red->blue->green 
		   do not invert means scale is 0-100/255/360, invert means scale is 100/255/360-0 */
} ral_integer_grid_layer;

typedef ral_integer_grid_layer *ral_integer_grid_layer_handle;

ral_integer_grid_layer_handle RAL_CALL ral_integer_grid_layer_create();
void RAL_CALL ral_integer_grid_layer_destroy(ral_integer_grid_layer **l);

/**\brief a RAL_REAL grid and visualization information */
typedef struct {
    short alpha;
    ral_grid *alpha_grid;
    ral_grid *gd;
    int palette_type; /* valid are grayscale, rainbow, bins */
    GDALColorEntry single_color;
    int symbol;
    int symbol_pixel_size;
    ral_double_range symbol_size_scale;
    ral_color_table *color_table; /* never used, only because of macros */
    ral_string_color_table *string_color_table; /* never used, only because of macros */
    ral_double_color_bins *color_bins;
    ral_double_range color_scale; /* if valid, this is not computed */
    GDALColorEntry grayscale_base_color; 
    int scale; /* 0 = Grayscale (0-255)
		  1 = Hue scale (0-360)
		  2 = Saturation scale (0-100)
		  3 = Value scale (0-100)
		  4 = Opacity scale (0-255) */
    ral_int_range hue_at; /* for rainbow */
    int invert; /* & 1: 0 = do not invert, 1 invert
		   do not invert means rainbow is red->green->blue, invert means red->blue->green 
		   do not invert means scale is 0-100/255/360, invert means scale is 100/255/360-0 */
} ral_real_grid_layer;

typedef ral_real_grid_layer *ral_real_grid_layer_handle;

ral_real_grid_layer_handle RAL_CALL ral_real_grid_layer_create();
void RAL_CALL ral_real_grid_layer_destroy(ral_real_grid_layer **l);

#define RAL_RENDER_AS_NATIVE 0
#define RAL_RENDER_AS_POINTS 1
#define RAL_RENDER_AS_LINES 2
#define RAL_RENDER_AS_POLYGONS 4

#define RAL_FIELD_UNDEFINED -10
#define RAL_FIELD_FIXED_SIZE -3
#define RAL_FIELD_Z -2
#define RAL_FIELD_FID -1
/* field index value >=0 is feature attribute table index */

/**\brief visualization information */
typedef struct {
    short alpha;
    int render_as;
    int palette_type;
    int symbol;
    int symbol_field; /* one of RAL_FIELD values or an index to attribute table */
    OGRFieldType symbol_field_type;
    int symbol_pixel_size;
    ral_int_range symbol_size_scale_int; /* range in attribute scale */
    ral_double_range symbol_size_scale_double; /* range in attribute scale */
    GDALColorEntry single_color;
    ral_int_range color_scale_int; /* range in attribute scale */
    ral_double_range color_scale_double; /* range in attribute scale */
    GDALColorEntry grayscale_base_color; 
    int scale; /* 0 = Grayscale (0-255)
		  1 = Hue scale (0-360)
		  2 = Saturation scale (0-100)
		  3 = Value scale (0-100)
		  4 = Opacity scale (0-255) */
    ral_int_range hue_at; /* for rainbow */
    int invert; /* & 1: 0 = do not invert, 1 invert
		   do not invert means rainbow is red->green->blue, invert means red->blue->green 
		   do not invert means scale is 0-100/255/360, invert means scale is 100/255/360-0 */
    int color_field; /* one of RAL_FIELD values or an index to attribute table */
    OGRFieldType color_field_type;
    ral_color_table *color_table;
    ral_string_color_table *string_color_table;
    ral_int_color_bins *int_bins;
    ral_double_color_bins *double_bins;
} ral_visual;

void ral_visual_initialize(ral_visual *v);
void ral_visual_finalize(ral_visual v);

#ifdef RAL_HAVE_GDAL
/**\brief an OGRLayerH and visualization information */
typedef struct {
    ral_visual visualization;
    OGRLayerH layer;
} ral_visual_layer;

typedef ral_visual_layer *ral_visual_layer_handle;

ral_visual_layer_handle RAL_CALL ral_visual_layer_create();
void RAL_CALL ral_visual_layer_destroy(ral_visual_layer **l);

/**\brief an OGRFeatureH and visualization information */
typedef struct {
    ral_visual visualization;
    OGRFeatureH feature;
} ral_visual_feature;

/**\brief an array of ral_visual_features */
typedef struct {
    int size;
    ral_visual_feature *features;
} ral_visual_feature_table;

typedef ral_visual_feature_table *ral_visual_feature_table_handle;

ral_visual_feature_table_handle RAL_CALL ral_visual_feature_table_create(int size);
void RAL_CALL ral_visual_feature_table_destroy(ral_visual_feature_table **t);
#endif

#endif
