#include "gvl.h"

double width = 500; /* pixels */
double height = 500; /* pixels */

int classification_function(OGRFeatureH feature, void *user)
{
    long fid = OGR_F_GetFID(feature);
    return fid < 10 ? 0 : 1;
}

int corine_color_table(gvl_raster_feature *feature, void *user) 
{
    return feature->has_int ? feature->i_value : (int)feature->f_value;
}

double value_function(OGRFeatureH feature, void *user)
{
    return OGR_F_GetFID(feature);
}

main() {

    OGRRegisterAll();
    OGRDataSourceH ds = OGROpen(".", 0, NULL);
    OGRLayerH layer = OGR_DS_GetLayerByName(ds, "clip2");

    GDALAllRegister();
    GDALDatasetH dataset = GDALOpen("c:/data/Corine/clc_fi25m.tif", GA_ReadOnly);

    OGREnvelope extent;
    OGR_L_GetExtent(layer, &extent, 1);
    
    cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, width, height);

    gvl_canvas *canvas = gvl_canvas_create(surface,
					   width, 
					   height,
					   extent.MinX,
					   extent.MinY,
					   extent.MaxX,
					   extent.MaxY);    

    gvl_symbolizer_table *table = gvl_symbolizer_table_create_with_continuous(value_function, 0, 16);

    gvl_text_symbolizer *for_text = (gvl_text_symbolizer *)gvl_symbolizer_create(GVL_SYMBOLIZER_TEXT);
    gvl_text_symbolizer_set_font(for_text, pango_font_description_from_string("Sans 12"));
    gvl_text_symbolizer_set_color(for_text, gvl_color_init(0,0,0,1));

    gvl_polygon_symbolizer *p1 = gvl_polygon_symbolizer_create_with_color
	(gvl_color_init(0.5,0.5,1,1),
	 gvl_line_symbolizer_create(gvl_line_style_create_plain(gvl_color_init(0,0,0,1))));

    gvl_polygon_symbolizer *p2 = gvl_polygon_symbolizer_create_with_color
	(gvl_color_init(1,0.5,0.5,1),
	 gvl_line_symbolizer_create(gvl_line_style_create_plain(gvl_color_init(0,0,0,1))));

    gvl_symbolizer_table_add(table, gvl_symbolizers_create(NULL,
							   NULL,
							   p1,
							   for_text,
							   NULL));
    
    gvl_symbolizer_table_add(table, gvl_symbolizers_create(NULL,
							   NULL,
							   p2,
							   for_text,
							   NULL));


    GDALColorTableH cth = GDALGetRasterColorTable(GDALGetRasterBand(dataset, 1));
    gvl_symbolizer_table *ct = gvl_symbolizer_table_create_with_classes(corine_color_table);

    int j;
    for (j = 0; j < GDALGetColorEntryCount(cth); j++) {
	GDALColorEntry *e = GDALGetColorEntry(cth, j);
	gvl_symbolizer_table_add(ct, gvl_symbolizers_create
				 (NULL,
				  NULL,
				  gvl_polygon_symbolizer_create_with_color
				  (gvl_color_init((double)e->c1/255, (double)e->c2/255, (double)e->c3/255, 1), NULL),
				  NULL,
				  NULL
				  ));
    }

    gvl_canvas_render_raster(canvas, dataset, ct, cth);

    gvl_canvas_render_layer(canvas, layer, table, NULL);
    
    cairo_surface_write_to_png(surface, "test.png");

    return 0;

}
