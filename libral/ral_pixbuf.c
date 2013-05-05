#include "config.h"
#include "msg.h"
#include "ral/ral.h"
#include "private/ral.h"

#ifdef RAL_HAVE_GDAL
#ifdef RAL_HAVE_GDK_PIXBUF

OGRCoordinateTransformationH CPL_STDCALL 
OCTNewCoordinateTransformation(
    OGRSpatialReferenceH hSourceSRS, OGRSpatialReferenceH hTargetSRS );

#define to255(i,s) floor((255.0*(double)(i)/(double)(s))+0.5)

/* after www.cs.rit.edu/~ncs/color/t_convert.html */
GDALColorEntry ral_rgb2hsv(GDALColorEntry rgb) {
    float r = (float)rgb.c1/256;
    float g = (float)rgb.c2/256;
    float b = (float)rgb.c3/256;
    float min, max, delta;
    float h,s,v;
    
    min = MIN( r, MIN(g, b) );
    max = MAX( r, MAX(g, b) );
    v = max;				// v
    
    delta = max - min;

    if( max != 0 )
	s = delta / max;		// s
    else {
	// r = g = b = 0		// s = 0, v is undefined
	s = 0;
	h = -1;
	rgb.c1 = -1;
	rgb.c2 = 0;
	rgb.c3 = floor(v * 100.999);
	return rgb;
    }
    
    if( r == max )
	h = ( g - b ) / delta;		// between yellow & magenta
    else if( g == max )
	h = 2 + ( b - r ) / delta;	// between cyan & yellow
    else
	h = 4 + ( r - g ) / delta;	// between magenta & cyan
    
    h *= 60;				// degrees
    if( h < 0 )
	h += 360;
    
    rgb.c1 = floor(h);
    rgb.c2 = floor(s * 100.999);
    rgb.c3 = floor(v * 100.999);
    return rgb;
}

GDALColorEntry ral_hsv2rgb(GDALColorEntry hsv)
{
    int i;
    GDALColorEntry rgb;
    float h = hsv.c1; float s = (float)hsv.c2/100.0; float v = (float)hsv.c3/100.0;
    float r; float g; float b;
    float f, p, q, t;

    if( s == 0 ) {
	// achromatic (grey)
	r = g = b = v;
	rgb.c1 = floor(255.999*r);
	rgb.c2 = floor(255.999*g);
	rgb.c3 = floor(255.999*b);
	rgb.c4 = hsv.c4;
	return rgb;
    }

    h /= 60;			// sector 0 to 5
    i = floor( h );
    if (i == 6) i = 5;
    f = h - i;			// factorial part of h
    p = v * ( 1 - s );
    q = v * ( 1 - s * f );
    t = v * ( 1 - s * ( 1 - f ) );

    switch( i ) {
    case 0:
	r = v;
	g = t;
	b = p;
	break;
    case 1:
	r = q;
	g = v;
	b = p;
	break;
    case 2:
	r = p;
	g = v;
	b = t;
	break;
    case 3:
	r = p;
	g = q;
	b = v;
	break;
    case 4:
	r = t;
	g = p;
	b = v;
	break;
    default:		// case 5:
	r = v;
	g = p;
	b = q;
	break;
    }
    rgb.c1 = floor(255.999*r);
    rgb.c2 = floor(255.999*g);
    rgb.c3 = floor(255.999*b);
    rgb.c4 = hsv.c4;
    return rgb;
}

static void
ral_pixbuf_destroy_notify (guchar * pixels,
			   gpointer data)
{
	/*fprintf(stderr,"free %#x\n",pixels);*/
	free(pixels);
}

ral_pixbuf *ral_pixbuf_create(int width, int height,
			      double minX, double maxY, double pixel_size,
			      GDALColorEntry background)
{
    ral_pixbuf *pb = NULL;
    RAL_CHECKM(pb = RAL_MALLOC(ral_pixbuf), RAL_ERRSTR_OOM);
    pb->image = NULL;
    pb->pixbuf = NULL;
    pb->destroy_fn = NULL;
    RAL_CHECKM(pb->image = malloc(RAL_PIXELSIZE*width*height), RAL_ERRSTR_OOM);
    pb->colorspace = GDK_COLORSPACE_RGB;
    pb->has_alpha = FALSE;
    pb->image_rowstride = width * RAL_PIXELSIZE;
    pb->rowstride = width * RAL_PIXBUF_PIXELSIZE;
    pb->bits_per_sample = 8;
    pb->M = height;
    pb->N = width;
    pb->world.min.x = minX;
    pb->world.max.y = maxY;
    pb->pixel_size = pixel_size;
    pb->world.max.x = pb->world.min.x + (double)width*pixel_size;
    pb->world.min.y = pb->world.max.y - (double)height*pixel_size;
    {
	int i,j;
	for (i = 0; i < pb->M; i++) for (j = 0; j < pb->N; j++)
	    RAL_PIXBUF_SET_PIXEL(pb, i, j, background.c1, background.c2, background.c3);
    }
    return pb;
 fail:
    ral_pixbuf_destroy(&pb);
    return NULL;
}

ral_pixbuf *ral_pixbuf_create_from_grid(ral_grid *gd)
{
    ral_pixbuf *pb = NULL;
    RAL_CHECKM(pb = RAL_MALLOC(ral_pixbuf), RAL_ERRSTR_OOM);
    pb->image = NULL;
    pb->pixbuf = NULL;
    pb->destroy_fn = NULL;
    RAL_CHECKM(pb->image = malloc(RAL_PIXELSIZE*gd->M*gd->N), RAL_ERRSTR_OOM);
    pb->destroy_fn = ral_pixbuf_destroy_notify;
    pb->colorspace = GDK_COLORSPACE_RGB;
    pb->has_alpha = FALSE;
    pb->image_rowstride = gd->N * RAL_PIXELSIZE;
    pb->rowstride = gd->N * RAL_PIXBUF_PIXELSIZE;
    pb->bits_per_sample = 8;
    pb->M = gd->M;
    pb->N = gd->N;
    pb->world = gd->world;
    pb->pixel_size = gd->cell_size;
    {
	int i,j;
	for (i = 0; i < pb->M; i++) for (j = 0; j < pb->N; j++)
	    RAL_PIXBUF_SET_PIXEL(pb, i, j, 0, 0, 0);
    }
    return pb;
 fail:
    ral_pixbuf_destroy(&pb);
    return NULL;
}

void ral_pixbuf_destroy(ral_pixbuf **pb)
{
    if (*pb) {
	RAL_FREE((*pb)->image);
	free(*pb);
    }
    *pb = NULL;
}

/* modified from goffice's go-image.c */
int ral_cairo_to_pixbuf(ral_pixbuf *pb)
{
    guint i, j;
    unsigned char *src, *dst;

    RAL_FREE(pb->pixbuf);
    RAL_CHECKM(pb->pixbuf = malloc(RAL_PIXBUF_PIXELSIZE*pb->M*pb->N), RAL_ERRSTR_OOM);
    pb->destroy_fn = ral_pixbuf_destroy_notify;
    
    dst = pb->pixbuf;
    src = pb->image;

    for (i = 0; i < pb->M; i++) {
	for (j = 0; j < pb->N; j++) {
#if G_BYTE_ORDER == G_LITTLE_ENDIAN
	    dst[0] = src[2];
	    dst[1] = src[1];
	    dst[2] = src[0];
#else
	    dst[0] = src[1];
	    dst[1] = src[2];
	    dst[2] = src[3];
#endif
	    src += RAL_PIXELSIZE;
	    dst += RAL_PIXBUF_PIXELSIZE;
	}
    }

    return 1;
 fail:
    return 0;
}

GdkPixbuf *ral_gdk_pixbuf(ral_pixbuf *pb)
{
     return gdk_pixbuf_new_from_data(pb->pixbuf,
				     pb->colorspace,
				     pb->has_alpha,
				     pb->bits_per_sample,
				     pb->N,
				     pb->M,
				     pb->rowstride,
				     pb->destroy_fn,
				     NULL);
}

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
		     double pixel_size)
{
    pb->image = image;
    pb->image_rowstride = image_rowstride;
    pb->pixbuf = pixbuf;
    pb->destroy_fn = destroy_fn;
    pb->colorspace = colorspace;
    pb->has_alpha = has_alpha;
    pb->rowstride = rowstride;
    pb->bits_per_sample = bits_per_sample;
    pb->N = width;
    pb->M = height;
    pb->world.min.x = world_min_x;
    pb->world.min.y = world_max_y-height*pixel_size;
    pb->world.max.x = world_min_x+width*pixel_size;
    pb->world.max.y = world_max_y;
    pb->pixel_size = pixel_size;
}

int ral_render_default_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io);
int ral_render_flow_direction_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer);
int ral_render_square_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io, double symbol_k);
int ral_render_dot_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io, double symbol_k);
int ral_render_cross_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io, double symbol_k);

int ral_render_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer)
{
    ral_interpolator i2c;
    ral_grid *gd = layer->gd;
    RAL_CHECKM(layer->gd, "No grid to render.");
    RAL_CHECKM(!layer->alpha_grid OR layer->alpha_grid->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ALPHA_IS_INTEGER);

    switch(layer->palette_type) {
    case RAL_PALETTE_SINGLE_COLOR: {
	ral_double_range x = {0,1}, y = {0,1};
	RAL_INTERPOLATOR_SETUP(i2c, x, y);
	break;
    }
    case RAL_PALETTE_GRAYSCALE: {
	ral_double_range y;
	if (layer->color_scale.max <= layer->color_scale.min) {
	    ral_integer_range r;
	    ral_integer_grid_get_value_range(gd, &r);
	    layer->color_scale.min = r.min;
	    layer->color_scale.max = r.max;
	}
	y.min = 0;
	switch(layer->scale) {
	case RAL_SCALE_GRAY:
	case RAL_SCALE_OPACITY:
	    y.max = 255.999;
	    break;
	case RAL_SCALE_HUE:
	    y.max = 360.999;
	    break;
	case RAL_SCALE_SATURATION:
	case RAL_SCALE_VALUE:
	    y.max = 100.999;
	    break;
	default:
	    y.max = 0;
	}
	if (layer->invert) {
	    y.min = y.max;
	    y.max = 0;
	}
	RAL_INTERPOLATOR_SETUP(i2c, layer->color_scale, y);
	break;
    }
    case RAL_PALETTE_RED_CHANNEL:
    case RAL_PALETTE_GREEN_CHANNEL:
    case RAL_PALETTE_BLUE_CHANNEL: {
	ral_double_range y;	
	if (layer->color_scale.max <= layer->color_scale.min) {
	    ral_integer_range r;
	    ral_integer_grid_get_value_range(gd, &r);
	    layer->color_scale.min = r.min;
	    layer->color_scale.max = r.max;
	}
	y.min = 0;
	y.max = 255.999;
	RAL_INTERPOLATOR_SETUP(i2c, layer->color_scale, y);
	break;
    }
    case RAL_PALETTE_RAINBOW:{
	ral_int_range r = layer->hue_at;
	r.min = max(min(r.min, 360), 0);
	r.max = max(min(r.max, 360), 0);
	if (layer->invert == RAL_RGB_HUE) {
	    if (r.max < r.min) r.max += 360;
	} else {
	    if (r.max > r.min) r.max -= 360;
	}
	if (layer->color_scale.max <= layer->color_scale.min) {
	    ral_integer_range r;
	    ral_integer_grid_get_value_range(gd, &r);
	    layer->color_scale.min = r.min;
	    layer->color_scale.max = r.max;
	}
	RAL_INTERPOLATOR_SETUP(i2c, layer->color_scale, r);
	break;
    }
    case RAL_PALETTE_COLOR_TABLE: {
	ral_double_range x = {0,1}, y = {0,1};
	RAL_INTERPOLATOR_SETUP(i2c, x, y);
	/*RAL_CHECKM(layer->color_table, "No color table although color table palette.");*/
	break;
    }
    case RAL_PALETTE_COLOR_BINS: {
	ral_double_range x = {0,1}, y = {0,1};
	RAL_INTERPOLATOR_SETUP(i2c, x, y);
	/*RAL_CHECKM(layer->color_bins, "No color bins although color bins palette.");*/
	break;
    }
    default: {
	ral_double_range x = {0,1}, y = {0,1};
	RAL_INTERPOLATOR_SETUP(i2c, x, y);
	RAL_CHECKM(0, ral_msg("Invalid palette type for integer grid: %i.", layer->palette_type));
    }
    }

    if (layer->gd->cell_size/pb->pixel_size >= 5.0) {
	double symbol_k = 0;
	if (layer->symbol_size_scale.max > layer->symbol_size_scale.min)
	    symbol_k = (double)layer->symbol_pixel_size/(double)(layer->symbol_size_scale.max - layer->symbol_size_scale.min);
	switch (layer->symbol) {
	case RAL_SYMBOL_FLOW_DIRECTION:
	    ral_render_flow_direction_integer_grid(pb, layer);
	    break;
	case RAL_SYMBOL_SQUARE:
	    ral_render_square_integer_grid(pb, layer, i2c, symbol_k);
	    break;
	case RAL_SYMBOL_DOT:
	    ral_render_dot_integer_grid(pb, layer, i2c, symbol_k);
	    break;
	case RAL_SYMBOL_CROSS:
	    ral_render_cross_integer_grid(pb, layer, i2c, symbol_k);
	    break;
	default:
	    ral_render_default_integer_grid(pb, layer, i2c);
	}
    } else 
	ral_render_default_integer_grid(pb, layer, i2c);

    return 1;
 fail:
    return 0;
}

#define RAL_APPLY_ALPHA(pixel, layer, color)				\
    if ((layer)->alpha_grid AND (layer)->alpha_grid->data) {		\
	ral_cell c;							\
	RAL_PIXEL2CELL(pixel, (layer)->alpha_grid, c);			\
	if (RAL_GRID_CELL_IN((layer)->alpha_grid, c) AND RAL_INTEGER_GRID_DATACELL((layer)->alpha_grid, c)) \
	    (color).c4 = RAL_INTEGER_GRID_CELL((layer)->alpha_grid, c);	\
    } else if ((layer)->alpha >= 0)					\
	(color).c4 = ((color).c4*(layer)->alpha)/255;

#define RAL_NV2COLOR(pixel, layer, nv, color, i2c)			\
    switch((layer)->palette_type) {					\
case RAL_PALETTE_GRAYSCALE:						\
if ((layer)->scale == RAL_SCALE_GRAY) {					\
    (color).c1 = (color).c2 = (color).c3 = floor(RAL_INTERPOLATE(i2c, (double)nv)); \
    (color).c4 = (layer)->grayscale_base_color.c4;			\
} else {								\
(color) = ral_rgb2hsv((layer)->grayscale_base_color);			\
switch((layer)->scale) {						\
case RAL_SCALE_HUE:							\
    (color).c1 = floor(RAL_INTERPOLATE(i2c, (double)nv));		\
    break;								\
case RAL_SCALE_SATURATION:						\
    (color).c2 = floor(RAL_INTERPOLATE(i2c, (double)nv));		\
    break;								\
case RAL_SCALE_VALUE:							\
    (color).c3 = floor(RAL_INTERPOLATE(i2c, (double)nv));		\
    break;								\
case RAL_SCALE_OPACITY:							\
    (color).c4 = floor(RAL_INTERPOLATE(i2c, (double)nv));		\
    break;								\
}									\
(color) = ral_hsv2rgb(color);						\
}									\
break;									\
case RAL_PALETTE_RED_CHANNEL:						\
(color).c1 = floor(RAL_INTERPOLATE(i2c, (double)nv));			\
       (color).c4 = 255;						\
       break;								\
case RAL_PALETTE_GREEN_CHANNEL:						\
       (color).c2 = floor(RAL_INTERPOLATE(i2c, (double)nv));		\
        (color).c4 = 255;						\
        break;								\
    case RAL_PALETTE_BLUE_CHANNEL:					\
        (color).c3 = floor(RAL_INTERPOLATE(i2c, (double)nv));           \
        (color).c4 = 255;						\
        break;								\
    case RAL_PALETTE_RAINBOW:						\
	       (color).c1 = floor(RAL_INTERPOLATE(i2c, (double)nv));		\
        if (((color).c1) > 360) (color).c1 -= 360;                      \
        if (((color).c1) < 0) (color).c1 += 360;                        \
	(color).c2 = (color).c3 = 100;					\
	(color) = ral_hsv2rgb(color);					\
	(color).c4 = 255;						\
	break;								\
    case RAL_PALETTE_COLOR_TABLE:					\
	if ((layer)->color_table)					\
	    RAL_COLOR_TABLE_GET((layer)->color_table, nv, color)	\
		break;							\
    case RAL_PALETTE_COLOR_BINS:					\
	if ((layer)->color_bins)					\
	    RAL_COLOR_BINS_GET(layer->color_bins, nv, color)		\
		break;							\
    default:								\
	break;								\
	       }							\
    RAL_APPLY_ALPHA(pixel, layer, color)

#define RAL_STR2COLOR(pixel, layer, str, color, io)			\
    switch((layer)->palette_type) {					\
    case RAL_PALETTE_COLOR_TABLE:					\
	if ((layer)->string_color_table)				\
	    RAL_STRING_COLOR_TABLE_GET((layer)->string_color_table, str, color)	\
		break;							\
    default:								\
	break;								\
    }									\
    RAL_APPLY_ALPHA(pixel, layer, color)

#define RAL_INITIAL_COLOR(pb, layer, pixel, color) \
    switch((layer)->palette_type) { \
    case RAL_PALETTE_RED_CHANNEL: \
    case RAL_PALETTE_GREEN_CHANNEL: \
    case RAL_PALETTE_BLUE_CHANNEL: \
        RAL_PIXBUF_GET_PIXEL_COLOR((pb), (pixel), (color));\
	(color).c4 = 255;\
	break;\
    default:\
	(color) = (layer)->single_color;\
    }

int ral_render_default_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io)
{
    ral_cell pixel;
    int w = pb->N;
    for (pixel.i = 0; pixel.i < pb->M; pixel.i++) {
	ral_cell c;
	c.i = RAL_PBi2GDi(pb, pixel.i, layer->gd);
	for (pixel.j = 0; pixel.j < w; pixel.j++) {
	    c.j = RAL_PBj2GDj(pb, pixel.j, layer->gd);
	    if (RAL_GRID_CELL_IN(layer->gd, c) AND RAL_INTEGER_GRID_DATACELL(layer->gd, c)) {
		GDALColorEntry color;
		RAL_INTEGER value;
		RAL_INITIAL_COLOR(pb, layer, pixel, color);
		value = RAL_INTEGER_GRID_CELL(layer->gd, c);
		RAL_NV2COLOR(pixel, layer, value, color, io);
		RAL_PIXBUF_ASSIGN_PIXEL_COLOR(pb, pixel, color);
	    }
	}
    }
    return 1;
}

int xral_render_flow_direction_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer)
{
    ral_cell c;
    int a = floor(layer->gd->cell_size/pb->pixel_size/2.0); /* length of the arrow in pixels */
    int h = floor(layer->gd->cell_size/pb->pixel_size/3.0)-1;
    for(c.i = 0; c.i < layer->gd->M; c.i++) {
	int i = RAL_GDi2PBi(layer->gd, c.i, pb);
	if ((i-a < 0) OR (i+a >= pb->M)) continue;
	for(c.j = 0; c.j < layer->gd->N; c.j++) {
	    GDALColorEntry color;
	    int i1, j1, b, di, dj, di1, dj1, di2, dj2, j;
	    if (RAL_INTEGER_GRID_NODATACELL(layer->gd, c)) continue;
	    j = RAL_GDj2PBj(layer->gd, c.j, pb);
	    if ((j-a < 0) OR (j+a >= pb->N)) continue;
	    color = layer->single_color;
	    switch (RAL_INTEGER_GRID_CELL(layer->gd, c)) {
	    case RAL_N:
		di = -1; dj = 0;  i1 = i - a; j1 = j;     di1 = 1;  dj1 = 1;  di2 = 1;  dj2 = -1;
		break;
	    case RAL_NE:
		di = -1; dj = 1;  i1 = i - a; j1 = j + a; di1 = 1;  dj1 = 0;  di2 = 0;  dj2 = -1;
		break;
	    case RAL_E:
		di = 0;  dj = 1;  i1 = i;     j1 = j + a; di1 = 1;  dj1 = -1; di2 = -1; dj2 = -1;
		break;
	    case RAL_SE:
		di = 1;  dj = 1;  i1 = i + a; j1 = j + a; di1 = -1; dj1 = 0;  di2 = 0;  dj2 = -1;
		break;
	    case RAL_S:
		di = 1;  dj = 0;  i1 = i + a; j1 = j;     di1 = -1; dj1 = 1;  di2 = -1; dj2 = -1;
		break;
	    case RAL_SW:
		di = 1;  dj = -1; i1 = i + a; j1 = j - a; di1 = -1; dj1 = 0;  di2 = 0;  dj2 = 1;
		break;
	    case RAL_W:
		di = 0;  dj = -1; i1 = i;     j1 = j - a; di1 = 1;  dj1 = 1;  di2 = -1; dj2 = 1;
		break;
	    case RAL_NW:
		di = -1; dj = -1; i1 = i - a; j1 = j - a; di1 = 0;  dj1 = 1;  di2 = 1;  dj2 = 0;
		break;
	    case RAL_FLAT_AREA:
		di = 0;  dj = 0;  i1 = i;     j1 = j;     di1 = 0;  dj1 = 0;  di2 = 0;  dj2 = 0;
		for (a = -h; a <= h; a++) {
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, i1+a,j1,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, i1,j1+a,color);
		}
		break;
	    case RAL_PIT_CELL:
		di = 0;  dj = 0;  i1 = i;     j1 = j;     di1 = 0;  dj1 = 0;  di2 = 0;  dj2 = 0;
		for (a = -h; a <= h; a++) {
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, i1+a,j1+h,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, i1+a,j1-h,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, i1+h,j1+a,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, i1-h,j1+a,color);
		}
		break;
	    default:
		di = dj = i1 = j1 = di1 = dj1 = di2 = dj2 = 0;
	    }
	    for (b = 1; b <= a; b++) {
		RAL_PIXBUF_SET_PIXEL_COLOR(pb, i+di*b,j+dj*b,color);
	    }
	    for (b = 1; b <= h; b++) {
		RAL_PIXBUF_SET_PIXEL_COLOR(pb, i1+di1*b,j1+dj1*b,color);
		RAL_PIXBUF_SET_PIXEL_COLOR(pb, i1+di2*b,j1+dj2*b,color);
	    }
	}
    }
    return 1;
}

int ral_render_flow_direction_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer)
{
    ral_cell c;
    int w = floor(layer->gd->cell_size/pb->pixel_size/2.0)+1;
    int v = floor(w/2.0)+1;
    for(c.i = 0; c.i < layer->gd->M; c.i++) {
	int i = RAL_GDi2PBi(layer->gd, c.i, pb);
	for(c.j = 0; c.j < layer->gd->N; c.j++) {
	    GDALColorEntry color;
	    int j;
	    if (RAL_INTEGER_GRID_NODATACELL(layer->gd, c)) continue;
	    j = RAL_GDj2PBj(layer->gd, c.j, pb);
	    color = layer->single_color;
	    switch (RAL_INTEGER_GRID_CELL(layer->gd, c)) {
	    case RAL_N: {
		int a, i2 = RAL_GDi2PBi(layer->gd, c.i-1, pb);
		if (j >= 0 AND j < pb->N)
		    for (a = min(pb->M-1,i); a >= max(0,i2); a--)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb, a,j,color);
		for (a = 0; a < v; a++) {
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i-w+a,j-a,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i-w+a,j+a,color);
		}
		break;
	    }
	    case RAL_NE: {
		int a, d, j2 = RAL_GDj2PBj(layer->gd, c.j+1, pb);
		for (d = 0; d < j2 - j + 1; d++) {
		    int a = i-d, b = j+d;
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb, a,b,color);
		}
		for (a = 0; a < v; a++) {
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i-w+a,j+w,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i-w,j+w-a,color);
		}
		break;
	    }
	    case RAL_E: {
		int a, b, j2 = RAL_GDj2PBj(layer->gd, c.j+1, pb);
		if (i >= 0 AND i < pb->M)
		    for (b = max(0,j); b <= min(pb->N-1,j2); b++)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb, i,b,color);
		for (a = 0; a < v; a++) {
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i-a,j+w-a,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i+a,j+w-a,color);
		}
		break;
	    }
	    case RAL_SE: {
		int a, d, j2 = RAL_GDj2PBj(layer->gd, c.j+1, pb);
		for (d = 0; d < j2 - j + 1; d++) {
		    int a = i+d, b = j+d;
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb, a,b,color);
		}
		for (a = 0; a < v; a++) {
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i+w-a,j+w,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i+w,j+w-a,color);
		}
		break;
	    }
	    case RAL_S: {
		int a, i2 = RAL_GDi2PBi(layer->gd, c.i+1, pb);
		if (j >= 0 AND j < pb->N)
		    for (a = max(0,i); a <= min(pb->M-1,i2); a++)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb, a,j,color);
		for (a = 0; a < v; a++) {
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i+w-a,j-a,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i+w-a,j+a,color);
		}
		break;
	    }
	    case RAL_SW: {
		int a, d, j2 = RAL_GDj2PBj(layer->gd, c.j-1, pb);
		for (d = 0; d < j - j2 + 1; d++) {
		    int a = i+d, b = j-d;
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb, a,b,color);
		}
		for (a = 0; a < v; a++) {
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i+w-a,j-w,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i+w,j-w+a,color);
		}
		break;
	    }
	    case RAL_W: {
		int a, b, j2 = RAL_GDj2PBj(layer->gd, c.j-1, pb);
		if (i >= 0 AND i < pb->M)
		    for (b = min(pb->N-1,j); b >= max(0,j2); b--)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb, i,b,color);
		for (a = 0; a < v; a++) {
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i-a,j-w+a,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i+a,j-w+a,color);
		}
		break;
	    }
	    case RAL_NW: {
		int a, d, j2 = RAL_GDj2PBj(layer->gd, c.j-1, pb);
		for (d = 0; d < j - j2 + 1; d++) {
		    int a = i-d, b = j-d;
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb, a,b,color);
		}
		for (a = 0; a < v; a++) {
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i-w+a,j-w,color);
		    RAL_PIXBUF_SET_PIXEL_COLOR_TEST(pb,i-w,j-w+a,color);
		}
		break;
	    }
	    case RAL_FLAT_AREA: {
		int a, b;
		if (j-v >= 0 AND j-v < pb->N)
		    for (a = max(0,i-v); a < min(pb->M,i+v+1); a++)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb,a,j-v,color);
		if (i-v >= 0 AND i-v < pb->M)
		    for (b = max(0,j-v); b < min(pb->N,j+v+1); b++)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb,i-v,b,color);
		if (j+v >= 0 AND j+v < pb->N)
		    for (a = max(0,i-v); a < min(pb->M,i+v+1); a++)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb,a,j+v,color);
		if (i+v >= 0 AND i+v < pb->M)
		    for (b = max(0,j-v); b < min(pb->N,j+v+1); b++)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb,i+v,b,color);
		break;
	    }
	    case RAL_PIT_CELL: {
		ral_cell c1, c2;
		c1.i = i-v;
		c1.j = j+v;
		c2.i = i+v;
		c2.j = j;
		RAL_LINE(pb, c1, c2, color, RAL_PIXBUF_ASSIGN_PIXEL_COLOR);
		c1.j = j-v;
		RAL_LINE(pb, c1, c2, color, RAL_PIXBUF_ASSIGN_PIXEL_COLOR);
		c2.i = i-v;
		c2.j = j+v;
		RAL_LINE(pb, c1, c2, color, RAL_PIXBUF_ASSIGN_PIXEL_COLOR);
		break;
	    }
	    default:
		break;
	    }
	}
    }
    return 1;
}

int ral_render_square_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io, double symbol_k)
{
    ral_cell c, pixel;
    for(c.i = 0; c.i < layer->gd->M; c.i++) {
	pixel.i = RAL_GDi2PBi(layer->gd, c.i, pb);
	if ((pixel.i < 0) OR (pixel.i >= pb->M)) continue;
	for(c.j = 0; c.j < layer->gd->N; c.j++) {
	    GDALColorEntry color;
	    RAL_INTEGER value;
	    int symbol_size;
	    if (RAL_INTEGER_GRID_NODATACELL(layer->gd, c)) continue;
	    pixel.j = RAL_GDj2PBj(layer->gd, c.j, pb);
	    if ((pixel.j < 0) OR (pixel.j >= pb->N)) continue;
	    value = RAL_INTEGER_GRID_CELL(layer->gd, c);
	    RAL_INITIAL_COLOR(pb, layer, pixel, color);
	    RAL_NV2COLOR(pixel, layer, value, color, io);
	    symbol_size = symbol_k > 0 ? 
		floor((value - layer->symbol_size_scale.min)*symbol_k + 0.5) :
		layer->symbol_pixel_size;
	    if (symbol_size < 1) continue;
	    if (symbol_size == 1) {
		RAL_PIXBUF_ASSIGN_PIXEL_COLOR(pb, pixel, color);
	    } else {
		int i2,j2;
		for (i2 = max(0, pixel.i-symbol_size+1); i2 < min(pb->M, pixel.i+symbol_size); i2++)
		    for (j2 = max(0, pixel.j-symbol_size+1); j2 < min(pb->N, pixel.j+symbol_size); j2++)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb, i2, j2, color);
	    }
	}
    }
    return 1;
}

int ral_render_dot_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io, double symbol_k)
{
    ral_cell c, pixel;
    for(c.i = 0; c.i < layer->gd->M; c.i++) {
	pixel.i = RAL_GDi2PBi(layer->gd, c.i, pb);
	if ((pixel.i < 0) OR (pixel.i >= pb->M)) continue;
	for(c.j = 0; c.j < layer->gd->N; c.j++) {
	    GDALColorEntry color;
	    RAL_INTEGER value;
	    int r;
	    if (RAL_INTEGER_GRID_NODATACELL(layer->gd, c)) continue;
	    pixel.j = RAL_GDj2PBj(layer->gd, c.j, pb);
	    if ((pixel.j < 0) OR (pixel.j >= pb->N)) continue;
	    value = RAL_INTEGER_GRID_CELL(layer->gd, c);
	    RAL_INITIAL_COLOR(pb, layer, pixel, color);
	    RAL_NV2COLOR(pixel, layer, value, color, io);
	    r = symbol_k > 0 ? 
		floor((value - layer->symbol_size_scale.min)*symbol_k + 0.5) :
		layer->symbol_pixel_size;
	    if (r < 1) continue;
	    if (r == 1) {
		RAL_PIXBUF_ASSIGN_PIXEL_COLOR(pb, pixel, color);
	    } else {
		RAL_FILLED_CIRCLE(pb, pixel, r, color, RAL_PIXBUF_ASSIGN_PIXEL_COLOR);
	    }
	}
    }
    return 1;
}

int ral_render_cross_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io, double symbol_k)
{
    ral_cell c, pixel;
    for(c.i = 0; c.i < layer->gd->M; c.i++) {
	pixel.i = RAL_GDi2PBi(layer->gd, c.i, pb);
	if ((pixel.i < 0) OR (pixel.i >= pb->M)) continue;
	for(c.j = 0; c.j < layer->gd->N; c.j++) {
	    GDALColorEntry color;
	    RAL_INTEGER value;
	    int symbol_size;
	    if (RAL_INTEGER_GRID_NODATACELL(layer->gd, c)) continue;
	    pixel.j = RAL_GDj2PBj(layer->gd, c.j, pb);
	    if ((pixel.j < 0) OR (pixel.j >= pb->N)) continue;
	    value = RAL_INTEGER_GRID_CELL(layer->gd, c);
	    RAL_INITIAL_COLOR(pb, layer, pixel, color);
	    RAL_NV2COLOR(pixel, layer, value, color, io);
	    symbol_size = symbol_k > 0 ? 
		floor((value - layer->symbol_size_scale.min)*symbol_k + 0.5) :
		layer->symbol_pixel_size;
	    if (symbol_size < 1) continue;
	    if (symbol_size == 1) {
		RAL_PIXBUF_ASSIGN_PIXEL_COLOR(pb, pixel, color);
	    } else {
		int i2,j2;
		for (i2 = max(0, pixel.i-symbol_size+1); i2 < min(pb->M, pixel.i+symbol_size); i2++)
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, i2, pixel.j, color);
		for (j2 = max(0, pixel.j-symbol_size+1); j2 < min(pb->N, pixel.j+symbol_size); j2++)
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, pixel.i, j2, color);
	    }
	}
    }
    return 1;
}

int ral_render_default_real_grid(ral_pixbuf *pb, ral_real_grid_layer *layer, ral_interpolator io);
int ral_render_square_real_grid(ral_pixbuf *pb, ral_real_grid_layer *layer, ral_interpolator io, double symbol_k);
int ral_render_dot_real_grid(ral_pixbuf *pb, ral_real_grid_layer *layer, ral_interpolator io, double symbol_k);
int ral_render_cross_real_grid(ral_pixbuf *pb, ral_real_grid_layer *layer, ral_interpolator io, double symbol_k);

int ral_render_real_grid(ral_pixbuf *pb, ral_real_grid_layer *layer)
{
    ral_interpolator i2c;
    ral_grid *gd;
    RAL_CHECKM(layer->gd, "No grid to render.");
    RAL_CHECKM(!layer->alpha_grid OR layer->alpha_grid->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ALPHA_IS_INTEGER);
    gd = layer->gd;

    switch(layer->palette_type) {
    case RAL_PALETTE_SINGLE_COLOR: {
	ral_double_range x = {0,1}, y = {0,1};
	RAL_INTERPOLATOR_SETUP(i2c, x, y);
	break;
    }
    case RAL_PALETTE_GRAYSCALE: {
	ral_double_range y;    
	if (layer->color_scale.max <= layer->color_scale.min) {
	    ral_real_range r;
	    ral_real_grid_get_value_range(gd, &r);
	    layer->color_scale.min = r.min;
	    layer->color_scale.max = r.max;
	}
	y.min = 0;
	switch(layer->scale) {
	case RAL_SCALE_GRAY:
	case RAL_SCALE_OPACITY:
	    y.max = 255.999;
	    break;
	case RAL_SCALE_HUE:
	    y.max = 360.999;
	    break;
	case RAL_SCALE_SATURATION:
	case RAL_SCALE_VALUE:
	    y.max = 100.999;
	    break;
	default:
	    y.max = 0;
	}
	if (layer->invert) {
	    y.min = y.max;
	    y.max = 0;
	}
	RAL_INTERPOLATOR_SETUP(i2c, layer->color_scale, y);
	break;
    }
    case RAL_PALETTE_RAINBOW: {
	ral_int_range r = layer->hue_at;
	r.min = max(min(r.min,360),0);
	r.max = max(min(r.max,360),0);
	if (layer->invert == RAL_RGB_HUE) {
	    if (r.max < r.min) r.max += 360;
	} else {
	    if (r.max > r.min) r.max -= 360;
	}
	if (layer->color_scale.max <= layer->color_scale.min) {
	    ral_real_range r;
	    ral_real_grid_get_value_range(gd, &r);
	    layer->color_scale.min = r.min;
	    layer->color_scale.max = r.max;
	}
	RAL_INTERPOLATOR_SETUP(i2c, layer->color_scale, r);
	break;
    }
    case RAL_PALETTE_COLOR_BINS: {
	ral_double_range x = {0,1}, y = {0,1};
	RAL_INTERPOLATOR_SETUP(i2c, x, y);
	/*RAL_CHECKM(layer->color_bins, "No color bins although color bins palette.");*/
	break;
    }
    default: {
	ral_double_range x = {0,1}, y = {0,1};
	RAL_INTERPOLATOR_SETUP(i2c, x, y);
	RAL_CHECKM(0, ral_msg("Invalid palette type for real grid: %i.", layer->palette_type));
    }
    }

    if (layer->gd->cell_size/pb->pixel_size >= 5.0) {
	double symbol_k = 0;
	if (layer->symbol_size_scale.max > layer->symbol_size_scale.min)
	    symbol_k = (double)layer->symbol_pixel_size/(double)(layer->symbol_size_scale.max - layer->symbol_size_scale.min);
	switch (layer->symbol) {
	case RAL_SYMBOL_SQUARE:
	    ral_render_square_real_grid(pb, layer, i2c, symbol_k);
	    break;
	case RAL_SYMBOL_DOT:
	    ral_render_dot_real_grid(pb, layer, i2c, symbol_k);
	    break;
	case RAL_SYMBOL_CROSS:
	    ral_render_cross_real_grid(pb, layer, i2c, symbol_k);
	    break;
	default:
	    ral_render_default_real_grid(pb, layer, i2c);
	}
    } else 
	ral_render_default_real_grid(pb, layer, i2c);

    return 1;
fail:
    return 0;
}

int ral_render_default_real_grid(ral_pixbuf *pb, ral_real_grid_layer *layer, ral_interpolator i2c)
{
    ral_cell pixel;
    for (pixel.i = 0; pixel.i < pb->M; pixel.i++) { 
	ral_cell c;
	c.i = RAL_PBi2GDi(pb, pixel.i, layer->gd);
	for (pixel.j = 0; pixel.j < pb->N; pixel.j++) {
	    c.j = RAL_PBj2GDj(pb, pixel.j, layer->gd);
	    if (RAL_GRID_CELL_IN(layer->gd, c) AND RAL_REAL_GRID_DATACELL(layer->gd, c)) {
		double value = RAL_REAL_GRID_CELL(layer->gd, c);
		GDALColorEntry color;
		RAL_INITIAL_COLOR(pb, layer, pixel, color);
		RAL_NV2COLOR(pixel, layer, value, color, i2c);
		RAL_PIXBUF_ASSIGN_PIXEL_COLOR(pb, pixel, color);
	    }
	}
    }
    return 1;
}

int ral_render_square_real_grid(ral_pixbuf *pb, ral_real_grid_layer *layer, ral_interpolator i2c, double symbol_k)
{
    ral_cell c, pixel;
    for(c.i = 0; c.i < layer->gd->M; c.i++) {
	pixel.i = RAL_GDi2PBi(layer->gd, c.i, pb);
	if ((pixel.i < 0) OR (pixel.i >= pb->M)) continue;
	for(c.j = 0; c.j < layer->gd->N; c.j++) {
	    RAL_REAL value;
	    GDALColorEntry color;
	    int symbol_size;
	    if (RAL_REAL_GRID_NODATACELL(layer->gd, c)) continue;
	    pixel.j = RAL_GDj2PBj(layer->gd, c.j, pb);
	    if ((pixel.j < 0) OR (pixel.j >= pb->N)) continue;
	    value = RAL_REAL_GRID_CELL(layer->gd, c);
	    RAL_INITIAL_COLOR(pb, layer, pixel, color);
	    RAL_NV2COLOR(pixel, layer, value, color, i2c);
	    symbol_size = symbol_k > 0 ? 
		floor((value - layer->symbol_size_scale.min)*symbol_k + 0.5) :
		layer->symbol_pixel_size;
	    if (symbol_size < 1) continue;
	    if (symbol_size == 1) {
		RAL_PIXBUF_ASSIGN_PIXEL_COLOR(pb, pixel, color);
	    } else {
		int i2,j2;
		for (i2 = max(0, pixel.i-symbol_size+1); i2 < min(pb->M, pixel.i+symbol_size); i2++)
		    for (j2 = max(0, pixel.j-symbol_size+1); j2 < min(pb->N, pixel.j+symbol_size); j2++)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb, i2, j2, color);
	    }
	}
    }
    return 1;
}

int ral_render_dot_real_grid(ral_pixbuf *pb, ral_real_grid_layer *layer, ral_interpolator i2c, double symbol_k)
{
    ral_cell c, pixel;
    for(c.i = 0; c.i < layer->gd->M; c.i++) {
	pixel.i = RAL_GDi2PBi(layer->gd, c.i, pb);
	if ((pixel.i < 0) OR (pixel.i >= pb->M)) continue;
	for(c.j = 0; c.j < layer->gd->N; c.j++) {
	    RAL_REAL value;
	    GDALColorEntry color;
	    int r;
	    if (RAL_REAL_GRID_NODATACELL(layer->gd, c)) continue;
	    pixel.j = RAL_GDj2PBj(layer->gd, c.j, pb);
	    if ((pixel.j < 0) OR (pixel.j >= pb->N)) continue;
	    value = RAL_REAL_GRID_CELL(layer->gd, c);
	    RAL_INITIAL_COLOR(pb, layer, pixel, color);
	    RAL_NV2COLOR(pixel, layer, value, color, i2c);
	    r = symbol_k > 0 ? 
		floor((value - layer->symbol_size_scale.min)*symbol_k + 0.5) :
		layer->symbol_pixel_size;
	    if (r < 1) continue;
	    if (r == 1) {
		RAL_PIXBUF_ASSIGN_PIXEL_COLOR(pb, pixel, color);
	    } else {
		RAL_FILLED_CIRCLE(pb, pixel, r, color, RAL_PIXBUF_ASSIGN_PIXEL_COLOR);
	    }
	}
    }
    return 1;
}

int ral_render_cross_real_grid(ral_pixbuf *pb, ral_real_grid_layer *layer, ral_interpolator i2c, double symbol_k)
{
    ral_cell c, pixel;
    for(c.i = 0; c.i < layer->gd->M; c.i++) {
	pixel.i = RAL_GDi2PBi(layer->gd, c.i, pb);
	if ((pixel.i < 0) OR (pixel.i >= pb->M)) continue;
	for(c.j = 0; c.j < layer->gd->N; c.j++) {
	    RAL_REAL value;
	    GDALColorEntry color;
	    int symbol_size;
	    if (RAL_REAL_GRID_NODATACELL(layer->gd, c)) continue;
	    pixel.j = RAL_GDj2PBj(layer->gd, c.j, pb);
	    if ((pixel.j < 0) OR (pixel.j >= pb->N)) continue;
	    value = RAL_REAL_GRID_CELL(layer->gd, c);
	    RAL_INITIAL_COLOR(pb, layer, pixel, color);
	    RAL_NV2COLOR(pixel, layer, value, color, i2c);
	    symbol_size = symbol_k > 0 ? 
		floor((value - layer->symbol_size_scale.min)*symbol_k + 0.5) :
		layer->symbol_pixel_size;
	    if (symbol_size < 1) continue;
	    if (symbol_size == 1) {
		RAL_PIXBUF_ASSIGN_PIXEL_COLOR(pb, pixel, color);
	    } else {
		int i2, j2;
		for (i2 = max(0, pixel.i-symbol_size+1); i2 < min(pb->M, pixel.i+symbol_size); i2++)
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, i2, pixel.j, color);
		for (j2 = max(0, pixel.j-symbol_size+1); j2 < min(pb->N, pixel.j+symbol_size); j2++)
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, pixel.i, j2, color);
	    }
	}
    }
    return 1;
}

int ral_render_squares(ral_pixbuf *pb, ral_geometry *g, int symbol_size, GDALColorEntry color)
{
    int a, b;
    for (a = 0; a < g->n_parts; a++) 
	for (b = 0; b < g->parts[a].n; b++) {
	    ral_point p = g->parts[a].nodes[b];
	    if (RAL_POINT_IN_RECTANGLE(p,pb->world)) {
		int i = floor((pb->world.max.y - p.y)/pb->pixel_size);
		int j = floor((p.x - pb->world.min.x)/pb->pixel_size);
		int i2, j2;
		if (i == pb->M OR j == pb->N) /* case where y === min or x == max */
		    continue;
		for (i2 = max(0,i-symbol_size+1); i2 < min(pb->M,i+symbol_size); i2++)
		    for (j2 = max(0,j-symbol_size+1); j2 < min(pb->N,j+symbol_size); j2++)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb, i2,j2,color);
	    }
	}
    return 1;
}

int ral_render_dots(ral_pixbuf *pb, ral_geometry *g, int r, GDALColorEntry color)
{
    int a, b;
    for (a = 0; a < g->n_parts; a++) 
	for (b = 0; b < g->parts[a].n; b++) {
	    ral_point p = g->parts[a].nodes[b];
	    if (RAL_POINT_IN_RECTANGLE(p,pb->world)) {
		ral_cell pixel;
		pixel.i = floor((pb->world.max.y - p.y)/pb->pixel_size);
		pixel.j = floor((p.x - pb->world.min.x)/pb->pixel_size);
		if (pixel.i == pb->M OR pixel.j == pb->N) /* case where y === min or x == max */
		    continue;
		if (r == 1) {
		    RAL_PIXBUF_ASSIGN_PIXEL_COLOR(pb, pixel, color);
		} else {
		    RAL_FILLED_CIRCLE(pb, pixel, r, color, RAL_PIXBUF_ASSIGN_PIXEL_COLOR);
		}
	    }
	}
    return 1;
}

int ral_render_crosses(ral_pixbuf *pb, ral_geometry *g, int symbol_size, GDALColorEntry color)
{
    int a, b;
    for (a = 0; a < g->n_parts; a++) 
	for (b = 0; b < g->parts[a].n; b++) {
	    ral_point p = g->parts[a].nodes[b];
	    if (RAL_POINT_IN_RECTANGLE(p,pb->world)) {
		int i = floor((pb->world.max.y - p.y)/pb->pixel_size);
		int j = floor((p.x - pb->world.min.x)/pb->pixel_size);
		int i2, j2;
		if (i == pb->M OR j == pb->N)
		    continue;
		for (i2 = max(0,i-symbol_size+1); i2 < min(pb->M,i+symbol_size); i2++)
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, i2, j, color);
		for (j2 = max(0,j-symbol_size+1); j2 < min(pb->N,j+symbol_size); j2++)
		    RAL_PIXBUF_SET_PIXEL_COLOR(pb, i, j2, color);
	    }
	}
    return 1;
}

int ral_render_wind_roses(ral_pixbuf *pb, ral_feature *feature, visual *visualization)
{
    int a, b;
    static char *suunnat[8] = {"N","NE","E","SE","S","SW","W","NW"};
    for (a = 0; a < feature->ral_geom->n_parts; a++) 
	for (b = 0; b < feature->ral_geom->parts[a].n; b++) {
	    ral_point p = feature->ral_geom->parts[a].nodes[b];
	    if (RAL_POINT_IN_RECTANGLE(p,pb->world)) {
		int i = floor((pb->world.max.y - p.y)/pb->pixel_size);
		int j = floor((p.x - pb->world.min.x)/pb->pixel_size);
		int i2, j2;
		int k;
		if (i == pb->M OR j == pb->N)
		    continue;
		for (i2 = max(0,i-1); i2 < min(pb->M,i+1); i2++)
		    for (j2 = max(0,j-1); j2 < min(pb->N,j+1); j2++)
			RAL_PIXBUF_SET_PIXEL_COLOR(pb, i2, j2, feature->color);
		for (k = 0; k < 8; k++) {
		    int index = OGR_F_GetFieldIndex(feature->feature, suunnat[k]);
		    if (index >= 0) {
			int c, size;
			double val = OGR_F_GetFieldAsDouble(feature->feature, index);
			val = RAL_INTERPOLATE(visualization->nv2ss, val);
			if (k % 2) val /= 1.141593;
			size = floor(val);
			switch(k) {
			case 0: /* N */
			    for (i2 = min(pb->M,i); i2 > max(0,i-size); i2--)
				RAL_PIXBUF_SET_PIXEL_COLOR(pb, i2, j, feature->color);
			    break;
			case 1:
			    for (c = 0; c < size; c++)
				RAL_PIXBUF_SET_PIXEL_COLOR(pb, max(min(i-c,pb->M),0), max(min(j+c,pb->N),0), feature->color);
			    break;
			case 2: /* E */
			    for (j2 = max(0,j); j2 < min(pb->N,j+size); j2++)
				RAL_PIXBUF_SET_PIXEL_COLOR(pb, i, j2, feature->color);
			    break;
			case 3:
			    for (c = 0; c < size; c++)
				RAL_PIXBUF_SET_PIXEL_COLOR(pb, max(min(i+c,pb->M),0), max(min(j+c,pb->N),0), feature->color);
			    break;
			case 4: /* S */
			    for (i2 = max(0,i); i2 < min(pb->M,i+size); i2++)
				RAL_PIXBUF_SET_PIXEL_COLOR(pb, i2, j, feature->color);
			    break;
			case 5:
			    for (c = 0; c < size; c++)
				RAL_PIXBUF_SET_PIXEL_COLOR(pb, max(min(i+c,pb->M),0), max(min(j-c,pb->N),0), feature->color);
			    break;
			case 6: /* W */
			    for (j2 = min(pb->N,j); j2 > max(0,j-size); j2--)
				RAL_PIXBUF_SET_PIXEL_COLOR(pb, i, j2, feature->color);
			    break;
			case 7:
			    for (c = 0; c < size; c++)
				RAL_PIXBUF_SET_PIXEL_COLOR(pb, max(min(i-c,pb->M),0), max(min(j-c,pb->N),0), feature->color);
			    break;
			}
		    }
		}
	    }
	}
    return 1;
}

int ral_render_polylines(ral_pixbuf *pb, ral_geometry *g, GDALColorEntry color)
{
    int i, j;
    for (i = 0; i < g->n_parts; i++)
	for (j = 0; j < g->parts[i].n - 1; j++) {
	    /* draw line from g->parts[i].nodes[j] to g->parts[i].nodes[j+1] */
	    /* clip */
	    ral_line l;
	    l.begin = g->parts[i].nodes[j];
	    l.end = g->parts[i].nodes[j+1];
	    if (ral_clip_line_to_rect(&l,&(pb->world))) {
		ral_cell cell1, cell2;
		cell1.i = floor((pb->world.max.y - l.begin.y)/pb->pixel_size);
		cell1.j = floor((l.begin.x - pb->world.min.x)/pb->pixel_size);
		cell2.i = floor((pb->world.max.y - l.end.y)/pb->pixel_size);
		cell2.j = floor((l.end.x - pb->world.min.x)/pb->pixel_size);
		RAL_LINE(pb, cell1, cell2, color, RAL_PIXBUF_ASSIGN_PIXEL_COLOR);
	    }
	}
    return 1;
}

int ral_render_polygons(ral_pixbuf *pb, ral_geometry *g, GDALColorEntry color)
{
    if (g->n_points == 0) return 1;
    ral_active_edge_table *aet_list = ral_get_active_edge_tables(&(g->parts), g->n_parts);
    RAL_CHECK(aet_list);
    ral_cell c;
    double y = pb->world.min.y + 0.5*pb->pixel_size;
    for (c.i = pb->M - 1; c.i >= 0; c.i--) {
	double *x;
	int n;
	ral_scanline_at(aet_list, g->n_parts, y, &x, &n);
	if (x) {
	    int draw = 0;
	    int begin = 0;
	    int k;
	    while ((begin < n) AND (x[begin] < pb->world.min.x)) {
		begin++;
		draw = !draw;
	    }
	    c.j = 0;
	    for (k = begin; k < n; k++) {
		int jmax = floor((x[k] - pb->world.min.x)/pb->pixel_size+0.5);
		while ((c.j < pb->N) AND (c.j < jmax)) {
		    if (draw) RAL_PIXBUF_SET_PIXEL_COLOR(pb, c.i, c.j, color);
		    c.j++;
		}
		if (c.j == pb->N) break;
		draw = !draw;
	    }
	    ral_delete_scanline(&x);
	}
	y += pb->pixel_size;
    }
    ral_active_edge_tables_destroy(&aet_list, g->n_parts);
    return 1;
 fail:
    return 0;
}

int ral_setup_color_interpolator(visual *visualization, OGRFeatureDefnH defn)
{

    if (visualization->color_field >= 0) {
	RAL_CHECK(ral_get_field_type(defn, visualization->color_field, &(visualization->color_field_type))); 
    } else if (visualization->color_field == RAL_FIELD_FID)
	visualization->color_field_type = OFTInteger;
    else if (visualization->color_field == RAL_FIELD_Z)
	visualization->color_field_type = OFTReal;

    switch (visualization->palette_type) {
    case RAL_PALETTE_SINGLE_COLOR:
	break;					
    case RAL_PALETTE_GRAYSCALE: {
	ral_double_range y;
	y.min = 0;
	switch(visualization->scale) {
	case RAL_SCALE_GRAY:
	case RAL_SCALE_OPACITY:
	    y.max = 255.999;
	    break;
	case RAL_SCALE_HUE:
	    y.max = 360.999;
	    break;
	case RAL_SCALE_SATURATION:
	case RAL_SCALE_VALUE:
	    y.max = 100.999;
	    break;
	default:
	    y.max = 0;
	}
	switch (visualization->color_field_type) {
	case OFTInteger:					
	    RAL_INTERPOLATOR_SETUP(visualization->nv2c, visualization->color_scale_int, y);
	    break;							
	case OFTReal:							
	    RAL_INTERPOLATOR_SETUP(visualization->nv2c, visualization->color_scale_double, y);   
	    break;							
	default:							
	    RAL_CHECKM(0, ral_msg("Invalid field type for grayscale palette: %i.", visualization->color_field_type));
	}
	break;
    }					
    case RAL_PALETTE_RAINBOW: {
	ral_int_range r = visualization->hue_at;
	r.min = max(min(r.min, 360), 0);
	r.max = max(min(r.max, 360), 0);
	if (visualization->invert == RAL_RGB_HUE) {
	    if (r.max < r.min) r.max += 360;
	} else {
	    if (r.max > r.min) r.max -= 360;
	}
	switch (visualization->color_field_type) {					
	case OFTInteger:						
	    RAL_INTERPOLATOR_SETUP(visualization->nv2c, visualization->color_scale_int, r); 
	    break;							
	case OFTReal:							
	    RAL_INTERPOLATOR_SETUP(visualization->nv2c, visualization->color_scale_double, r); 
	    break;							
	case OFTString:							
	    break;							
	default:							
	    RAL_CHECKM(0, ral_msg("Invalid field type for rainbow palette: %i.", visualization->color_field_type));
	}								
	break;			
    }
    case RAL_PALETTE_COLOR_TABLE:					
	switch (visualization->color_field_type) {					
	case OFTString:							
	case OFTInteger:						
	    break;							
	default:							
	    RAL_CHECKM(0, ral_msg("Invalid field type for color table palette: %i.", visualization->color_field_type));
	}								
	break;								
    case RAL_PALETTE_COLOR_BINS:					
	switch (visualization->color_field_type) {
	case OFTInteger:
	case OFTReal:
	    break;
	default:
	    RAL_CHECKM(0, ral_msg("Invalid field type for color bins palette: %i.", visualization->color_field_type));
	}
	break;
    default:
	RAL_CHECKM(0, ral_msg("Invalid palette type for visual: %i.", visualization->palette_type));
    }
    return 1;
 fail:
    return 0;
}

void ral_set_color(visual *visualization, ral_feature *feature)
{
    switch (visualization->palette_type) 
    {
    case RAL_PALETTE_SINGLE_COLOR:
	feature->color = visualization->single_color;
	feature->color.c4 = (feature->color.c4*visualization->alpha)/255;
	break;
    case RAL_PALETTE_GRAYSCALE:
    {
	short c = 0;
	switch (visualization->color_field_type)
	{
	case OFTInteger:
	    if (visualization->color_field == RAL_FIELD_FID) {
		double key = OGR_F_GetFID(feature->feature);
		c = floor(RAL_INTERPOLATE(visualization->nv2c, key));
	    } else if ((visualization->color_field >= 0) AND OGR_F_IsFieldSet(feature->feature, visualization->color_field)) { 
		OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visualization->color_field); 
		c = floor(RAL_INTERPOLATE(visualization->nv2c, field->Integer)); 
	    }
	    break;
	case OFTReal:
	    if (visualization->color_field == RAL_FIELD_Z) {
		OGRGeometryH g = feature->geometry;
		int k = OGR_G_GetGeometryCount(g);
		if (k)
		    g = OGR_G_GetGeometryRef(g, 0);
		c = floor(RAL_INTERPOLATE(visualization->nv2c, OGR_G_GetZ(g, 0)));
	    } else if ((visualization->color_field >= 0) AND OGR_F_IsFieldSet(feature->feature, visualization->color_field)) {
		OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visualization->color_field);
		c = floor(RAL_INTERPOLATE(visualization->nv2c, field->Real));
	    }
	    break;
	default:
	    break;
	}
	if (visualization->scale == RAL_SCALE_GRAY) {
	    feature->color.c1 = feature->color.c2 = feature->color.c3 = c;
	    feature->color.c4 = visualization->alpha;
	} else {
	    feature->color = ral_rgb2hsv(visualization->grayscale_base_color);
	    switch(visualization->scale) {
	    case RAL_SCALE_HUE:
		feature->color.c1 = c;
		break;
	    case RAL_SCALE_SATURATION:
		feature->color.c2 = c;
		break;
	    case RAL_SCALE_VALUE:
		feature->color.c3 = c;
		break;	
	    case RAL_SCALE_OPACITY:
		feature->color.c4 = c;
		break;	
	    }
	    feature->color = ral_hsv2rgb(feature->color);
	}
	break;
    }
    case RAL_PALETTE_RAINBOW:
    {
	short c = 0;
	switch (visualization->color_field_type) {
	case OFTInteger:
	    if (visualization->color_field == RAL_FIELD_FID) {
		double key = OGR_F_GetFID(feature->feature);
		c = floor(RAL_INTERPOLATE(visualization->nv2c, key));
	    } else if ((visualization->color_field >= 0) AND OGR_F_IsFieldSet(feature->feature, visualization->color_field)) {
		OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visualization->color_field);
		c = floor(RAL_INTERPOLATE(visualization->nv2c, field->Integer));
	    }
	    break;
	case OFTReal:
	    if (visualization->color_field == RAL_FIELD_Z) {
		OGRGeometryH g = feature->geometry;
		while (OGR_G_GetGeometryCount(g))
		    g = OGR_G_GetGeometryRef(g, 0);
		c = floor(RAL_INTERPOLATE(visualization->nv2c, OGR_G_GetZ(g, 0)));
	    } else if ((visualization->color_field >= 0) AND OGR_F_IsFieldSet(feature->feature, visualization->color_field)) {
		OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visualization->color_field);
		c = floor(RAL_INTERPOLATE(visualization->nv2c, field->Real));
	    }
	    break;
	default:
	    break;
	}
	feature->color.c1 = c;
	if ((feature->color.c1) > 360) feature->color.c1 -= 360;
	if ((feature->color.c1) < 0) feature->color.c1 += 360;
	feature->color.c2 = feature->color.c3 = 100;
	feature->color = ral_hsv2rgb(feature->color);
	feature->color.c4 = visualization->alpha;
	break;
    }
    case RAL_PALETTE_COLOR_TABLE:
    {
	switch(visualization->color_field_type){
	case OFTInteger:
	    if (visualization->color_field == RAL_FIELD_FID){
		long key = OGR_F_GetFID(feature->feature);
		RAL_COLOR_TABLE_GET(visualization->color_table, key, feature->color);
	    } else if ((visualization->color_field >= 0) AND OGR_F_IsFieldSet(feature->feature, visualization->color_field)) {
		OGRField*field = OGR_F_GetRawFieldRef(feature->feature, visualization->color_field);
                /*fprintf(stderr, "value %i\n", field->Integer);*/
		RAL_COLOR_TABLE_GET(visualization->color_table, field->Integer, feature->color);
                /*fprintf(stderr, "color %i %i %i\n", feature->color.c1, feature->color.c2, feature->color.c3);*/
	    }
	    break;
	case OFTString:
	    if ((visualization->color_field >= 0) AND OGR_F_IsFieldSet(feature->feature, visualization->color_field)) {
		OGRField*field = OGR_F_GetRawFieldRef(feature->feature, visualization->color_field);
		RAL_STRING_COLOR_TABLE_GET(visualization->string_color_table, field->String, feature->color);
	    }
	    break;
	default:
	    break;
	}
	feature->color.c4 = (feature->color.c4*visualization->alpha)/255;
	break;
    }
    case RAL_PALETTE_COLOR_BINS:
	switch(visualization->color_field_type) {
	case OFTInteger:
	    if (visualization->color_field == RAL_FIELD_FID) {
		long key = OGR_F_GetFID(feature->feature);
		RAL_COLOR_BINS_GET(visualization->int_bins, key, feature->color);
	    } else if ((visualization->color_field >= 0) AND OGR_F_IsFieldSet(feature->feature, visualization->color_field)) {
		OGRField*field = OGR_F_GetRawFieldRef(feature->feature, visualization->color_field);
		RAL_COLOR_BINS_GET(visualization->int_bins, field->Integer, feature->color);
	    }
	    break;
	case OFTReal:
	    if (visualization->color_field == RAL_FIELD_Z) {
		OGRGeometryH g = feature->geometry;
		int k = OGR_G_GetGeometryCount(g);
		if (k)
		    g = OGR_G_GetGeometryRef(g, 0);
		RAL_COLOR_BINS_GET(visualization->double_bins, OGR_G_GetZ(g, 0), feature->color);
	    } else if ((visualization->color_field >= 0) AND OGR_F_IsFieldSet(feature->feature, visualization->color_field)) {
		OGRField*field = OGR_F_GetRawFieldRef(feature->feature, visualization->color_field);
		RAL_COLOR_BINS_GET(visualization->double_bins, field->Real, feature->color);
	    }
	    break;
	default:
	    break;
	}
	feature->color.c4 = (feature->color.c4*visualization->alpha)/255;
    }
}

int ral_render_feature(ral_pixbuf *pb, ral_feature *feature, visual *visualization)
{
    if (visualization->symbol AND ((feature->geometry_type == wkbPolygon) OR (feature->geometry_type == wkbMultiPolygon))) {

/* this may be very slow in some cases, maybe an option to use the extent could be added? */ 

	int t = wkbFlatten(OGR_G_GetGeometryType(feature->geometry)); /* multipolygons in polygon */

	OGRGeometryH g = feature->geometry;
	OGRGeometryH centroid;

	if (t == wkbMultiPolygon) {
	    int n = OGR_G_GetGeometryCount(feature->geometry);
	    double max_size;
	    int i, i_of_max;
	    RAL_CHECK(n > 0);
	    max_size = 0;
	    i_of_max = 0;
	    for (i = 0; i < n; i++) {
		double size;
		g = OGR_G_GetGeometryRef(feature->geometry, i);
		size = OGR_G_Area(g);
		if (i == 0 OR size > max_size) {
		    max_size = size;
		    i_of_max = i;
		}
	    }
	    g = OGR_G_GetGeometryRef(feature->geometry, i_of_max);
	}
	centroid = OGR_G_CreateGeometry(wkbPoint);
	RAL_CHECK(OGR_G_Centroid(g, centroid) != OGRERR_FAILURE);
	if (feature->destroy_geometry) OGR_G_DestroyGeometry(feature->geometry);
	feature->geometry = centroid;
	feature->destroy_geometry = 1;
    }

    RAL_CHECK(feature->ral_geom = ral_geometry_create_from_OGR(feature->geometry));
    
    if (visualization->symbol) {
	int size = 0;
	switch (visualization->symbol_size_field_type) {
	case OFTInteger:
	    if (visualization->symbol_size_field >= 0) {
		if (OGR_F_IsFieldSet(feature->feature, visualization->symbol_size_field)) {
		    OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visualization->symbol_size_field); 
		    size = floor(RAL_INTERPOLATE(visualization->nv2ss, field->Integer));
		}
	    } else if (visualization->symbol_size_field == RAL_FIELD_FID)
		size = floor(RAL_INTERPOLATE(visualization->nv2ss, OGR_F_GetFID(feature->feature)));
	    else if (visualization->symbol_size_field == RAL_FIELD_FIXED_SIZE)
		size = visualization->symbol_size;
	    break;
	case OFTReal:
	    if ((visualization->symbol_size_field >= 0) AND OGR_F_IsFieldSet(feature->feature, visualization->symbol_size_field)) {
		OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visualization->symbol_size_field);
		size = floor(RAL_INTERPOLATE(visualization->nv2ss, field->Real));
	    }
	    break;
	default:
	    break;
	}
	switch (visualization->symbol) {
	case RAL_SYMBOL_SQUARE:
	    if (size > 0)
		ral_render_squares(pb, feature->ral_geom, size, feature->color);
	    break;
	case RAL_SYMBOL_DOT:
	    if (size > 0)
		ral_render_dots(pb, feature->ral_geom, size, feature->color);
	    break;
	case RAL_SYMBOL_CROSS:
	    if (size > 0)
		ral_render_crosses(pb, feature->ral_geom, size, feature->color);
	    break;
	case RAL_SYMBOL_WIND_ROSE:
	    ral_render_wind_roses(pb, feature, visualization);
	    break;
	default:
	    if (size > 0)
		ral_render_crosses(pb, feature->ral_geom, size, feature->color);
	    break;
	}
    } else if (feature->geometry_type == wkbLineString OR feature->geometry_type == wkbMultiLineString) {
	RAL_CHECK(ral_render_polylines(pb, feature->ral_geom, feature->color));
    } else {
	RAL_CHECK(ral_render_polygons(pb, feature->ral_geom, feature->color));
    }
		
    ral_geometry_destroy(&(feature->ral_geom));
    if (feature->destroy_geometry) {
	OGR_G_DestroyGeometry(feature->geometry);
	feature->destroy_geometry = 0;
	feature->geometry = NULL;
    }
    return 1;
    
fail:
    if (feature->ral_geom) ral_geometry_destroy(&(feature->ral_geom));
    if (feature->destroy_geometry) OGR_G_DestroyGeometry(feature->geometry);
    return 0;
}

visual *ral_get_visualization(ral_visual *visual, OGRFeatureH feature)
{
    return &(visual->visuals[0]);
}

int ral_render_visual_layer(ral_pixbuf *pb, ral_visual_layer *layer)
{
    ral_feature feature;
    int ret = 1;
    OGRFeatureDefnH defn = OGR_L_GetLayerDefn(layer->layer);
    
    feature.feature = NULL;

    CPLPushErrorHandler(ral_cpl_error);

    /* set up interpolators in all visualizations */

    for (int i = 0; i < layer->visualization->n; i++) {
	visual *visualization = &(layer->visualization->visuals[i]);
	ral_double_range y;

	y.min = 0;
	y.max = visualization->symbol_size+1;
	
	if (visualization->symbol_size_field >= 0) {
	    RAL_CHECK(ral_get_field_type(defn, visualization->symbol_size_field, &visualization->symbol_size_field_type));
	} else if (visualization->symbol_size_field == RAL_FIELD_FID)
	    visualization->symbol_size_field_type = OFTInteger;
	else if (visualization->symbol_size_field == RAL_FIELD_FIXED_SIZE)
	    visualization->symbol_size_field_type = OFTInteger;
	else
	    visualization->symbol_size_field_type = 0;

	switch (visualization->symbol_size_field_type) {
	case OFTInteger:
	    RAL_INTERPOLATOR_SETUP(visualization->nv2ss, visualization->symbol_size_scale_int, y);
	    break;
	case OFTReal:
	    RAL_INTERPOLATOR_SETUP(visualization->nv2ss, visualization->symbol_size_scale_double, y);
	    break;
	default:
	    RAL_CHECKM(0, ral_msg("Invalid field type for symbol size: %i.", visualization->symbol_size_field_type));
	}

	visualization->color_field_type = 0;
	RAL_CHECK(ral_setup_color_interpolator(visualization, defn));
    
    }

    OGR_L_SetSpatialFilterRect(layer->layer, pb->world.min.x, pb->world.min.y, pb->world.max.x, pb->world.max.y);
    
    OGR_L_ResetReading(layer->layer);

    while ((feature.feature = OGR_L_GetNextFeature(layer->layer))) {

	int i, n;
	OGRGeometryH geometry = OGR_F_GetGeometryRef(feature.feature);
	if (!geometry) {
	    fprintf(stderr, "Warning: OGR_F_GetGeometryRef returned a null geometry.\n");
	    OGR_F_Destroy(feature.feature);
	    break;
	}

	visual *visualization = ral_get_visualization(layer->visualization, feature.feature);

	feature.destroy_geometry = 0;

	if (wkbFlatten(OGR_G_GetGeometryType(geometry)) == wkbGeometryCollection) {
	    n = OGR_G_GetGeometryCount(geometry);
	    if (n == 0) continue;
	    feature.geometry = OGR_G_GetGeometryRef(geometry, 0);
	} else {
	    n = 1;
	    feature.geometry = geometry;
	}

	for (i = 0; i < n; i++) {

	    if (i > 0)
		feature.geometry = OGR_G_GetGeometryRef(geometry, i);

	    feature.geometry_type = wkbFlatten(OGR_G_GetGeometryType(feature.geometry));

	    if (!visualization->symbol) {
		OGREnvelope e;
		OGR_G_GetEnvelope( feature.geometry, &e );
		/* if smaller than one pixel, do not draw lines or areas */
		if (((e.MaxX-e.MinX) < pb->pixel_size) AND ((e.MaxY-e.MinY) < pb->pixel_size)) {
		    if (feature.destroy_geometry) OGR_G_DestroyGeometry(feature.geometry);
		    continue;
		}
	    }
	    
	    RAL_FEATURE_SET_COLOR(feature, 0, 0, 0, 0); /* by default nothing is shown */
	    
	    ral_set_color(visualization, &feature);
	    
	    if (feature.color.c4 > 0)
		ral_render_feature(pb, &feature, visualization);

	    if (feature.destroy_geometry) {
		OGR_G_DestroyGeometry(feature.geometry);
		feature.destroy_geometry = 0;
		feature.geometry = NULL;
	    }

	}

	OGR_F_Destroy(feature.feature);
	
	continue;

    fail:
	
	if (feature.feature) OGR_F_Destroy(feature.feature);
	if (feature.destroy_geometry AND feature.geometry) OGR_G_DestroyGeometry(feature.geometry);
	ret = 0;
	
	break;
	
    }
    OGR_L_SetSpatialFilter(layer->layer, NULL);
    CPLPopErrorHandler();
    return ret;
}

int ral_render_visual_feature_table(ral_pixbuf *pb, ral_visual_feature_table *t)
{
    ral_feature feature;
    int ret = 1;
    int j, n;

    CPLPushErrorHandler(ral_cpl_error);
    
    for (int i = 0; i < t->size; i++) {

	OGRGeometryH geometry;
	OGRFeatureDefnH defn;

	feature.destroy_geometry = 0; /* the geom after it has been rendered */

	defn = OGR_F_GetDefnRef(t->features[i]);

	visual *visualization = ral_get_visualization(t->visualization, t->features[i]);

	ral_double_range y;

	y.min = 0;
	y.max = visualization->symbol_size+1;
	
	if (visualization->symbol_size_field >= 0) {
	    RAL_CHECK(ral_get_field_type(defn, visualization->symbol_size_field, &visualization->symbol_size_field_type));
	} else if (visualization->symbol_size_field == RAL_FIELD_FID)
	    visualization->symbol_size_field_type = OFTInteger;
	else if (visualization->symbol_size_field == RAL_FIELD_FIXED_SIZE)
	    visualization->symbol_size_field_type = OFTInteger;
	else
	    visualization->symbol_size_field_type = 0;

	switch (visualization->symbol_size_field_type) {
	case OFTInteger:
	    RAL_INTERPOLATOR_SETUP(visualization->nv2ss, visualization->symbol_size_scale_int, y);
	    break;
	case OFTReal:
	    RAL_INTERPOLATOR_SETUP(visualization->nv2ss, visualization->symbol_size_scale_double, y);
	    break;
	default:
	    RAL_CHECKM(0, ral_msg("Invalid field type for symbol size: %i.", visualization->symbol_size_field_type));
	}

	visualization->color_field_type = 0;
	RAL_CHECK(ral_setup_color_interpolator(visualization, defn));

	if (visualization->symbol_size_field >= 0) {
	    RAL_CHECK(ral_get_field_type(defn, visualization->symbol_size_field, &(visualization->symbol_size_field_type)));
	} else if (visualization->symbol_size_field == RAL_FIELD_FID)
	    visualization->symbol_size_field_type = OFTInteger;

	y.min = 0;
	y.max = visualization->symbol_size+1;
	switch (visualization->symbol_size_field_type) {
	case OFTInteger:
	    RAL_INTERPOLATOR_SETUP(visualization->nv2ss, visualization->symbol_size_scale_int, y);
	    break;
	case OFTReal:
	    RAL_INTERPOLATOR_SETUP(visualization->nv2ss, visualization->symbol_size_scale_double, y);
	    break;
	default:
	    RAL_CHECKM(0, ral_msg("Invalid field type for symbol size: %i.", visualization->symbol_size_field_type));
	}

	RAL_CHECK(ral_setup_color_interpolator(visualization, defn));
	
	feature.feature = t->features[i];

	geometry = OGR_F_GetGeometryRef(feature.feature);

	if (!geometry) {
	    fprintf(stderr, "Warning: OGR_F_GetGeometryRef returned a null geometry.\n");
	    break;
	}

	if (wkbFlatten(OGR_G_GetGeometryType(geometry)) == wkbGeometryCollection) {
	    n = OGR_G_GetGeometryCount(geometry);
	    if (n == 0) continue;
	    feature.geometry = OGR_G_GetGeometryRef(geometry, 0);
	} else {
	    n = 1;
	    feature.geometry = geometry;
	}

	for (j = 0; j < n; j++) {

	    if (j > 0)
		feature.geometry = OGR_G_GetGeometryRef(geometry, j);

	    feature.geometry_type = wkbFlatten(OGR_G_GetGeometryType(feature.geometry));
	    
	    if (visualization->symbol) {
		OGREnvelope e;
		OGR_G_GetEnvelope( feature.geometry, &e );
		/* if smaller than one pixel, do not draw anything */
		if (((e.MaxX-e.MinX) < pb->pixel_size) AND ((e.MaxY-e.MinY) < pb->pixel_size)) {
		    continue;
		}
	    }
	    
	    RAL_FEATURE_SET_COLOR(feature, 0, 0, 0, 0); /* by default nothing is shown */

	    ral_set_color(visualization, &feature);

	    if (feature.color.c4 > 0)
		ral_render_feature(pb, &feature, visualization);

	}

	continue;

    fail:

	ret = 0;
	break;
	
    }
    CPLPopErrorHandler();
    return ret;
}

int ral_get_field_type(OGRFeatureDefnH defn, int field, OGRFieldType *field_type) 
{
    OGRFieldDefnH d;
    RAL_CHECK(defn);
    RAL_CHECKM(field >= 0 AND field < OGR_FD_GetFieldCount(defn), 
	       ral_msg("The schema for %s does not have field %i.", OGR_FD_GetName(defn), field));
    d = OGR_FD_GetFieldDefn(defn, field);
    *field_type = OGR_Fld_GetType(d);
    return 1;
fail:
    return 0;
}

#endif
#endif
