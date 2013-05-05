#ifndef RAL_VISUAL_H
#define RAL_VISUAL_H

/**\file ral/visual.h
   \brief A definition of a visual geospatial feature and layer.
*/

/**\brief a range defined by two integers */
typedef struct _ral_int_range ral_int_range;

/**\brief a range defined by two real numbers */
typedef struct _ral_double_range ral_double_range;

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
typedef struct _ral_color_table ral_color_table;
typedef ral_color_table *ral_color_table_handle;

ral_color_table_handle RAL_CALL ral_color_table_create(int n);
void RAL_CALL ral_color_table_destroy(ral_color_table **table);
int RAL_CALL ral_color_table_set(ral_color_table *table, int i, long key, GDALColorEntry color);

/**\brief a hash, where the keys are strings and values are colors */
typedef struct _ral_string_color_table ral_string_color_table;
typedef ral_string_color_table *ral_string_color_table_handle;

ral_string_color_table_handle RAL_CALL ral_string_color_table_create(int n);
void RAL_CALL ral_string_color_table_destroy(ral_string_color_table **table);
int RAL_CALL ral_string_color_table_set(ral_string_color_table *table, int i, char *key, GDALColorEntry color);

/**\brief a hash, where the keys are bins defined with RAL_INTEGERs and values are colors */
typedef struct _ral_integer_color_bins ral_integer_color_bins;
typedef ral_integer_color_bins *ral_integer_color_bins_handle;

ral_integer_color_bins_handle RAL_CALL ral_integer_color_bins_create(int n);
void RAL_CALL ral_integer_color_bins_destroy(ral_integer_color_bins **bins);

/**\brief a hash, where the keys are bins defined with RAL_REALs and values are colors */
typedef struct _ral_real_color_bins ral_real_color_bins;
typedef ral_real_color_bins *ral_real_color_bins_handle;

ral_real_color_bins_handle RAL_CALL ral_real_color_bins_create(int n);
void RAL_CALL ral_real_color_bins_destroy(ral_real_color_bins **bins);

/**\brief a hash, where the keys are bins defined with ints and values are colors */
typedef struct _ral_int_color_bins ral_int_color_bins;
typedef ral_int_color_bins *ral_int_color_bins_handle;

ral_int_color_bins_handle RAL_CALL ral_int_color_bins_create(int n);
void RAL_CALL ral_int_color_bins_destroy(ral_int_color_bins **bins);

/**\brief a hash, where the keys are bins defined with doubles and values are colors */
typedef struct _ral_double_color_bins ral_double_color_bins;
typedef ral_double_color_bins *ral_double_color_bins_handle;

ral_double_color_bins_handle RAL_CALL ral_double_color_bins_create(int n);
void RAL_CALL ral_double_color_bins_destroy(ral_double_color_bins **bins);

/**\brief a RAL_INTEGER grid and visualization information */
typedef struct _ral_integer_grid_layer ral_integer_grid_layer;
typedef ral_integer_grid_layer *ral_integer_grid_layer_handle;

ral_integer_grid_layer_handle RAL_CALL ral_integer_grid_layer_create();
void RAL_CALL ral_integer_grid_layer_destroy(ral_integer_grid_layer **l);

/**\brief a RAL_REAL grid and visualization information */
typedef struct _ral_real_grid_layer ral_real_grid_layer;
typedef ral_real_grid_layer *ral_real_grid_layer_handle;

ral_real_grid_layer_handle RAL_CALL ral_real_grid_layer_create();
void RAL_CALL ral_real_grid_layer_destroy(ral_real_grid_layer **l);

#define RAL_FIELD_UNDEFINED -10
#define RAL_FIELD_FIXED_SIZE -3
#define RAL_FIELD_Z -2
#define RAL_FIELD_FID -1
/* field index value >=0 is feature attribute table index */

/**\brief visualization information */
typedef struct _ral_rule ral_rule;

ral_rule *ral_rule_create();
void ral_rule_destroy(ral_rule **r);

int ral_rule_set_name(ral_rule *r, char *name);
void ral_rule_set_elsefilter(ral_rule *r);
int ral_rule_set_filter_i(ral_rule *r, char *property, int cmp, int value);
int ral_rule_set_filter_n(ral_rule *r, char *property, int cmp, double value);
int ral_rule_set_filter_s(ral_rule *r, char *property, int cmp, char *value);

/**\brief visualization information */
typedef struct _ral_visual ral_visual;

ral_visual *ral_visual_create();
void ral_visual_destroy(ral_visual **v);

int ral_visual_add_rule(ral_visual*, ral_rule*);

void ral_visual_set_alpha(ral_visual*, int);

void ral_visual_set_symbol(ral_visual*, int);
void ral_visual_set_symbol_size(ral_visual*, int);

void ral_visual_set_symbol_size_property(ral_visual*, char*);
void ral_visual_set_symbol_size_scale(ral_visual*, double, double);

void ral_visual_set_palette_type(ral_visual*, int);

void ral_visual_set_single_color(ral_visual*, int, int, int, int);

void ral_visual_set_color_property(ral_visual*, char*);

void ral_visual_set_color_scale(ral_visual*, double, double);

void ral_visual_set_hue_range(ral_visual*, int, int, int);

void ral_visual_set_grayscale_base_color(ral_visual*, int, int, int, int scale_type);

#ifdef RAL_HAVE_GDAL

/**\brief an OGRLayerH and visualization information */
typedef struct _ral_visual_layer ral_visual_layer;
typedef ral_visual_layer *ral_visual_layer_handle;

ral_visual_layer_handle RAL_CALL ral_visual_layer_create();
void RAL_CALL ral_visual_layer_destroy(ral_visual_layer **l);

/**\brief an array of OGR features and visualization information */
typedef struct _ral_visual_feature_table ral_visual_feature_table;
typedef ral_visual_feature_table *ral_visual_feature_table_handle;

ral_visual_feature_table_handle RAL_CALL ral_visual_feature_table_create(int size);
void RAL_CALL ral_visual_feature_table_destroy(ral_visual_feature_table **t);

#endif

#endif
