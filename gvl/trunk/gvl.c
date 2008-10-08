#include "gvl_private.h"

#include "gvl.h"


gvl_point gvl_point_init(double x, double y)
{
    gvl_point p;
    p.x = x;
    p.y = y;
    return p;
}


gvl_color gvl_color_init (double red, double green, double blue, double alpha)
{
    gvl_color color;
    color.red = red;
    color.green = green;
    color.blue = blue;
    color.alpha = alpha;
    return color;
}


gvl_mark *gvl_mark_create(gvl_mark_type type,
			  double size,
			  gvl_color stroke,
			  double stroke_width)
{
    gvl_mark *mark = NULL;
    GVL_TEST_POINTER(mark = GVL_MALLOC(gvl_mark));
    mark->type = type;
    mark->size = size;
    mark->stroke = stroke;
    mark->stroke_width = stroke_width;
    mark->filled = 0;
    return mark;
 fail:
    gvl_mark_destroy(&mark);
    return NULL;
}


gvl_mark *gvl_mark_create_filled(gvl_mark_type type,
				 double size,
				 gvl_color stroke,
				 double stroke_width,
				 gvl_color fill)
{
    gvl_mark *mark = NULL;
    GVL_TEST_POINTER(mark = GVL_MALLOC(gvl_mark));
    mark->type = type;
    mark->size = size;
    mark->stroke = stroke;
    mark->stroke_width = stroke_width;
    mark->filled = 1;
    mark->fill = fill;
    return mark;
 fail:
    gvl_mark_destroy(&mark);
    return NULL;
}


void gvl_mark_destroy(gvl_mark **mark)
{
    if (*mark) {
	GVL_FREE(*mark);
    }
}


void gvl_draw_mark(cairo_t *cr, gvl_mark *mark, double x, double y)
{
    switch (mark->type) {
    case GVL_MARK_CROSS:
	cairo_move_to(cr, x-mark->size/2, y);
	cairo_rel_line_to(cr, mark->size, 0.);
	cairo_rel_move_to(cr, -mark->size/2, -mark->size/2);
	cairo_rel_line_to(cr, 0., mark->size);
	break;
    default:
	return;
    }
    cairo_set_line_width(cr, mark->stroke_width);
    cairo_set_source_rgba(cr, mark->stroke.red, mark->stroke.green, mark->stroke.blue, mark->stroke.alpha);
    if (mark->filled) {
	cairo_stroke_preserve(cr);
	cairo_set_source_rgba(cr, mark->fill.red, mark->fill.green, mark->fill.blue, mark->fill.alpha);
	cairo_fill(cr);
    } else {
	cairo_stroke(cr);
    }
}


gvl_dashes *gvl_dashes_create(int num_dashes)
{
    gvl_dashes *dashes = NULL;
    GVL_TEST_POINTER(dashes = GVL_MALLOC(gvl_dashes));
    dashes->num_dashes = num_dashes;
    GVL_TEST_POINTER(dashes->dashes = GVL_CALLOC(dashes->num_dashes, double));
    return dashes;
 fail:
    gvl_dashes_destroy(&dashes);
    return NULL;
}


gvl_dashes *gvl_dashes_clone(gvl_dashes *dashes)
{
    if (dashes == NULL)
	return NULL;
    gvl_dashes *clone = NULL;
    GVL_TEST_POINTER(clone = GVL_MALLOC(gvl_dashes));
    clone->num_dashes = dashes->num_dashes;
    GVL_TEST_POINTER(clone->dashes = GVL_CALLOC(clone->num_dashes, double));
    int i;
    for (i = 0; i < clone->num_dashes; i++)
	clone->dashes[i] = dashes->dashes[i];
    return clone;
 fail:
    gvl_dashes_destroy(&clone);
    return NULL;
}


void gvl_dashes_destroy(gvl_dashes **dashes)
{
    if (*dashes) {
	GVL_FREE((*dashes)->dashes);
	GVL_FREE(*dashes);
    }
}


gvl_line_style *gvl_line_style_create(gvl_color color,
				      double width,
				      cairo_line_join_t line_join,
				      cairo_line_cap_t line_cap,
				      double miter_limit,
				      gvl_dashes *dashes)
{
    gvl_line_style *line_style = NULL;
    GVL_TEST_POINTER(line_style = GVL_MALLOC(gvl_line_style));
    line_style->color = color;
    line_style->width = width;
    line_style->line_join = line_join;
    line_style->line_cap = line_cap;
    line_style->miter_limit = miter_limit;
    line_style->dashes = dashes;
    line_style->next = NULL;
    return line_style;
 fail:
    gvl_line_style_destroy(&line_style);
    return NULL;
}


gvl_line_style *gvl_line_style_create_plain(gvl_color color)
{
    gvl_line_style *line_style = NULL;
    GVL_TEST_POINTER(line_style = GVL_MALLOC(gvl_line_style));
    line_style->color = color;
    line_style->width = 1;
    line_style->line_join = CAIRO_LINE_JOIN_MITER;
    line_style->line_cap = CAIRO_LINE_CAP_BUTT;
    line_style->miter_limit = 10.0;
    line_style->dashes = NULL;
    line_style->next = NULL;
    return line_style;
 fail:
    gvl_line_style_destroy(&line_style);
    return NULL;
}


gvl_line_style *gvl_line_style_clone(gvl_line_style *style)
{
    if (style == NULL)
	return NULL;
    gvl_line_style *clone = NULL;
    GVL_TEST_POINTER(clone = GVL_MALLOC(gvl_line_style));
    clone->color = style->color;
    clone->width = style->width;
    clone->line_join = style->line_join;
    clone->line_cap = style->line_cap;
    clone->miter_limit = style->miter_limit;
    clone->dashes = gvl_dashes_clone(style->dashes);
    if (style->next)
	clone->next = gvl_line_style_clone(style->next);
    else
	clone->next = NULL;
    return clone;
 fail:
    gvl_line_style_destroy(&clone);
    return NULL;
}


void gvl_line_style_destroy(gvl_line_style **line_style)
{
    if (*line_style) {
	gvl_line_style_destroy(&(*line_style)->next);
	gvl_dashes_destroy(&(*line_style)->dashes);
	GVL_FREE(*line_style);
    }
}


void gvl_add_line_style(gvl_line_style *line_style,
			gvl_line_style *next)
{
    gvl_line_style *s = line_style;
    while (s->next)
	s = line_style->next;
    s->next = next;
}


void gvl_set_line_style(cairo_t *cr, gvl_line_style *style)
{
    cairo_set_source_rgba(cr, style->color.red, style->color.green, style->color.blue, style->color.alpha);
    cairo_set_line_width(cr, style->width);
    cairo_set_line_join(cr, style->line_join);
    cairo_set_line_cap(cr, style->line_cap);
    cairo_set_miter_limit(cr, style->miter_limit);
    if (style->dashes) 
	cairo_set_dash(cr, style->dashes->dashes, style->dashes->num_dashes, style->dashes->offset);
}

gvl_line_symbolizer *gvl_line_symbolizer_create();
gvl_line_symbolizer *gvl_line_symbolizer_clone(gvl_line_symbolizer *sr);
void gvl_line_symbolizer_destroy(gvl_line_symbolizer **sr);

gvl_polygon_symbolizer *gvl_polygon_symbolizer_create();
gvl_polygon_symbolizer *gvl_polygon_symbolizer_clone(gvl_polygon_symbolizer *sr);
void gvl_polygon_symbolizer_destroy(gvl_polygon_symbolizer **sr);

gvl_point_symbolizer *gvl_point_symbolizer_create();
gvl_point_symbolizer *gvl_point_symbolizer_clone(gvl_point_symbolizer *sr);
void gvl_point_symbolizer_destroy(gvl_point_symbolizer **sr);

gvl_text_symbolizer *gvl_text_symbolizer_create();
gvl_text_symbolizer *gvl_text_symbolizer_clone(gvl_text_symbolizer *sr);
void gvl_text_symbolizer_destroy(gvl_text_symbolizer **sr);

gvl_raster_symbolizer *gvl_raster_symbolizer_create();
gvl_raster_symbolizer *gvl_raster_symbolizer_clone(gvl_raster_symbolizer *sr);
void gvl_raster_symbolizer_destroy(gvl_raster_symbolizer **sr);


gvl_symbolizer *gvl_symbolizer_create(gvl_symbolizer_class symbolizer_class)
{
    switch(symbolizer_class) {
    GVL_SYMBOLIZER_POINT:
	return (gvl_symbolizer *)gvl_point_symbolizer_create();
    GVL_SYMBOLIZER_LINE:
	return (gvl_symbolizer *)gvl_line_symbolizer_create();
    GVL_SYMBOLIZER_POLYGON:
	return (gvl_symbolizer *)gvl_polygon_symbolizer_create();
    GVL_SYMBOLIZER_TEXT:
	return (gvl_symbolizer *)gvl_text_symbolizer_create();
    GVL_SYMBOLIZER_RASTER:
	return (gvl_symbolizer *)gvl_raster_symbolizer_create();
    }
}


gvl_symbolizer *gvl_symbolizer_clone(gvl_symbolizer *symbolizer)
{
    switch(symbolizer->my_class) {
    GVL_SYMBOLIZER_POINT:
	return (gvl_symbolizer *)gvl_point_symbolizer_clone((gvl_point_symbolizer *)symbolizer);
    GVL_SYMBOLIZER_LINE:
	return (gvl_symbolizer *)gvl_line_symbolizer_clone((gvl_line_symbolizer *)symbolizer);
    GVL_SYMBOLIZER_POLYGON:
	return (gvl_symbolizer *)gvl_polygon_symbolizer_clone((gvl_polygon_symbolizer *)symbolizer);
    GVL_SYMBOLIZER_TEXT:
	return (gvl_symbolizer *)gvl_text_symbolizer_clone((gvl_text_symbolizer *)symbolizer);
    GVL_SYMBOLIZER_RASTER:
	return (gvl_symbolizer *)gvl_raster_symbolizer_clone((gvl_raster_symbolizer *)symbolizer);
    }
}


void gvl_symbolizer_destroy(gvl_symbolizer **symbolizer)
{
    switch((*symbolizer)->my_class) {
    GVL_SYMBOLIZER_POINT:
	return gvl_point_symbolizer_destroy((gvl_point_symbolizer **)symbolizer);
    GVL_SYMBOLIZER_LINE:
	return gvl_line_symbolizer_destroy((gvl_line_symbolizer **)symbolizer);
    GVL_SYMBOLIZER_POLYGON:
	return gvl_polygon_symbolizer_destroy((gvl_polygon_symbolizer **)symbolizer);
    GVL_SYMBOLIZER_TEXT:
	return gvl_text_symbolizer_destroy((gvl_text_symbolizer **)symbolizer);
    GVL_SYMBOLIZER_RASTER:
	return gvl_raster_symbolizer_destroy((gvl_raster_symbolizer **)symbolizer);
    }
}


gvl_line_symbolizer *gvl_line_symbolizer_create()
{
    gvl_line_symbolizer *sr = NULL;
    GVL_TEST_POINTER(sr = GVL_MALLOC(gvl_line_symbolizer));
    sr->base.my_class = GVL_SYMBOLIZER_LINE;
    sr->base.name = NULL;
    sr->base.next = NULL;
    sr->style = NULL;
    sr->mark = NULL;
    GVL_TEST_POINTER(sr->style = gvl_line_style_create_plain(gvl_color_init(0,0,0,1)));
    return sr;
 fail:
    gvl_line_symbolizer_destroy(&sr);
    return NULL;
}


gvl_line_symbolizer *gvl_line_symbolizer_clone(gvl_line_symbolizer *sr)
{
    if (sr == NULL)
	return NULL;
    gvl_line_symbolizer *clone = NULL;
    GVL_TEST_POINTER(clone = GVL_MALLOC(gvl_line_symbolizer));
    clone->style = gvl_line_style_clone(sr->style);
    clone->mark = sr->mark;
    return clone;
 fail:
    gvl_line_symbolizer_destroy(&clone);
    return NULL;
}


void gvl_line_symbolizer_destroy(gvl_line_symbolizer **sr)
{
    if (*sr) {
	gvl_line_style_destroy(&(*sr)->style);
	GVL_FREE(*sr);
    }
}


gvl_polygon_symbolizer *gvl_polygon_symbolizer_create()
{
    gvl_polygon_symbolizer *sr = NULL;
    GVL_TEST_POINTER(sr = GVL_MALLOC(gvl_polygon_symbolizer));
    sr->base.my_class = GVL_SYMBOLIZER_POLYGON;
    sr->base.name = NULL;
    sr->base.next = NULL;
    sr->color = gvl_color_init(0, 0, 0, 1);
    sr->pattern = NULL;
    sr->border = NULL;
    return sr;
 fail:
    gvl_polygon_symbolizer_destroy(&sr);
    return NULL;
}


gvl_polygon_symbolizer *gvl_polygon_symbolizer_clone(gvl_polygon_symbolizer *sr)
{
    if (sr == NULL)
	return NULL;
    gvl_polygon_symbolizer *clone = NULL;
    GVL_TEST_POINTER(clone = GVL_MALLOC(gvl_polygon_symbolizer));
    clone->color = sr->color;
    clone->pattern = cairo_pattern_reference(sr->pattern);
    clone->border = gvl_line_symbolizer_clone(sr->border);
    return clone;
 fail:
    gvl_polygon_symbolizer_destroy(&clone);
    return NULL;
}


void gvl_polygon_symbolizer_destroy(gvl_polygon_symbolizer **sr)
{
    if (*sr) {
	if ((*sr)->pattern)
	    cairo_pattern_destroy((*sr)->pattern);
	gvl_line_symbolizer_destroy(&(*sr)->border);
	GVL_FREE(*sr);
    }
}


gvl_point_symbolizer *gvl_point_symbolizer_create()
{
    gvl_point_symbolizer *sr = NULL;
    GVL_TEST_POINTER(sr = GVL_MALLOC(gvl_point_symbolizer));
    sr->base.my_class = GVL_SYMBOLIZER_POINT;
    sr->base.name = NULL;
    sr->base.next = NULL;
    sr->graphic = NULL;
    sr->mark = NULL;
    sr->rotation = 0;
    sr->anchor_point = gvl_point_init(0, 0);
    sr->displacement = gvl_point_init(0, 0);
    return sr;
 fail:
    gvl_point_symbolizer_destroy(&sr);
    return NULL;
}


gvl_point_symbolizer *gvl_point_symbolizer_clone(gvl_point_symbolizer *sr)
{
    if (sr == NULL)
	return NULL;
    gvl_point_symbolizer *clone = NULL;
    GVL_TEST_POINTER(clone = GVL_MALLOC(gvl_point_symbolizer));
    clone->graphic = sr->graphic;
    clone->mark = sr->mark;
    clone->rotation = sr->rotation;
    clone->anchor_point = sr->anchor_point;
    clone->displacement = sr->displacement;
    return clone;
 fail:
    gvl_point_symbolizer_destroy(&clone);
    return NULL;
}


void gvl_point_symbolizer_destroy(gvl_point_symbolizer **sr)
{
    if (*sr) {
	if ((*sr)->graphic)
	    g_object_unref((*sr)->graphic);
	GVL_FREE(*sr);
    }
}


void gvl_point_symbolizer_set_rotation(gvl_point_symbolizer *sr, double rotation)
{
    sr->rotation = rotation;
}


double gvl_point_symbolizer_get_rotation(gvl_point_symbolizer *sr)
{
    return sr->rotation;
}


void gvl_point_symbolizer_set_anchor_point(gvl_point_symbolizer *sr, double x, double y)
{
    sr->anchor_point.x = x;
    sr->anchor_point.y = y;
}


void gvl_point_symbolizer_get_anchor_point(gvl_point_symbolizer *sr, double *x, double *y)
{
    *x = sr->anchor_point.x;
    *y = sr->anchor_point.y;
}


void gvl_point_symbolizer_set_displacement(gvl_point_symbolizer *sr, double x, double y)
{
    sr->displacement.x = x;
    sr->displacement.y = y;
}


void gvl_point_symbolizer_get_displacement(gvl_point_symbolizer *sr, double *x, double *y)
{
    *x = sr->displacement.x;
    *y = sr->displacement.y;
}


gvl_text_symbolizer *gvl_text_symbolizer_create()
{
    gvl_text_symbolizer *sr = NULL;
    GVL_TEST_POINTER(sr = GVL_MALLOC(gvl_text_symbolizer));
    sr->base.my_class = GVL_SYMBOLIZER_TEXT;
    sr->base.name = NULL;
    sr->base.next = NULL;
    sr->label = NULL;
    sr->font = NULL;
    sr->color = gvl_color_init(0, 0, 0, 1);
    sr->rotation = 0;
    sr->anchor_point = gvl_point_init(0, 0);
    sr->displacement = gvl_point_init(0, 0);
    sr->perpendicular_offset = 0;
    sr->is_repeated = 0;
    sr->initial_gap = 0;
    sr->is_aligned = 1;
    sr->generalize_line = 0;
    sr->halo_radius = 0;
    sr->halo = NULL;
    return sr;
 fail:
    gvl_text_symbolizer_destroy(&sr);
    return NULL;
}


gvl_text_symbolizer *gvl_text_symbolizer_clone(gvl_text_symbolizer *sr)
{
    if (sr == NULL)
	return NULL;
    gvl_text_symbolizer *clone = NULL;
    GVL_TEST_POINTER(clone = GVL_MALLOC(gvl_text_symbolizer));
    clone->label = sr->label;
    clone->font = pango_font_description_copy(sr->font);
    clone->color = sr->color;
    clone->rotation = sr->rotation;
    clone->anchor_point = sr->anchor_point;
    clone->displacement = sr->displacement;
    clone->perpendicular_offset = sr->perpendicular_offset;
    clone->is_repeated = sr->is_repeated;
    clone->initial_gap = sr->initial_gap;
    clone->is_aligned = sr->is_aligned;
    clone->generalize_line = sr->generalize_line;
    clone->halo_radius = sr->halo_radius;
    clone->halo = gvl_polygon_symbolizer_clone(sr->halo);
    return clone;
 fail:
    gvl_text_symbolizer_destroy(&clone);
    return NULL;
}


void gvl_text_symbolizer_destroy(gvl_text_symbolizer **sr)
{
    if (*sr) {
	if ((*sr)->font)
	    pango_font_description_free((*sr)->font);
	if ((*sr)->halo)
	    gvl_polygon_symbolizer_destroy(&(*sr)->halo);
	GVL_FREE(*sr);
    }
}


void gvl_text_symbolizer_set_rotation(gvl_text_symbolizer *sr, double rotation)
{
    sr->rotation = rotation;
}


double gvl_text_symbolizer_get_rotation(gvl_text_symbolizer *sr)
{
    return sr->rotation;
}


void gvl_text_symbolizer_set_anchor_point(gvl_text_symbolizer *sr, double x, double y)
{
    sr->anchor_point.x = x;
    sr->anchor_point.y = y;
}


void gvl_text_symbolizer_get_anchor_point(gvl_text_symbolizer *sr, double *x, double *y)
{
    *x = sr->anchor_point.x;
    *y = sr->anchor_point.y;
}


void gvl_text_symbolizer_set_displacement(gvl_text_symbolizer *sr, double x, double y)
{
    sr->displacement.x = x;
    sr->displacement.y = y;
}


void gvl_text_symbolizer_get_displacement(gvl_text_symbolizer *sr, double *x, double *y)
{
    *x = sr->displacement.x;
    *y = sr->displacement.y;
}


gvl_raster_symbolizer *gvl_raster_symbolizer_create()
{
    gvl_raster_symbolizer *sr = NULL;
    GVL_TEST_POINTER(sr = GVL_MALLOC(gvl_raster_symbolizer));
    sr->base.my_class = GVL_SYMBOLIZER_RASTER;
    sr->base.name = NULL;
    sr->base.next = NULL;
    sr->color = gvl_color_init(0, 0, 0, 1);
    return sr;
 fail:
    gvl_raster_symbolizer_destroy(&sr);
    return NULL;
}


gvl_raster_symbolizer *gvl_raster_symbolizer_clone(gvl_raster_symbolizer *sr)
{
    if (sr == NULL)
	return NULL;
    gvl_raster_symbolizer *clone = NULL;
    GVL_TEST_POINTER(clone = GVL_MALLOC(gvl_raster_symbolizer));
    clone->color = sr->color;
    return clone;
 fail:
    gvl_raster_symbolizer_destroy(&clone);
    return NULL;
}


void gvl_raster_symbolizer_destroy(gvl_raster_symbolizer **sr)
{
    if (*sr) {
	GVL_FREE(*sr);
    }
}


char *gvl_label(char *label_mark_up, OGRFeatureH feature)
{
    char *test = malloc(5);
    strcpy(test, "test");
    return test;
}


void gvl_set_polygon_symbolizer(cairo_t *cr, gvl_polygon_symbolizer *sr)
{
    if (sr->pattern) {
	cairo_set_source(cr, sr->pattern);
    } else {
	cairo_set_source_rgba(cr, sr->color.red, sr->color.green, sr->color.blue, sr->color.alpha);
    }
    cairo_set_fill_rule(cr, CAIRO_FILL_RULE_EVEN_ODD);
}


void gvl_set_point_symbolizer(cairo_t *cr, gvl_point_symbolizer *sr)
{
}


void gvl_set_text_symbolizer(cairo_t *cr, gvl_text_symbolizer *sr)
{
}


gvl_symbolizer_table *gvl_symbolizer_table_create()
{
    gvl_symbolizer_table *table = NULL;
    GVL_TEST_POINTER(table = GVL_MALLOC(gvl_symbolizer_table));
    table->size = 20;
    table->n = 0;
    table->classification_function = NULL;
    table->value_function = NULL;
    table->value_min = 0;
    table->value_max = 0;
    GVL_TEST_POINTER(table->symbolizers = GVL_CALLOC(table->size, gvl_symbolizer*));
    return table;
 fail:
    gvl_symbolizer_table_destroy(&table);
    return NULL;
}


gvl_symbolizer_table *gvl_symbolizer_table_create_with_classes(gvl_classification_function_type *classification_function)
{
    gvl_symbolizer_table *table = NULL;
    GVL_TEST_POINTER(table = GVL_MALLOC(gvl_symbolizer_table));
    table->size = 20;
    table->n = 0;
    table->classification_function = classification_function;
    table->value_function = NULL;
    table->value_min = 0;
    table->value_max = 0;
    GVL_TEST_POINTER(table->symbolizers = GVL_CALLOC(table->size, gvl_symbolizer*));
    return table;
 fail:
    gvl_symbolizer_table_destroy(&table);
    return NULL;
}


gvl_symbolizer_table *gvl_symbolizer_table_create_with_continuous(gvl_value_function_type *value_function,
								  double value_min,
								  double value_max)
{
    gvl_symbolizer_table *table = NULL;
    GVL_TEST_POINTER(table = GVL_MALLOC(gvl_symbolizer_table));
    table->size = 20;
    table->n = 0;
    table->classification_function = NULL;
    table->value_function = value_function;
    table->value_min = value_min;
    table->value_max = value_max;
    GVL_TEST_POINTER(table->symbolizers = GVL_CALLOC(table->size, gvl_symbolizer*));
    return table;
 fail:
    gvl_symbolizer_table_destroy(&table);
    return NULL;
}


void gvl_symbolizer_table_destroy(gvl_symbolizer_table **table)
{
    if (*table) {
	if ((*table)->symbolizers) {
	    int i;
	    for (i = 0; i < (*table)->n; i++) {
		gvl_symbolizer_destroy(&(*table)->symbolizers[i]);
	    }
	    free((*table)->symbolizers);
	}
	GVL_FREE(*table);
    }
}


gvl_status gvl_symbolizer_table_add(gvl_symbolizer_table *table, gvl_symbolizer *sr)
{
    if (table->n >= table->size) {
	table->size += 20;
	GVL_TEST_POINTER(table->symbolizers = GVL_REALLOC(table->symbolizers, table->size, gvl_symbolizer*));
    }
    table->symbolizers[table->n++] = sr;
    return GVL_STATUS_SUCCESS;
 fail:
    return GVL_STATUS_OUT_OF_MEMORY;
}


gvl_canvas *gvl_canvas_create(cairo_surface_t *surface,
			      double width,
			      double height,
			      double map_min_x,
			      double map_min_y,
			      double map_max_x,
			      double map_max_y)
{
    gvl_canvas *canvas = NULL;
    GVL_TEST_POINTER(canvas = GVL_MALLOC(gvl_canvas));

    canvas->surface = surface;
    canvas->cr = cairo_create(surface);
	
    canvas->width = width;
    canvas->height = height;

    canvas->viewport.min.x = map_min_x;
    canvas->viewport.min.y = map_min_y;
    canvas->viewport.max.x = map_max_x;
    canvas->viewport.max.y = map_max_y;

    if (width/(map_max_x-map_min_x) < height/(map_max_y-map_min_y)) {
	canvas->scale = width/(map_max_x-map_min_x);
	canvas->viewport.max.y = canvas->viewport.min.y + height/canvas->scale;
    } else {
	canvas->scale = height/(map_max_y-map_min_y);
	canvas->viewport.max.x = canvas->viewport.min.x + width/canvas->scale;
    }

    return canvas;
 fail:
    gvl_canvas_destroy(&canvas);
    return NULL;
}


void gvl_canvas_destroy(gvl_canvas **canvas)
{
    if (*canvas) {
	cairo_surface_show_page((*canvas)->surface);
	cairo_surface_flush((*canvas)->surface);
	cairo_surface_finish((*canvas)->surface);
	cairo_surface_destroy((*canvas)->surface);
	cairo_destroy((*canvas)->cr);
    }
    GVL_FREE(*canvas);
}


gvl_point gvl_transform(gvl_canvas *canvas, double x, double y)
{
    gvl_point p;
    p.x = (x-canvas->viewport.min.x)*canvas->scale;
    p.y = canvas->height-(y-canvas->viewport.min.y)*canvas->scale;
    return p;
}


void gvl_canvas_rectangle(gvl_canvas *canvas, double x, double y, double width, double height)
{
    gvl_point min = gvl_transform(canvas, x, y);
    width *= canvas->scale;
    height *= canvas->scale;
    cairo_rectangle(canvas->cr, min.x, min.y, width, height);
}


void gvl_canvas_geometry(gvl_canvas *canvas, gvl_geometry *geometry)
{
}


void gvl_canvas_ogr_geometry(gvl_canvas *canvas, OGRGeometryH geometry)
{
    int n = OGR_G_GetGeometryCount(geometry);
    if (n > 0) {
	int i;
	for (i = 0; i < n; i++)
	    gvl_canvas_geometry(canvas, OGR_G_GetGeometryRef(geometry, i));
    } else {
	n = OGR_G_GetPointCount(geometry);
	gvl_point p;
	p = gvl_transform(canvas, OGR_G_GetX(geometry, 0), OGR_G_GetY(geometry, 0));
	cairo_move_to(canvas->cr, p.x, p.y);
	int i;
	for (i = 1; i < n; i++) {
	    p = gvl_transform(canvas, OGR_G_GetX(geometry, i), OGR_G_GetY(geometry, i));
	    cairo_line_to(canvas->cr, p.x, p.y);
	}
    }
}


void gvl_canvas_geometry_mark_vertices(gvl_canvas *canvas, gvl_geometry *geometry, gvl_mark *mark)
{
}


void gvl_canvas_ogr_geometry_mark_vertices(gvl_canvas *canvas, OGRGeometryH geometry, gvl_mark *mark)
{
    int n = OGR_G_GetGeometryCount(geometry); 
    if (n > 0) {
	int i;
	for (i = 0; i < n; i++)
	    gvl_canvas_geometry_mark_vertices(canvas, OGR_G_GetGeometryRef(geometry, i), mark);
    } else {
	n = OGR_G_GetPointCount(geometry);
	gvl_point p;
	p = gvl_transform(canvas, OGR_G_GetX(geometry, 0), OGR_G_GetY(geometry, 0));
	gvl_draw_mark(canvas->cr, mark, p.x, p.y);
	int i;
	for (i = 1; i < n; i++) {
	    p = gvl_transform(canvas, OGR_G_GetX(geometry, i), OGR_G_GetY(geometry, i));
	    gvl_draw_mark(canvas->cr, mark, p.x, p.y);
	}
    }
}


void gvl_canvas_stroke_line(gvl_canvas *canvas, gvl_geometry *geometry, gvl_line_symbolizer *sr)
{
}


void gvl_canvas_stroke_ogr_line(gvl_canvas *canvas, OGRGeometryH geometry, gvl_line_symbolizer *sr)
{
    gvl_line_style *style = sr->style;
    do {
	gvl_set_line_style(canvas->cr, style);
	style = style->next;
	if (style)
	    cairo_stroke_preserve(canvas->cr);
	else
	    cairo_stroke(canvas->cr);
    } while (style);
    if (sr->mark)
	gvl_canvas_geometry_mark_vertices(canvas, geometry, sr->mark);
}

int _gvl_get_symbolizer(gvl_symbolizer_table *table, gvl_symbolizer **sr, void *feature, void *user)
{
    if (table->classification_function) {
	int class = table->classification_function(feature, user);
	if (class < 0 || class >= table->n)
	    return 0;
	*sr = table->symbolizers[class];
    } else if (table->value_function) {
	double value = table->value_function(feature, user);
	/* (value - value_min) / (value_max - value_min) == (x - x_min) / (x_max - x_min) */
	    
	/* if x_min > x_max ? */
	double k = (value - table->value_min) / (table->value_max - table->value_min);
	k = MAX(0.0, MIN(1.0, k));
	    
	if ((*sr)->my_class == GVL_SYMBOLIZER_POLYGON) {
	    gvl_polygon_symbolizer *s = (gvl_polygon_symbolizer *)*sr;
	    gvl_polygon_symbolizer **t = (gvl_polygon_symbolizer **)table->symbolizers;
	    s->color.red = t[0]->color.red + k * (t[1]->color.red - t[0]->color.red);
	    s->color.green = t[0]->color.green + k * (t[1]->color.green - t[0]->color.green);
	    s->color.blue = t[0]->color.blue + k * (t[1]->color.blue - t[0]->color.blue);
	}
    }
    return 1;
}

gvl_status gvl_canvas_render_layer(gvl_canvas *canvas, gvl_layer *layer, gvl_symbolizer_table *table, void *user)
{
}

gvl_status gvl_canvas_render_ogr_layer(gvl_canvas *canvas, OGRLayerH layer, gvl_symbolizer_table *table, void *user)
{
    gvl_status e;

    if (table->n < 1)
	return GVL_STATUS_EMPTY_SYMBOLIZER_TABLE;

    gvl_symbolizer *sr = table->symbolizers[0];

    if (table->value_function) {
	if (table->n < 2)
	    return GVL_STATUS_NEED_TWO_SYMBOLIZERS_TO_INTERPOLATE;
	sr = gvl_symbolizer_clone(sr);
    }

    OGRFeatureH feature;

    OGR_L_SetSpatialFilterRect(layer, 
			       canvas->viewport.min.x, 
			       canvas->viewport.min.y, 
			       canvas->viewport.max.x, 
			       canvas->viewport.max.y);

    OGR_L_ResetReading(layer);
 
    while ((feature = OGR_L_GetNextFeature(layer))) {

	if (!_gvl_get_symbolizer(table, &sr, feature, user))
	    continue;

	int i, n = 1;

	OGRGeometryH geometry = OGR_F_GetGeometryRef(feature);
	int type = wkbFlatten(OGR_G_GetGeometryType(geometry));
	
	if (type == wkbGeometryCollection) {
	    n = OGR_G_GetGeometryCount(geometry);
	    if (n == 0) continue;
	    geometry = OGR_G_GetGeometryRef(geometry, 0);
	    type = wkbFlatten(OGR_G_GetGeometryType(geometry));
	}

	for (i = 0; i < n; i++) {

	    if (i > 0)
		geometry = OGR_G_GetGeometryRef(OGR_F_GetGeometryRef(feature), i);

	    switch (type) {
	    case wkbPoint:
	    case wkbMultiPoint:

		if (sr->my_class == GVL_SYMBOLIZER_POINT) { 
		    gvl_set_point_symbolizer(canvas->cr, (gvl_point_symbolizer*)sr);
		}

		break;
	    case wkbLineString:
	    case wkbMultiLineString:
		
		if (sr->my_class == GVL_SYMBOLIZER_LINE) {
		    gvl_canvas_geometry(canvas, geometry);
		    gvl_canvas_stroke_line(canvas, geometry, (gvl_line_symbolizer*)sr);
		}

		break;
	    case wkbPolygon:
	    case wkbMultiPolygon:

		if (sr->my_class == GVL_SYMBOLIZER_POLYGON) {
		    gvl_canvas_geometry(canvas, geometry);
		    gvl_set_polygon_symbolizer(canvas->cr, (gvl_polygon_symbolizer*)sr);
		    if (((gvl_polygon_symbolizer*)sr)->border) {
			cairo_fill_preserve(canvas->cr);
			gvl_canvas_stroke_line(canvas, geometry, ((gvl_polygon_symbolizer*)sr)->border);
		    } else {
			cairo_fill(canvas->cr);
		    }
		}
		if (sr->my_class == GVL_SYMBOLIZER_TEXT) {
		    char *label = gvl_label(((gvl_text_symbolizer*)sr)->label, feature);
		    if (!label)
			break;
		    PangoLayout *layout = pango_cairo_create_layout(canvas->cr);
		    pango_layout_set_font_description(layout, ((gvl_text_symbolizer*)sr)->font);
		    pango_layout_set_text(layout, label, -1);
		    int width, height;
		    pango_layout_get_pixel_size(layout, &width, &height);
		    OGRGeometryH centroid = OGR_G_CreateGeometry(wkbPoint);
		    if (centroid) {
			if (OGR_G_Centroid(geometry, centroid) != OGRERR_FAILURE) {
			    gvl_point p = gvl_transform(canvas, OGR_G_GetX(centroid, 0), OGR_G_GetY(centroid, 0));
			    cairo_move_to(canvas->cr, p.x-width/2, p.y-height);
			    pango_cairo_show_layout(canvas->cr, layout);
			}
			OGR_G_DestroyGeometry(centroid);
		    }
		    g_object_unref(layout);
		    free(label);
		}

		break;
	    default: /* should not happen */
		break;
	    }

	}

	OGR_F_Destroy(feature);

    }
    OGR_L_SetSpatialFilter(layer, NULL);
    if (table->value_function)
	gvl_symbolizer_destroy(&sr);
    return GVL_STATUS_SUCCESS;
 fail:
    if (table->value_function)
	gvl_symbolizer_destroy(&sr);
    return e;
}


typedef struct {
#ifdef BIG_ENDIAN
    unsigned char A;
    unsigned char R;
    unsigned char G;
    unsigned char B;
#else
    unsigned char B;
    unsigned char G;
    unsigned char R;
    unsigned char A;
#endif
} ARGB32;


typedef struct {
    gvl_rectangle bbox;
    int width;
    int height;
    double x_min;
    double y_max;
    double dx;
    double dy;
    int *int_data;
    float *float_data;
} gvl_raster;


gvl_status _gvl_clip_from_gdal(gvl_canvas *canvas, GDALDatasetH dataset, gvl_raster *raster)
{
    raster->int_data = NULL;
    raster->float_data = NULL;

    double t[6];

    GDALGetGeoTransform(dataset, t);

    if (!(t[2] == t[4] && t[2] == 0))
	return GVL_STATUS_FAILURE; /* the raster is not a strict north up image */

    int gdal_width = GDALGetRasterXSize(dataset);
    int gdal_height = GDALGetRasterYSize(dataset);

    raster->bbox.min.x = MAX(canvas->viewport.min.x, t[0]);
    raster->bbox.max.x = MIN(canvas->viewport.max.x, t[0]+gdal_width*t[1]);
    raster->bbox.min.y = MAX(canvas->viewport.min.y, t[3]-gdal_height*t[1]);
    raster->bbox.max.y = MIN(canvas->viewport.max.y, t[3]);

    if ((raster->bbox.min.x > raster->bbox.max.x) || (raster->bbox.min.y > raster->bbox.max.y))
	return GVL_STATUS_SUCCESS;
    
    int x0 = floor((raster->bbox.min.x - t[0])/t[1]+0.0000000001);
    int y0 = floor((raster->bbox.max.y - t[3])/t[5]+0.0000000001);

    int w = MIN(ceil((raster->bbox.max.x - t[0])/t[1]), gdal_width) - x0;
    int h = MIN(ceil((raster->bbox.min.y - t[3])/t[5]), gdal_height) - y0;

    raster->width = ceil((double)w*t[1]*canvas->scale);
    raster->height = ceil((double)h*fabs(t[5])*canvas->scale);

    raster->x_min = t[0] + (double)x0*t[1];
    raster->y_max = t[3] + (double)(gdal_height-y0)*t[5];

    raster->dx = t[1]*(double)w/(double)raster->width;
    raster->dy = fabs(t[5])*(double)h/(double)raster->height;

    GDALRasterBandH hBand = GDALGetRasterBand(dataset, 1);
    GDALDataType datatype = GDALGetRasterDataType(hBand);
 
    GDALDataType target_datatype;
    
    switch (datatype) {
    case GDT_Byte:
    case GDT_UInt16:
    case GDT_Int16:
    case GDT_UInt32:
    case GDT_Int32:
	target_datatype = GDT_Int32;
	GVL_TEST_POINTER(raster->int_data = GVL_CALLOC(raster->width * raster->height, int));
	break;
    case GDT_Float32:
    case GDT_Float64:
	target_datatype = GDT_Float32;
	GVL_TEST_POINTER(raster->float_data = GVL_CALLOC(raster->width * raster->height, float));
	break;
    default:
	goto fail;
    }
    
    if (GDALRasterIO(hBand, GF_Read, 
		     x0, y0, w, h, 
		     raster->int_data ? (void *)raster->int_data : (void *)raster->float_data, 
		     raster->width, raster->height, target_datatype, 
		     0, 0) != CE_None)
	goto fail;

    int success;
    double nodata_value = GDALGetRasterNoDataValue(hBand, &success);

    return GVL_STATUS_SUCCESS;
 fail:
    GVL_FREE(raster->int_data);
    GVL_FREE(raster->float_data);
    return GVL_STATUS_FAILURE;
}


gvl_status gvl_canvas_render_raster(gvl_canvas *canvas, GDALDatasetH dataset, gvl_symbolizer_table *table, void *user)
{
    gvl_status e;
    gvl_symbolizer *sr = table->symbolizers[0];

    if (table->n < 1)
	return GVL_STATUS_EMPTY_SYMBOLIZER_TABLE;

    if (table->value_function) {
	if (table->n < 2)
	    return GVL_STATUS_NEED_TWO_SYMBOLIZERS_TO_INTERPOLATE;
	sr = gvl_symbolizer_clone(sr);
    }

    gvl_raster raster;
    GVL_TEST_SUCCESS(_gvl_clip_from_gdal(canvas, dataset, &raster));

    gvl_raster_feature feature;
    feature.has_int = raster.int_data != NULL;

    if (cairo_surface_get_type(canvas->surface) == CAIRO_SURFACE_TYPE_IMAGE) {

	ARGB32 *target = cairo_image_surface_get_data(canvas->surface);
	double cell_width = 1/canvas->scale;
	int target_width = cairo_image_surface_get_width(canvas->surface);
	int x1 = floor((raster.bbox.min.x - canvas->viewport.min.x)/cell_width+0.0000000001);
	int y1 = floor(-(raster.bbox.max.y - canvas->viewport.max.y)/cell_width+0.0000000001);
	int x2 = MIN(raster.width-1, ceil((raster.bbox.max.x - canvas->viewport.min.x)/cell_width-0.0000000001));
	int y2 = MIN(raster.height-1, ceil(-(raster.bbox.min.y - canvas->viewport.max.y)/cell_width-0.0000000001));
	
	if (sr->my_class == GVL_SYMBOLIZER_POLYGON) {
	    int x, y;
	    for (x = x1; x <= x2; x++) for (y = y1; y <= y2; y++) {
		
		double x_map = raster.x_min + (double)x*cell_width; /* + cell_width/2 */
		double y_map = raster.y_max - (double)y*cell_width;
		int xd = floor((x_map - raster.x_min)/raster.dx);
		int yd = floor((raster.y_max - y_map)/raster.dy);
		
		if (raster.int_data) 
		    feature.i_value = raster.int_data[xd+yd*raster.width];
		else
		    feature.f_value = raster.float_data[xd+yd*raster.width];
		
		if (!_gvl_get_symbolizer(table, &sr, &feature, user))
		    continue;

		target[x+y*target_width].A = 255;
		target[x+y*target_width].R = floor(255.9999*((gvl_polygon_symbolizer*)sr)->color.red);
		target[x+y*target_width].G = floor(255.9999*((gvl_polygon_symbolizer*)sr)->color.green);
		target[x+y*target_width].B = floor(255.9999*((gvl_polygon_symbolizer*)sr)->color.blue);
	    }
	    
	}

    } else {

	cairo_antialias_t aa = cairo_get_antialias(canvas->cr);
	cairo_set_antialias(canvas->cr, CAIRO_ANTIALIAS_NONE);
	
	int x, y;
	for (x = 0; x < raster.width; x++) for (y = 0; y < raster.height; y++) {
		
	    if (raster.int_data) 
		feature.i_value = raster.int_data[x+y*raster.width];
	    else
		feature.f_value = raster.float_data[x+y*raster.width];
		
	    if (!_gvl_get_symbolizer(table, &sr, &feature, user))
		continue;
		
	    int i, n = 1;
		
	    if (sr->my_class == GVL_SYMBOLIZER_POLYGON) {
		gvl_rectangle rect;
		
		rect.min.x = MAX(raster.bbox.min.x, raster.x_min + (double)x*raster.dx);
		rect.max.x = MIN(raster.bbox.max.x, raster.x_min + (double)(x+1)*raster.dx);
		rect.min.y = MAX(raster.bbox.min.y, raster.y_max - (double)(y+1)*raster.dy); 
		rect.max.y = MIN(raster.bbox.max.y, raster.y_max - (double)y*raster.dy);
		    
		gvl_canvas_rectangle(canvas, rect.min.x, rect.min.y, rect.max.x-rect.min.x, rect.max.y-rect.min.y);
		    
		gvl_set_polygon_symbolizer(canvas->cr, (gvl_polygon_symbolizer*)sr);
		if (((gvl_polygon_symbolizer*)sr)->border) {
		    cairo_fill_preserve(canvas->cr);
		    /*gvl_stroke_line(canvas, geometry, ((gvl_polygon_symbolizer*)sr)->border);*/
		} else {
		    cairo_fill(canvas->cr);
		}
	    }

	    /*
	      if (srs->for_text) {
	      char *label = gvl_label(srs->for_text->label, feature);
	      if (!label)
	      break;
	      PangoLayout *layout = pango_cairo_create_layout(canvas->cr);
	      pango_layout_set_font_description(layout, srs->for_text->font);
	      pango_layout_set_text(layout, label, -1);
	      int width, height;
	      pango_layout_get_pixel_size(layout, &width, &height);
	      OGRGeometryH centroid = OGR_G_CreateGeometry(wkbPoint);
	      if (centroid) {
	      if (OGR_G_Centroid(geometry, centroid) != OGRERR_FAILURE) {
	      struct gvl_point p = gvl_transform(canvas, OGR_G_GetX(centroid, 0), OGR_G_GetY(centroid, 0));
	      cairo_move_to(canvas->cr, p.x-width/2, p.y-height);
	      pango_cairo_show_layout(canvas->cr, layout);
	      }
	      OGR_G_DestroyGeometry(centroid);
	      }
	      g_object_unref(layout);
	      free(label);
	      }
	    */
		
	}
	cairo_set_antialias(canvas->cr, aa);
    }
    
    if (table->value_function)
	gvl_symbolizer_destroy(&sr);
    GVL_FREE(raster.int_data);
    GVL_FREE(raster.float_data);
    return GVL_STATUS_SUCCESS;
 fail:
    if (table->value_function)
	gvl_symbolizer_destroy(&sr);
    GVL_FREE(raster.int_data);
    GVL_FREE(raster.float_data);
    return e;
    
}
