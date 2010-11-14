#include "config.h"
#include "msg.h"
#include "ral.h"
#include <string.h>

#ifndef HAVE_STRDUP
char *strdup(char *str)
{
    char *tmp = (char *)malloc(strlen(str)+1);
    strcpy(tmp, str);
    return tmp;
}
#endif

ral_color_table *ral_color_table_create(int n)
{
    ral_color_table *table;
    RAL_CHECKM(table = RAL_MALLOC(ral_color_table), RAL_ERRSTR_OOM);
    table->n = n;
    table->keys = NULL;
    table->colors = NULL;
    RAL_CHECKM(table->keys = RAL_CALLOC(n, RAL_INTEGER), RAL_ERRSTR_OOM);
    RAL_CHECKM(table->colors = RAL_CALLOC(n, GDALColorEntry), RAL_ERRSTR_OOM);
    return table;
 fail:
    ral_color_table_destroy(&table);
    return NULL;
}

void ral_color_table_destroy(ral_color_table **table)
{
    if (*table) {
	if ((*table)->keys) free((*table)->keys);
	if ((*table)->colors) free((*table)->colors);
	free(*table);
	*table = NULL;
    }
}

ral_string_color_table *ral_string_color_table_create(int n)
{
    int i;
    ral_string_color_table *table;
    RAL_CHECKM(table = RAL_MALLOC(ral_string_color_table), RAL_ERRSTR_OOM);
    table->n = n;
    table->keys = NULL;
    table->colors = NULL;
    RAL_CHECKM(table->keys = RAL_CALLOC(n, char *), RAL_ERRSTR_OOM);
    for (i = 0; i < n; i++) {
	table->keys[i] = NULL;
    }
    RAL_CHECKM(table->colors = RAL_CALLOC(n, GDALColorEntry), RAL_ERRSTR_OOM);
    return table;
 fail:
    ral_string_color_table_destroy(&table);
    return NULL;
}

void ral_string_color_table_destroy(ral_string_color_table **table)
{
    if (*table) {
	int i;
	if ((*table)->keys) {
	    for (i = 0; i < (*table)->n; i++) {
		if ((*table)->keys[i]) free((*table)->keys[i]);
	    }
	    free((*table)->keys);
	}
	if ((*table)->colors) free((*table)->colors);
	free(*table);
	*table = NULL;
    }
}

int ral_string_color_table_set(ral_string_color_table *table, char *key, int i, GDALColorEntry color)
{
    RAL_CHECKM(i >= 0 AND i < table->n, RAL_ERRSTR_IOB);
    if (table->keys[i]) free(table->keys[i]);
    RAL_CHECKM(table->keys[i] = strdup(key), RAL_ERRSTR_OOM);
    table->colors[i] = color;
    return 1;
 fail:
    return 0;
}

ral_integer_color_bins *ral_integer_color_bins_create(int n) 
{
    ral_integer_color_bins *bins;
    RAL_CHECKM(bins = RAL_MALLOC(ral_integer_color_bins), RAL_ERRSTR_OOM);
    bins->n = n;
    bins->bins = NULL;
    bins->colors = NULL;
    RAL_CHECKM(bins->bins = RAL_CALLOC(n-1, RAL_INTEGER), RAL_ERRSTR_OOM);
    RAL_CHECKM(bins->colors = RAL_CALLOC(n, GDALColorEntry), RAL_ERRSTR_OOM);
    return bins;
 fail:
    ral_integer_color_bins_destroy(&bins);
    return NULL;
}

void ral_integer_color_bins_destroy(ral_integer_color_bins **bins)
{
    if (*bins) {
	if ((*bins)->bins) free((*bins)->bins);
	if ((*bins)->colors) free((*bins)->colors);
	free(*bins);
	*bins = NULL;
    }
}

ral_real_color_bins *ral_real_color_bins_create(int n) 
{
    ral_real_color_bins *bins = NULL;
    RAL_CHECKM(bins = RAL_MALLOC(ral_real_color_bins), RAL_ERRSTR_OOM);
    bins->n = n;
    bins->bins = NULL;
    bins->colors = NULL;
    RAL_CHECKM(bins->bins = RAL_CALLOC(n-1, RAL_REAL), RAL_ERRSTR_OOM);
    RAL_CHECKM(bins->colors = RAL_CALLOC(n, GDALColorEntry), RAL_ERRSTR_OOM);
    return bins;
 fail:
    ral_real_color_bins_destroy(&bins);
    return NULL;
}

void ral_real_color_bins_destroy(ral_real_color_bins **bins)
{
    if (*bins) {
	if ((*bins)->bins) free((*bins)->bins);
	if ((*bins)->colors) free((*bins)->colors);
	free(*bins);
	*bins = NULL;
    }
}

ral_int_color_bins *ral_int_color_bins_create(int n) 
{
    ral_int_color_bins *bins;
    RAL_CHECKM(bins = RAL_MALLOC(ral_int_color_bins), RAL_ERRSTR_OOM);
    bins->n = n;
    bins->bins = NULL;
    bins->colors = NULL;
    RAL_CHECKM(bins->bins = RAL_CALLOC(n-1, int), RAL_ERRSTR_OOM);
    RAL_CHECKM(bins->colors = RAL_CALLOC(n, GDALColorEntry), RAL_ERRSTR_OOM);
    return bins;
 fail:
    ral_int_color_bins_destroy(&bins);
    return NULL;
}

void ral_int_color_bins_destroy(ral_int_color_bins **bins)
{
    if (*bins) {
	if ((*bins)->bins) free((*bins)->bins);
	if ((*bins)->colors) free((*bins)->colors);
	free(*bins);
	*bins = NULL;
    }
}

ral_double_color_bins *ral_double_color_bins_create(int n) 
{
    ral_double_color_bins *bins;
    RAL_CHECKM(bins = RAL_MALLOC(ral_double_color_bins), RAL_ERRSTR_OOM);
    bins->n = n;
    bins->bins = NULL;
    bins->colors = NULL;
    RAL_CHECKM(bins->bins = RAL_CALLOC(n-1, double), RAL_ERRSTR_OOM);
    RAL_CHECKM(bins->colors = RAL_CALLOC(n, GDALColorEntry), RAL_ERRSTR_OOM);
    return bins;
 fail:
    ral_double_color_bins_destroy(&bins);
    return NULL;
}

void ral_double_color_bins_destroy(ral_double_color_bins **bins)
{
    if (*bins) {
	if ((*bins)->bins) free((*bins)->bins);
	if ((*bins)->colors) free((*bins)->colors);
	free(*bins);
	*bins = NULL;
    }
}

ral_integer_grid_layer *ral_integer_grid_layer_create()
{
    ral_integer_grid_layer *l;
    RAL_CHECKM(l = RAL_MALLOC(ral_integer_grid_layer), RAL_ERRSTR_OOM);
    l->alpha = 255;
    l->alpha_grid = NULL;
    l->gd = NULL;
    l->palette_type = RAL_PALETTE_GRAYSCALE;
    l->single_color.c4 = l->single_color.c3 = l->single_color.c2 = l->single_color.c1 = 255;
    l->symbol = 0;
    l->symbol_size_scale.min = 0;
    l->symbol_size_scale.max = -1;
    l->color_table = NULL;
    l->string_color_table = NULL;
    l->color_bins = NULL;
    l->color_scale.min = 0;
    l->color_scale.max = -1;
    l->grayscale_base_color.c3 = l->grayscale_base_color.c2 = l->grayscale_base_color.c1 = 0;
    l->grayscale_base_color.c4 = 255;    
    l->scale = RAL_SCALE_GRAY;
    l->hue_at.min = RAL_RAINBOW_HUE_AT_MIN;
    l->hue_at.max = RAL_RAINBOW_HUE_AT_MAX;
    l->invert = RAL_RGB_HUE;
    return l;
fail:
    return NULL;
}

void ral_integer_grid_layer_destroy(ral_integer_grid_layer **l)
{
    if (*l) {
	ral_color_table_destroy(&(*l)->color_table);
	ral_string_color_table_destroy(&(*l)->string_color_table);
	ral_int_color_bins_destroy(&(*l)->color_bins);
	free(*l);
	*l = NULL;
    }
}

ral_real_grid_layer *ral_real_grid_layer_create()
{
    ral_real_grid_layer *l;
    RAL_CHECKM(l = RAL_MALLOC(ral_real_grid_layer), RAL_ERRSTR_OOM);
    l->alpha = 255;
    l->alpha_grid = NULL;
    l->gd = NULL;
    l->palette_type = RAL_PALETTE_GRAYSCALE;
    l->single_color.c4 = l->single_color.c3 = l->single_color.c2 = l->single_color.c1 = 255;
    l->symbol = 0;
    l->symbol_size_scale.min = 0;
    l->symbol_size_scale.max = -1;
    l->color_table = NULL;
    l->string_color_table = NULL;
    l->color_bins = NULL;
    l->color_scale.min = 0;
    l->color_scale.max = -1;
    l->grayscale_base_color.c3 = l->grayscale_base_color.c2 = l->grayscale_base_color.c1 = 0;
    l->grayscale_base_color.c4 = 255;    
    l->scale = RAL_SCALE_GRAY;
    l->hue_at.min = RAL_RAINBOW_HUE_AT_MIN;
    l->hue_at.max = RAL_RAINBOW_HUE_AT_MAX;
    l->invert = RAL_RGB_HUE;
    return l;
fail:
    return NULL;
}

void ral_real_grid_layer_destroy(ral_real_grid_layer **l)
{
    if (*l) {
	ral_color_table_destroy(&(*l)->color_table);
	ral_string_color_table_destroy(&(*l)->string_color_table);
	ral_double_color_bins_destroy(&(*l)->color_bins);
	free(*l);
	*l = NULL;
    }
}

void ral_visual_initialize(ral_visual *v)
{
    v->alpha = 255;
    v->render_as = RAL_RENDER_AS_NATIVE;
    v->palette_type = RAL_PALETTE_SINGLE_COLOR;
    v->symbol = RAL_SYMBOL_CROSS;
    v->symbol_field = RAL_FIELD_FIXED_SIZE;
    v->symbol_pixel_size = RAL_DEFAULT_SYMBOL_PIXEL_SIZE;
    v->symbol_size_scale_int.min = 0;
    v->symbol_size_scale_int.max = -1;
    v->symbol_size_scale_double.min = 0;
    v->symbol_size_scale_double.max = -1;
    v->single_color.c4 = v->single_color.c3 = v->single_color.c2 = v->single_color.c1 = 255;
    v->color_scale_int.min = 0;
    v->color_scale_int.max = -1;
    v->color_scale_double.min = 0;
    v->color_scale_double.max = -1;
    v->grayscale_base_color.c3 = v->grayscale_base_color.c2 = v->grayscale_base_color.c1 = 0;
    v->grayscale_base_color.c4 = 255;    
    v->scale = RAL_SCALE_GRAY;
    v->hue_at.min = RAL_RAINBOW_HUE_AT_MIN;
    v->hue_at.max = RAL_RAINBOW_HUE_AT_MAX;
    v->invert = RAL_RGB_HUE;
    v->color_field = RAL_FIELD_FID;
    v->color_table = NULL;
    v->string_color_table = NULL;
    v->int_bins = NULL;
    v->double_bins = NULL;
}

void ral_visual_finalize(ral_visual v)
{
    ral_color_table_destroy(&v.color_table);
    ral_string_color_table_destroy(&v.string_color_table);
    ral_int_color_bins_destroy(&v.int_bins);
    ral_double_color_bins_destroy(&v.double_bins);
}

#ifdef RAL_HAVE_GDAL
ral_visual_layer *ral_visual_layer_create() 
{
    ral_visual_layer *l;
    RAL_CHECKM(l = RAL_MALLOC(ral_visual_layer), RAL_ERRSTR_OOM);
    ral_visual_initialize(&(l->visualization));
    l->layer = NULL;
    return l;
fail:
    return NULL;
}

void ral_visual_layer_destroy(ral_visual_layer **l)
{
    if (*l) {
	ral_visual_finalize((*l)->visualization);
	free(*l);
	*l = NULL;
    }
}

ral_visual_feature_table *ral_visual_feature_table_create(int size)
{
    ral_visual_feature_table *t = NULL;
    int i;
    RAL_CHECKM(t = RAL_MALLOC(ral_visual_feature_table), RAL_ERRSTR_OOM);
    t->size = size;
    RAL_CHECKM(t->features = RAL_CALLOC(size, ral_visual_feature), RAL_ERRSTR_OOM);
    for (i = 0; i < size; i++) {
	t->features[i].feature = NULL;
	ral_visual_initialize(&(t->features[i].visualization));
    }
    return t;
fail:
    ral_visual_feature_table_destroy(&t);
    return NULL;
}

void ral_visual_feature_table_destroy(ral_visual_feature_table **t)
{
    if (*t) {
	if ((*t)->features) {
	    int i;
	    for (i = 0; i < (*t)->size; i++) {
		ral_visual_finalize((*t)->features[i].visualization);
	    }
	    free((*t)->features);
	}
	free(*t);
	*t = NULL;
    }
}
#endif
