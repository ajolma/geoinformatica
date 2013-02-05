#include "ral/ral.h"

OGRCoordinateTransformationH CPL_STDCALL 
OCTNewCoordinateTransformation(
    OGRSpatialReferenceH hSourceSRS, OGRSpatialReferenceH hTargetSRS );

int main() {
    
    ral_grid *gd = ral_grid_create(RAL_INTEGER_GRID, 10, 10);
    ral_cell c;
    ral_hash *table = NULL;
    int i;

    RAL_FOR(c, gd) RAL_INTEGER_GRID_CELL(gd, c) = c.i*c.j;

    if ((table = ral_grid_contents(gd)))
	for (i = 0; i < table->size; i++) {
	    ral_hash_int_item *a = (ral_hash_int_item *)table->table[i];
	    while (a) {
		fprintf(stderr,"cont: %i %i\n",a->key,a->value);
		a = a->next;
	    }
	}
    
    ral_cell_integer_values *data  = NULL;
    c.i = 4;
    c.j = 5;
    RAL_CHECK(data = ral_integer_grid_get_circle(gd, c, 2));
    printf("rac: %i\n",data->size);
    for (i = 0; i < data->size; i++) {
	printf("%i %i %i\n",data->cells[i].i,data->cells[i].j,data->values[i]);
    }

    RAL_INTEGER nodata_value1,nodata_value2;
    int ret;

    ral_grid_set_real_nodata_value(gd, -9999);    
    ral_grid_get_integer_nodata_value(gd, &nodata_value1);
    ret = ral_grid_lt_integer(gd, 1);
    ral_grid_get_integer_nodata_value(gd, &nodata_value2);

    if (nodata_value1 == nodata_value2) printf("ok 1\n"); else printf("not ok 1\n");

    /*
    OGRSpatialReferenceH sr_from = OSRNewSpatialReference(NULL);
    OGRSpatialReferenceH sr_to = OSRNewSpatialReference(NULL);
    RAL_CHECK(OSRImportFromEPSG(sr_from, 4030) == OGRERR_NONE);
    RAL_CHECK(OSRImportFromEPSG(sr_to, 2393) == OGRERR_NONE);
    OGRCoordinateTransformationH transformation = NULL;
    transformation = OCTNewCoordinateTransformation(sr_from, sr_to);
    RAL_CHECK(transformation);

    OGRGeometryH ll = OGR_G_CreateGeometry(wkbPoint);
    
    double x,y,z;
    OGR_G_SetPoint(ll, 0,  3020012.500000, 6599987.500000, 1.000000);
    OGR_G_GetPoint(ll, 0, &x, &y, &z);
    fprintf(stderr,"dim %f %f %f\n", x,y,z);

    RAL_CHECK(OGR_G_Transform(ll, transformation) == OGRERR_NONE);

    OGR_G_GetPoint(ll, 0, &x, &y, &z);
    fprintf(stderr,"dim %f %f %f %i\n", x,y,z);
    */

fail:
 
    return 0;

}
