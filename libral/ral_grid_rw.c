#include "config.h"
#include "msg.h"
#include "ral/ral.h"

#ifdef RAL_HAVE_GDAL
void CPL_DLL CPL_STDCALL ral_cpl_error(CPLErr eclass, int code, const char *msg)
{
    if (code == CE_Fatal) {
	fprintf(stderr, "GDAL: %s\n", msg);
	exit(1);
    }
    RAL_CHECKM(0, msg);
 fail:
    return;
}

#define P2G(xp,yp,t,xg,yg) xg = (t[0]) + (t[1])*(xp) + (t[2])*(yp); \
    yg = (t[3]) + (t[4])*(xp) + (t[5])*(yp);
#define G2P(xg,yg,t,xp,yp) xp = floor((t[0]) + (t[1])*(xg) + (t[2])*(yg)); \
    yp = floor((t[3]) + (t[4])*(xg) + (t[5])*(yg));

ral_grid_handle RAL_CALL ral_grid_create_using_GDAL(GDALDatasetH dataset, int band, ral_rectangle clip_region, double cell_size)
{
    GDALRasterBandH hBand;
    GDALDataType datatype;
    int M, N, gd_datatype;
    int W, H; /* size of the full GDAL raster */
    int north_up, east_up, i0, j0, i1, j1, w, h; /* the clip region (P) */
    int ws, hs; /* the size of the buffer into which to rasterIO to */
    CPLErr err;
    ral_grid *gd_s = NULL, *gd_t = NULL;
    double t[6] = {0,1,0,0,0,1}; /* the geotransformation P -> G */
    double tx[6]; /* the inverse geotransformation G -> P */
    ral_rectangle GDAL; /* boundaries of the GDAL raster */
    ral_point p0, p1, p2, p3; /* locations of corners of clip region: 
				 top left, top right, bottom right, bottom left, i.e,
				 0,0       W',0       W',H'         0,H' */
  
    CPLPushErrorHandler(ral_cpl_error);

    GDALGetGeoTransform(dataset, t);
    north_up = (t[2] == 0) AND (t[4] == 0);
    east_up = (t[1] == 0) AND (t[5] == 0);
    /*fprintf(stderr, "\nt is\n%f %f %f\n%f %f %f\n", t[0],t[1],t[2],t[3],t[4],t[5]);*/

    W = GDALGetRasterXSize(dataset);
    H = GDALGetRasterYSize(dataset);
    /*fprintf(stderr, "cell size is %f, raster size is %i %i\n", cell_size, W, H);*/

    /* test all corners to find the min & max xg and yg */
    {
        double x, y;
        P2G(0, 0, t, GDAL.min.x, GDAL.min.y);
        GDAL.max.x = GDAL.min.x;
        GDAL.max.y = GDAL.min.y;
        P2G(0, H, t, x, y);
        GDAL.min.x = MIN(x, GDAL.min.x);
        GDAL.min.y = MIN(y, GDAL.min.y);
        GDAL.max.x = MAX(x, GDAL.max.x);
        GDAL.max.y = MAX(y, GDAL.max.y);
        P2G(W, H, t, x, y);
        GDAL.min.x = MIN(x, GDAL.min.x);
        GDAL.min.y = MIN(y, GDAL.min.y);
        GDAL.max.x = MAX(x, GDAL.max.x);
        GDAL.max.y = MAX(y, GDAL.max.y);
        P2G(W, 0, t, x, y);
        GDAL.min.x = MIN(x, GDAL.min.x);
        GDAL.min.y = MIN(y, GDAL.min.y);
        GDAL.max.x = MAX(x, GDAL.max.x);
        GDAL.max.y = MAX(y, GDAL.max.y);
    }

    /*fprintf(stderr, "clip region is %f %f %f %f\n", clip_region.min.x, clip_region.min.y, clip_region.max.x, clip_region.max.y);
      fprintf(stderr, "GDAL raster is %f %f %f %f\n", GDAL.min.x, GDAL.min.y, GDAL.max.x, GDAL.max.y);*/
    clip_region.min.x = MAX(clip_region.min.x, GDAL.min.x);
    clip_region.min.y = MAX(clip_region.min.y, GDAL.min.y);
    clip_region.max.x = MIN(clip_region.max.x, GDAL.max.x);
    clip_region.max.y = MIN(clip_region.max.y, GDAL.max.y);
    /*fprintf(stderr, "visible region is %f %f %f %f\n", clip_region.min.x, clip_region.min.y, clip_region.max.x, clip_region.max.y);*/
    RAL_CHECK((clip_region.min.x < clip_region.max.x) AND (clip_region.min.y < clip_region.max.y));

    /* the inverse transformation, from georeferenced space to pixel space */
    {
        double tmp = t[2]*t[4] - t[1]*t[5];
        tx[0] = (t[0]*t[5] - t[2]*t[3])/tmp;
        tx[1] = -t[5]/tmp;
        tx[2] = t[2]/tmp;
        tx[3] = (t[1]*t[3] - t[0]*t[4])/tmp;
        tx[4] = t[4]/tmp;
        tx[5] = -t[1]/tmp;
    }

    /* the clip region in pixel space */
    /* test all corners to find the min & max xp and yp (j0..j1, i0..i1) */
    {
        int i, j;
        G2P(clip_region.min.x, clip_region.min.y, tx, j0, i0);
        j1 = j0;
        i1 = i0;
        G2P(clip_region.min.x, clip_region.max.y, tx, j, i);
        j0 = MIN(j, j0);
        i0 = MIN(i, i0);
        j1 = MAX(j, j1);
        i1 = MAX(i, i1);
        G2P(clip_region.max.x, clip_region.max.y, tx, j, i);
        j0 = MIN(j, j0);
        i0 = MIN(i, i0);
        j1 = MAX(j, j1);
        i1 = MAX(i, i1);
        G2P(clip_region.max.x, clip_region.min.y, tx, j, i);
        j0 = MIN(j, j0);
        i0 = MIN(i, i0);
        j1 = MAX(j, j1);
        i1 = MAX(i, i1);
        j0 = MAX(j0, 0); j0 = MIN(j0, W-1);
        j1 = MAX(j1, 0); j1 = MIN(j1, W-1);
        i0 = MAX(i0, 0); i0 = MIN(i0, H-1);
        i1 = MAX(i1, 0); i1 = MIN(i1, H-1);
    }
    w = j1 - j0 + 1;
    h = i1 - i0 + 1;
    /*fprintf(stderr, "visible region in raster is %i %i %i %i\n", j0, i0, j1, i1);*/
    RAL_CHECK(w > 0 AND h > 0);
    
    /* the corners of the raster clip */
    P2G(j0, i0, t, p0.x, p0.y);
    P2G(j1+1, i0, t, p1.x, p1.y);
    P2G(j1+1, i1+1, t, p2.x, p2.y);
    P2G(j0, i1+1, t, p3.x, p3.y);
    /*fprintf(stderr, "source corners: (%f,%f  %f,%f  %f,%f  %f,%f)\n", p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);*/

    /* the width and height of the resized raster clip */
    /* the resized clip has the same corner coordinates as the clip */
    ws = round(sqrt((p1.x-p0.x)*(p1.x-p0.x)+(p1.y-p0.y)*(p1.y-p0.y))/cell_size);
    hs = round(sqrt((p1.x-p2.x)*(p1.x-p2.x)+(p1.y-p2.y)*(p1.y-p2.y))/cell_size);
    /*fprintf(stderr, "clipped source size is %i, %i\n", ws, hs);*/
    
    hBand = GDALGetRasterBand(dataset, band);

    RAL_CHECK(hBand);

    switch (GDALGetRasterDataType(hBand)) {
    case GDT_Byte:
    case GDT_UInt16:
    case GDT_Int16:
    case GDT_UInt32:
    case GDT_Int32:
	gd_datatype = RAL_INTEGER_GRID;
	switch (sizeof(RAL_INTEGER)) { /* hmm.. this breaks if INTEGER is unsigned */
	case 1:
	    datatype = GDT_Byte;
	    break;
	case 2:
	    datatype = GDT_Int16;
	    break;
	case 4:
	    datatype = GDT_Int32;
	    break;
	default:
	    RAL_CHECKM(0, ral_msg("Strange sizeof(INTEGER): %i",sizeof(RAL_INTEGER)));
	}
	break;
    case GDT_Float32:
    case GDT_Float64:
	gd_datatype = RAL_REAL_GRID;
	switch (sizeof(RAL_REAL)) {
	case 4:
	    datatype = GDT_Float32;
	    break;
	case 8:
	    datatype = GDT_Float64;
	    break;
	default:
	    RAL_CHECKM(0, ral_msg("Strange sizeof(REAL): %i", sizeof(RAL_REAL)));
	}
	break;
    default:
	RAL_CHECKM(0, "complex data type not supported");
    }
 
    /* size of the grid in display */
    
    M = ceil(fabs(clip_region.max.y - clip_region.min.y)/cell_size);
    N = ceil(fabs(clip_region.max.x - clip_region.min.x)/cell_size);

    /*fprintf(stderr, "display size is %i, %i\n", N, M);*/

    RAL_CHECK(gd_s = ral_grid_create(gd_datatype, hs, ws));
    RAL_CHECK(gd_t = ral_grid_create(gd_datatype, M, N));

    ral_grid_set_bounds_csnx(gd_t, cell_size, clip_region.min.x, clip_region.max.y);
  
    err = GDALRasterIO(hBand, GF_Read, j0, i0, w, h, gd_s->data, ws, hs, datatype, 0, 0);
    RAL_CHECK(err == CE_None);
    {
	int success;
	double nodata_value = GDALGetRasterNoDataValue(hBand, &success);
	if (success) {
	    RAL_CHECK(ral_grid_set_real_nodata_value(gd_t, nodata_value));
            RAL_CHECK(ral_grid_set_all_nodata(gd_t));
        } else {
	    RAL_CHECK(ral_grid_set_real_nodata_value(gd_t, -9999)); /* change this! */
            RAL_CHECK(ral_grid_set_all_nodata(gd_t));
	}
    }
    /* from source to target */
    {
        /* b = from p0 to p1 */
	double bx = p1.x - p0.x;
	double by = p1.y - p0.y;
        double b = east_up ? 0 : bx/by;
	double b2 = east_up ? 1 : sqrt(1+1/b/b);
	/*fprintf(stderr, "b = %f %f (%f)\n", bx, by, b);*/
        /* c = from p0 to p3 */
	double cx = p3.x - p0.x;
	double cy = p3.y - p0.y;
        double c = north_up ? 0 : cx/cy;
        double c2 = north_up ? 1 : sqrt(1+1/c/c);
	/*fprintf(stderr, "c = %f %f (%f)\n", cx, cy, c);*/
	ral_cell cs, ct;
        switch (gd_t->datatype) {
        case RAL_REAL_GRID:
            RAL_FOR(ct, gd_t) {
                /* p = the location of the center of the target pixel in georeferenced coordinates */
                double px = clip_region.min.x + cell_size*(ct.j+0.5);
                double py = clip_region.max.y - cell_size*(ct.i+0.5);
		/* vector a = from p0 to p */
                double ax = px - p0.x;
		double ay = py - p0.y;
		/* x = the vector from p0 to the beginning of y */
                double x = east_up ? ay : (north_up ? ax : (ax-c*ay)/(1-c/b));
                if (!east_up AND !north_up AND (x/b > 0)) continue;
		/* the length */
                x = fabs(x)*b2;
		/* y = length of the parallel to c vector from b to p */
                double y = east_up ? ax : (north_up ? ay : (ax-b*ay)/(1-b/c));
                if (!east_up AND !north_up AND (y/c < 0)) continue;
		/* the length */
                y = fabs(y)*c2;
		ral_cell cs; /* the coordinates in the clipped raster */
                cs.j = floor(x/cell_size);
		cs.i = floor(y/cell_size);
                if (RAL_GRID_CELL_IN(gd_s, cs)) 
                    RAL_REAL_GRID_CELL(gd_t, ct) = RAL_REAL_GRID_CELL(gd_s, cs);
            }
            break;
        case RAL_INTEGER_GRID:
            RAL_FOR(ct, gd_t) {
                /* p = the location of the center of the target pixel in georeferenced coordinates */
                double px = clip_region.min.x + cell_size*(ct.j+0.5);
                double py = clip_region.max.y - cell_size*(ct.i+0.5);
		/* vector a = from p0 to p */
                double ax = px - p0.x;
		double ay = py - p0.y;
		/* x = the vector from p0 to the beginning of y */
                double x = east_up ? ay : (north_up ? ax : (ax-c*ay)/(1-c/b));
                if (!east_up AND !north_up AND (x/b > 0)) continue;
		/* the length */
                x = fabs(x)*b2;
		/* y = length of the parallel to c vector from b to p */
                double y = east_up ? ax : (north_up ? ay : (ax-b*ay)/(1-b/c));
                if (!east_up AND !north_up AND (y/c < 0)) continue;
		/* the length */
                y = fabs(y)*c2;
		ral_cell cs; /* the coordinates in the clipped raster */
                cs.j = floor(x/cell_size);
		cs.i = floor(y/cell_size);
                /*
                if ((cs.i == 0 AND cs.j == 0) OR (cs.i == hs-1 AND cs.j == 0) OR 
                    (cs.i == 0 AND cs.j == ws-1) OR (cs.i == hs-1 AND cs.j == ws-1) OR
                    (ct.i == 0 AND ct.j == 0) OR (ct.i == M-1 AND ct.j == N-1)) {
		    fprintf(stderr, "p = %f %f\n", px, py);
		    fprintf(stderr, "a = %f %f\n", ax, ay);
		    fprintf(stderr, "x = %f\n", x);
		    fprintf(stderr, "y = %f\n", y);
		    fprintf(stderr, "copy %i, %i -> %i, %i\n", cs.j, cs.i, ct.j, ct.i);
		}
                */
                if (RAL_GRID_CELL_IN(gd_s, cs)) {
                    RAL_INTEGER_GRID_CELL(gd_t, ct) = RAL_INTEGER_GRID_CELL(gd_s, cs);
                }
            }
        }
    }
    
    CPLPopErrorHandler();
    ral_grid_destroy(&gd_s);
    return gd_t;
fail:
    CPLPopErrorHandler();
    ral_grid_destroy(&gd_s);
    ral_grid_destroy(&gd_t);
    return NULL;
}
#endif

int RAL_CALL ral_grid_write(ral_grid *gd, char *filename)
{
    FILE *f = NULL;
    size_t l = 0;

    RAL_CHECKM(f = fopen(filename,"wb"), ral_msg("%s: %s\n", filename, strerror(errno)));

    switch (gd->datatype) {
    case RAL_REAL_GRID: 
	l = fwrite(gd->data,sizeof(RAL_REAL),gd->M*gd->N,f);
	break;
    case RAL_INTEGER_GRID:
	l = fwrite(gd->data,sizeof(RAL_INTEGER),gd->M*gd->N,f);
    }

    RAL_CHECKM(l == gd->M*gd->N, "file write failed\n");

    fclose(f);
    return 1;
fail:
    if (f) fclose(f);
    return 0;
}
