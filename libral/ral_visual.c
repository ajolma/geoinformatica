#include "config.h"
#include "msg.h"
#include "ral/ral.h"
#include "private/ral.h"
#include <string.h>

#ifndef HAVE_STRDUPx
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
    RAL_CHECKM(table->keys = RAL_CALLOC(n, long), RAL_ERRSTR_OOM);
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

int ral_color_table_set(ral_color_table *table, int i, long key, GDALColorEntry color)
{
    RAL_CHECKM(i >= 0 AND i < table->n, RAL_ERRSTR_IOB);
    table->keys[i] = key;
    table->colors[i] = color;
    return 1;
 fail:
    return 0;
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

int ral_string_color_table_set(ral_string_color_table *table, int i, char *key, GDALColorEntry color)
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

ral_rule *ral_rule_create()
{
    ral_rule *r;
    RAL_CHECKM(r = RAL_MALLOC(ral_rule), RAL_ERRSTR_OOM);
    r->name = NULL;
    r->scale = 0;
    r->filter = 0;
    r->property = NULL;
    r->svalue = NULL;
    return r;
fail:
    return NULL;
}

void ral_rule_destroy(ral_rule **r)
{
    if (*r) {
	if ((*r)->name) free((*r)->name);
	if ((*r)->property) free((*r)->property);
	if ((*r)->svalue) free((*r)->svalue);
	free(*r);
	*r = NULL;
    }
}

int ral_rule_set_name(ral_rule *r, char *name)
{
    if (r->name) free(r->name);
    RAL_CHECKM(r->name = strdup(name), RAL_ERRSTR_OOM);
    return 1;
fail:
    return 0;
}

void ral_rule_set_elsefilter(ral_rule *r)
{
    r->filter = 2;
}

int ral_rule_set_filter_i(ral_rule *r, char *property, int cmp, int value)
{
    if (r->property) free(r->property);
    RAL_CHECKM(r->property = strdup(property), RAL_ERRSTR_OOM);
    return 1;
fail:
    return 0;
}

int ral_rule_set_filter_n(ral_rule *r, char *property, int cmp, double value)
{
    if (r->property) free(r->property);
    RAL_CHECKM(r->property = strdup(property), RAL_ERRSTR_OOM);
    return 1;
fail:
    return 0;
}

int ral_rule_set_filter_s(ral_rule *r, char *property, int cmp, char *value)
{
    if (r->property) free(r->property);
    RAL_CHECKM(r->property = strdup(property), RAL_ERRSTR_OOM);
    if (r->svalue) free(r->svalue);
    RAL_CHECKM(r->svalue = strdup(value), RAL_ERRSTR_OOM);
    return 1;
fail:
    return 0;
}

void visual_initialize(visual *v)
{
    v->alpha = 255;
    v->symbol = RAL_SYMBOL_CROSS;
    v->symbol_size = RAL_DEFAULT_SYMBOL_PIXEL_SIZE;

    v->symbol_size_property = NULL;
    v->symbol_size_field = 0;
    v->symbol_size_field_type = 0;
    v->symbol_size_scale_int.min = 0;
    v->symbol_size_scale_int.max = -1;
    v->symbol_size_scale_double.min = 0;
    v->symbol_size_scale_double.max = -1;
    
    v->palette_type = RAL_PALETTE_SINGLE_COLOR;

    v->single_color.c4 = v->single_color.c3 = v->single_color.c2 = v->single_color.c1 = 255;
    v->color_property = NULL;
    v->color_field = 0;
    v->color_field_type = 0;
    
    v->color_scale_int.min = 0;
    v->color_scale_int.max = -1;
    v->color_scale_double.min = 0;
    v->color_scale_double.max = -1;

    v->hue_at.min = RAL_RAINBOW_HUE_AT_MIN;
    v->hue_at.max = RAL_RAINBOW_HUE_AT_MAX;
    v->invert = RAL_RGB_HUE;
    
    v->grayscale_base_color.c3 = v->grayscale_base_color.c2 = v->grayscale_base_color.c1 = 0;
    v->grayscale_base_color.c4 = 255;
    v->scale = RAL_SCALE_GRAY;

    v->color_table = NULL;
    v->string_color_table = NULL;

    v->int_bins = NULL;
    v->double_bins = NULL;
}

void visual_finalize(visual *v) 
{
    if (v->symbol_size_property) free(v->symbol_size_property);
    if (v->color_property) free(v->color_property);
    if (v->color_table) ral_color_table_destroy(&(v->color_table));
    if (v->string_color_table) ral_string_color_table_destroy(&(v->string_color_table));
    if (v->int_bins) ral_int_color_bins_destroy(&(v->int_bins));
    if (v->double_bins) ral_double_color_bins_destroy(&(v->double_bins));
}

ral_visual *ral_visual_create()
{
    ral_visual *v;
    RAL_CHECKM(v = RAL_MALLOC(ral_visual), RAL_ERRSTR_OOM);
    v->n = 0;
    v->rules = NULL;
    v->visuals = NULL;
    /* the default rule */
    return v;
fail:
    return NULL;
}

void ral_visual_destroy(ral_visual **v)
{
    if (*v) {
	ral_visual *x = *v;
	if (x->rules) {
	    for (int i = 0; i < x->n; i++) {
		ral_rule_destroy(&(x->rules[i]));
	    }
	    free(x->rules);
	}
	if (x->visuals) {
	    for (int i = 0; i < x->n; i++) {
		visual_finalize(&(x->visuals[i]));
	    }
	    free(x->visuals);
	}
	*v = NULL;
    }
}

int ral_visual_add_rule(ral_visual *v, ral_rule *r)
{
    ral_rule **rules = v->rules;
    visual *visuals = v->visuals;
    int n = v->n;
    v->n++;
    RAL_CHECKM(v->rules = RAL_CALLOC(v->n, ral_rule*), RAL_ERRSTR_OOM);
    RAL_CHECKM(v->visuals = RAL_CALLOC(v->n, visual), RAL_ERRSTR_OOM);
    for (int i = 0; i < n; i++) {
	v->rules[i] = rules[i];
	v->visuals[i] = visuals[i];
    }
    v->rules[v->n-1] = r;
    visual_initialize(&(v->visuals[v->n-1]));
    return 1;
fail:
    return 0;
}

void ral_visual_set_alpha(ral_visual *v, int a)
{
    v->visuals[v->n-1].alpha = a;
}

void ral_visual_set_symbol(ral_visual *v, int s)
{
    
}

void ral_visual_set_symbol_size(ral_visual *v, int s)
{
}

void ral_visual_set_symbol_size_property(ral_visual *v, char *p)
{
    v->visuals[v->n-1].symbol_size_property = strdup(p);
}

void ral_visual_set_symbol_size_scale(ral_visual *v, double min, double max)
{

}

void ral_visual_set_palette_type(ral_visual *v, int t)
{
}

void ral_visual_set_single_color(ral_visual *v, int r, int g, int b, int a)
{
}

void ral_visual_set_color_property(ral_visual *v, char *p)
{
    v->visuals[v->n-1].color_property = strdup(p);
}

void ral_visual_set_color_size_scale(ral_visual *v, double min, double max)
{
}

void ral_visual_set_hue_range(ral_visual *v, int min, int max, int invert)
{
}

void ral_visual_set_grayscale_base_color(ral_visual *v, int r, int g, int b, int scale_type)
{
}

#ifdef RAL_HAVE_GDAL

ral_visual_layer *ral_visual_layer_create() 
{
    ral_visual_layer *l = NULL;
    RAL_CHECKM(l = RAL_MALLOC(ral_visual_layer), RAL_ERRSTR_OOM);
    RAL_CHECKM(l->visualization = ral_visual_create(), RAL_ERRSTR_OOM);
    l->layer = NULL;
    return l;
fail:
    if (l) ral_visual_layer_destroy(&l);
    return NULL;
}

void ral_visual_layer_destroy(ral_visual_layer **l)
{
    if (*l) {
	if ((*l)->visualization) ral_visual_destroy(&((*l)->visualization));
	free(*l);
	*l = NULL;
    }
}

ral_visual_feature_table *ral_visual_feature_table_create(int size)
{
    ral_visual_feature_table *t = NULL;
    RAL_CHECKM(t = RAL_MALLOC(ral_visual_feature_table), RAL_ERRSTR_OOM);
    t->features = NULL;
    RAL_CHECKM(t->visualization = ral_visual_create(), RAL_ERRSTR_OOM);
    t->size = size;
    RAL_CHECKM(t->features = RAL_CALLOC(size, OGRFeatureH), RAL_ERRSTR_OOM);
    return t;
fail:
    ral_visual_feature_table_destroy(&t);
    return NULL;
}

void ral_visual_feature_table_destroy(ral_visual_feature_table **t)
{
    if (*t) {
	if ((*t)->visualization) ral_visual_destroy(&((*t)->visualization));
	if ((*t)->features) free((*t)->features);
	free(*t);
	*t = NULL;
    }
}

#endif
