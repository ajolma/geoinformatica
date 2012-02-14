#include <windows.h>
#include "ral_grid.h"
#include "ral_catchment.h"


APIENTRY __declspec(dllexport) ral_grid
*dll_ral_grid_create(int datatype, int M, int N)
{
  return ral_grid_create(datatype,M,N);
}


APIENTRY __declspec(dllexport) void
dll_ral_grid_destroy(ral_grid *gd)
{
  ral_grid_destroy(&gd);
}


APIENTRY __declspec(dllexport) RAL_INTEGER
dll_ral_grid_get_integer(ral_grid *gd, int i, int j)
{
  RAL_INTEGER k;
  ral_cell c;
  
  c.i = i;
  c.j = j;
  ral_grid_get_integer(gd,c,&k);
  return k;
}


APIENTRY __declspec(dllexport) int
dll_ral_grid_set_integer(ral_grid *gd, int i, int j, RAL_INTEGER k)
{
  ral_cell c;
  
  c.i = i;
  c.j = j;
  return ral_grid_set_integer(gd,c,k);
}


APIENTRY __declspec(dllexport) RAL_REAL
dll_ral_grid_get_real(ral_grid *gd, int i, int j)
{
  RAL_REAL r;
  ral_cell c;
  
  c.i = i;
  c.j = j;
  ral_grid_get_real(gd,c,&r);
  return r;
}


APIENTRY __declspec(dllexport) int
dll_ral_grid_set_real(ral_grid *gd, int i, int j, RAL_REAL r)
{
  ral_cell c;
  
  c.i = i;
  c.j = j;
  return ral_grid_set_real(gd,c,r);
}


APIENTRY __declspec(dllexport) RAL_INTEGER
dll_ral_grid_get_integer_nodata_value(ral_grid *gd)
{
  RAL_INTEGER nodata;
  ral_grid_get_integer_nodata_value(gd, &nodata);
  return nodata;
}


APIENTRY __declspec(dllexport) void
dll_ral_grid_set_integer_nodata_value(ral_grid *gd, RAL_INTEGER nodata)
{
  ral_grid_set_integer_nodata_value(gd, nodata);
}


APIENTRY __declspec(dllexport) RAL_REAL
dll_ral_grid_get_real_nodata_value(ral_grid *gd)
{
  RAL_REAL x = -9999;
  ral_grid_get_real_nodata_value(gd, &x);
  return x;
}


APIENTRY __declspec(dllexport) int
dll_ral_grid_set_real_nodata_value(ral_grid *gd, RAL_REAL nodata)
{
  return ral_grid_set_real_nodata_value(gd, nodata);
}


APIENTRY __declspec(dllexport) int
dll_ral_grid_get_datatype(ral_grid *gd)
{
  return ral_grid_get_datatype(gd);
}


APIENTRY __declspec(dllexport) int
dll_ral_grid_get_number_of_rows(ral_grid *gd)
{
  return gd->M;
}


APIENTRY __declspec(dllexport) int
dll_ral_grid_get_number_of_columns(ral_grid *gd)
{
  return gd->N;
}


APIENTRY __declspec(dllexport) double
dll_ral_grid_get_unitdist(ral_grid *gd)
{
  return ral_grid_get_cell_size(gd);
}


APIENTRY __declspec(dllexport) double
dll_ral_grid_get_minx(ral_grid *gd)
{
  return gd->world.min.x;
}


APIENTRY __declspec(dllexport) double
dll_ral_grid_get_miny(ral_grid *gd)
{
  return gd->world.min.y;
}


APIENTRY __declspec(dllexport) void
dll_ral_grid_set_bounds_unn(ral_grid *gd, double unitdist, double minX, double minY)
{
  ral_grid_set_bounds_csnn(gd, unitdist, minX, minY);
}


APIENTRY __declspec(dllexport) RAL_INTEGER
dll_ral_grid_get_integer_minval(ral_grid *gd)
{
  return gd->datatype == RAL_INTEGER_GRID ? (RAL_IGD_VALUE_RANGE(gd))->min : (RAL_RGD_VALUE_RANGE(gd))->min;
}


APIENTRY __declspec(dllexport) RAL_INTEGER
dll_ral_grid_get_integer_maxval(ral_grid *gd)
{
  return gd->datatype == RAL_INTEGER_GRID ? (RAL_IGD_VALUE_RANGE(gd))->max : (RAL_RGD_VALUE_RANGE(gd))->max;
}


APIENTRY __declspec(dllexport) void
dll_ral_grid_set_integer_minmax(ral_grid *gd, RAL_INTEGER min, RAL_INTEGER max)
{
  RAL_IGD_VALUE_RANGE(gd)->min = min;
  RAL_IGD_VALUE_RANGE(gd)->max = max;
}


APIENTRY __declspec(dllexport) RAL_REAL
dll_ral_grid_get_real_minval(ral_grid *gd)
{
  return gd->datatype == RAL_INTEGER_GRID ? (RAL_IGD_VALUE_RANGE(gd))->min : (RAL_RGD_VALUE_RANGE(gd))->min;
}


APIENTRY __declspec(dllexport) RAL_REAL
dll_ral_grid_get_real_maxval(ral_grid *gd)
{
  return gd->datatype == RAL_INTEGER_GRID ? (RAL_IGD_VALUE_RANGE(gd))->max : (RAL_RGD_VALUE_RANGE(gd))->max;
}

APIENTRY __declspec(dllexport) char
dll_ral_geterrormsgchar(int index, int *status)
{

  // There is currently no error message
  if (index == 0 AND !ral_has_msg()) {
    *status = -1;
    return '\0';
  }
  
  // Invalid index to the error message buffer
  if (index >= RAL_MSG_BUF_SIZE OR index < 0) {
    *status = -2;
    return '\0';
  }

  if (ral_msg_buf[index] != '\0') 
    //Within the error message 
    *status = 1;
  else
    //End of error message
    *status = 0;
  return ral_msg_buf[index];
}


APIENTRY __declspec(dllexport) ral_grid
*dll_ral_dem2fdg(ral_grid *dem)
{
  ral_grid *fdg;

  RAL_CHECK(fdg = ral_dem2fdg(dem, RAL_D8));
  RAL_CHECK(ral_fdg_fixflats2(fdg, dem) >= 0);
  RAL_CHECK(ral_fdg_fixpits(fdg, dem) >= 0);
  return fdg;

 fail:
  ral_grid_destroy(&fdg);
  return NULL;
}


APIENTRY __declspec(dllexport) ral_grid
*dll_ral_fdg2uag(ral_grid *fdg)
{
  ral_grid *uag;   

  if (fdg->datatype == RAL_REAL_GRID)
    RAL_CHECK(ral_grid_2igd(fdg));
  RAL_CHECK(uag = ral_fdg2uag(fdg, NULL));
  return uag;

 fail:
  ral_grid_destroy(&uag);
  return NULL;
}


APIENTRY __declspec(dllexport) ral_grid
*dll_ral_fdg2catchment(ral_grid *fdg, int i, int j)
{
  ral_cell c;
  ral_grid *catchment;
  
  if (fdg->datatype == RAL_REAL_GRID)
    RAL_CHECK(ral_grid_2igd(fdg));
  c.i = i;
  c.j = j;
  RAL_CHECK(catchment = ral_igdnewlike(fdg));
  RAL_CHECK(ral_fdg2catchment(fdg, catchment, c));
  RAL_CHECK(ral_grid_set_integer_nodata_value(catchment, 0));
  return catchment;

 fail:
  ral_grid_destroy(&catchment);
  return NULL;
}


APIENTRY __declspec(dllexport) ral_grid
*dll_ral_fdg2catchment2(ral_grid *fdg, ral_grid *sink, RAL_INTEGER value)
{
  ral_cell c, d;
  ral_point p;
  ral_grid *catchment;

  if (fdg->datatype == RAL_REAL_GRID)
    RAL_CHECK(ral_grid_2igd(fdg));
  if (sink->datatype == RAL_REAL_GRID)
    RAL_CHECK(ral_grid_2igd(sink));
  RAL_CHECK(catchment = ral_igdnewlike(fdg));
  RAL_FOR(c, sink)
    if (RAL_IGD_CELL(sink,c) == value) {
      p = ral_grid_cell2point(sink, c);
      if (RAL_GRID__POINT_IN(fdg, p)) {
	d = ral_grid_point2cell(fdg, p);
	RAL_CHECK(ral_fdg2catchment(fdg, catchment, d));
      }
    }
  RAL_CHECK(ral_grid_set_integer_nodata_value(catchment, 0));
  return catchment;

 fail:
  ral_grid_destroy(&catchment);
  return NULL;
}


APIENTRY __declspec(dllexport) int
dll_ral_uag2streams(ral_grid *uag, RAL_REAL threshold)
{
  RAL_CHECK(ral_grid_gtreal(uag, threshold));
  RAL_CHECK(ral_grid_set_integer_nodata_value(uag, 0));
  return 1;

 fail:
  return 0;
}


APIENTRY __declspec(dllexport) ral_grid
*dll_ral_fdg_distance_to_channel(ral_grid *fdg, ral_grid *streams)
{
  if (fdg->datatype == RAL_REAL_GRID)
    RAL_CHECK(ral_grid_2igd(fdg));
  if (streams->datatype == RAL_REAL_GRID)
    RAL_CHECK(ral_grid_2igd(streams));
  return ral_fdg_distance_to_channel(fdg, streams, 0);
  
 fail:
  return NULL;
}


APIENTRY __declspec(dllexport) ral_grid
*dll_ral_diffpath(ral_grid *fdg, ral_grid *sink, ral_grid *value)
{
  ral_cell c, f;
  ral_grid *diff;
  
  if (fdg->datatype == RAL_REAL_GRID)
    RAL_CHECK(ral_grid_2igd(fdg));
  if (sink->datatype == RAL_REAL_GRID)
    RAL_CHECK(ral_grid_2igd(sink));
  RAL_CHECKM(ral_grid_overlayable(fdg, sink), RAL_ERRSTR_ARGS_OVERLAYABLE);
  RAL_CHECKM(ral_grid_overlayable(fdg, value), RAL_ERRSTR_ARGS_OVERLAYABLE);

  switch (value->datatype) {
  case RAL_INTEGER_GRID:
    RAL_CHECK(diff = ral_igdnewlike(value));
    RAL_CHECK(ral_grid_set_all_nodata(diff));
    RAL_FOR(c, fdg) {
      RAL_INTEGER value1 = RAL_IGD_CELL(value, c);
      f = c;
      while (RAL_GRID__CELL_IN(fdg, f) AND RAL_GRID__DATACELL(fdg, f) AND RAL_IGD_NODATACELL(sink, f))
	f = RAL_FLOW(fdg, f);
      if (RAL_GRID__CELL_IN(value, f)) {
	RAL_INTEGER value2 = RAL_IGD_CELL(value, f);
	RAL_IGD_CELL(diff, c) = value1 - value2;
      } else
	RAL_IGD_SETNODATACELL(diff, c);
    }
    return diff;
  case RAL_REAL_GRID:
    RAL_CHECK(diff = ral_rgdnewlike(value));
    RAL_CHECK(ral_grid_set_all_nodata(diff));
    RAL_FOR(c, fdg) {
      RAL_REAL value1 = RAL_RGD_CELL(value, c);
      f = c;
      while (RAL_GRID__CELL_IN(fdg, f) AND RAL_GRID__DATACELL(fdg, f) AND RAL_IGD_NODATACELL(sink, f))
	f = RAL_FLOW(fdg, f);
      if (RAL_GRID__CELL_IN(value, f)) {
	RAL_REAL value2 = RAL_RGD_CELL(value, f);
	RAL_RGD_CELL(diff, c) = value1 - value2;
      } else
	RAL_RGD_SETNODATACELL(diff, c);
    }
    return diff;
  }
  
 fail:
  ral_grid_destroy(&diff);
  return NULL;
}


APIENTRY __declspec(dllexport) int
dll_ral_valuepairs(ral_grid *mask, ral_grid *dist, ral_grid *value, char *filepath)
{
  RAL_INTEGER intnodata;
  int npairs = 0;
  RAL_REAL distmax = -99999999, valmax = -99999999, distval, valval, realnodata;
  ral_cell c;
  FILE *fpw;
  
  RAL_CHECKM(fpw = fopen(filepath,"w"), "Text file %s for storing the pair values could not be opened", filepath);
  ral_grid_setmask(dist, mask);
  RAL_FOR(c, dist) {
    npairs++;
    distval = RAL_GRID__CELL(dist, c);
    valval = RAL_GRID__CELL(value, c);
    if (distval > distmax)
      distmax = distval;
    if (valval > valmax)
      valmax = valval;
  }
  fprintf(fpw, "#Number_of_pairs,%d\n", npairs);
  switch (dist->datatype) {
  case RAL_INTEGER_GRID:
    fprintf(fpw, "#Maximum_distance,%d\n", (RAL_INTEGER) distmax);
    break;
  case RAL_REAL_GRID:
    fprintf(fpw, "#Maximum_distance,%f\n", distmax);
    break;
  }
  switch (value->datatype) {
  case RAL_INTEGER_GRID:
    fprintf(fpw, "#Maximum_value,%d\n", (RAL_INTEGER) valmax);
    RAL_CHECK(ral_grid_get_integer_nodata_value(value, &intnodata));
    fprintf(fpw, "#NoData_Value,%d\n", intnodata);
    break;
  case RAL_REAL_GRID:
    fprintf(fpw, "#Maximum_value,%f\n", valmax);
    RAL_CHECK(ral_grid_get_real_nodata_value(value, &realnodata));
    fprintf(fpw, "#NoData_Value,%f\n", realnodata);
    break;
  }
  fputs("#Distance Value\n",fpw);
  RAL_FOR(c, dist) {
    distval = RAL_GRID__CELL(dist, c);
    valval = RAL_GRID__CELL(value, c);
    switch (dist->datatype) {
    case RAL_INTEGER_GRID:
      switch (value->datatype) {
      case RAL_INTEGER_GRID:
	fprintf(fpw, "%d, %d\n",(RAL_INTEGER) distval, (RAL_INTEGER) valval);
	break;
      case RAL_REAL_GRID:
	fprintf(fpw, "%d, %f\n",(RAL_INTEGER) distval, valval);
	break;
      }
      break;
    case RAL_REAL_GRID:
      switch (value->datatype) {
      case RAL_INTEGER_GRID:
	fprintf(fpw, "%f, %d\n",distval, (RAL_INTEGER) valval);
	break;
      case RAL_REAL_GRID:
	fprintf(fpw, "%f, %f\n",distval,valval);
	break;
      }
      break;
    }
  }
  ral_grid_clearmask(dist);
  fclose(fpw);
  return 1;

 fail:
  return 0;
}


APIENTRY __declspec(dllexport) ral_grid
*dll_ral_classify_integer(ral_grid *gd, int nbounds, RAL_INTEGER *bounds)
{
  int i;
  ral_cell c;
  ral_grid *class, *tmp1, *tmp2;
  
  RAL_CHECK(class = ral_igdnewlike(gd));
  RAL_CHECK(ral_grid_set_integer_nodata_value(class, -9999));
  RAL_FOR(c, gd)
    if (RAL_IGD_NODATACELL(gd, c))
      RAL_IGD_SETNODATACELL(class, c);
  for (i = 1; i <= nbounds-1; i++) {
    RAL_CHECK(tmp1 = ral_igdnewcopy(gd));
    RAL_CHECK(tmp2 = ral_igdnewcopy(gd));
    RAL_CHECK(ral_grid_geinteger(tmp1, bounds[i-1]));
    RAL_CHECK(ral_grid_ltinteger(tmp2, bounds[i]));
    RAL_CHECK(ral_grid_andgd(tmp1, tmp2));
    RAL_CHECK(ral_grid_if_then_integer(tmp1, class, i));
    ral_grid_destroy(&tmp1);
    ral_grid_destroy(&tmp2);
  }
  return class;

 fail:
  ral_grid_destroy(&tmp1);
  ral_grid_destroy(&tmp2);
  ral_grid_destroy(&class);
  return NULL;
}


APIENTRY __declspec(dllexport) ral_grid
*dll_ral_classify_real(ral_grid *gd, int nbounds, RAL_REAL *bounds)
{
  int i;
  ral_cell c;
  ral_grid *class, *tmp1, *tmp2;
  
  RAL_CHECK(class = ral_igdnewlike(gd));
  RAL_CHECK(ral_grid_set_integer_nodata_value(class, -9999));
  RAL_FOR(c, gd)
    if (RAL_RGD_NODATACELL(gd, c))
      RAL_IGD_SETNODATACELL(class, c);
  for (i = 1; i <= nbounds-1; i++) {
    tmp1 = ral_rgdnewcopy(gd);
    tmp2 = ral_rgdnewcopy(gd);
    RAL_CHECK(ral_grid_gereal(tmp1, bounds[i-1]));
    RAL_CHECK(ral_grid_ltreal(tmp2, bounds[i]));
    RAL_CHECK(ral_grid_andgd(tmp1, tmp2));
    RAL_CHECK(ral_grid_if_then_integer(tmp1, class, i));
    ral_grid_destroy(&tmp1);
    ral_grid_destroy(&tmp2);
  }
  return class;

 fail:
  ral_grid_destroy(&tmp1);
  ral_grid_destroy(&tmp2);
  ral_grid_destroy(&class);
  return NULL;
}


void ii(int key, int value, void *x) {
	fprintf(x,"%i %i\n",key,value);
}

APIENTRY __declspec(dllexport) int
dll_ral_zonal_class_combinations(int ngrids, ral_grid **gd, ral_grid *zones, char *filepath)
{
  int i, n, *keys;
  ral_hash **table, index;
  ral_cell c, d;
  ral_point p;
  ral_grid *comb;
  FILE *fpw;
  
  RAL_CHECK(ral_hash_create(&index, sizeof(int)));
  if (zones->datatype == RAL_REAL_GRID)
    RAL_CHECK(ral_grid_2igd(zones));
  RAL_CHECKM(ngrids > 0 AND ngrids < 5, "dll_ral_class_combinations can only handle up to 4 grids");
  RAL_CHECKM(fpw = fopen(filepath,"w"), "Text file %s for storing the combination data could not be opened", filepath);
  RAL_CHECK(comb = ral_igdnewlike(zones));

  if (ngrids > 1) {
    for (i = 1; i <= ngrids; i++) {
      if (gd[i-1]->datatype == RAL_REAL_GRID)
	RAL_CHECK(ral_grid_2igd(gd[i-1]));
      RAL_FOR(c, zones) {
	p = ral_grid_cell2point(zones, c);
	d = ral_grid_point2cell(gd[i-1], p);
	if (RAL_GRID__CELL_IN(gd[i-1], d) AND RAL_IGD_DATACELL(gd[i-1],d)) {
	  RAL_CHECKM(RAL_IGD_CELL(gd[i-1],d) > 0 AND RAL_IGD_CELL(gd[i-1],d) < 10, \
		     "with more than 1 grid can only handle grid values from 1 to 9");
	  RAL_IGD_CELL(comb, c) = RAL_IGD_CELL(comb, c) + pow(10,i-1)*RAL_IGD_CELL(gd[i-1],d);
	}
	else
	  ; //0 for no data, do not add anything
      }
    }
  } else { // only one grid - number of classes not restricted to 9
    RAL_FOR(c, zones) {
      p = ral_grid_cell2point(zones, c);
      d = ral_grid_point2cell(gd[0], p);
      if (RAL_GRID__CELL_IN(gd[0], d))
	RAL_IGD_CELL(comb, c) = RAL_IGD_CELL(gd[0],d);
      else
	; // no data in the value grid - do not add anything 
    }
  }
  RAL_CHECK(ral_grid_zonalcontents(comb, zones, &table, &index));
  keys = ral_hash_keys(&index, &n);
  for (i = 1; i <= n; i++) {
    int *ix;
    if (ral_hash_int_lookup(&index, keys[i-1], &ix)) {
      fprintf(fpw, "%i\n", keys[i-1]);
      ral_hash_int_enumerate(table[*ix], &ii, fpw);
    }
  }
  fclose(fpw);
  return 1;

 fail:
  ral_grid_destroy(&comb);
  return 0;
}
