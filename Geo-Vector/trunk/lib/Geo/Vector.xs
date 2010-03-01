#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <gtk2-ex-geo.h>

#include <ral.h>

#define RAL_GRIDPTR "ral_gridPtr"
#define RAL_ERRSTR_OOM "Out of memory"

#include "../../const-c.inc"

#include "help.c"

MODULE = Geo::Vector		PACKAGE = Geo::Vector

INCLUDE: ../../const-xs.inc

OGRDataSourceH
OGRDataSourceH(ogr)
	SV *ogr
	CODE:
	{
		OGRDataSourceH h = (OGRDataSourceH)0;
		IV tmp = SV2Handle(ogr);
		h = (OGRDataSourceH)tmp;
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

OGRLayerH
OGRLayerH(layer)
	SV *layer
	CODE:
	{
		OGRLayerH h = (OGRLayerH)0;
		IV tmp = SV2Handle(layer);
		h = (OGRLayerH)tmp;
		RETVAL = h;
	}
  OUTPUT:
    RETVAL

int
field_index(field)
	char *field
	CODE:
		if (strcmp(field, ".FID"))
		   RETVAL = RAL_FIELD_FID;
		else if (strcmp(field, ".Z"))
		   RETVAL = RAL_FIELD_FID;
		else if (strcmp(field, "Fixed size"))
		   RETVAL = RAL_FIELD_FIXED_SIZE;
		else
		   RETVAL = 0;
	OUTPUT:
	    RETVAL

void
xs_rasterize(l, gd, render_override, fid_to_rasterize, value_field)
	OGRLayerH l
	ral_grid *gd
	int render_override
	int fid_to_rasterize
	int value_field
	CODE:
	if (fid_to_rasterize > -1 ) {

		OGRFieldType ft = 0;
		OGRFeatureH f = OGR_L_GetFeature(l, fid_to_rasterize);
		if (value_field >= 0)
			RAL_CHECK(ral_get_field_type(l, value_field, &ft));
		ral_grid_rasterize_feature(gd, f, value_field, ft, render_override);

	} else {

		ral_grid_rasterize_layer(gd, l, value_field, render_override);
	}
	fail:
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

ral_pixbuf *
gtk2_ex_geo_pixbuf_create(int width, int height, double minX, double maxY, double pixel_size, int bgc1, int bgc2, int bgc3)
	CODE:
		GDALColorEntry background = {bgc1, bgc2, bgc3, 255};
		ral_pixbuf *pb = ral_pixbuf_create(width, height, minX, maxY, pixel_size, background);
		RETVAL = pb;
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

void 
gtk2_ex_geo_pixbuf_destroy(pb)
	ral_pixbuf *pb
	CODE:
	ral_pixbuf_destroy(&pb);

void
ral_pixbuf_save(pb, filename, type, option_keys, option_values)
	ral_pixbuf *pb
	const char *filename
	const char *type
	AV* option_keys
	AV* option_values
	CODE:
		GdkPixbuf *gpb;
		GError *error = NULL;
		int i;
		char **ok = NULL;
		char **ov = NULL;
		int size = av_len(option_keys)+1;
		gpb = ral_gdk_pixbuf(pb);
		RAL_CHECKM(ok = (char **)calloc(size, sizeof(char *)), RAL_ERRSTR_OOM);
		RAL_CHECKM(ov = (char **)calloc(size, sizeof(char *)), RAL_ERRSTR_OOM);
		for (i = 0; i < size; i++) {
			STRLEN len;
			SV **s = av_fetch(option_keys, i, 0);
			ok[i] = SvPV(*s, len);
			s = av_fetch(option_values, i, 0);
			ov[i] = SvPV(*s, len);
		}
		gdk_pixbuf_savev(gpb, filename, type, ok, ov, &error);
		fail:
		if (ok) {
			for (i = 0; i < size; i++) {
				if (ok[i]) free (ok[i]);
			}
			free(ok);
		}
		if (ov) {
			for (i = 0; i < size; i++) {
				if (ov[i]) free (ov[i]);
			}
			free(ov);
		}
		if (error) {
			croak(error->message);
			g_error_free(error);
		}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

ral_visual_layer *
ral_visual_layer_create(perl_layer, ogr_layer)
	HV *perl_layer
	OGRLayerH ogr_layer
	CODE:
		ral_visual_layer *layer = ral_visual_layer_create();
		layer->layer = ogr_layer;
		RAL_CHECK(fetch2visual(perl_layer, &layer->visualization, OGR_L_GetLayerDefn(layer->layer)));
		RAL_FETCH(perl_layer, "EPSG_FROM", layer->EPSG_from, SvIV);
		RAL_FETCH(perl_layer, "EPSG_TO", layer->EPSG_to, SvIV);
		goto ok;
		fail:
		ral_visual_layer_destroy(&layer);
		layer = NULL;
		ok:
		RETVAL = layer;
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

void
ral_visual_layer_destroy(layer)
	ral_visual_layer *layer
	CODE:
		ral_visual_layer_destroy(&layer);

void
ral_visual_layer_render(layer, pb)
	ral_visual_layer *layer
	gtk2_ex_geo_pixbuf *pb
	CODE:
		ral_pixbuf rpb;
		gtk2_ex_geo_pixbuf_2_ral_pixbuf(pb, &rpb);
		ral_render_visual_layer(&rpb, layer);
	POSTCALL:
	if (ral_has_msg())
		croak(ral_get_msg());

ral_visual_feature_table *
ral_visual_feature_table_create(perl_layer, features)
	HV *perl_layer
	AV *features
	CODE:
		ral_visual_feature_table *layer = ral_visual_feature_table_create(av_len(features)+1);
		RAL_CHECK(layer);
		char *color_field_name = NULL, *symbol_size_field_name = NULL;;

		RAL_FETCH(perl_layer, "COLOR_FIELD", color_field_name, SvPV_nolen);
		RAL_FETCH(perl_layer, "SYMBOL_FIELD", symbol_size_field_name, SvPV_nolen);

		int i;
		for (i = 0; i <= av_len(features); i++) {
			SV** sv = av_fetch(features,i,0);
			OGRFeatureH f = SV2Handle(*sv);
			layer->features[i].feature = f;
			OGRFeatureDefnH fed = OGR_F_GetDefnRef(f);

			int field = -1;
			if (color_field_name) {
			    if (strcmp(color_field_name, ".Z")) {
				field = -2;
			    } else {
				field = OGR_FD_GetFieldIndex(fed, color_field_name);
				if (field >= 0) {
				    OGRFieldDefnH fid = OGR_FD_GetFieldDefn(fed, field);
				    OGRFieldType fit = OGR_Fld_GetType(fid);
				    if (!(fit == OFTInteger OR fit == OFTReal))
					field = -1;
				}
			    }
			}
			RAL_STORE(perl_layer, "COLOR_FIELD_VALUE", field, newSViv);

			field = -2;
			if (symbol_size_field_name) {
				field = OGR_FD_GetFieldIndex(fed, symbol_size_field_name);
				if (field >= 0) {
					OGRFieldDefnH fid = OGR_FD_GetFieldDefn(fed, field);
					OGRFieldType fit = OGR_Fld_GetType(fid);
					if (!(fit == OFTInteger OR fit == OFTReal))
						field = -2;
				} else
					field = -2;
			}
			RAL_STORE(perl_layer, "SYMBOL_FIELD_VALUE", field, newSViv);

			RAL_CHECK(fetch2visual(perl_layer, &layer->features[i].visualization, OGR_F_GetDefnRef(f)));
			
		}

		RAL_FETCH(perl_layer, "EPSG_FROM", layer->EPSG_from, SvIV);
		RAL_FETCH(perl_layer, "EPSG_TO", layer->EPSG_to, SvIV);
		goto ok;
		fail:
		ral_visual_feature_table_destroy(&layer);
		layer = NULL;
		ok:
		RETVAL = layer;
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

void
ral_visual_feature_table_destroy(layer)
	ral_visual_feature_table *layer
	CODE:
		ral_visual_feature_table_destroy(&layer);

void
ral_visual_feature_table_render(layer, pb)
	ral_visual_feature_table *layer
	gtk2_ex_geo_pixbuf *pb
	CODE:
		ral_pixbuf rpb;
		gtk2_ex_geo_pixbuf_2_ral_pixbuf(pb, &rpb);
		ral_render_visual_feature_table(&rpb, layer);
	POSTCALL:
	if (ral_has_msg())
		croak(ral_get_msg());

GdkPixbuf_noinc *
gtk2_ex_geo_pixbuf_get_pixbuf(ral_pixbuf *pb)
	CODE:
		if (ral_cairo_to_pixbuf(pb))
			RETVAL = ral_gdk_pixbuf(pb);
	OUTPUT:
		RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

cairo_surface_t_noinc *
gtk2_ex_geo_pixbuf_get_cairo_surface(pb)
	ral_pixbuf *pb
    CODE:
	RETVAL = cairo_image_surface_create_for_data
		(pb->image, CAIRO_FORMAT_ARGB32, pb->N, pb->M, pb->image_rowstride);
    OUTPUT:
	RETVAL

