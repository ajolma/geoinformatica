#include "config.h"
#include "msg.h"
#include "ral.h"

#ifdef RAL_HAVE_GDAL
#ifdef RAL_HAVE_GDK_PIXBUF

OGRCoordinateTransformationH CPL_STDCALL 
OCTNewCoordinateTransformation(
    OGRSpatialReferenceH hSourceSRS, OGRSpatialReferenceH hTargetSRS );

#define to255(i,s) floor((255.0*(double)(i)/(double)(s))+0.5)

/* after www.cs.rit.edu/~ncs/color/t_convert.html */
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

int ral_render_default_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io);
int ral_render_flow_direction_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer);
int ral_render_square_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io, double symbol_k);
int ral_render_dot_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io, double symbol_k);
int ral_render_cross_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer, ral_interpolator io, double symbol_k);

int ral_render_integer_grid(ral_pixbuf *pb, ral_integer_grid_layer *layer)
{
    ral_interpolator i2c;
    ral_grid *gd = layer->gd;
    ral_double_range y;
    RAL_CHECKM(layer->gd, "No grid to render.");
    RAL_CHECKM(!layer->alpha_grid OR layer->alpha_grid->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ALPHA_IS_INTEGER);

    switch(layer->palette_type) {
    case RAL_PALETTE_SINGLE_COLOR:
	break;
    case RAL_PALETTE_GRAYSCALE:
    case RAL_PALETTE_RED_CHANNEL:
    case RAL_PALETTE_GREEN_CHANNEL:
    case RAL_PALETTE_BLUE_CHANNEL:
	if (layer->range.max <= layer->range.min)
	    ral_integer_grid_get_value_range(gd, &(layer->range));
	y.min = 0;
	if (layer->hue < 0)
	    y.max = 255.99;
	else {
	    layer->hue = max(min(layer->hue,360),0);
	    y.max = 100.99;
	}
	RAL_INTERPOLATOR_SETUP(i2c, layer->range, y);
	break;
    case RAL_PALETTE_RAINBOW: {
	ral_int_range r = layer->hue_at;
	r.min = max(min(r.min, 360), 0);
	r.max = max(min(r.max, 360), 0);
	if (layer->hue_dir == 1) {
	    if (r.max < r.min) r.max += 360;
	} else {
	    if (r.max > r.min) r.max -= 360;
	}
	if (layer->range.max <= layer->range.min)
	    ral_integer_grid_get_value_range(gd, &(layer->range));
	RAL_INTERPOLATOR_SETUP(i2c, layer->range, r);
	break;
    }
    case RAL_PALETTE_COLOR_TABLE:
	/*RAL_CHECKM(layer->color_table, "No color table although color table palette.");*/
	break;
    case RAL_PALETTE_COLOR_BINS:
	/*RAL_CHECKM(layer->color_bins, "No color bins although color bins palette.");*/
	break;
    default:
	RAL_CHECKM(0, ral_msg("Invalid palette type for integer grid: %i.", layer->palette_type));
    }

    if (layer->gd->cell_size/pb->pixel_size >= 5.0) {
	double symbol_k = 0;
	if (layer->symbol_size_max > layer->symbol_size_min)
	    symbol_k = (double)layer->symbol_pixel_size/(double)(layer->symbol_size_max - layer->symbol_size_min);
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
	RAL_PIXEL2CELL(pixel, (layer)->alpha_grid, c);		\
	if (RAL_GRID_CELL_IN((layer)->alpha_grid, c) AND RAL_INTEGER_GRID_DATACELL((layer)->alpha_grid, c)) \
	    (color).c4 = RAL_INTEGER_GRID_CELL((layer)->alpha_grid, c);		\
    } else if ((layer)->alpha >= 0)					\
	(color).c4 = ((color).c4*(layer)->alpha)/255;

#define RAL_NV2COLOR(pixel, layer, nv, color, i2c)			\
    switch((layer)->palette_type) {					\
    case RAL_PALETTE_GRAYSCALE:						\
	if ((layer)->hue < 0) {						\
	    (color).c1 = (color).c2 = (color).c3 = floor(RAL_INTERPOLATE(i2c, (double)nv)); \
	    (color).c4 = 255;						\
	} else {							\
            (color).c1 = layer->hue;                                    \
            (color).c2 = 100;                                           \
            (color).c3 = floor(RAL_INTERPOLATE(i2c, (double)nv));	\
	    (color) = ral_hsv2rgb(color);				\
	    (color).c4 = 255;     	                                \
	}								\
	break;								\
    case RAL_PALETTE_RED_CHANNEL:					\
        (color).c1 = floor(RAL_INTERPOLATE(i2c, (double)nv));           \
        (color).c4 = 255;						\
        break;								\
    case RAL_PALETTE_GREEN_CHANNEL:					\
        (color).c2 = floor(RAL_INTERPOLATE(i2c, (double)nv));           \
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
    }									\
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
		floor((value - layer->symbol_size_min)*symbol_k + 0.5) :
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
		floor((value - layer->symbol_size_min)*symbol_k + 0.5) :
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
		floor((value - layer->symbol_size_min)*symbol_k + 0.5) :
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
    ral_double_range y;
    ral_grid *gd;
    RAL_CHECKM(layer->gd, "No grid to render.");
    RAL_CHECKM(!layer->alpha_grid OR layer->alpha_grid->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ALPHA_IS_INTEGER);
    gd = layer->gd;

    switch(layer->palette_type) {
    case RAL_PALETTE_SINGLE_COLOR:
	break;
    case RAL_PALETTE_GRAYSCALE:
	if (layer->range.max <= layer->range.min)
	    ral_real_grid_get_value_range(gd, &(layer->range));
	y.min = 0;
	if (layer->hue < 0)
	    y.max = 255.99;
	else {
	    layer->hue = max(min(layer->hue,360),0);
	    y.max = 100.99;
	}
	RAL_INTERPOLATOR_SETUP(i2c, layer->range, y);
	break;
    case RAL_PALETTE_RAINBOW: {
	ral_int_range r = layer->hue_at;
	r.min = max(min(r.min,360),0);
	r.max = max(min(r.max,360),0);
	if (layer->hue_dir == 1) {
	    if (r.max < r.min) r.max += 360;
	} else {
	    if (r.max > r.min) r.max -= 360;
	}
	if (layer->range.max <= layer->range.min)
	    ral_real_grid_get_value_range(gd, &(layer->range));
	RAL_INTERPOLATOR_SETUP(i2c, layer->range, r);
	break;
    }
    case RAL_PALETTE_COLOR_BINS:
	/*RAL_CHECKM(layer->color_bins, "No color bins although color bins palette.");*/
	break;
    default:
	RAL_CHECKM(0, ral_msg("Invalid palette type for real grid: %i.", layer->palette_type));
    }

    if (layer->gd->cell_size/pb->pixel_size >= 5.0) {
	double symbol_k = 0;
	if (layer->symbol_size_max > layer->symbol_size_min)
	    symbol_k = (double)layer->symbol_pixel_size/(double)(layer->symbol_size_max - layer->symbol_size_min);
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
		floor((value - layer->symbol_size_min)*symbol_k + 0.5) :
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
		floor((value - layer->symbol_size_min)*symbol_k + 0.5) :
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
		floor((value - layer->symbol_size_min)*symbol_k + 0.5) :
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

int ral_render_wind_roses(ral_pixbuf *pb, ral_feature *feature, ral_visual *visualization)
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
			val = RAL_INTERPOLATE(feature->nv2ss, val);
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
	    if (ral_clip_line_to_rect(&l,pb->world)) {
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
    ral_active_edge_table *aet_list = ral_get_active_edge_tables(g->parts, g->n_parts);
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

int ral_setup_color_interpolator(ral_visual visualization, OGRFeatureDefnH defn, ral_feature *feature)
{

    if (visualization.color_field >= 0) {
	RAL_CHECK(ral_get_field_type(defn, visualization.color_field, &(feature->color_field_type))); 
    } else if (visualization.color_field == -1)
	feature->color_field_type = OFTInteger; /* FID */
    else if (visualization.color_field == -2)
	feature->color_field_type = OFTReal; /* Z */

    switch (visualization.palette_type) {
    case RAL_PALETTE_SINGLE_COLOR:
	break;					
    case RAL_PALETTE_GRAYSCALE: {
	ral_double_range y;
	y.min = 0;
	if (visualization.hue < 0)
	    y.max = 255.99;
	else {
	    visualization.hue = max(min(visualization.hue,360),0);
	    y.max = 100.99;
	}
	switch (feature->color_field_type) {
	case OFTInteger:					
	    RAL_INTERPOLATOR_SETUP(feature->nv2c, visualization.color_int, y);
	    break;							
	case OFTReal:							
	    RAL_INTERPOLATOR_SETUP(feature->nv2c, visualization.color_double, y);   
	    break;							
	default:							
	    RAL_CHECKM(0, ral_msg("Invalid field type for grayscale palette: %s.", 
				  OGR_GetFieldTypeName(feature->color_field_type)));
	}
	break;
    }					
    case RAL_PALETTE_RAINBOW: {
	ral_int_range r = visualization.hue_at;
	r.min = max(min(r.min, 360), 0);
	r.max = max(min(r.max, 360), 0);
	if (visualization.hue_dir == 1) {
	    if (r.max < r.min) r.max += 360;
	} else {
	    if (r.max > r.min) r.max -= 360;
	}
	switch (feature->color_field_type) {					
	case OFTInteger:						
	    RAL_INTERPOLATOR_SETUP(feature->nv2c, visualization.color_int, r); 
	    break;							
	case OFTReal:							
	    RAL_INTERPOLATOR_SETUP(feature->nv2c, visualization.color_double, r); 
	    break;							
	case OFTString:							
	    break;							
	default:							
	    RAL_CHECKM(0, ral_msg("Invalid field type for rainbow palette: %s.", 
				  OGR_GetFieldTypeName(feature->color_field_type)));
	}								
	break;			
    }
    case RAL_PALETTE_COLOR_TABLE:					
	switch (feature->color_field_type) {					
	case OFTString:							
	case OFTInteger:						
	    break;							
	default:							
	    RAL_CHECKM(0, ral_msg("Invalid field type for color table palette: %s.", 
				  OGR_GetFieldTypeName(feature->color_field_type)));
	}								
	break;								
    case RAL_PALETTE_COLOR_BINS:					
	switch (feature->color_field_type) {
	case OFTInteger:
	case OFTReal:
	    break;
	default:
	    RAL_CHECKM(0, ral_msg("Invalid field type for color bins palette: %s.", 
				  OGR_GetFieldTypeName(feature->color_field_type)));
	}
	break;
    default:
	RAL_CHECKM(0, ral_msg("Invalid palette type for visual: %i.", visualization.palette_type));
    }
    return 1;
 fail:
    return 0;
}

void ral_set_color(ral_visual *visual, ral_feature *feature)
{
    switch (visual->palette_type) 
    {
    case RAL_PALETTE_SINGLE_COLOR:
	feature->color = visual->single_color;
	feature->color.c4 = (feature->color.c4*visual->alpha)/255;
	break;
    case RAL_PALETTE_GRAYSCALE:
    {
	short c = 0;
	switch (feature->color_field_type)
	{
	case OFTInteger:
	    if (visual->color_field == -1) {
		double key = OGR_F_GetFID(feature->feature);
		c = floor(RAL_INTERPOLATE(feature->nv2c, key));
	    } else if (OGR_F_IsFieldSet(feature->feature, visual->color_field)) { 
		OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visual->color_field); 
		c = floor(RAL_INTERPOLATE(feature->nv2c, field->Integer)); 
	    }
	    break;
	case OFTReal:
	    if (visual->color_field == -2) {
		OGRGeometryH g = feature->geometry;
		int k = OGR_G_GetGeometryCount(g);
		if (k)
		    g = OGR_G_GetGeometryRef(g, 0);
		c = floor(RAL_INTERPOLATE(feature->nv2c, OGR_G_GetZ(g, 0)));
	    } else if (OGR_F_IsFieldSet(feature->feature, visual->color_field)) {
		OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visual->color_field);
		c = floor(RAL_INTERPOLATE(feature->nv2c, field->Real));
	    }
	    break;
	default:
	    break;
	}
	if (visual->hue < 0) {
	    feature->color.c1 = feature->color.c2 = feature->color.c3 = c;
	    feature->color.c4 = visual->alpha;
	} else {
	    feature->color.c1 = visual->hue;
	    feature->color.c2 = 100;
	    feature->color.c3 = c;
	    feature->color = ral_hsv2rgb(feature->color);
	    feature->color.c4 = visual->alpha;
	}
	break;
    }
    case RAL_PALETTE_RAINBOW:
    {
	short c = 0;
	switch (feature->color_field_type) {
	case OFTInteger:
	    if (visual->color_field == -1) {
		double key = OGR_F_GetFID(feature->feature);
		c = floor(RAL_INTERPOLATE(feature->nv2c, key));
	    } else if (OGR_F_IsFieldSet(feature->feature, visual->color_field)) {
		OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visual->color_field);
		c = floor(RAL_INTERPOLATE(feature->nv2c, field->Integer));
	    }
	    break;
	case OFTReal:
	    if (visual->color_field == -2) {
		OGRGeometryH g = feature->geometry;
		while (OGR_G_GetGeometryCount(g))
		    g = OGR_G_GetGeometryRef(g, 0);
		c = floor(RAL_INTERPOLATE(feature->nv2c, OGR_G_GetZ(g, 0)));
	    } else if (OGR_F_IsFieldSet(feature->feature, visual->color_field)) {
		OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visual->color_field);
		c = floor(RAL_INTERPOLATE(feature->nv2c, field->Real));
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
	feature->color.c4 = visual->alpha;
	break;
    }
    case RAL_PALETTE_COLOR_TABLE:
    {
	switch(feature->color_field_type){
	case OFTInteger:
	    if (visual->color_field<0){
		long key = OGR_F_GetFID(feature->feature);
		RAL_COLOR_TABLE_GET(visual->color_table, key, feature->color);
	    } else if (OGR_F_IsFieldSet(feature->feature, visual->color_field)) {
		OGRField*field = OGR_F_GetRawFieldRef(feature->feature, visual->color_field);
		RAL_COLOR_TABLE_GET(visual->color_table, field->Integer, feature->color);
	    }
	    break;
	case OFTString:
	    if (OGR_F_IsFieldSet(feature->feature, visual->color_field)) {
		OGRField*field = OGR_F_GetRawFieldRef(feature->feature, visual->color_field);
		RAL_STRING_COLOR_TABLE_GET(visual->string_color_table, field->String, feature->color);
	    }
	    break;
	default:
	    break;
	}
	feature->color.c4 = (feature->color.c4*visual->alpha)/255;
	break;
    }
    case RAL_PALETTE_COLOR_BINS:
	switch(feature->color_field_type) {
	case OFTInteger:
	    if (visual->color_field == -1) {
		long key = OGR_F_GetFID(feature->feature);
		RAL_COLOR_BINS_GET(visual->int_bins, key, feature->color);
	    } else if (OGR_F_IsFieldSet(feature->feature, visual->color_field)) {
		OGRField*field = OGR_F_GetRawFieldRef(feature->feature, visual->color_field);
		RAL_COLOR_BINS_GET(visual->int_bins, field->Integer, feature->color);
	    }
	    break;
	case OFTReal:
	    if (visual->color_field == -2) {
		OGRGeometryH g = feature->geometry;
		int k = OGR_G_GetGeometryCount(g);
		if (k)
		    g = OGR_G_GetGeometryRef(g, 0);
		RAL_COLOR_BINS_GET(visual->double_bins, OGR_G_GetZ(g, 0), feature->color);
	    } else if (OGR_F_IsFieldSet(feature->feature, visual->color_field)) {
		OGRField*field = OGR_F_GetRawFieldRef(feature->feature, visual->color_field);
		RAL_COLOR_BINS_GET(visual->double_bins, field->Real, feature->color);
	    }
	    break;
	default:
	    break;
	}
	feature->color.c4 = (feature->color.c4*visual->alpha)/255;
    }
}

int ral_render_feature(ral_pixbuf *pb, ral_feature *feature, ral_visual *visual)
{
    if (visual->symbol AND (feature->render_as & RAL_RENDER_AS_POLYGONS) AND
	((feature->geometry_type == wkbPolygon) OR (feature->geometry_type == wkbMultiPolygon))) {

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
		size = OGR_G_GetArea(g);
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
	feature->render_as = RAL_RENDER_AS_POINTS;
	feature->destroy_geometry = 1;
    }

    RAL_CHECK(feature->ral_geom = ral_geometry_create_from_OGR(feature->geometry));
    
    if (feature->render_as & RAL_RENDER_AS_POINTS) {
	int size = 0;
	switch (feature->symbol_size_field_type) {
	case OFTInteger:
	    if (visual->symbol_field >= 0) {
		if (OGR_F_IsFieldSet(feature->feature, visual->symbol_field)) {
		    OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visual->symbol_field); 
		    size = floor(RAL_INTERPOLATE(feature->nv2ss, field->Integer));
		}
	    } else if (visual->symbol_field == -1) /* FID */
		size = floor(RAL_INTERPOLATE(feature->nv2ss, OGR_F_GetFID(feature->feature)));
	    else /* Fixed size */
		size = visual->symbol_pixel_size;
	    break;
	case OFTReal:
	    if (OGR_F_IsFieldSet(feature->feature, visual->symbol_field)) {
		OGRField *field = OGR_F_GetRawFieldRef(feature->feature, visual->symbol_field);
		size = floor(RAL_INTERPOLATE(feature->nv2ss, field->Real));
	    }
	    break;
	default:
	    break;
	}
	switch (visual->symbol) {
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
	    ral_render_wind_roses(pb, feature, visual);
	    break;
	default:
	    if (size > 0)
		ral_render_crosses(pb, feature->ral_geom, size, feature->color);
	    break;
	}
    }

    if (feature->render_as & RAL_RENDER_AS_LINES)
	RAL_CHECK(ral_render_polylines(pb, feature->ral_geom, feature->color));
		
    if (feature->render_as & RAL_RENDER_AS_POLYGONS)
	RAL_CHECK(ral_render_polygons(pb, feature->ral_geom, feature->color));
		
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

int ral_render_visual_layer(ral_pixbuf *pb, ral_visual_layer *layer)
{
    ral_feature feature;
    ral_double_range y;
    int ret = 1;
    OGRFeatureDefnH defn = OGR_L_GetLayerDefn(layer->layer);
    OGRCoordinateTransformationH transformation = NULL;
    
    feature.feature = NULL;
    feature.symbol_size_field_type = 0;
    feature.color_field_type = 0;
    
    CPLPushErrorHandler(ral_cpl_error);

    if (layer->visualization.symbol_field >= 0) {
	RAL_CHECK(ral_get_field_type(defn, layer->visualization.symbol_field, &feature.symbol_size_field_type));
    } else
	feature.symbol_size_field_type = OFTInteger; /* FID */

    y.min = 0;
    y.max = layer->visualization.symbol_pixel_size+1;
    switch (feature.symbol_size_field_type) {
    case OFTInteger:
	RAL_INTERPOLATOR_SETUP(feature.nv2ss, layer->visualization.symbol_size_int, y);
	break;
    case OFTReal:
	RAL_INTERPOLATOR_SETUP(feature.nv2ss, layer->visualization.symbol_size_double, y);
	break;
    default:
	RAL_CHECKM(0, ral_msg("Invalid field type for symbol size: %s.", 
			      OGR_GetFieldTypeName(feature.symbol_size_field_type)));
    }

    RAL_CHECK(ral_setup_color_interpolator(layer->visualization, defn, &feature));

    if (layer->EPSG_from AND layer->EPSG_to) {
	OGRSpatialReferenceH sr_from = OSRNewSpatialReference(NULL);
	OGRSpatialReferenceH sr_to = OSRNewSpatialReference(NULL);
	RAL_CHECK(OSRImportFromEPSG(sr_from, layer->EPSG_from) == OGRERR_NONE);
	RAL_CHECK(OSRImportFromEPSG(sr_to, layer->EPSG_to) == OGRERR_NONE);
	transformation = OCTNewCoordinateTransformation(sr_from, sr_to);
	RAL_CHECK(transformation);
    }

    if (transformation) {
	OGRGeometryH ll = OGR_G_CreateGeometry(wkbPoint);
	OGRGeometryH ul = OGR_G_CreateGeometry(wkbPoint);
	OGRGeometryH lr = OGR_G_CreateGeometry(wkbPoint);
	OGRGeometryH ur = OGR_G_CreateGeometry(wkbPoint);
	ral_point llp, ulp, lrp, urp;
	double z;
	int t;
	OGR_G_SetCoordinateDimension(ll,3);
	OGR_G_SetCoordinateDimension(ul,3);
	OGR_G_SetCoordinateDimension(lr,3);
	OGR_G_SetCoordinateDimension(ur,3);
	OGR_G_SetPoint(ll, 0, pb->world.min.x, pb->world.min.y, 1);
	fprintf(stderr,"ll: %f %f %f\n", pb->world.min.x, pb->world.min.y, 1);
	OGR_G_SetPoint(ul, 0, pb->world.min.x, pb->world.max.y, 1);
	OGR_G_SetPoint(lr, 0, pb->world.max.x, pb->world.min.y, 1);
	OGR_G_SetPoint(ur, 0, pb->world.max.x, pb->world.max.y, 1);
	fprintf(stderr,"a\n");
	RAL_CHECK(OGR_G_Transform(ll, transformation) == OGRERR_NONE);
	fprintf(stderr,"b\n");
	RAL_CHECK(OGR_G_Transform(ul, transformation) == OGRERR_NONE);
	fprintf(stderr,"c\n");
	RAL_CHECK(OGR_G_Transform(lr, transformation) == OGRERR_NONE);
	fprintf(stderr,"d\n");
	RAL_CHECK(OGR_G_Transform(ur, transformation) == OGRERR_NONE);
	fprintf(stderr,"e\n");
	OGR_G_GetPoint(ll, 0, &(llp.x), &(llp.y), &z);
	OGR_G_GetPoint(ul, 0, &(ulp.x), &(ulp.y), &z);
	OGR_G_GetPoint(lr, 0, &(lrp.x), &(lrp.y), &z);
	OGR_G_GetPoint(ur, 0, &(urp.x), &(urp.y), &z);
	OGR_L_SetSpatialFilterRect(layer->layer, min(llp.x,ulp.x), min(llp.y,lrp.y), max(lrp.x,urp.x), max(ulp.y,urp.y));
	t = OGR_G_GetGeometryType(ll);
	OGR_G_DestroyGeometry(ll);
	OGR_G_DestroyGeometry(ul);
	OGR_G_DestroyGeometry(lr);
	OGR_G_DestroyGeometry(ur);
	fprintf(stderr,"filter: %f %f %f %f %i\n", min(llp.x,ulp.x), min(llp.y,lrp.y), max(lrp.x,urp.x), max(ulp.y,urp.y), t);
    } else
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

	feature.destroy_geometry = 0;
	feature.render_as = 0;

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
	    
	    if (transformation) {
		RAL_CHECK(feature.geometry = OGR_G_Clone(feature.geometry));
		feature.destroy_geometry = 1;
		RAL_CHECK(OGR_G_Transform(feature.geometry, transformation) == OGRERR_NONE);
	    }
	
	    if (layer->visualization.render_as)

		feature.render_as = layer->visualization.render_as;

	    else {
		
		switch (feature.geometry_type) { /* below we support several RENDER_AS options... */
		case wkbPoint:
		case wkbMultiPoint:
		    feature.render_as = RAL_RENDER_AS_POINTS;
		    break;
		case wkbLineString:
		case wkbMultiLineString:
		    feature.render_as = RAL_RENDER_AS_LINES;
		    break;
		case wkbPolygon:
		case wkbMultiPolygon:
		    feature.render_as = RAL_RENDER_AS_POLYGONS;
		    break;
		default: /* should not happen */
		    break;
		}

	    }

	    if (!(feature.render_as & RAL_RENDER_AS_POINTS)) {
		OGREnvelope e;
		OGR_G_GetEnvelope( feature.geometry, &e );
		/* if smaller than one pixel, do not draw anything */
		if (((e.MaxX-e.MinX) < pb->pixel_size) AND ((e.MaxY-e.MinY) < pb->pixel_size)) {
		    /* drawing anything needs the color which we do not have at this point 
		       ral_point p;
		       p.x = e.MinX;
		       p.y = e.MinY;
		       if (RAL_POINT_IN_RECTANGLE(p, pb->world)) {
		       int i, j;
		       i = floor((pb->world.max.y - p.y)/pb->pixel_size);
		       j = floor((p.x - pb->world.min.x)/pb->pixel_size);
		       RAL_PIXBUF_SET_PIXEL_COLOR(pb, i, j, c);
		       continue;
		       }
		    */
		    if (feature.destroy_geometry) OGR_G_DestroyGeometry(feature.geometry);
		    continue;
		}
	    }
	    
	    RAL_FEATURE_SET_COLOR(feature, 0, 0, 0, 0); /* by default nothing is shown */
	    
	    ral_set_color(&(layer->visualization), &feature);
	    
	    if (feature.color.c4 > 0 AND feature.render_as)
		ral_render_feature(pb, &feature, &(layer->visualization));

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
    ral_double_range y;
    int ret = 1;
    int i ,j, n;

    feature.feature = NULL;
    feature.symbol_size_field_type = 0;
    feature.color_field_type = 0;
    
    for (i = 0; i < t->size; i++) {

	OGRGeometryH geometry;
	OGRFeatureDefnH defn;

	feature.destroy_geometry = 0; /* the geom after it has been rendered */

	defn = OGR_F_GetDefnRef(t->features[i].feature);

	CPLPushErrorHandler(ral_cpl_error);

	if (t->features[i].visualization.symbol_field >= 0) {
	    RAL_CHECK(ral_get_field_type(defn, t->features[i].visualization.symbol_field, &feature.symbol_size_field_type));
	} else
	    feature.symbol_size_field_type = OFTInteger; /* FID */

	y.min = 0;
	y.max = t->features[i].visualization.symbol_pixel_size+1;
	switch (feature.symbol_size_field_type) {
	case OFTInteger:
	    RAL_INTERPOLATOR_SETUP(feature.nv2ss, t->features[i].visualization.symbol_size_int, y);
	    break;
	case OFTReal:
	    RAL_INTERPOLATOR_SETUP(feature.nv2ss, t->features[i].visualization.symbol_size_double, y);
	    break;
	default:
	    RAL_CHECKM(0, ral_msg("Invalid field type for symbol size: %s.", 
				  OGR_GetFieldTypeName(feature.symbol_size_field_type)));
	}

	RAL_CHECK(ral_setup_color_interpolator(t->features[i].visualization, defn, &feature));
	
	feature.feature = t->features[i].feature;

	feature.render_as = 0;
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

	    if (t->features[i].visualization.render_as)

		feature.render_as = t->features[i].visualization.render_as;

	    else {
		
		switch (feature.geometry_type) { /* below we support several RENDER_AS options... */
		case wkbPoint:
		case wkbMultiPoint:
		    feature.render_as = RAL_RENDER_AS_POINTS;
		    break;
		case wkbLineString:
		case wkbMultiLineString:
		    feature.render_as = RAL_RENDER_AS_LINES;
		    break;
		case wkbPolygon:
		case wkbMultiPolygon:
		    feature.render_as = RAL_RENDER_AS_POLYGONS;
		    break;
		default: /* should not happen */
		    break;
		}
		
	    }
	    
	    if (!(feature.render_as & RAL_RENDER_AS_POINTS)) {
		OGREnvelope e;
		OGR_G_GetEnvelope( feature.geometry, &e );
		/* if smaller than one pixel, do not draw anything */
		if (((e.MaxX-e.MinX) < pb->pixel_size) AND ((e.MaxY-e.MinY) < pb->pixel_size)) {
		    /* drawing anything needs the color which we do not have at this point 
		       ral_point p;
		       p.x = e.MinX;
		       p.y = e.MinY;
		       if (RAL_POINT_IN_RECTANGLE(p, pb->world)) {
		       int i, j;
		       i = floor((pb->world.max.y - p.y)/pb->pixel_size);
		       j = floor((p.x - pb->world.min.x)/pb->pixel_size);
		       RAL_PIXBUF_SET_PIXEL_COLOR(pb, i, j, c);
		       continue;
		       }
		    */
		    continue;
		}
	    }
	    
	    RAL_FEATURE_SET_COLOR(feature, 0, 0, 0, 0); /* by default nothing is shown */

	    ral_set_color(&(t->features[i].visualization), &feature);

	    if (feature.color.c4 > 0 AND feature.render_as)
		ral_render_feature(pb, &feature, &(t->features[i].visualization));

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
