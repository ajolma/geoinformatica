#include "config.h"
#include "msg.h"
#include "ral/ral.h"
#include "private/ral.h"

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

ral_grid_handle RAL_CALL ral_grid_create_using_GDAL(GDALDatasetH dataset, int band, ral_rectangle clip_region, double cell_size)
{
    GDALRasterBandH hBand;
    GDALDataType datatype;
    int i0, j0, w, h, M, N, W, H, gd_datatype;
    CPLErr err;
    ral_grid *gd = NULL;
    double t[6] = {0,1,0,0,0,1};
    double aspect;
    double min_x, max_x, min_y, max_y;
  
    CPLPushErrorHandler(ral_cpl_error);

    GDALGetGeoTransform(dataset, t);

    RAL_CHECKM(t[2] == t[4] AND t[2] == 0, "the raster is not a strict north up image");

    W = GDALGetRasterXSize(dataset);
    H = GDALGetRasterYSize(dataset);

    min_x = t[1] > 0 ? t[0] : t[0]+W*t[1];
    max_x = t[1] > 0 ? t[0]+W*t[1] : t[0];
    min_y = t[5] > 0 ? t[3] : t[3]+H*t[5];
    max_y = t[5] > 0 ? t[3]+H*t[5] : t[3];

    clip_region.min.x = MAX(clip_region.min.x, min_x);
    clip_region.min.y = MAX(clip_region.min.y, min_y);
    clip_region.max.x = MIN(clip_region.max.x, max_x);
    clip_region.max.y = MIN(clip_region.max.y, max_y);

    RAL_CHECK((clip_region.min.x < clip_region.max.x) AND 
	      (clip_region.min.y < clip_region.max.y));
    
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
 
    j0 = floor((clip_region.min.x - min_x)/fabs(t[1])+0.0000000001);
    i0 = floor((max_y - clip_region.max.y)/fabs(t[5])+0.0000000001);
    w = MIN(ceil((clip_region.max.x - min_x)/fabs(t[1])) - j0, W - j0);
    h = MIN(ceil((max_y - clip_region.min.y)/fabs(t[5])) - i0, H - i0);

    RAL_CHECK(w > 0 AND h > 0);

    M = ceil((double)h*fabs(t[5])/cell_size);
    if (H < M) {
        M = H;
        cell_size = (double)h*fabs(t[5])/(double)M;
    }
    
    N = ceil((double)w*fabs(t[1])/cell_size);
    if (W < N) {
        N = W;
        cell_size = (double)w*fabs(t[1])/(double)N;
        M = ceil((double)h*fabs(t[5])/cell_size);
    }

    RAL_CHECK(gd = ral_grid_create(gd_datatype, M, N));

    ral_grid_set_bounds_csnx(gd, cell_size, min_x+(double)j0*fabs(t[1]), max_y-(double)i0*fabs(t[5]));

    if (t[1] < 0) {
	if (j0 > 0 OR w < W) {
	    j0 = W - (j0+w);
	}
    }
    if (t[5] > 0) {
	if (i0 > 0 OR h < H) {
	    i0 = H - (i0+h);
	}
    }
  
    err = GDALRasterIO(hBand, GF_Read, j0, i0, w, h, gd->data, N, M, datatype, 0, 0);
    RAL_CHECK(err == CE_None);
    {
	int success;
	double nodata_value = GDALGetRasterNoDataValue(hBand, &success);
	if (success)
	    RAL_CHECK(ral_grid_set_real_nodata_value(gd, nodata_value));
    }
    if (t[1] < 0) ral_grid_flip_horizontal(gd);
    if (t[5] > 0) ral_grid_flip_vertical(gd);
    
    CPLPopErrorHandler();
    return gd;
fail:
    CPLPopErrorHandler();
    ral_grid_destroy(&gd);
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
