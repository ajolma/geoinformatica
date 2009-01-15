#include "config.h"
#include "msg.h"
#include "ral.h"

/* grid routines */

char ral_msg_buf[RAL_MSG_BUF_SIZE] = "";
int ral_has_msg_flag = 0;

void ral_set_msg(char *msg)
{
    ral_has_msg_flag = 1;
    snprintf(ral_msg_buf, RAL_MSG_BUF_SIZE-1, "%s", msg);
}

char *ral_msg(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    ral_has_msg_flag = 1;
    snprintf(ral_msg_buf, RAL_MSG_BUF_SIZE-1, format, ap);
    va_end(ap); 
    return ral_msg_buf;
}

int ral_has_msg()
{
    return ral_has_msg_flag;
}

char *ral_get_msg()
{
    if (!ral_has_msg_flag)
	return NULL;
    ral_has_msg_flag = 0;
    return ral_msg_buf;
}

int ral_r2i(RAL_REAL x, RAL_INTEGER *i) 
{
    if (x < RAL_INTEGER_MIN OR x > RAL_INTEGER_MAX) return 0;
    *i = round(x);
    return 1;
}


ral_cell *ral_cell_create()
{
    ral_cell *c = RAL_MALLOC(ral_cell);
    RAL_CHECKM(c, RAL_ERRSTR_OOM);
    c->i = 0;
    c->j = 0;
    return c;
 fail:
    return NULL;
}


void ral_cell_destroy(ral_cell **c)
{
    if (*c) free(*c);
    *c = NULL;
}


ral_cell ral_cell_move(ral_cell c, int dir) 
{
    switch (dir) {
    case 1:{ c.i--;         break; }
    case 2:{ c.i--; c.j++;  break; }
    case 3:{ c.j++;         break; }
    case 4:{ c.i++; c.j++;  break; }
    case 5:{ c.i++;         break; }
    case 6:{ c.i++; c.j--;  break; }
    case 7:{ c.j--;         break; }
    case 8:{ c.i--; c.j--;  break; }
    }
    return c;
}


int ral_cell_dir(ral_cell a, ral_cell b)
{
    if (b.i < a.i AND b.j == a.j)
	return 1;
    else if (b.i < a.i AND b.j > a.j)
	return 2;
    else if (b.i == a.i AND b.j > a.j)
	return 3;
    else if (b.i > a.i AND b.j > a.j)
	return 4;
    else if (b.i > a.i AND b.j == a.j)
	return 5;
    else if (b.i > a.i AND b.j < a.j)
	return 6;
    else if (b.i == a.i AND b.j < a.j)
	return 7;
    else 
	return 8;
}


ral_grid *ral_grid_create(int datatype, int M, int N)
{
    ral_grid *gd = NULL;
    size_t n = M*N;
    RAL_CHECKM(gd = RAL_MALLOC(ral_grid), RAL_ERRSTR_OOM);
    gd->datatype = datatype == RAL_REAL_GRID ?  RAL_REAL_GRID : RAL_INTEGER_GRID;
    gd->M = M;
    gd->N = N;
    gd->cell_size = 1;
    gd->world.min.x = 0;
    gd->world.max.x = N;
    gd->world.min.y = 0;
    gd->world.max.y = M;
    gd->nodata_value = NULL;
    gd->mask = NULL;
    if (gd->datatype == RAL_INTEGER_GRID)
	gd->data = RAL_CALLOC(n, RAL_INTEGER);
    else
	gd->data = RAL_CALLOC(n, RAL_REAL);
    RAL_CHECKM(gd->data, RAL_ERRSTR_OOM);
    return gd;
 fail:
    ral_grid_destroy(&gd);
    return NULL;
}


ral_grid *ral_grid_create_like(ral_grid *gd, int datatype)
{
    ral_grid *g;
    if (!datatype)
	datatype = gd->datatype;
    RAL_CHECK(g = ral_grid_create(datatype, gd->M, gd->N));
    g->cell_size = gd->cell_size;
    g->world = gd->world;
    if (gd->datatype == RAL_INTEGER_GRID) {
	if (gd->nodata_value) {
	    RAL_INTEGER nodata_value;
	    RAL_CHECK(ral_grid_get_integer_nodata_value(gd, &nodata_value));
	    RAL_CHECK(ral_grid_set_integer_nodata_value(g, nodata_value));
	}
    } else {
	if (gd->nodata_value) {
	    RAL_REAL nodata_value;
	    RAL_CHECK(ral_grid_get_real_nodata_value(gd, &nodata_value));
	    RAL_CHECK(ral_grid_set_real_nodata_value(g, nodata_value));
	}
    }
    return g;
 fail:
    ral_grid_destroy(&g);
    return NULL;
}


ral_grid *ral_grid_create_copy(ral_grid *gd, int datatype)
{
    ral_grid *g;
    ral_cell c;
    RAL_CHECK(g = ral_grid_create_like(gd, datatype));
    if (gd->datatype == RAL_INTEGER_GRID) {
	if (g->datatype == RAL_INTEGER_GRID) {
	    RAL_FOR(c, gd)
		RAL_INTEGER_GRID_CELL(g, c) = RAL_INTEGER_GRID_CELL(gd, c);
	} else {
	    RAL_FOR(c, gd)
		RAL_REAL_GRID_CELL(g, c) = RAL_INTEGER_GRID_CELL(gd, c);
	}
    } else {
	if (g->datatype == RAL_INTEGER_GRID) {
	    RAL_FOR(c, gd)
		RAL_CHECKM(ral_r2i(RAL_REAL_GRID_CELL(gd, c),&RAL_INTEGER_GRID_CELL(g, c)), RAL_ERRSTR_IOB);
	} else {
	    RAL_FOR(c, gd)
		RAL_REAL_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c);
	}
    }
    return g;
 fail:
    ral_grid_destroy(&g);
    return NULL;
}


void ral_grid_destroy(ral_grid **gd)
{
    if (*gd) {
	if ((*gd)->nodata_value) free((*gd)->nodata_value);
	if ((*gd)->data) free((*gd)->data);
	free(*gd);
	*gd = NULL;
    }
}


int ral_grid_get_height(ral_grid *gd) 
{
    return gd->M;
}


int ral_grid_get_width(ral_grid *gd) 
{
    return gd->N;
}


int ral_grid_get_datatype(ral_grid *gd) 
{
    return gd->datatype;
}


double ral_grid_get_cell_size(ral_grid *gd)
{  
    return gd->cell_size;
}


ral_rectangle ral_grid_get_world(ral_grid *gd)
{
    return gd->world;
}


int ral_grid_has_nodata_value(ral_grid *gd)
{
    return gd->nodata_value != NULL;
}


int ral_grid_get_integer_nodata_value(ral_grid *gd, RAL_INTEGER *nodata_value)
{
    RAL_CHECKM(gd->nodata_value, "The grid does not have a no data value.");
    if (gd->datatype == RAL_INTEGER_GRID) 
	*nodata_value = RAL_INTEGER_GRID_NODATA_VALUE(gd);
    else
	RAL_CHECKM(ral_r2i(RAL_REAL_GRID_NODATA_VALUE(gd), nodata_value), RAL_ERRSTR_IOB);
    return 1;
 fail:
    return 0;
}


int ral_grid_get_real_nodata_value(ral_grid *gd, RAL_REAL *nodata_value)
{
    RAL_CHECKM(gd->nodata_value, "The grid does not have a no data value.");
    *nodata_value = RAL_GRID_NODATA_VALUE(gd);
    return 1;
 fail:
    return 0;
}


int ral_grid_set_integer_nodata_value(ral_grid *gd, RAL_INTEGER nodata_value)
{
    if (gd->datatype == RAL_INTEGER_GRID) {
	if (gd->nodata_value == NULL)
	    RAL_CHECKM(gd->nodata_value = RAL_MALLOC(RAL_INTEGER), RAL_ERRSTR_OOM);
	*((RAL_INTEGER *)((gd)->nodata_value)) = nodata_value;
    } else {
	if (gd->nodata_value == NULL)
	    RAL_CHECKM(gd->nodata_value = RAL_MALLOC(RAL_REAL), RAL_ERRSTR_OOM);
	*((RAL_REAL *)((gd)->nodata_value)) = nodata_value;
    }
    return 1;
 fail:
    return 0;
}

int ral_grid_set_real_nodata_value(ral_grid *gd, RAL_REAL nodata_value)
{
    if (gd->datatype == RAL_INTEGER_GRID) {
	if (gd->nodata_value == NULL)
	    RAL_CHECKM(gd->nodata_value = RAL_MALLOC(RAL_INTEGER), RAL_ERRSTR_OOM);
	if (nodata_value <= RAL_INTEGER_MIN)
	    *(RAL_INTEGER *)((gd)->nodata_value) = RAL_INTEGER_MIN;
	else if (nodata_value >= RAL_INTEGER_MAX)
	    *(RAL_INTEGER *)((gd)->nodata_value) = RAL_INTEGER_MAX;
	else
	    *(RAL_INTEGER *)((gd)->nodata_value) = round(nodata_value);
    } else {
	if (gd->nodata_value == NULL)
	    RAL_CHECKM(gd->nodata_value = RAL_MALLOC(RAL_REAL), RAL_ERRSTR_OOM);
	*(RAL_REAL *)((gd)->nodata_value) = nodata_value;
    }
    return 1;
 fail:
    return 0;
}


void ral_grid_remove_nodata_value(ral_grid *gd)
{
    if (gd->nodata_value) {
	free(gd->nodata_value);
	gd->nodata_value = NULL;
    }
}


ral_grid *ral_grid_get_mask(ral_grid *gd)
{
    return gd->mask;
}


void ral_grid_set_mask(ral_grid *gd, ral_grid *mask)
{
    gd->mask = mask;
}


void ral_grid_clear_mask(ral_grid *gd)
{
    gd->mask = NULL;
}


void RAL_CALL ral_grid_flip_horizontal(ral_grid *gd)
{
    if (gd->datatype == RAL_REAL_GRID) {
	ral_cell c;
	RAL_REAL x;
	for (c.i = 0; c.i < gd->M; c.i++) 
	    for (c.j = 0; c.j < gd->N/2; c.j++) {
		ral_cell d = c;
		d.j = gd->N - 1 - c.j;
		x = RAL_REAL_GRID_CELL(gd, d);
		RAL_REAL_GRID_CELL(gd, d) = RAL_REAL_GRID_CELL(gd, c);
		RAL_REAL_GRID_CELL(gd, c) = x;
	    } 
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	ral_cell c;
	RAL_INTEGER x;
	for (c.i = 0; c.i < gd->M; c.i++) 
	    for (c.j = 0; c.j < gd->N/2; c.j++) {
		ral_cell d = c;
		d.j = gd->N - 1 - c.j;
		x = RAL_INTEGER_GRID_CELL(gd, d);
		RAL_INTEGER_GRID_CELL(gd, d) = RAL_INTEGER_GRID_CELL(gd, c);
		RAL_INTEGER_GRID_CELL(gd, c) = x;
	    }
    } 
}


void RAL_CALL ral_grid_flip_vertical(ral_grid *gd)
{
    if (gd->datatype == RAL_REAL_GRID) {
	ral_cell c;
	RAL_REAL x;
	for (c.i = 0; c.i < gd->M/2; c.i++) 
	    for (c.j = 0; c.j < gd->N; c.j++) {
		ral_cell d = c;
		d.i = gd->M - 1 - c.i;
		x = RAL_REAL_GRID_CELL(gd, d);
		RAL_REAL_GRID_CELL(gd, d) = RAL_REAL_GRID_CELL(gd, c);
		RAL_REAL_GRID_CELL(gd, c) = x;
	    } 
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	ral_cell c;
	RAL_INTEGER x;
	for (c.i = 0; c.i < gd->M/2; c.i++) 
	    for (c.j = 0; c.j < gd->N; c.j++) {
		ral_cell d = c;
		d.i = gd->M - 1 - c.i;
		x = RAL_INTEGER_GRID_CELL(gd, d);
		RAL_INTEGER_GRID_CELL(gd, d) = RAL_INTEGER_GRID_CELL(gd, c);
		RAL_INTEGER_GRID_CELL(gd, c) = x;
	    }
    } 
} 


int ral_grid_coerce(ral_grid *gd, int data_type)
{
    if (gd->datatype == RAL_REAL_GRID AND data_type == RAL_INTEGER_GRID) {
	ral_grid *g = ral_grid_create_copy(gd, RAL_INTEGER_GRID);
	ral_grid temp;
	RAL_CHECK(g);
	swap (*g, *gd, temp);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID AND data_type == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_copy(gd, RAL_REAL_GRID);
	ral_grid temp;
	RAL_CHECK(g);
	swap (*g, *gd, temp);
	ral_grid_destroy(&g);
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_overlayable(ral_grid *g1, ral_grid *g2)
{
    return (g1->M == g2->M AND g1->N == g2->N AND 
	    fabs(g1->cell_size - g2->cell_size) < RAL_EPSILON AND
	    fabs(g1->world.min.x - g2->world.min.x) < RAL_EPSILON AND
	    fabs(g1->world.min.y - g2->world.min.y) < RAL_EPSILON);
}


void ral_grid_set_bounds_csnn(ral_grid *gd, double cell_size, double minX, double minY)
{
    gd->cell_size = cell_size;
    gd->world.min.x = minX;
    gd->world.min.y = minY;
    gd->world.max.x = minX+gd->N*cell_size;
    gd->world.max.y = minY+gd->M*cell_size;
}


void ral_grid_set_bounds_csnx(ral_grid *gd, double cell_size, double minX, double maxY)
{
    gd->cell_size = cell_size;
    gd->world.min.x = minX;
    gd->world.min.y = maxY-gd->M*cell_size;
    gd->world.max.x = minX+gd->N*cell_size;
    gd->world.max.y = maxY;
}


void ral_grid_set_bounds_csxn(ral_grid *gd, double cell_size, double maxX, double minY)
{
    gd->cell_size = cell_size;
    gd->world.min.x = maxX-gd->N*cell_size;
    gd->world.min.y = minY;
    gd->world.max.x = maxX;
    gd->world.max.y = minY+gd->M*cell_size;
}


void ral_grid_set_bounds_csxx(ral_grid *gd, double cell_size, double maxX, double maxY)
{
    gd->cell_size = cell_size;
    gd->world.min.x = maxX-gd->N*cell_size;
    gd->world.min.y = maxY-gd->M*cell_size;
    gd->world.max.x = maxX;
    gd->world.max.y = maxY;
}


void ral_grid_set_bounds_nxn(ral_grid *gd, double minX, double maxX, double minY)
{
    gd->cell_size = (maxX-minX)/gd->N;
    
    gd->world.min.x = minX;
    gd->world.min.y = minY;
    gd->world.max.x = maxX;
    gd->world.max.y = minY+gd->M*gd->cell_size;
}


void ral_grid_set_bounds_nxx(ral_grid *gd, double minX, double maxX, double maxY)
{
    gd->cell_size = (maxX-minX)/gd->N;
    gd->world.min.x = minX;
    gd->world.min.y = maxY-gd->M*gd->cell_size;
    gd->world.max.x = maxX;
    gd->world.max.y = maxY;
}


void ral_grid_set_bounds_nnx(ral_grid *gd, double minX, double minY, double maxY)
{
    gd->cell_size = (maxY-minY)/gd->M;
    gd->world.min.x = minX;
    gd->world.min.y = minY;
    gd->world.max.x = minX+gd->N*gd->cell_size;
    gd->world.max.y = maxY;
}


void ral_grid_set_bounds_xnx(ral_grid *gd, double maxX, double minY, double maxY)
{
    gd->cell_size = (maxY-minY)/gd->M;
    gd->world.min.x = maxX-gd->N*gd->cell_size;
    gd->world.min.y = minY;
    gd->world.max.x = maxX;
    gd->world.max.y = maxY;
}


void ral_grid_copy_bounds(ral_grid *from,ral_grid *to)
{
    to->cell_size = from->cell_size;
    to->world = from->world;
}


ral_cell ral_grid_point2cell(ral_grid *gd, ral_point p)
{
    ral_cell c;
    p.x -= gd->world.min.x;
    p.x /= gd->cell_size;
    p.y = gd->world.max.y - p.y;
    p.y /= gd->cell_size;
    c.i = floor(p.y);
    c.j = floor(p.x);
    return c;
}


ral_point ral_grid_cell2point(ral_grid *gd, ral_cell c)
{
    ral_point p;
    p.x = gd->world.min.x + (RAL_REAL)c.j*gd->cell_size + gd->cell_size/2;
    p.y = gd->world.min.y + (RAL_REAL)(gd->M-c.i)*gd->cell_size - gd->cell_size/2;
    p.z = 0;
    p.m = 0;
    return p;
}


ral_point ral_grid_cell2point_upleft(ral_grid *gd, ral_cell c)
{
    ral_point p;
    p.x = gd->world.min.x + (RAL_REAL)c.j*gd->cell_size;
    p.y = gd->world.min.y + (RAL_REAL)(gd->M-c.i)*gd->cell_size;
    p.z = 0;
    p.m = 0;
    return p;
}


int ral_grid_get_real(ral_grid *gd, ral_cell c, RAL_REAL *x)
{
    RAL_CHECKM(RAL_GRID_CELL_IN(gd, c), RAL_ERRSTR_COB);
    switch (gd->datatype) {
    case RAL_REAL_GRID: 
	*x = RAL_REAL_GRID_CELL(gd, c);
	break;
    case RAL_INTEGER_GRID:
	*x = RAL_INTEGER_GRID_CELL(gd, c);
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_get_integer(ral_grid *gd, ral_cell c, RAL_INTEGER *x)
{
    RAL_CHECKM(RAL_GRID_CELL_IN(gd, c), RAL_ERRSTR_COB);
    switch (gd->datatype) {
    case RAL_REAL_GRID: {
	RAL_CHECKM(ral_r2i(RAL_REAL_GRID_CELL(gd, c),x), RAL_ERRSTR_IOB);
	break;
    }
    case RAL_INTEGER_GRID:
	*x = RAL_INTEGER_GRID_CELL(gd, c);
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_set_real(ral_grid *gd, ral_cell c, RAL_REAL x)
{
    RAL_CHECKM(RAL_GRID_CELL_IN(gd, c), RAL_ERRSTR_COB);
    switch (gd->datatype) {
    case RAL_REAL_GRID:
	RAL_REAL_GRID_CELL(gd, c) = x;
	break;
    case RAL_INTEGER_GRID: {
	RAL_CHECKM(ral_r2i(x, &RAL_INTEGER_GRID_CELL(gd, c)), RAL_ERRSTR_IOB);
    }
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_set_integer(ral_grid *gd, ral_cell c, RAL_INTEGER x)
{
    RAL_CHECKM(RAL_GRID_CELL_IN(gd, c), RAL_ERRSTR_COB);
    switch (gd->datatype) {
    case RAL_REAL_GRID:
	RAL_REAL_GRID_CELL(gd, c) = x;
	break;
    case RAL_INTEGER_GRID:
	RAL_INTEGER_GRID_CELL(gd, c) = x;
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_set_nodata(ral_grid *gd, ral_cell c)
{
    RAL_CHECKM(gd->nodata_value, "the grid does not have a nodata value");
    RAL_CHECKM(RAL_GRID_CELL_IN(gd, c), RAL_ERRSTR_COB);
    switch (gd->datatype) {
    case RAL_REAL_GRID:
	RAL_REAL_GRID_CELL(gd, c) = RAL_REAL_GRID_NODATA_VALUE(gd);
	break;
    case RAL_INTEGER_GRID: 
	RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_NODATA_VALUE(gd);
    }
    return 1;
fail:
    return 0;
}


int ral_integer_grid_get_value_range(ral_grid *gd, ral_integer_range *range)
{
    ral_cell c;
    int f = 0;
    RAL_FOR(c, gd) {
	if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
	    RAL_INTEGER a = RAL_INTEGER_GRID_CELL(gd, c);
	    if (!f) {
		range->min = range->max = a;
		f = 1;
	    } else {
		range->min = min(range->min, a);
		range->max = max(range->max, a);
	    }
	}
    }
    return f;
}


int ral_real_grid_get_value_range(ral_grid *gd, ral_real_range *range)
{
    ral_cell c;
    int f = 0;
    RAL_FOR(c, gd) {
	if (RAL_REAL_GRID_DATACELL(gd, c)) {
	    RAL_REAL a = RAL_REAL_GRID_CELL(gd, c);
	    if (!f) {
		range->min = range->max = a;
		f = 1;
	    } else {
		range->min = min(range->min, a);
		range->max = max(range->max, a);
	    }
	}
    }
    return f;
}


int ral_grid_set_all_integer(ral_grid *gd, RAL_INTEGER x)
{
    if (gd->datatype == RAL_REAL_GRID) {
	ral_cell c;
	RAL_FOR(c, gd)
	    RAL_REAL_GRID_CELL(gd, c) = x;
    } else {
	ral_cell c;
	RAL_FOR(c, gd)
	    RAL_INTEGER_GRID_CELL(gd, c) = x;
    }
    return 1;
}


int ral_grid_set_all_real(ral_grid *gd, RAL_REAL x)
{
    if (gd->datatype == RAL_REAL_GRID) {
	ral_cell c;
	RAL_FOR(c, gd)
	    RAL_REAL_GRID_CELL(gd, c) = x;
    } else {
	RAL_INTEGER i;
	ral_cell c;
	RAL_CHECKM(ral_r2i(x,&i), RAL_ERRSTR_IOB);
	RAL_FOR(c, gd)
	    RAL_INTEGER_GRID_CELL(gd, c) = i;
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_set_all_nodata(ral_grid *gd)
{
    RAL_CHECKM(gd->nodata_value, "the grid does not have a nodata value");
    switch (gd->datatype) {
    case RAL_REAL_GRID: {
	ral_cell c;
	RAL_FOR(c, gd)
	    RAL_REAL_GRID_CELL(gd, c) = RAL_REAL_GRID_NODATA_VALUE(gd);
	break;
    } 
    case RAL_INTEGER_GRID: {
	ral_cell c;
	RAL_FOR(c, gd)
	    RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_NODATA_VALUE(gd);
    }
    }
    return 1;
 fail:
    return 0;
}


ral_grid *ral_grid_round(ral_grid *gd)
{
    ral_cell c;
    ral_grid *g = NULL;
    RAL_CHECK(g = ral_grid_create_like(gd, RAL_INTEGER_GRID));
    switch (gd->datatype) {
    case RAL_INTEGER_GRID: {
	RAL_FOR(c, gd)
	    RAL_INTEGER_GRID_CELL(g, c) = RAL_INTEGER_GRID_CELL(gd, c);
	break;
    }
    case RAL_REAL_GRID: {
	RAL_FOR(c, gd) {
	    RAL_CHECKM(ral_r2i(RAL_REAL_GRID_CELL(gd, c), &RAL_INTEGER_GRID_CELL(g, c)), RAL_ERRSTR_IOB);
	}
    }
    }
    return g;
 fail:
    ral_grid_destroy(&g);
    return NULL;
}


void *ral_grid_get_focal(ral_grid *gd, ral_cell c, int d)
{
    ral_cell a;
    int i = 0;
    void *x = NULL;
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_CHECKM(x = RAL_CALLOC((2*d+1)*(2*d+1), RAL_INTEGER), RAL_ERRSTR_OOM);
	for (a.i = c.i - d; a.i <= c.i + d; a.i++)
	    for (a.j = c.j - d; a.j <= c.j + d; a.j++) {
		((RAL_INTEGER *)x)[i] = RAL_GRID_CELL_IN(gd, a) ? 
		    RAL_INTEGER_GRID_CELL(gd, a) : RAL_INTEGER_GRID_NODATA_VALUE(gd);
		i++;
	    }
    } else if (gd->datatype == RAL_REAL_GRID) {
	RAL_CHECKM(x = RAL_CALLOC((2*d+1)*(2*d+1), RAL_REAL), RAL_ERRSTR_OOM);
	for (a.i = c.i - d; a.i <= c.i + d; a.i++)
	    for (a.j = c.j - d; a.j <= c.j + d; a.j++) {
		((RAL_REAL *)x)[i] = RAL_GRID_CELL_IN(gd, a) ? 
		    RAL_REAL_GRID_CELL(gd, a) : RAL_REAL_GRID_NODATA_VALUE(gd);
		i++;
	    }
    }
    return x;
 fail:
    return NULL;
}


void ral_grid_set_focal(ral_grid *gd, ral_cell c, void *x, int *mask, int d)
{
    ral_cell a;
    int i = 0;
    if (gd->datatype == RAL_INTEGER_GRID)
	for (a.i = c.i - d; a.i <= c.i + d; a.i++)
	    for (a.j = c.j - d; a.j <= c.j + d; a.j++) {
		if (mask[i] AND RAL_GRID_CELL_IN(gd, a)) 
		    RAL_INTEGER_GRID_CELL(gd, a) = ((RAL_INTEGER *)x)[i];
		i++;
	    }
    else if (gd->datatype == RAL_REAL_GRID)
	for (a.i = c.i - d; a.i <= c.i + d; a.i++)
	    for (a.j = c.j - d; a.j <= c.j + d; a.j++) {
		if (mask[i] AND RAL_GRID_CELL_IN(gd, a)) 
		    RAL_REAL_GRID_CELL(gd, a) = ((RAL_REAL *)x)[i];
		i++;
	    }
}


int ral_integer_grid_focal_sum(ral_grid *grid, ral_cell cell, int *mask, int delta, int *sum)
{
    int f = 0;
    ral_cell c;
    int i = 0;
    *sum = 0;
    RAL_CHECKM(grid->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
	    if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_INTEGER_GRID_DATACELL(grid, c)) {
		f++;
		*sum += RAL_INTEGER_GRID_CELL(grid, c);
	    }
	    i++;
	}
    return f;
 fail:
    return -1;
}


int ral_real_grid_focal_sum(ral_grid *grid, ral_cell cell, int *mask, int delta, double *sum)
{
    int f = 0;
    ral_cell c;
    int i = 0;
    *sum = 0;
    RAL_CHECKM(grid->datatype == RAL_REAL_GRID, RAL_ERRSTR_ARG_REAL);
    for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
	    if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_REAL_GRID_DATACELL(grid, c)) {
		f++;
		*sum += RAL_REAL_GRID_CELL(grid, c);
	    }
	    i++;
	}
    return f;
fail:
    return -1;
}


int ral_grid_focal_mean(ral_grid *grid, ral_cell cell, int *mask, int delta, double *mean)
{
    int f = 0;
    ral_cell c;
    int i = 0;
    *mean = 0;
    if (grid->datatype == RAL_INTEGER_GRID) {
	for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
		if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_INTEGER_GRID_DATACELL(grid, c)) {
		    f++;
		    *mean += RAL_INTEGER_GRID_CELL(grid, c);
		}
		i++;
	    }
    } else {
	for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
		if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_REAL_GRID_DATACELL(grid, c)) {
		    f++;
		    *mean += RAL_REAL_GRID_CELL(grid, c);
		}
		i++;
	    }
    }
    *mean /= (double)f;
    return f;
}


int ral_grid_focal_variance(ral_grid *grid, ral_cell cell, int *mask, int delta, double *variance)
{
    int n = 0;
    ral_cell c;
    double mean = 0;
    int i = 0;
    if (grid->datatype == RAL_INTEGER_GRID) {
	for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
		if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_INTEGER_GRID_DATACELL(grid, c)) {
		    double oldmean = mean;
		    n++;
		    mean += (RAL_INTEGER_GRID_CELL(grid, c) - oldmean) / n;
		    *variance += (RAL_INTEGER_GRID_CELL(grid, c) - oldmean) * (RAL_INTEGER_GRID_CELL(grid, c) - mean);
		}
		i++;
	    }
    } else {
	for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
		if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_REAL_GRID_DATACELL(grid, c)) {
		    double oldmean = mean;
		    n++;
		    mean += (RAL_REAL_GRID_CELL(grid, c) - oldmean) / n;
		    *variance += (RAL_REAL_GRID_CELL(grid, c) - oldmean) * (RAL_REAL_GRID_CELL(grid, c) - mean);
		}
		i++;
	    }
    }
    if (n > 1) *variance /= (n - 1);
    return n;
}
    

int ral_grid_focal_count(ral_grid *grid, ral_cell cell, int *mask, int delta)
{
    int f = 0;
    ral_cell c;
    int i = 0;
    if (grid->datatype == RAL_INTEGER_GRID) {
	for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
		if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_INTEGER_GRID_DATACELL(grid, c))
		    f++;
		i++;
	    }
    } else {
	for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
		if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_REAL_GRID_DATACELL(grid, c))
		    f++;
		i++;
	    }
    }
    return f;
}


int ral_grid_focal_count_of(ral_grid *grid, ral_cell cell, int *mask, int delta, RAL_INTEGER value)
{
    int f = 0;
    ral_cell c;
    int i = 0;
    RAL_CHECKM(grid->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
	    if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_INTEGER_GRID_DATACELL(grid, c)) {
		if (RAL_INTEGER_GRID_CELL(grid, c) == value)
		    f++;
	    }
	    i++;
	}
fail:
    return f;
}


int ral_integer_grid_focal_range(ral_grid *grid, ral_cell cell, int *mask, int delta, ral_integer_range *range)
{
    int f = 0;
    ral_cell c;
    int i = 0;
    RAL_CHECKM(grid->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
	    if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_INTEGER_GRID_DATACELL(grid, c)) {
		if (!f) {
		    range->max = range->min = RAL_INTEGER_GRID_CELL(grid, c);
		} else {
		    range->min = min(range->min, RAL_INTEGER_GRID_CELL(grid, c));
		    range->max = max(range->max, RAL_INTEGER_GRID_CELL(grid, c));
		}
		f++;
	    }
	    i++;
	}
fail:
    return f;
}


int ral_real_grid_focal_range(ral_grid *grid, ral_cell cell, int *mask, int delta, ral_real_range *range)
{
    int f = 0;
    ral_cell c;
    int i = 0;
    RAL_CHECKM(grid->datatype == RAL_REAL_GRID, RAL_ERRSTR_ARG_REAL);
    for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
	    if (mask[i] AND RAL_GRID_CELL_IN(grid, c) AND RAL_REAL_GRID_DATACELL(grid, c)) {
		if (!f) {
		    range->max = range->min = RAL_REAL_GRID_CELL(grid, c);
		} else {
		    range->min = min(range->min, RAL_REAL_GRID_CELL(grid, c));
		    range->max = max(range->max, RAL_REAL_GRID_CELL(grid, c));
		}
		f++;
	    }
	    i++;
	}
fail:
    return f;
}


int ral_grid_convolve(ral_grid *grid, ral_cell cell, double *kernel, int delta, double *g)
{
    int f = 0;
    ral_cell c;
    int i = 0;
    *g = 0;
    if (grid->datatype == RAL_INTEGER_GRID) {
	for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
		if (RAL_GRID_CELL_IN(grid, c) AND RAL_INTEGER_GRID_DATACELL(grid, c)) {
		    f++;
		    *g += kernel[i] * RAL_INTEGER_GRID_CELL(grid, c);
		}
		i++;
	    }
    } else {
	for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
	    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
		if (RAL_GRID_CELL_IN(grid, c) AND RAL_REAL_GRID_DATACELL(grid, c)) {
		    f++;
		    *g += kernel[i] * RAL_REAL_GRID_CELL(grid, c);
		}
		i++;
	    }
    }
    return f;
}


ral_grid *ral_grid_focal_sum_grid(ral_grid *grid, int *mask, int delta)
{
    ral_grid *ret = NULL;
    ral_cell c;
    RAL_CHECK(ret = ral_grid_create_copy(grid, 0));
    if (grid->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, ret) {
	    int sum;
	    if (ral_integer_grid_focal_sum(grid, c, mask, delta, &sum))
		RAL_INTEGER_GRID_CELL(ret, c) = sum;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(ret, c); /* sets to zero if no nodata */
	}
    } else {
	RAL_FOR(c, ret) {
	    double sum;
	    if (ral_real_grid_focal_sum(grid, c, mask, delta, &sum))
		RAL_REAL_GRID_CELL(ret, c) = sum;
	    else
		RAL_REAL_GRID_SETNODATACELL(ret, c); /* sets to zero if no nodata */
	}
    }
    return ret;
 fail:
    ral_grid_destroy(&ret);
    return NULL;
}


ral_grid *ral_grid_focal_mean_grid(ral_grid *grid, int *mask, int delta)
{
    ral_grid *ret = NULL;
    ral_cell c;
    RAL_CHECK(ret = ral_grid_create_copy(grid, RAL_REAL_GRID));
    RAL_FOR(c, ret) {
	double mean;
	if (ral_grid_focal_mean(grid, c, mask, delta, &mean))
	    RAL_REAL_GRID_CELL(ret, c) = mean;
	else
	    RAL_REAL_GRID_SETNODATACELL(ret, c); /* sets to zero if no nodata */
    }
    return ret;
 fail:
    ral_grid_destroy(&ret);
    return NULL;
}


ral_grid *ral_grid_focal_variance_grid(ral_grid *grid, int *mask, int delta)
{
    ral_grid *ret = NULL;
    ral_cell c;
    RAL_CHECK(ret = ral_grid_create_copy(grid, RAL_REAL_GRID));
    RAL_FOR(c, ret) {
	double variance;
	if (ral_grid_focal_mean(grid, c, mask, delta, &variance))
	    RAL_REAL_GRID_CELL(ret, c) = variance;
	else
	    RAL_REAL_GRID_SETNODATACELL(ret, c); /* sets to zero if no nodata */
    }
    return ret;
 fail:
    ral_grid_destroy(&ret);
    return NULL;
}


ral_grid *ral_grid_focal_count_grid(ral_grid *grid, int *mask, int delta)
{
    ral_grid *ret = NULL;
    ral_cell c;
    RAL_CHECK(ret = ral_grid_create_copy(grid, RAL_INTEGER_GRID));
    RAL_FOR(c, ret)
	RAL_INTEGER_GRID_CELL(ret, c) = ral_grid_focal_count(grid, c, mask, delta);
    return ret;
 fail:
    ral_grid_destroy(&ret);
    return NULL;
}


ral_grid *ral_grid_focal_count_of_grid(ral_grid *grid, int *mask, int delta, RAL_INTEGER value)
{
    ral_grid *ret = NULL;
    ral_cell c;
    RAL_CHECK(ret = ral_grid_create_copy(grid, RAL_INTEGER_GRID));
    RAL_FOR(c, ret)
	RAL_INTEGER_GRID_CELL(ret, c) = ral_grid_focal_count_of(grid, c, mask, delta, value);
    return ret;
 fail:
    ral_grid_destroy(&ret);
    return NULL;
}


ral_grid_handle RAL_CALL ral_grid_spread(ral_grid *grid, double *mask, int delta)
{
    ral_grid *ret = NULL;
    RAL_CHECK(ret = ral_grid_create_like(grid, RAL_REAL_GRID));
    ral_cell cell;
    if (grid->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(cell, grid) {
	    if (RAL_INTEGER_GRID_DATACELL(grid, cell)) {
		int i = 0;
		int x = RAL_INTEGER_GRID_CELL(grid, cell);
		ral_cell c;
		for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
		    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
			if (RAL_GRID_CELL_IN(ret, c))
			    RAL_REAL_GRID_CELL(ret, c) += mask[i] * (double)x;
			i++;
		    }
	    }
	}
    } else {
	RAL_FOR(cell, grid) {
	    if (RAL_REAL_GRID_DATACELL(grid, cell)) {
		int i = 0;
		double x = RAL_REAL_GRID_CELL(grid, cell);
		ral_cell c;
		for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++)
		    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
			if (RAL_GRID_CELL_IN(ret, c))
			    RAL_REAL_GRID_CELL(ret, c) += mask[i] * x;
			i++;
		    }
	    }
	}
    }
    return ret;
fail:
    ral_grid_destroy(&ret);
    return NULL;
}


ral_grid_handle RAL_CALL ral_grid_spread_random(ral_grid *grid, double *mask, int delta)
{
    ral_grid *ret = NULL;
    RAL_CHECKM(grid->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    RAL_CHECK(ret = ral_grid_create_like(grid, RAL_INTEGER_GRID));
    ral_cell cell;
    RAL_FOR(cell, grid) {
	if (RAL_INTEGER_GRID_DATACELL(grid, cell)) {
	    int x = RAL_INTEGER_GRID_CELL(grid, cell);
	    int j;
	    for (j = 0; j < x; j++) {
		int i = 0;
		ral_cell c;
		double p = rand()/((double)RAND_MAX + 1);
		double w = mask[0];
		for (c.i = cell.i - delta; c.i <= cell.i + delta; c.i++) {
		    for (c.j = cell.j - delta; c.j <= cell.j + delta; c.j++) {
			if (p < w) {
			    if (RAL_GRID_CELL_IN(ret, c))
				RAL_INTEGER_GRID_CELL(ret, c)++;
			    i = -1;
			    break;
			}
			w += mask[++i];
		    }
		    if (i < 0)
			break;
		}
	    }
	}
    }
    return ret;
fail:
    ral_grid_destroy(&ret);
    return NULL;
}


ral_grid *ral_grid_convolve_grid(ral_grid *grid, double *kernel, int delta)
{
    ral_grid *ret = NULL;
    ral_cell c;
    RAL_CHECK(ret = ral_grid_create_like(grid, RAL_REAL_GRID));
    RAL_FOR(c, ret) {
	double g;
	if (ral_grid_convolve(grid, c, kernel, delta, &g))
	    RAL_REAL_GRID_CELL(ret, c) = g;
	else
	    RAL_REAL_GRID_SETNODATACELL(ret, c); /* sets to zero if no nodata */
    }
    return ret;
 fail:
    ral_grid_destroy(&ret);
    return NULL;
}


/* should be used only if "to" is created new like "from" */
void ral_grid_steal_data(ral_grid *to, ral_grid *from)
{
    if (to->data) free(to->data);
    if (to->nodata_value) free(to->nodata_value);
    to->data = from->data;
    to->nodata_value = from->nodata_value;
    to->mask = from->mask;
    from->data = NULL;
    from->nodata_value = NULL;
    to->datatype = from->datatype;
}


int ral_grid_data(ral_grid *gd)
{
    ral_cell c;
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c)) 
		RAL_INTEGER_GRID_CELL(gd, c) = 1;
	    else
		RAL_INTEGER_GRID_CELL(gd, c) = 0;
	}
    } else if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c)) 
		RAL_INTEGER_GRID_CELL(g, c) = 1;
	    else
		RAL_INTEGER_GRID_CELL(g, c) = 0;
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    }
    ral_grid_remove_nodata_value(gd);
    return 1;
 fail:
    return 0;
}


int ral_grid_not(ral_grid *gd)
{
    ral_cell c;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_FOR(c, gd)
	if (RAL_INTEGER_GRID_DATACELL(gd, c)) 
	    RAL_INTEGER_GRID_CELL(gd, c) = !RAL_INTEGER_GRID_CELL(gd, c);
    return 1;
 fail:
    return 0;
}


int ral_grid_and_grid(ral_grid *gd1, ral_grid *gd2)
{
    ral_cell c;
    RAL_CHECKM(gd1->M == gd2->M AND gd1->N == gd2->N, RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    RAL_FOR(c, gd1) {
	if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c)) {
	    RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) AND RAL_INTEGER_GRID_CELL(gd2, c);
	} else 
	    RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_or_grid(ral_grid *gd1, ral_grid *gd2) 
{  
    ral_cell c;
    RAL_CHECKM(gd1->M == gd2->M AND gd1->N == gd2->N, RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    RAL_FOR(c, gd1) {
	if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c)) {
	    RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) OR RAL_INTEGER_GRID_CELL(gd2, c);
	} else 
	    RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_add_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) +=  x;
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x,&i), RAL_ERRSTR_IOB);
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) += i;
    
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_add_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    switch (gd->datatype) {
    case RAL_REAL_GRID:
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) +=  x;
	break;
    case RAL_INTEGER_GRID:
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) += x;
    }
    return 1;
}



int ral_grid_add_grid(ral_grid *gd1, ral_grid *gd2)
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) += RAL_REAL_GRID_CELL(gd2, c);
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) += RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c)) {
		long a = RAL_INTEGER_GRID_CELL(gd1, c) + round(RAL_REAL_GRID_CELL(gd2, c));
		RAL_CHECKM(a > RAL_INTEGER_MIN AND a < RAL_INTEGER_MAX, RAL_ERRSTR_IOB);
		RAL_INTEGER_GRID_CELL(gd1, c) = a;
	    } else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) += RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_sub_grid(ral_grid *gd1, ral_grid *gd2)
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) -= RAL_REAL_GRID_CELL(gd2, c);
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) -= RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c)) {
		long a = RAL_INTEGER_GRID_CELL(gd1, c) - round(RAL_REAL_GRID_CELL(gd2, c));
		RAL_CHECKM(a > RAL_INTEGER_MIN AND a < RAL_INTEGER_MAX, RAL_ERRSTR_IOB);
		RAL_INTEGER_GRID_CELL(gd1, c) = a;
	    } else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) -= RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_mult_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) *= x;
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) *= i;
    
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_mult_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    switch (gd->datatype) {
    case RAL_REAL_GRID:
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) *= x;
	break;
    case RAL_INTEGER_GRID:
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) *= x;
    }
    return 1;
}



int ral_grid_mult_grid(ral_grid *gd1, ral_grid *gd2) 
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) *= RAL_REAL_GRID_CELL(gd2, c);
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) *= RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c)) {
		long a = RAL_INTEGER_GRID_CELL(gd1, c) * round(RAL_REAL_GRID_CELL(gd2, c));
		RAL_CHECKM(a > RAL_INTEGER_MIN AND a < RAL_INTEGER_MAX, RAL_ERRSTR_IOB);
		RAL_INTEGER_GRID_CELL(gd1, c) = a;
	    } else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) *= RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_div_real(ral_grid *gd, RAL_REAL x) 
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) /= x;
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
		RAL_CHECKM(ral_r2i((RAL_REAL)RAL_INTEGER_GRID_CELL(gd, c)/x,&RAL_INTEGER_GRID_CELL(gd, c)), RAL_ERRSTR_IOB);
	    }
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_div_integer(ral_grid *gd, RAL_INTEGER x) 
{
    ral_cell c;
    RAL_CHECKM(x != 0, RAL_ERRSTR_DBZ);
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) /= x;
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = (RAL_INTEGER)(RAL_INTEGER_GRID_CELL(gd, c)/x);
    }
    return 1;
 fail:
    return 0;
}


int ral_real_div_grid(RAL_REAL x, ral_grid *gd)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd) {
	    RAL_CHECKM(RAL_REAL_GRID_CELL(gd, c) != 0, RAL_ERRSTR_DBZ);
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) = x / RAL_REAL_GRID_CELL(gd, c);
	}
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
		RAL_CHECKM(RAL_INTEGER_GRID_CELL(gd, c) != 0, RAL_ERRSTR_DBZ);
		RAL_CHECKM(ral_r2i(x/(RAL_REAL)RAL_INTEGER_GRID_CELL(gd, c),&RAL_INTEGER_GRID_CELL(gd, c)), RAL_ERRSTR_IOB);
	    }
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_integer_div_grid(RAL_INTEGER x, ral_grid *gd)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd) {
	    RAL_CHECKM(RAL_REAL_GRID_CELL(gd, c) != 0, RAL_ERRSTR_DBZ);
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) = (RAL_REAL)x / RAL_REAL_GRID_CELL(gd, c);
	}
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
		RAL_CHECKM(RAL_INTEGER_GRID_CELL(gd, c) != 0, RAL_ERRSTR_DBZ);
		RAL_INTEGER_GRID_CELL(gd, c) = (RAL_INTEGER)(x/RAL_INTEGER_GRID_CELL(gd, c));
	    }
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_div_grid(ral_grid *gd1, ral_grid *gd2) 
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c)) {
		RAL_CHECKM(RAL_REAL_GRID_CELL(gd2, c) != 0, RAL_ERRSTR_DBZ);
		RAL_REAL_GRID_CELL(gd1, c) /= RAL_REAL_GRID_CELL(gd2, c);
	    } else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c)) {
		RAL_CHECKM(RAL_INTEGER_GRID_CELL(gd2, c) != 0, RAL_ERRSTR_DBZ);
		RAL_REAL_GRID_CELL(gd1, c) /= RAL_INTEGER_GRID_CELL(gd2, c);
	    } else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c)) {
		RAL_CHECKM(RAL_REAL_GRID_CELL(gd2, c) != 0, RAL_ERRSTR_DBZ);
		RAL_CHECKM(ral_r2i((RAL_REAL)RAL_INTEGER_GRID_CELL(gd1, c)/RAL_REAL_GRID_CELL(gd2, c), &RAL_INTEGER_GRID_CELL(gd1, c)), RAL_ERRSTR_IOB);
	    } else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c)) {
		RAL_CHECKM(RAL_INTEGER_GRID_CELL(gd2, c) != 0, RAL_ERRSTR_DBZ);
		RAL_CHECKM(ral_r2i((RAL_REAL)RAL_INTEGER_GRID_CELL(gd1, c)/(RAL_REAL)RAL_INTEGER_GRID_CELL(gd2, c), &RAL_INTEGER_GRID_CELL(gd1, c)),
		       RAL_ERRSTR_IOB);
	    } else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_modulus_integer(ral_grid *gd, RAL_INTEGER x) 
{
    ral_cell c;
    RAL_CHECKM(x != 0, RAL_ERRSTR_DBZ);
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_FOR(c, gd)
	if (RAL_INTEGER_GRID_DATACELL(gd, c))
	    RAL_INTEGER_GRID_CELL(gd, c) %= x;
    return 1;
 fail:
    return 0;
}


int ral_integer_modulus_grid(RAL_INTEGER x, ral_grid *gd)
{
    ral_cell c;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_FOR(c, gd) {
	if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
	    RAL_CHECKM(RAL_INTEGER_GRID_CELL(gd, c) != 0, RAL_ERRSTR_DBZ);
	    RAL_INTEGER_GRID_CELL(gd, c) = x % RAL_INTEGER_GRID_CELL(gd, c);
	}
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_modulus_grid(ral_grid *gd1, ral_grid *gd2) 
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    RAL_FOR(c, gd1) {
	if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c)) {
	    RAL_CHECKM(RAL_INTEGER_GRID_CELL(gd2, c) != 0, RAL_ERRSTR_DBZ);
	    RAL_INTEGER_GRID_CELL(gd1, c) %= RAL_INTEGER_GRID_CELL(gd2, c);
	} else
	    RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_power_real(ral_grid *gd, RAL_REAL x) 
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) = pow(RAL_REAL_GRID_CELL(gd, c), x);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
		RAL_CHECKM(ral_r2i(pow((RAL_REAL)RAL_INTEGER_GRID_CELL(gd, c), x), &RAL_INTEGER_GRID_CELL(gd, c)), RAL_ERRSTR_IOB);
	    }
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_real_power_grid(RAL_REAL x, ral_grid *gd)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) = pow(x, RAL_REAL_GRID_CELL(gd, c));
	}
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
		RAL_CHECKM(ral_r2i(pow(x, (RAL_REAL)RAL_INTEGER_GRID_CELL(gd, c)), &RAL_INTEGER_GRID_CELL(gd, c)), RAL_ERRSTR_IOB);
	    }
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_power_grid(ral_grid *gd1, ral_grid *gd2) 
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) = pow(RAL_REAL_GRID_CELL(gd1, c), RAL_REAL_GRID_CELL(gd2, c));
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) = pow(RAL_REAL_GRID_CELL(gd1, c), (double)RAL_INTEGER_GRID_CELL(gd2, c));
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c)) {
		RAL_CHECKM(ral_r2i(pow((RAL_REAL)RAL_INTEGER_GRID_CELL(gd1, c), RAL_REAL_GRID_CELL(gd2, c)), &RAL_INTEGER_GRID_CELL(gd1, c)), 
		       RAL_ERRSTR_IOB);
	    } else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c)) {
		RAL_CHECKM(ral_r2i(pow((RAL_REAL)RAL_INTEGER_GRID_CELL(gd1, c), (RAL_REAL)RAL_INTEGER_GRID_CELL(gd2, c)), &RAL_INTEGER_GRID_CELL(gd1, c)), 
		       RAL_ERRSTR_IOB);
	    } else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_abs(ral_grid *gd) 
{
    ral_cell c;
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = abs(RAL_INTEGER_GRID_CELL(gd, c));
    } else if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) = fabs(RAL_REAL_GRID_CELL(gd, c));
    }
    return 1;
}


int ral_grid_acos(ral_grid *gd) 
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = acos(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_atan(ral_grid *gd) 
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = atan(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_atan2(ral_grid *gd1, ral_grid *gd2) 
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECK(ral_grid_coerce(gd1, RAL_REAL_GRID));
    RAL_CHECK(ral_grid_coerce(gd2, RAL_REAL_GRID));
    RAL_FOR(c, gd1) {
	if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
	    RAL_REAL_GRID_CELL(gd1, c) = atan2(RAL_REAL_GRID_CELL(gd1, c),RAL_REAL_GRID_CELL(gd2, c));
	else
	    RAL_REAL_GRID_SETNODATACELL(gd1, c);
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_ceil(ral_grid *gd) 
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = ceil(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_cos(ral_grid *gd) 
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = cos(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_cosh(ral_grid *gd) 
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = cosh(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_exp(ral_grid *gd) 
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = exp(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_floor(ral_grid *gd) 
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = floor(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_log(ral_grid *gd)
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = log(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_log10(ral_grid *gd)
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c)) {
	    double x = RAL_REAL_GRID_CELL(gd, c);
	    RAL_CHECKM(x > 0, RAL_ERRSTR_LOG);
	    RAL_REAL_GRID_CELL(gd, c) = log10(x);
	}
    return 1;
 fail:
    return 0;
}


int ral_grid_pow(ral_grid *gd, RAL_REAL b)
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = pow(RAL_REAL_GRID_CELL(gd, c),b);
    return 1;
 fail:
    return 0;
}


int ral_grid_sin(ral_grid *gd)
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = sin(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_sinh(ral_grid *gd)
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = sinh(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_sqrt(ral_grid *gd)
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = sqrt(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_tan(ral_grid *gd)
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = tan(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_tanh(ral_grid *gd)
{
    ral_cell c;
    RAL_CHECK(ral_grid_coerce(gd, RAL_REAL_GRID));
    RAL_FOR(c, gd)
	if (RAL_REAL_GRID_DATACELL(gd, c))
	    RAL_REAL_GRID_CELL(gd, c) = tanh(RAL_REAL_GRID_CELL(gd, c));
    return 1;
 fail:
    return 0;
}


int ral_grid_lt_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
        RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) < x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
        RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) < i;
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_lt_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
        RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) < x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
        RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) < i;

    }
    return 1;
 fail:
    return 0;
}


int ral_grid_gt_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) > x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
	RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) > i;
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_gt_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) > x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
	RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) > i;
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_le_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
        RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) <= x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
        RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
        RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) <= i;

    }
    return 1;
 fail:
    return 0;
}


int ral_grid_le_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
        RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) <= x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
        RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
        RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) <= i;

    }
    return 1;
 fail:
    return 0;
}


int ral_grid_ge_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
        RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) >= x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
        RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
        RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) >= i;

    }
    return 1;
 fail:
    return 0;
}


int ral_grid_ge_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
        RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) >= x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
        RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
        RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) >= i;

    }
    return 1;
 fail:
    return 0;
}


int ral_grid_eq_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
        RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) == x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
        RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
        RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) == i;

    }
    return 1;
 fail:
    return 0;
}


int ral_grid_eq_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
        RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) == x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
        RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
        RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) == i;

    }
    return 1;
 fail:
    return 0;
}


int ral_grid_ne_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
        RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) != x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
        RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
        RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) != i;
	}

    }
    return 1;
 fail:
    return 0;
}


int ral_grid_ne_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
        RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) != x;
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
        RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
        RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) != i;
	}
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_cmp_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) > x ? 1 : (RAL_REAL_GRID_CELL(gd, c) == x ? 0 : -1);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
	RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) > i ? 1 : (RAL_INTEGER_GRID_CELL(gd, c) == i ? 0 : -1);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_cmp_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, c) > x ? 1 : (RAL_REAL_GRID_CELL(gd, c) == x ? 0 : -1);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd, g);
	ral_grid_destroy(&g);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
	RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = RAL_INTEGER_GRID_CELL(gd, c) > i ? 1 : (RAL_INTEGER_GRID_CELL(gd, c) == i ? 0 : -1);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_lt_grid(ral_grid *gd1, ral_grid *gd2)
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) < RAL_REAL_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) < RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) < round(RAL_REAL_GRID_CELL(gd2, c));
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) < RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_gt_grid(ral_grid *gd1, ral_grid *gd2) 
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) > RAL_REAL_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) > RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) > round(RAL_REAL_GRID_CELL(gd2, c));
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) > RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_le_grid(ral_grid *gd1, ral_grid *gd2) 
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) <= RAL_REAL_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) <= RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) <= round(RAL_REAL_GRID_CELL(gd2, c));
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) <= RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_ge_grid(ral_grid *gd1, ral_grid *gd2) 
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) >= RAL_REAL_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) >= RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) >= round(RAL_REAL_GRID_CELL(gd2, c));
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) >= RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_eq_grid(ral_grid *gd1, ral_grid *gd2)
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) == RAL_REAL_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) == RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) == round(RAL_REAL_GRID_CELL(gd2, c));
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) == RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_ne_grid(ral_grid *gd1, ral_grid *gd2)
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) != RAL_REAL_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) != RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) != round(RAL_REAL_GRID_CELL(gd2, c));
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) != RAL_INTEGER_GRID_CELL(gd2, c);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_cmp_grid(ral_grid *gd1, ral_grid *gd2)
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) > RAL_REAL_GRID_CELL(gd2, c) ? 
		    1 : (RAL_REAL_GRID_CELL(gd1, c) == RAL_REAL_GRID_CELL(gd2, c) ? 0 : -1);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	ral_grid *g = ral_grid_create_like(gd1, RAL_INTEGER_GRID);
	RAL_CHECK(g);
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd1, c) > RAL_INTEGER_GRID_CELL(gd2, c) ? 
		    1 : (RAL_REAL_GRID_CELL(gd1, c) == RAL_INTEGER_GRID_CELL(gd2, c) ? 0 : -1);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(g, c);
	}
	ral_grid_steal_data(gd1, g);
	ral_grid_destroy(&g);
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) > round(RAL_REAL_GRID_CELL(gd2, c)) ? 
		    1 : (RAL_INTEGER_GRID_CELL(gd1, c) == round(RAL_REAL_GRID_CELL(gd2, c)) ? 0 : -1);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = RAL_INTEGER_GRID_CELL(gd1, c) > RAL_INTEGER_GRID_CELL(gd2, c) ? 
		    1 : (RAL_INTEGER_GRID_CELL(gd1, c) == RAL_INTEGER_GRID_CELL(gd2, c) ? 0 : -1);
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_min_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) = min(RAL_REAL_GRID_CELL(gd, c), x);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = min(RAL_INTEGER_GRID_CELL(gd, c), i);
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_min_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) = min(RAL_REAL_GRID_CELL(gd, c), x);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = min(RAL_INTEGER_GRID_CELL(gd, c), x);
    } 
    return 1;
}


int ral_grid_max_real(ral_grid *gd, RAL_REAL x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) = max(RAL_REAL_GRID_CELL(gd, c), x);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = max(RAL_INTEGER_GRID_CELL(gd, c), i);
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_max_integer(ral_grid *gd, RAL_INTEGER x)
{
    ral_cell c;
    if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		RAL_REAL_GRID_CELL(gd, c) = max(RAL_REAL_GRID_CELL(gd, c), x);
    } else if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(x, &i), RAL_ERRSTR_IOB);
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		RAL_INTEGER_GRID_CELL(gd, c) = max(RAL_INTEGER_GRID_CELL(gd, c), i);
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_min_grid(ral_grid *gd1, ral_grid *gd2)
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) = min(RAL_REAL_GRID_CELL(gd1, c),RAL_REAL_GRID_CELL(gd2, c));
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) = min(RAL_REAL_GRID_CELL(gd1, c),RAL_INTEGER_GRID_CELL(gd2, c));
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = min(RAL_INTEGER_GRID_CELL(gd1, c),round(RAL_REAL_GRID_CELL(gd2, c)));
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = min(RAL_INTEGER_GRID_CELL(gd1, c),RAL_INTEGER_GRID_CELL(gd2, c));
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


int ral_grid_max_grid(ral_grid *gd1, ral_grid *gd2)
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(gd1, gd2), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) = max(RAL_REAL_GRID_CELL(gd1, c),RAL_REAL_GRID_CELL(gd2, c));
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_REAL_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_REAL_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_REAL_GRID_CELL(gd1, c) = max(RAL_REAL_GRID_CELL(gd1, c),RAL_INTEGER_GRID_CELL(gd2, c));
	    else
		RAL_REAL_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_REAL_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = max(RAL_INTEGER_GRID_CELL(gd1, c),round(RAL_REAL_GRID_CELL(gd2, c)));
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } else if (gd1->datatype == RAL_INTEGER_GRID AND gd2->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd1) {
	    if (RAL_INTEGER_GRID_DATACELL(gd1, c) AND RAL_INTEGER_GRID_DATACELL(gd2, c))
		RAL_INTEGER_GRID_CELL(gd1, c) = max(RAL_INTEGER_GRID_CELL(gd1, c),RAL_INTEGER_GRID_CELL(gd2, c));
	    else
		RAL_INTEGER_GRID_SETNODATACELL(gd1, c);
	}
    } 
    return 1;
 fail:
    return 0;
}


void RAL_CALL ral_grid_random(ral_grid *gd)
{
    if (gd->datatype == RAL_INTEGER_GRID) {
	ral_cell c;
	RAL_FOR(c, gd) {
	    /* from i randomly to 0..i */
	    double p = rand()/((double)RAND_MAX+1);
	    RAL_INTEGER_GRID_CELL(gd, c) = (int)(p*(RAL_INTEGER_GRID_CELL(gd, c)+1));
	}
    } else {
	ral_cell c;
	RAL_FOR(c, gd) {
	    /* from x randomly to [0..x] */
	    double p = rand()/((double)RAND_MAX);
	    RAL_REAL_GRID_CELL(gd, c) = p*RAL_REAL_GRID_CELL(gd, c);
	}
    }
}


int ral_cmp_integer(const void *a, const void *b)
{
    if (*(RAL_INTEGER *)a < *(RAL_INTEGER *)b) return -1;
    if (*(RAL_INTEGER *)a > *(RAL_INTEGER *)b) return 1;
    return 0;
}

ral_grid *ral_grid_cross(ral_grid *a, ral_grid *b)
{
    ral_grid *c = NULL;
    ral_cell p;
    ral_hash *atable = NULL, *btable = NULL;
    RAL_INTEGER *ca = NULL, *cb = NULL;
    int na, nb;
    RAL_CHECKM((a->datatype == RAL_INTEGER_GRID) AND (b->datatype == RAL_INTEGER_GRID), RAL_ERRSTR_ARGS_INTEGER);
    RAL_CHECKM(ral_grid_overlayable(a, b), RAL_ERRSTR_ARGS_OVERLAYABLE);

    RAL_CHECK(atable = ral_grid_contents(a));
    RAL_CHECK(btable = ral_grid_contents(b));
    RAL_CHECK(ca = ral_hash_keys(atable, &na));
    RAL_CHECK(cb = ral_hash_keys(btable, &nb));
    RAL_CHECK(c = ral_grid_create_like(a, RAL_INTEGER_GRID));
    qsort(ca, na, sizeof(RAL_INTEGER), &ral_cmp_integer);
    qsort(cb, nb, sizeof(RAL_INTEGER), &ral_cmp_integer);
    RAL_FOR(p, a) {
	if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_DATACELL(b, p)) {
	    int ia = 0, ib = 0;
	    while (ia < na AND ca[ia] != RAL_INTEGER_GRID_CELL(a, p)) ia++;
	    while (ib < nb AND cb[ib] != RAL_INTEGER_GRID_CELL(b, p)) ib++;
	    RAL_INTEGER_GRID_CELL(c, p) = ib + ia*na + 1;
	} else 
	    RAL_INTEGER_GRID_SETNODATACELL(c, p);
    }
 fail:
    ral_hash_destroy(&atable);
    ral_hash_destroy(&btable);
    if (ca) free(ca);
    if (cb) free(cb);
    return c;
}


/* if a then b = c */
int ral_grid_if_then_real(ral_grid *a, ral_grid *b, RAL_REAL c)
{
    ral_cell p;
    RAL_CHECKM(a->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ONLY_INT_IS_BOOLEAN);
    RAL_CHECKM(ral_grid_overlayable(a, b), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (b->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(c, &i), RAL_ERRSTR_IOB);
	RAL_FOR(p, a)
	    if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_CELL(a, p)) RAL_INTEGER_GRID_CELL(b, p) = i;
    } else if (b->datatype == RAL_REAL_GRID) {
	RAL_FOR(p, a)
	    if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_CELL(a, p)) RAL_REAL_GRID_CELL(b, p) = c;
    
    }
    return 1;
 fail:
    return 0;
}

int ral_grid_if_then_integer(ral_grid *a, ral_grid *b, RAL_INTEGER c)
{
    ral_cell p;
    RAL_CHECKM(a->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ONLY_INT_IS_BOOLEAN);
    RAL_CHECKM(ral_grid_overlayable(a, b), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (b->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER i;
	RAL_CHECKM(ral_r2i(c, &i), RAL_ERRSTR_IOB);
	RAL_FOR(p, a)
	    if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_CELL(a, p)) RAL_INTEGER_GRID_CELL(b, p) = i;
    } else if (b->datatype == RAL_REAL_GRID) {
	RAL_FOR(p, a)
	    if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_CELL(a, p)) RAL_REAL_GRID_CELL(b, p) = c;
    
    }
    return 1;
 fail:
    return 0;
}

/* if a then b = c else b = d */
int ral_grid_if_then_else_real(ral_grid *a, ral_grid *b, RAL_REAL c, RAL_REAL d)
{
    ral_cell p;
    RAL_CHECKM(a->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ONLY_INT_IS_BOOLEAN);
    RAL_CHECKM(ral_grid_overlayable(a, b), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (b->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER x,y;
	RAL_CHECKM(ral_r2i(c, &x), RAL_ERRSTR_IOB);
	RAL_CHECKM(ral_r2i(d, &y), RAL_ERRSTR_IOB);
	RAL_FOR(p, a) {
	    if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_CELL(a, p)) {
		RAL_INTEGER_GRID_CELL(b, p) = x;
	    } else {
		RAL_INTEGER_GRID_CELL(b, p) = y;
	    }
	}
    } else if (b->datatype == RAL_REAL_GRID) {
	RAL_FOR(p, a) {
	    if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_CELL(a, p)) {
		RAL_REAL_GRID_CELL(b, p) = c;
	    } else {
		RAL_REAL_GRID_CELL(b, p) = d;
	    }
	}
    
    }
    return 1;
 fail:
    return 0;
}

int ral_grid_if_then_else_integer(ral_grid *a, ral_grid *b, RAL_INTEGER c, RAL_INTEGER d)
{
    ral_cell p;
    RAL_CHECKM(a->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ONLY_INT_IS_BOOLEAN);
    RAL_CHECKM(ral_grid_overlayable(a, b), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (b->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER x,y;
	RAL_CHECKM(ral_r2i(c, &x), RAL_ERRSTR_IOB);
	RAL_CHECKM(ral_r2i(d, &y), RAL_ERRSTR_IOB);
	RAL_FOR(p, a) {
	    if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_CELL(a, p)) {
		RAL_INTEGER_GRID_CELL(b, p) = x;
	    } else {
		RAL_INTEGER_GRID_CELL(b, p) = y;
	    }
	}
    } else if (b->datatype == RAL_REAL_GRID) {
	RAL_FOR(p, a) {
	    if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_CELL(a, p)) {
		RAL_REAL_GRID_CELL(b, p) = c;
	    } else {
		RAL_REAL_GRID_CELL(b, p) = d;
	    }
	}
    
    }
    return 1;
 fail:
    return 0;
}

/* if a then b = c */
int ral_grid_if_then_grid(ral_grid *a, ral_grid *b, ral_grid *c)
{
    ral_cell p;
    RAL_CHECKM(a->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ONLY_INT_IS_BOOLEAN);
    RAL_CHECKM(ral_grid_overlayable(a, b) AND ral_grid_overlayable(a, c), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (b->datatype == RAL_INTEGER_GRID) {
	if (c->datatype == RAL_INTEGER_GRID) {
	    RAL_FOR(p, a)
		if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_DATACELL(c, p) AND RAL_INTEGER_GRID_CELL(a, p)) 
		    RAL_INTEGER_GRID_CELL(b, p) = RAL_INTEGER_GRID_CELL(c, p);
	} else if (c->datatype == RAL_REAL_GRID) {
	    RAL_FOR(p, a) {
		if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_REAL_GRID_DATACELL(c, p) AND RAL_INTEGER_GRID_CELL(a, p)) {
		    RAL_CHECKM(ral_r2i(RAL_REAL_GRID_CELL(c, p), &RAL_INTEGER_GRID_CELL(b, p)), RAL_ERRSTR_IOB);
		}
	    }
	} else {
	    RAL_CHECKM(0, RAL_ERRSTR_DATATYPE);
	}
    } else if (b->datatype == RAL_REAL_GRID) {
	if (c->datatype == RAL_INTEGER_GRID) {
	    RAL_FOR(p, a)
		if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_INTEGER_GRID_DATACELL(c, p) AND RAL_INTEGER_GRID_CELL(a, p)) 
		    RAL_REAL_GRID_CELL(b, p) = RAL_INTEGER_GRID_CELL(c, p);
	} else if (c->datatype == RAL_REAL_GRID) {
	    RAL_FOR(p, a)
		if (RAL_INTEGER_GRID_DATACELL(a, p) AND RAL_REAL_GRID_DATACELL(c, p) AND RAL_INTEGER_GRID_CELL(a, p)) 
		    RAL_REAL_GRID_CELL(b, p) = RAL_REAL_GRID_CELL(c, p);
	} else {
	    RAL_CHECKM(0, RAL_ERRSTR_DATATYPE);
	}
    
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_zonal_if_then_real(ral_grid *a, ral_grid *b, RAL_INTEGER *k, RAL_REAL *v, int n)
{
    ral_cell p;
    RAL_CHECKM(a->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ZONING_INTEGER);
    RAL_CHECKM(ral_grid_overlayable(a, b), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (b->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(p, a) {
	    int i = 0;
	    if (RAL_INTEGER_GRID_NODATACELL(a, p)) continue;
	    while (i < n AND k[i] != RAL_INTEGER_GRID_CELL(a, p)) i++;
	    if (i == n)
		continue;
	    RAL_CHECKM(ral_r2i(v[i], &RAL_INTEGER_GRID_CELL(b, p)), RAL_ERRSTR_IOB);
	}
    } else if (b->datatype == RAL_REAL_GRID) {
	RAL_FOR(p, a) {
	    int i = 0;
	    if (RAL_INTEGER_GRID_NODATACELL(a, p)) continue;
	    while (i < n AND k[i] != RAL_INTEGER_GRID_CELL(a, p)) i++;
	    if (i == n)
		continue;
	    RAL_REAL_GRID_CELL(b, p) = v[i];
	}
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_zonal_if_then_integer(ral_grid *a, ral_grid *b, RAL_INTEGER *k, RAL_INTEGER *v, int n)
{
    ral_cell p;
    RAL_CHECKM(a->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ZONING_INTEGER);
    RAL_CHECKM(ral_grid_overlayable(a, b), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (b->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(p, a) {
	    int i = 0;
	    if (RAL_INTEGER_GRID_NODATACELL(a, p)) continue;
	    while (i < n AND k[i] != RAL_INTEGER_GRID_CELL(a, p)) i++;
	    if (i == n)
		continue;
	    RAL_INTEGER_GRID_CELL(b, p) = v[i];
	}
    } else if (b->datatype == RAL_REAL_GRID) {
	RAL_FOR(p, a) {
	    int i = 0;
	    if (RAL_INTEGER_GRID_NODATACELL(a, p)) continue;
	    while (i < n AND k[i] != RAL_INTEGER_GRID_CELL(a, p)) i++;
	    if (i == n)
		continue;
	    RAL_REAL_GRID_CELL(b, p) = v[i];
	}
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_apply_templ(ral_grid *gd, int *templ, int new_val)
{
    int matches = 0;
    ral_cell c;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_FOR(c, gd) {
	/* go through the 3x3 neighborhood 
	   in a bit different way than what's usual here */
	ral_cell a = c;
	int match = 1;

	while (1) { /* the intention is not to loop 
		       but break out in the middle */
	    /* 0 */
	    a.i--;
	    a.j--;
	    if (templ[0] >= 0) {
		if (a.i < 0 OR a.j < 0) 
		    match = templ[0] == 0; /* we assume outside is 0 */
		else 
		    match = (templ[0] AND RAL_INTEGER_GRID_CELL(gd, a)) OR 
			(!templ[0] AND !RAL_INTEGER_GRID_CELL(gd, a));
		if (!match) break;	  
	    }
	    /* 1 */
	    a.j++;
	    if (templ[1] >= 0) {
		if (a.i < 0) 
		    match = templ[1] == 0; 
		else 
		    match = (templ[1] AND RAL_INTEGER_GRID_CELL(gd, a)) OR 
			(!templ[1] AND !RAL_INTEGER_GRID_CELL(gd, a));
		if (!match) break;	  
	    }
	    /* 2 */
	    a.j++;
	    if (templ[2] >= 0) {
		if (a.i < 0 OR a.j == gd->N) 
		    match = templ[2] == 0; 
		else 
		    match = (templ[2] AND RAL_INTEGER_GRID_CELL(gd, a)) OR 
			(!templ[2] AND !RAL_INTEGER_GRID_CELL(gd, a));
		if (!match) break;	  
	    }
	    /* 3 */
	    a.i++;
	    a.j-=2;
	    if (templ[3] >= 0) {	    
		if (a.j < 0) 
		    match = templ[3] == 0; 
		else 
		    match = (templ[3] AND RAL_INTEGER_GRID_CELL(gd, a)) OR 
			(!templ[3] AND !RAL_INTEGER_GRID_CELL(gd, a));
		if (!match) break;	  
	    }
	    /* 4 */
	    a.j++;
	    if (templ[4] >= 0) {
		match = (templ[4] AND RAL_INTEGER_GRID_CELL(gd, a)) OR 
		    (!templ[4] AND !RAL_INTEGER_GRID_CELL(gd, a));
		if (!match) break;	  
	    }
	    /* 5 */
	    a.j++;
	    if (templ[5] >= 0) {
		if (a.j == gd->N) 
		    match = templ[5] == 0; 
		else 
		    match = (templ[5] AND RAL_INTEGER_GRID_CELL(gd, a)) OR 
			(!templ[5] AND !RAL_INTEGER_GRID_CELL(gd, a));
		if (!match) break;	  
	    }
	    /* 6 */	  
	    a.i++;
	    a.j-=2;
	    if (templ[6] >= 0) {
		if (a.i == gd->M OR a.j < 0) 
		    match = templ[6] == 0; 
		else 
		    match = (templ[6] AND RAL_INTEGER_GRID_CELL(gd, a)) OR 
			(!templ[6] AND !RAL_INTEGER_GRID_CELL(gd, a));
		if (!match) break;	  
	    }
	    /* 7 */
	    a.j++;
	    if (templ[7] >= 0) {
		if (a.i == gd->M) 
		    match = templ[7] == 0; 
		else 
		    match = (templ[7] AND RAL_INTEGER_GRID_CELL(gd, a)) OR 
			(!templ[7] AND !RAL_INTEGER_GRID_CELL(gd, a));
		if (!match) break;	  
	    }
	    /* 8 */
	    a.j++;
	    if (templ[8] >= 0) {
		if (a.i == gd->M OR a.j == gd->N) 
		    match = templ[8] == 0; 
		else 
		    match = (templ[8] AND RAL_INTEGER_GRID_CELL(gd, a)) OR 
			(!templ[8] AND !RAL_INTEGER_GRID_CELL(gd, a));
		if (!match) break;	  
	    }
	    break;
	}
	if (match) {
	    RAL_INTEGER_GRID_CELL(gd, c) = 2;
	    matches++;
	}
    }
    RAL_FOR(c, gd) 
	if (RAL_INTEGER_GRID_CELL(gd, c) > 1) RAL_INTEGER_GRID_CELL(gd, c) = new_val;
    return matches;
fail:
    return -1;
}


ral_grid *ral_grid_ca_step(ral_grid *gd, void *k)
{
    ral_grid *g = NULL;
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER *a = (RAL_INTEGER *)k;
	ral_cell c;
	RAL_CHECK(g = ral_grid_create_like(gd, RAL_INTEGER_GRID));
	RAL_FOR(c, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
		RAL_INTEGER result = a[0]*RAL_INTEGER_GRID_CELL(gd, c);
		int dir;
		RAL_DIRECTIONS(dir) {
		    ral_cell d = ral_cell_move(c, dir);
		    if (RAL_GRID_CELL_IN(gd, d) AND RAL_INTEGER_GRID_DATACELL(gd, d))
			result += a[dir]*RAL_INTEGER_GRID_CELL(gd, d);
		}
		RAL_INTEGER_GRID_CELL(g, c) = result;
	    }
	}
    } else {
	RAL_REAL *a = (RAL_REAL *)k;
	ral_cell c;
	RAL_CHECK(g = ral_grid_create_like(gd, RAL_REAL_GRID));
	RAL_FOR(c, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, c)) {
		RAL_REAL result = a[0]*RAL_REAL_GRID_CELL(gd, c);
		int dir;
		RAL_DIRECTIONS(dir) {
		    ral_cell d = ral_cell_move(c, dir);
		    if (RAL_GRID_CELL_IN(gd, d) AND RAL_REAL_GRID_DATACELL(gd, d))
			result += a[dir]*RAL_REAL_GRID_CELL(gd, d);
		}
		RAL_REAL_GRID_CELL(g, c) = result;
	    }
	}
    }
    return g;
 fail:
    ral_grid_destroy(&g);
    return NULL;
}


int ral_grid_map(ral_grid *gd, int *s, int *d, int n)
{
    ral_cell c;
    int i;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_FOR(c, gd) {
	for (i = 0; i < n; i++) {
	    if (s[i] > RAL_INTEGER_GRID_CELL(gd, c))
		break;
	    else if (s[i] == RAL_INTEGER_GRID_CELL(gd, c)) {
		RAL_INTEGER_GRID_CELL(gd, c) = d[i];
		break;
	    }
	}
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_map_integer_grid(ral_grid *gd, int *s_min, int *s_max, int *d, int n, int *deflt)
{
    ral_cell c;
    int i;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_FOR(c, gd) {
	int match = 0;
	for (i = 0; i < n; i++) {
	    if (s_min[i] > RAL_INTEGER_GRID_CELL(gd, c))
		break;
	    else if (s_min[i] <= RAL_INTEGER_GRID_CELL(gd, c) AND s_max[i] > RAL_INTEGER_GRID_CELL(gd, c)) {
		RAL_INTEGER_GRID_CELL(gd, c) = d[i];
		match = 1;
		break;
	    }
	}
	if (!match AND deflt)
	    RAL_INTEGER_GRID_CELL(gd, c) = *deflt;
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_map_real_grid(ral_grid *gd, double *s_min, double *s_max, double *d, int n, double *deflt)
{
    ral_cell c;
    int i;
    RAL_CHECKM(gd->datatype == RAL_REAL_GRID, RAL_ERRSTR_ARG_REAL);
    RAL_FOR(c, gd) {
	int match = 0;
	for (i = 0; i < n; i++) {
	    if (s_min[i] > RAL_REAL_GRID_CELL(gd, c))
		break;
	    else if (s_min[i] <= RAL_REAL_GRID_CELL(gd, c) AND s_max[i] > RAL_REAL_GRID_CELL(gd, c)) {
		RAL_REAL_GRID_CELL(gd, c) = d[i];
		match = 1;
		break;
	    }
	}
	if (!match AND deflt)
	    RAL_REAL_GRID_CELL(gd, c) = *deflt;
    }
    return 1;
 fail:
    return 0;
}


void ral_integer_grid_reclassify(ral_grid *gd, ral_hash *h)
{
    ral_cell c;
    RAL_FOR(c, gd) {
	if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
	    RAL_INTEGER *y;
	    RAL_HASH_LOOKUP(h, RAL_INTEGER_GRID_CELL(gd, c), &y, ral_hash_integer_item);
	    if (y)
		RAL_INTEGER_GRID_CELL(gd, c) = *y;
	}
    }
}


ral_grid *ral_real_grid_reclassify(ral_grid *gd, RAL_REAL *x, RAL_INTEGER *y, int n)
{
    ral_cell c;
    ral_grid *g;
    RAL_CHECK(g = ral_grid_create_like(gd, RAL_INTEGER_GRID));
    RAL_FOR(c, gd) {
	if (RAL_REAL_GRID_DATACELL(gd, c)) {
	    RAL_REAL v = RAL_REAL_GRID_DATACELL(gd, c);
	    int i = 0;
	    while (v > x[i] AND i < n - 1 )
		i++;
	    RAL_INTEGER_GRID_CELL(g, c) = y[i];
	} else
	    RAL_INTEGER_GRID_SETNODATACELL(g, c);
    }
 fail:
    ral_grid_destroy(&g);
    return NULL;
}


int ral_grid_zonesize_internal(ral_grid *gd, ral_grid *visited, ral_cell c, int color, int connectivity)
{
    int lastBorder;
    int leftLimit, rightLimit;
    int i2;
    int size = 0;
    if (RAL_INTEGER_GRID_CELL(gd, c) != color) return 0;
    /* Seek left */
    leftLimit = -1;
    for (i2 = c.i; i2 >= 0; i2--) {
	if (RAL_INTEGER_GRID_AT(gd, i2, c.j) != color) break;
	size++;
	RAL_INTEGER_GRID_AT(visited, i2, c.j) = 1;
	if (connectivity == 8)
	    leftLimit = max(0,i2-1);
	else
	    leftLimit = i2;
    }
    if (leftLimit == -1) return 1;
    /* Seek right */
    if (connectivity == 8)
	rightLimit = min(gd->M-1,c.i+1);
    else
	rightLimit = c.i;
    for (i2 = c.i+1; i2 < gd->M; i2++) {	
	if (RAL_INTEGER_GRID_AT(gd, i2, c.j) != color) break;
	size++;
	RAL_INTEGER_GRID_AT(visited, i2, c.j) = 1;
	if (connectivity == 8)
	    rightLimit = min(gd->M-1,i2+1);
	else
	    rightLimit = i2;
    }
    /* Look at lines above and below */
    /* Above */
    if (c.j > 0) {
	ral_cell c2;
	c2.j = c.j-1;
	lastBorder = 1;
	for (c2.i = leftLimit; c2.i <= rightLimit; c2.i++) {
	    int a;
	    a = RAL_INTEGER_GRID_CELL(gd, c2);
	    if (lastBorder) {
		if (a == color) {	
		    if (!RAL_INTEGER_GRID_CELL(visited, c2))
			size += ral_grid_zonesize_internal(gd, visited, c2, color, connectivity);
		    lastBorder = 0;
		}
	    } else if (a != color)
		lastBorder = 1;
	}
    }
    /* Below */
    if (c.j < gd->N - 1) {
	ral_cell c2;
	c2.j = c.j+1;
	lastBorder = 1;
	for (c2.i = leftLimit; c2.i <= rightLimit; c2.i++) {
	    int a;
	    a = RAL_INTEGER_GRID_CELL(gd, c2);
	    if (lastBorder) {
		if (a == color) {
		    if (!RAL_INTEGER_GRID_CELL(visited, c2))
			size += ral_grid_zonesize_internal(gd, visited, c2, color, connectivity);
		    lastBorder = 0;
		}
	    } else if (a != color)
		lastBorder = 1;
	}
    }
    return size;
}


int ral_grid_rzonesize_internal(ral_grid *gd, ral_grid *visited, ral_cell c, RAL_REAL color, int connectivity)
{
    int lastBorder;
    int leftLimit, rightLimit;
    int i2;
    int size = 0;
    if (RAL_REAL_GRID_CELL(gd, c) != color) return 0;
    /* Seek left */
    leftLimit = -1;
    for (i2 = c.i; i2 >= 0; i2--) {
	if (RAL_REAL_GRID_AT(gd, i2, c.j) != color) break;
	size++;
	RAL_INTEGER_GRID_AT(visited, i2, c.j) = 1;
	if (connectivity == 8)
	    leftLimit = max(0,i2-1);
	else
	    leftLimit = i2;
    }
    if (leftLimit == -1) return 1;
    /* Seek right */
    if (connectivity == 8)
	rightLimit = min(gd->M-1,c.i+1);
    else
	rightLimit = c.i;
    for (i2 = c.i+1; i2 < gd->M; i2++) {	
	if (RAL_REAL_GRID_AT(gd, i2, c.j) != color) break;
	size++;
	RAL_INTEGER_GRID_AT(visited, i2, c.j) = 1;
	if (connectivity == 8)
	    rightLimit = min(gd->M-1,i2+1);
	else
	    rightLimit = i2;
    }
    /* Look at lines above and below */
    /* Above */
    if (c.j > 0) {
	ral_cell c2;
	c2.j = c.j-1;
	lastBorder = 1;
	for (c2.i = leftLimit; c2.i <= rightLimit; c2.i++) {
	    int a;
	    a = RAL_REAL_GRID_CELL(gd, c2);
	    if (lastBorder) {
		if (a == color) {
		    if (!RAL_INTEGER_GRID_CELL(visited, c2))
			size += ral_grid_rzonesize_internal(gd, visited, c2, color, connectivity);
		    lastBorder = 0;
		}
	    } else if (a != color)
		lastBorder = 1;
	}
    }
    /* Below */
    if (c.j < gd->N - 1) {
	ral_cell c2;
	c2.j = c.j+1;
	lastBorder = 1;
	for (c2.i = leftLimit; c2.i <= rightLimit; c2.i++) {
	    int a;
	    a = RAL_REAL_GRID_CELL(gd, c2);
	    if (lastBorder) {
		if (a == color) {
		    if (!RAL_INTEGER_GRID_CELL(visited, c2))
			size += ral_grid_rzonesize_internal(gd, visited, c2, color, connectivity);
		    lastBorder = 0;
		}
	    } else if (a != color)
		lastBorder = 1;
	}
    }
    return size;
}


double ral_grid_zonesize(ral_grid *gd, ral_cell c)
{
    ral_grid *visited = NULL;
    double size = 0;
    RAL_CHECKM(RAL_GRID_CELL_IN(gd, c), RAL_ERRSTR_COB);
    RAL_CHECK(visited = ral_grid_create_like(gd, RAL_INTEGER_GRID));
    if (gd->datatype == RAL_INTEGER_GRID) {
	size = gd->cell_size*gd->cell_size*
	    (double)ral_grid_zonesize_internal(gd, visited, c, RAL_INTEGER_GRID_CELL(gd, c), 8);
    } else if (gd->datatype == RAL_REAL_GRID) {
	size = gd->cell_size*gd->cell_size*
	    (double)ral_grid_rzonesize_internal(gd, visited, c, RAL_REAL_GRID_CELL(gd, c), 8);
    } else {
	RAL_CHECKM(0, RAL_ERRSTR_DATATYPE);
    }
    ral_grid_destroy(&visited);
    return size;
 fail:
    ral_grid_destroy(&visited);
    return 0;
}


ral_grid *ral_grid_borders(ral_grid *gd)
{
    ral_grid *borders;
    ral_cell c;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    if (!(borders = ral_grid_create_copy(gd, RAL_INTEGER_GRID))) return NULL;
    for (c.i = 0; c.i < gd->M; c.i++) {
	int j0 = 0;
	int on = RAL_INTEGER_GRID_AT(gd, c.i, 0);
	for (c.j = 0; c.j < gd->N; c.j++)
	    if (!gd->mask OR (RAL_GRID_CELL_IN(gd->mask, (c)) AND RAL_INTEGER_GRID_CELL(gd->mask, (c)))) {
		if (!RAL_INTEGER_GRID_CELL(gd, c)) {
		    if (on) {
			if ((c.i > 0) AND (c.i < gd->M)) {
			    int jc;
			    for (jc = j0+1; jc < c.j-1; jc++) {
				if (RAL_INTEGER_GRID_AT(gd,c.i-1,jc) AND RAL_INTEGER_GRID_AT(gd,c.i+1,jc)) 
				    RAL_INTEGER_GRID_AT(borders,c.i,jc) = 0;
			    }
			}
			on = 0;
		    }
		} else if (!on) {
		    on = 1;
		    j0 = c.j;
		}
	    }
	if (on) {
		if ((c.i > 0) AND (c.i < gd->M)) {
		    int jc;
		    for (jc = j0+1; jc < c.j-1; jc++) {
			if (RAL_INTEGER_GRID_AT(gd,c.i-1,jc) AND RAL_INTEGER_GRID_AT(gd,c.i+1,jc)) 
			    RAL_INTEGER_GRID_AT(borders,c.i,jc) = 0;
		    }
		}
	}
    }
    return borders;
 fail:
    return NULL;
}


void ral_grid_mark_borders(ral_grid *gd, ral_cell c, ral_grid *visited, ral_grid *borders)
{
    int paint = RAL_INTEGER_GRID_CELL(gd, c);
    int d;

    RAL_INTEGER_GRID_CELL(visited, c) = 1;
    for (d = 0; d < 9; d++) {
	ral_cell t = ral_cell_move(c, d);
	if (RAL_GRID_CELL_IN(gd, t)) {
	    if (RAL_INTEGER_GRID_CELL(gd, t) != paint)
		RAL_INTEGER_GRID_CELL(borders, c) = paint;
	    else if (!RAL_INTEGER_GRID_CELL(visited, t))
		ral_grid_mark_borders(gd, t, visited, borders);
	} else 
	    RAL_INTEGER_GRID_CELL(borders, c) = paint;
    }
}


ral_grid *ral_grid_borders_recursive(ral_grid *gd)
{
    ral_grid *borders, *visited;
    ral_cell c;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    if (!(borders = ral_grid_create_like(gd, RAL_INTEGER_GRID))) return NULL;
    if (!(visited = ral_grid_create_like(gd, RAL_INTEGER_GRID))) {
	ral_grid_destroy(&borders);
	return NULL;
    }
    RAL_FOR(c, gd)
	if (RAL_INTEGER_GRID_CELL(gd, c) AND !RAL_INTEGER_GRID_CELL(visited, c))
	    ral_grid_mark_borders(gd, c, visited, borders);
    ral_grid_destroy(&visited);
    return borders;
fail:
    return NULL;
}


ral_grid *ral_grid_areas(ral_grid *gd, int k)
{
    ral_grid *areas;
    ral_cell c;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    if (!(areas = ral_grid_create_like(gd, RAL_INTEGER_GRID))) return NULL;
    RAL_FOR(c, gd) {
	/* ral_cell is part of an area 
	   if there is at least 
	   k consecutive nonzero cells as neighbors */
	int r, d, co = 0, cm = 0;
	if (!RAL_INTEGER_GRID_CELL(gd, c) OR RAL_INTEGER_GRID_NODATACELL(gd, c)) continue;
	for (r = 0; r < 2; r++) {
	    for (d = 1; d < 9; d++) {
		ral_cell x = ral_cell_move(c, d);
		if (RAL_GRID_CELL_IN(gd, x) AND RAL_INTEGER_GRID_CELL(gd, x))
		    co++;
		else {
		    if (co > cm) cm = co;
		    co = 0;
		}
	    }
	}
	if (co > cm) cm = co;
	if (cm >= k) RAL_INTEGER_GRID_CELL(areas, c) = RAL_INTEGER_GRID_CELL(gd, c);
    }
    return areas;
 fail:
    return NULL;
}


int ral_grid_connect(ral_grid *gd)
{
    ral_cell c;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_FOR(c, gd) {
	/* connect within 3x3 mask */
	if (RAL_INTEGER_GRID_CELL(gd, c)) continue;
	else {
	    int d, k = 0;
	    /* d <-> d + 3,4,5 */
	    for (d = 1; d < 9; d++) {
		int e = d + 4;
		ral_cell cd = c, ce = c;
		if (e > 8) e -= 8;  
		cd = ral_cell_move(cd, d);
		ce = ral_cell_move(ce, e);
		if (RAL_GRID_CELL_IN(gd, cd) AND RAL_GRID_CELL_IN(gd, ce) AND 
		    RAL_INTEGER_GRID_CELL(gd, cd) AND RAL_INTEGER_GRID_CELL(gd, cd) == RAL_INTEGER_GRID_CELL(gd, ce)) {
		    k =  RAL_INTEGER_GRID_CELL(gd, cd);
		    break;
		}
	    }
	    RAL_INTEGER_GRID_CELL(gd, c) = k;
	}
    }
    return 1;
 fail:
    return 0;
}


int ral_grid_number_of_areas(ral_grid *gd, int connectivity)
{
    int k = 1;
    ral_cell c;
    ral_grid *done = NULL;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_CHECK(done = ral_grid_create_like(gd, RAL_INTEGER_GRID));
    RAL_FOR(c, gd) {
	if (RAL_INTEGER_GRID_CELL(gd, c) AND RAL_INTEGER_GRID_DATACELL(gd, c) AND !RAL_INTEGER_GRID_CELL(done, c)) {
	    k++;
	    RAL_CHECKM(k <= RAL_INTEGER_MAX, RAL_ERRSTR_IOB);
	    ral_integer_grid_floodfill(gd, done, c, k, connectivity);
	}
    }
    ral_grid_destroy(&done);
    return 1;
 fail:
    ral_grid_destroy(&done);
    return 0;
}


ral_grid *ral_grid_clip(ral_grid *gd, ral_window w)
{
    ral_grid *g = NULL;
    ral_point up_left;
    RAL_CHECK(g = ral_grid_create(gd->datatype, RAL_WINDOW_HEIGHT(w), RAL_WINDOW_WIDTH(w)));
    up_left = ral_grid_cell2point_upleft(gd, w.up_left);
    ral_grid_set_bounds_csnx(g, gd->cell_size, up_left.x, up_left.y);
    if (gd->datatype == RAL_REAL_GRID) {
	ral_cell c;
	if (gd->nodata_value) {
	    RAL_REAL nodata_value;
	    RAL_CHECK(ral_grid_get_real_nodata_value(gd, &nodata_value));
	    RAL_CHECK(ral_grid_set_real_nodata_value(g, nodata_value));
	} else {
	    RAL_CHECK(ral_grid_set_real_nodata_value(g, -9999));
	}
	ral_grid_set_all_nodata(g);
	for (c.i = max(w.up_left.i, 0); c.i <= min(w.down_right.i, gd->M-1); c.i++)
	    for (c.j = max(w.up_left.j, 0); c.j <= min(w.down_right.j, gd->N-1); c.j++)
		RAL_REAL_GRID_AT(g, c.i - w.up_left.i, c.j - w.up_left.j) = RAL_REAL_GRID_CELL(gd, c);
    } else { /* if (gd->datatype == RAL_INTEGER_GRID) { */
	ral_cell c;
	if (gd->nodata_value) {
	    RAL_INTEGER nodata_value;
	    RAL_CHECK(ral_grid_get_integer_nodata_value(gd, &nodata_value));
	    RAL_CHECK(ral_grid_set_integer_nodata_value(g, nodata_value));
	} else {
	    RAL_CHECK(ral_grid_set_integer_nodata_value(g, -9999));
	}
	ral_grid_set_all_nodata(g);
	for (c.i = max(w.up_left.i, 0); c.i <= min(w.down_right.i, gd->M-1); c.i++)
	    for (c.j = max(w.up_left.j, 0); c.j <= min(w.down_right.j, gd->N-1); c.j++)
		RAL_INTEGER_GRID_AT(g, c.i - w.up_left.i, c.j - w.up_left.j) = RAL_INTEGER_GRID_CELL(gd, c);
    }
    return g;
 fail:
    return NULL;
}


ral_grid *ral_grid_join(ral_grid *g1, ral_grid *g2)
{
    ral_grid *g = NULL;
    double ddw, ddh;
    int dw, dh, new_M, new_N;

    RAL_CHECKM(g1->cell_size == g2->cell_size, RAL_ERRSTR_CANNOT_JOIN" (different cell_sizes)");

    /* check the alignment */
    ddw = (g2->world.min.x - g1->world.min.x)/g1->cell_size;
    ddh = (g2->world.max.y - g1->world.max.y)/g1->cell_size;
    dw = round(ddw);
    dh = round(ddh);
    RAL_CHECKM(abs(ddw-(double)dw) < 0.1, RAL_ERRSTR_CANNOT_JOIN" (bad horizontal alignment)");
    RAL_CHECKM(abs(ddh-(double)dh) < 0.1, RAL_ERRSTR_CANNOT_JOIN" (bad vertical alignment)");

    if (dh >= 0)
	new_M = max(g1->M + dh, g2->M);
    else
	new_M = max(g1->M, g2->M - dh);

    if (dw >= 0)
	new_N = max(g1->N, dw + g2->N);
    else
	new_N = max(g1->N - dw, g2->N);
    
    RAL_CHECK(g = ral_grid_create(max(g1->datatype, g2->datatype), new_M, new_N));
    if (g1->nodata_value) {

	if (g1->datatype == RAL_INTEGER_GRID) {

	    RAL_INTEGER nodata_value;
	    RAL_CHECK(ral_grid_get_integer_nodata_value(g1, &nodata_value));
	    if (g->datatype == RAL_INTEGER_GRID) {
		RAL_CHECK(ral_grid_set_integer_nodata_value(g, nodata_value));
	    } else {
		RAL_CHECK(ral_grid_set_real_nodata_value(g, nodata_value));
	    }

	} else {

	    RAL_REAL nodata_value;
	    RAL_CHECK(ral_grid_get_real_nodata_value(g1, &nodata_value));
	    RAL_CHECK(ral_grid_set_real_nodata_value(g, nodata_value));

	}

    } else { /* we need one anyway */

	RAL_CHECK(ral_grid_set_integer_nodata_value(g, -9999));

    }

    /* g1 is fixed and g2 may be aligned a bit */
    ral_grid_set_bounds_csnx(g, g1->cell_size,
			  min(g1->world.min.x, g1->world.min.x + dw*g1->cell_size),
			  max(g1->world.max.y,  g1->world.max.y + dh*g1->cell_size));
 
    
    if (g->datatype == RAL_INTEGER_GRID) {
	RAL_INTEGER nodata_value = RAL_INTEGER_GRID_NODATA_VALUE(g);
	ral_cell c;
	RAL_FOR(c, g) {
	    ral_cell c2 = c, c1 = c;
	    if (dh >= 0)
		c1.i -= dh;
	    else
		c2.i += dh;
	    if (dw >= 0)
		c2.j -= dw;
	    else
		c1.j += dw;
	    if (RAL_GRID_CELL_IN(g1, c1) AND RAL_INTEGER_GRID_DATACELL(g1, c1)) {
		RAL_INTEGER_GRID_CELL(g, c) = RAL_INTEGER_GRID_CELL(g1, c1);
	    } else if (RAL_GRID_CELL_IN(g2, c2) AND RAL_INTEGER_GRID_DATACELL(g2, c2)) {
		RAL_INTEGER_GRID_CELL(g, c) = RAL_INTEGER_GRID_CELL(g2, c2);
	    } else {
		RAL_INTEGER_GRID_CELL(g, c) = nodata_value;
	    }
	}
    } else if (g1->datatype == RAL_INTEGER_GRID) {
	RAL_REAL nodata_value = RAL_REAL_GRID_NODATA_VALUE(g);
	ral_cell c;
	RAL_FOR(c, g) {
	    ral_cell c1 = c, c2 = c;
	    if (dh >= 0)
		c1.i -= dh;
	    else
		c2.i += dh;		
	    if (dw >= 0)
		c2.j -= dw;
	    else
		c1.j += dw;
	    if (RAL_GRID_CELL_IN(g1, c1) AND RAL_INTEGER_GRID_DATACELL(g1, c1)) {
		RAL_REAL_GRID_CELL(g, c) = RAL_INTEGER_GRID_CELL(g1, c1);
	    } else if (RAL_GRID_CELL_IN(g2, c2) AND RAL_REAL_GRID_DATACELL(g2, c2)) {
		RAL_REAL_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(g2, c2);
	    } else {
		RAL_REAL_GRID_CELL(g, c) = nodata_value;
	    }
	}
    } else if (g2->datatype == RAL_INTEGER_GRID) {
	RAL_REAL nodata_value = RAL_REAL_GRID_NODATA_VALUE(g);
	ral_cell c;
	RAL_FOR(c, g) {
	    ral_cell c1 = c, c2 = c;
	    if (dh >= 0)
		c1.i -= dh;
	    else
		c2.i += dh;		
	    if (dw >= 0)
		c2.j -= dw;
	    else
		c1.j += dw;
	    if (RAL_GRID_CELL_IN(g1, c1) AND RAL_REAL_GRID_DATACELL(g1, c1)) {
		RAL_REAL_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(g1, c1);
	    } else if (RAL_GRID_CELL_IN(g2, c2) AND RAL_INTEGER_GRID_DATACELL(g2, c2)) {
		RAL_REAL_GRID_CELL(g, c) = RAL_INTEGER_GRID_CELL(g2, c2);
	    } else {
		RAL_REAL_GRID_CELL(g, c) = nodata_value;
	    }
	}
    } else {
	RAL_REAL nodata_value = RAL_REAL_GRID_NODATA_VALUE(g);
	ral_cell c;
	RAL_FOR(c, g) {
	    ral_cell c1 = c, c2 = c;
	    if (dh >= 0)
		c1.i -= dh;
	    else
		c2.i += dh;		
	    if (dw >= 0)
		c2.j -= dw;
	    else
		c1.j += dw;
	    if (RAL_GRID_CELL_IN(g1, c1) AND RAL_REAL_GRID_DATACELL(g1, c1)) {
		RAL_REAL_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(g1, c1);
	    } else if (RAL_GRID_CELL_IN(g2, c2) AND RAL_REAL_GRID_DATACELL(g2, c2)) {
		RAL_REAL_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(g2, c2);
	    } else {
		RAL_REAL_GRID_CELL(g, c) = nodata_value;
	    }
	}
    } 

    return g;
 fail:
    ral_grid_destroy(&g);
    return NULL;
}


int ral_grid_pick(ral_grid *dest, ral_grid *src)
{
    ral_cell c;
    switch (dest->datatype) {
    case RAL_REAL_GRID: {
	switch (src->datatype) {
	case RAL_REAL_GRID: {
	    RAL_FOR(c, dest) {
		ral_cell d = ral_grid_point2cell(src, ral_grid_cell2point(dest, c));
		if (RAL_GRID_CELL_IN(src, d) AND RAL_REAL_GRID_DATACELL(src, d)) { /* should also test src->mask */
		    RAL_REAL_GRID_CELL(dest, c) = RAL_REAL_GRID_CELL(src, d);
		}
	    }
	    break;
	}
	case RAL_INTEGER_GRID: {
	    RAL_FOR(c, dest) {
		ral_cell d = ral_grid_point2cell(src, ral_grid_cell2point(dest, c));
		if (RAL_GRID_CELL_IN(src, d) AND RAL_INTEGER_GRID_DATACELL(src, d)) { /* should also test src->mask */
		    RAL_REAL_GRID_CELL(dest, c) = RAL_INTEGER_GRID_CELL(src, d);
		}
	    }
	    break;
	}
	}
	break;
    }
    case RAL_INTEGER_GRID: {
	switch (src->datatype) {
	case RAL_REAL_GRID: {
	    RAL_FOR(c, dest) {
		ral_cell d = ral_grid_point2cell(src, ral_grid_cell2point(dest, c));
		if (RAL_GRID_CELL_IN(src, d) AND RAL_REAL_GRID_DATACELL(src, d)) { /* should also test src->mask */
		    RAL_INTEGER i;
		    RAL_CHECKM(ral_r2i(RAL_REAL_GRID_CELL(src, d), &i), RAL_ERRSTR_IOB);
		    RAL_INTEGER_GRID_CELL(dest, c) = i;
		}
	    }
	    break;
	}
	case RAL_INTEGER_GRID: {
	    RAL_FOR(c, dest) {
		ral_cell d = ral_grid_point2cell(src, ral_grid_cell2point(dest, c));
		if (RAL_GRID_CELL_IN(src, d) AND RAL_INTEGER_GRID_DATACELL(src, d)) { /* should also test src->mask */
		    RAL_INTEGER_GRID_CELL(dest, c) = RAL_INTEGER_GRID_CELL(src, d);
		}
	    }
	    break;
	}
	}
	break;
    }
    }
    return 1;
fail:
    return 0;
}


/* 
   this computes the area (polygon P) that the ral_cell c (of destination
   raster) covers in source raster and its bounding box

   is this now a bit different than elsewhere?
   
   should we assume that tr translates center points of cells?
 */
void ral_rect_in_src(ral_cell c, double *tr, ral_polygon P, int *bbox)
{
    P.nodes[0].y = tr[0]+tr[1]*((double)c.i-0.0)+tr[2]*((double)c.j-0.0);
    bbox[2] = bbox[0] = ceil(P.nodes[0].y);
    P.nodes[0].x = tr[3]+tr[4]*((double)c.i-0.0)+tr[5]*((double)c.j-0.0);
    bbox[3] = bbox[1] = ceil(P.nodes[0].x);
    P.nodes[1].y = tr[0]+tr[1]*((double)c.i-0.0)+tr[2]*((double)c.j+1.0);
    bbox[0] = min(bbox[0],ceil(P.nodes[1].y));
    bbox[2] = max(bbox[2],ceil(P.nodes[1].y));
    P.nodes[1].x = tr[3]+tr[4]*((double)c.i-0.0)+tr[5]*((double)c.j+1.0);
    bbox[1] = min(bbox[1],floor(P.nodes[1].x));
    bbox[3] = max(bbox[3],floor(P.nodes[1].x));
    P.nodes[2].y = tr[0]+tr[1]*((double)c.i+1.0)+tr[2]*((double)c.j+1.0);
    bbox[0] = min(bbox[0],floor(P.nodes[2].y));
    bbox[2] = max(bbox[2],floor(P.nodes[2].y));
    P.nodes[2].x = tr[3]+tr[4]*((double)c.i+1.0)+tr[5]*((double)c.j+1.0);
    bbox[1] = min(bbox[1],floor(P.nodes[2].x));
    bbox[3] = max(bbox[3],floor(P.nodes[2].x));
    P.nodes[3].y = tr[0]+tr[1]*((double)c.i+1.0)+tr[2]*((double)c.j-0.0);
    bbox[0] = min(bbox[0],floor(P.nodes[3].y));
    bbox[2] = max(bbox[2],floor(P.nodes[3].y));
    P.nodes[3].x = tr[3]+tr[4]*((double)c.i+1.0)+tr[5]*((double)c.j-0.0);
    bbox[1] = min(bbox[1],ceil(P.nodes[3].x));
    bbox[3] = max(bbox[3],ceil(P.nodes[3].x));
}


ral_grid *ral_grid_transform(ral_grid *gd, double tr[], int M, int N, int pick, int value) {
    /* i0=ai + bi * i + ci * j				
       j0=aj + bj * i + cj * j
       tr = (ai,bi,ci,aj,bj,cj) */
    ral_grid *g = NULL;
    ral_cell c, p;

    if ((pick > 0) AND (pick < 10))
	RAL_CHECK(g = ral_grid_create(RAL_REAL_GRID, M, N))
    else 
	RAL_CHECK(g = ral_grid_create(gd->datatype, M, N));

    /* calculate cell_size, world.min.x ...? no because new cell_size_x is not necessarily cell_size_y */

    RAL_CHECK(ral_grid_set_integer_nodata_value(g, -9999));
    ral_grid_set_all_nodata(g);
    if (!pick) {
	if (gd->datatype == RAL_INTEGER_GRID) {
	    RAL_FOR(c, g) {
		p.i = round(tr[0]+tr[1]*c.i+tr[2]*c.j);
		p.j = round(tr[3]+tr[4]*c.i+tr[5]*c.j);
		if (RAL_GRID_CELL_IN(gd, p) AND RAL_GRID_DATACELL(gd,p)) RAL_INTEGER_GRID_CELL(g, c) = RAL_INTEGER_GRID_CELL(gd, p);
	    }
	} else {
	    RAL_FOR(c, g) {
		p.i = round(tr[0]+tr[1]*c.i+tr[2]*c.j);
		p.j = round(tr[3]+tr[4]*c.i+tr[5]*c.j);
		if (RAL_GRID_CELL_IN(gd, p) AND RAL_GRID_DATACELL(gd,p)) RAL_REAL_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, p);
	    }
	}
    } else {
	int bbox[4];
	ral_point src[4];
	ral_polygon P;
	P.nodes = src;
	P.n = 4;
	if (gd->datatype == RAL_INTEGER_GRID) {
	    RAL_FOR(c, g) {
		int n = 0;
		double mean = 0, variance = 0;
		int f = 1;
		ral_rect_in_src(c, tr, P, bbox);
		for (p.i = max(bbox[0],0); p.i < min(bbox[2]+1,gd->M) ; p.i++) {
		    for (p.j = max(bbox[1],0); p.j < min(bbox[3]+1,gd->N) ; p.j++) {
			ral_point q;
			q.x = p.j;
			q.y = p.i;
			if (RAL_INTEGER_GRID_DATACELL(gd,p) AND ral_pnpoly(q, P)) {
			    switch (pick) {
			    case 1:{ 
				n++;
				mean += (RAL_INTEGER_GRID_CELL(gd, p) - mean) / n;
				break;
			    }
			    case 2:{
				double oldmean = mean;
				n++;
				mean += (RAL_INTEGER_GRID_CELL(gd, p) - mean) / n;
				variance += (RAL_INTEGER_GRID_CELL(gd, p) - oldmean) * (RAL_INTEGER_GRID_CELL(gd, p) - mean);
				break; 
			    }
			    case 10:{
				if (f) {
				    RAL_INTEGER_GRID_CELL(g, c) = RAL_INTEGER_GRID_CELL(gd, p);
				    f = 0;
				} else {
				    RAL_INTEGER_GRID_CELL(g, c) = min(RAL_INTEGER_GRID_CELL(g, c),RAL_INTEGER_GRID_CELL(gd, p));
				}
				break; 
			    }
			    case 11:{ 
				if (f) {
				    RAL_INTEGER_GRID_CELL(g, c) = RAL_INTEGER_GRID_CELL(gd, p);  
				    f = 0;
				} else {
				    RAL_INTEGER_GRID_CELL(g, c) = max(RAL_INTEGER_GRID_CELL(g, c),RAL_INTEGER_GRID_CELL(gd, p));  
				}
				break; 
			    }
			    case 20:{
				if (f) {				    
				    RAL_INTEGER_GRID_CELL(g, c) = 0;
				    f = 0;
				} 
				if (RAL_INTEGER_GRID_CELL(gd, p) == value) RAL_INTEGER_GRID_CELL(g, c)++;
				break; 
			    }
			    }
			}
		    }
		}
		switch (pick) {
		case 1:{
		    if (n)
			RAL_REAL_GRID_CELL(g, c) = mean;
		    break;
		}
		case 2:{ 
		    if (n)
			RAL_REAL_GRID_CELL(g, c) = variance/(n-1);
		    break; 
		}
		}
	    }
	} else {
	    RAL_FOR(c, g) {
		int n = 0;
		double mean = 0, variance = 0;
		int f = 1;
		ral_rect_in_src(c, tr, P, bbox);
		for (p.i = max(bbox[0],0); p.i < min(bbox[2]+1,gd->M) ; p.i++) {
		    for (p.j = max(bbox[1],0); p.j < min(bbox[3]+1,gd->N) ; p.j++) {
			ral_point q;
			q.x = p.j;
			q.y = p.i;
			if (RAL_REAL_GRID_DATACELL(gd,p) AND ral_pnpoly(q, P)) {
			    switch (pick) {
			    case 1:{ 
				n++;
				mean += (RAL_REAL_GRID_CELL(gd, p) - mean) / n;
				break;
			    }
			    case 2:{
				double oldmean = mean;
				n++;
				mean += (RAL_REAL_GRID_CELL(gd, p) - mean) / n;
				variance += (RAL_REAL_GRID_CELL(gd, p) - oldmean) * (RAL_REAL_GRID_CELL(gd, p) - mean);
				break; 
			    }
			    case 10:{
				if (f) {
				    RAL_REAL_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, p);
				    f = 0;
				} else {
				    RAL_REAL_GRID_CELL(g, c) = min(RAL_REAL_GRID_CELL(g, c),RAL_REAL_GRID_CELL(gd, p));
				}
				break; 
			    }
			    case 11:{ 
				if (f) {
				    RAL_REAL_GRID_CELL(g, c) = RAL_REAL_GRID_CELL(gd, p);  
				    f = 0;
				} else {
				    RAL_REAL_GRID_CELL(g, c) = max(RAL_REAL_GRID_CELL(g, c),RAL_REAL_GRID_CELL(gd, p));  
				}
				break; 
			    }
			    }
			}
		    }
		}
		switch (pick) {
		case 1:{
		    if (n)
			RAL_REAL_GRID_CELL(g, c) = mean;
		    break;
		}
		case 2:{ 
		    if (n)
			RAL_REAL_GRID_CELL(g, c) = variance/(n-1);
		    break; 
		}
		}
	    }
	}
    }
    return g;
 fail:
    ral_grid_destroy(&g);
    return NULL;
}


void ral_real_grid_line(ral_grid *gd, ral_cell c1, ral_cell c2, RAL_REAL pen)
{
    RAL_LINE(gd, c1, c2, pen, RAL_REAL_GRID_SET_CELL);
}


void ral_integer_grid_line(ral_grid *gd, ral_cell c1, ral_cell c2, RAL_INTEGER pen)
{
    RAL_LINE(gd, c1, c2, pen, RAL_INTEGER_GRID_SET_CELL);
}


void ral_real_grid_filled_rect(ral_grid *gd, ral_cell c1, ral_cell c2, RAL_REAL pen)
{
    ral_cell c;
    if (c2.i < c1.i) swap(c1.i, c2.i, c.i);
    if (c2.j < c1.j) swap(c1.j, c2.j, c.j);
    for (c.i = max(0,c1.i); c.i < min(gd->M, c2.i+1); c.i++) {
	for (c.j = max(0,c1.j); c.j < min(gd->N, c2.j+1); c.j++) {
	    RAL_REAL_GRID_CELL(gd, c) = pen;
	}
    }
}


void ral_integer_grid_filled_rect(ral_grid *gd, ral_cell c1, ral_cell c2, RAL_INTEGER pen)
{
    ral_cell c;
    if (c2.i < c1.i) swap(c1.i, c2.i, c.i);
    if (c2.j < c1.j) swap(c1.j, c2.j, c.j);
    for (c.i = max(0,c1.i); c.i < min(gd->M,c2.i+1); c.i++) {
	for (c.j = max(0,c1.j); c.j < min(gd->N,c2.j+1); c.j++) {
	    RAL_INTEGER_GRID_CELL(gd, c) = pen;
	}
    }
}


#ifdef RAL_HAVE_GDAL
int ral_grid_filled_polygon(ral_grid *gd, ral_geometry *g, RAL_INTEGER pen_integer, RAL_REAL pen_real)
{
    ral_active_edge_table *aet_list = NULL;
    ral_cell c;
    double y = gd->world.min.y + 0.5*gd->cell_size;
    RAL_CHECK(aet_list = ral_get_active_edge_tables(g->parts, g->n_parts));
    switch (gd->datatype) {
    case RAL_INTEGER_GRID:
	for (c.i = gd->M - 1; c.i >= 0; c.i--) {
	    double *x;
	    int n;	    
	    ral_scanline_at(aet_list, g->n_parts, y, &x, &n);
	    if (x) {
		int draw = 0;
		int begin = 0;
		int k;
		while ((begin < n) AND (x[begin] < gd->world.min.x)) {
		    begin++;
		    draw = !draw;
		}
		c.j = 0;
		for (k = begin; k < n; k++) {
		    int jmax = floor((x[k] - gd->world.min.x)/gd->cell_size+0.5);
		    while ((c.j < gd->N) AND (c.j < jmax)) {
			if (draw) RAL_INTEGER_GRID_CELL(gd, c) = pen_integer;
			c.j++;
		    }
		    if (c.j == gd->N) break;
		    draw = !draw;
		}
		ral_delete_scanline(&x);
	    }
	    y += gd->cell_size;
	}
	break;
    case RAL_REAL_GRID:
    {
	for (c.i = gd->M - 1; c.i >= 0; c.i--) {
	    double *x;
	    int n;
	    ral_scanline_at(aet_list, g->n_parts, y, &x, &n);
	    if (x) {
		int draw = 0;
		int begin = 0;
		int k;
		while ((begin < n) AND (x[begin] < gd->world.min.x)) {
		    begin++;
		    draw = !draw;
		}
		c.j = 0;
		for (k = begin; k < n; k++) {
		    int jmax = floor((x[k] - gd->world.min.x)/gd->cell_size+0.5);
		    while ((c.j < gd->N) AND (c.j < jmax)) {
			if (draw) RAL_REAL_GRID_CELL(gd, c) = pen_real;
			c.j++;
		    }
		    if (c.j == gd->N) break;
		    draw = !draw;
		}
		ral_delete_scanline(&x);
	    }
	    y += gd->cell_size;
	}
    }
    }
    
    ral_active_edge_tables_destroy(&aet_list, g->n_parts);
    return 1;
 fail:
    ral_active_edge_tables_destroy(&aet_list, g->n_parts);
    return 0;
}


int ral_grid_rasterize_feature(ral_grid *gd, OGRFeatureH f, int value_field, OGRFieldType ft, int render_override)
{
    ral_geometry *g = ral_geometry_create_from_OGR(OGR_F_GetGeometryRef(f));
    RAL_INTEGER i_value = 1;
    RAL_REAL d_value = 1;

    int render_as = 0;

    RAL_CHECK(g);

    if (value_field > -1) {
	if (ft == OFTInteger)
	    i_value = OGR_F_GetFieldAsInteger(f, value_field);
	else
	    d_value = OGR_F_GetFieldAsDouble(f, value_field);
    }

    if (g->type == wkbPoint OR g->type == wkbMultiPoint OR 
	g->type == wkbPoint25D OR g->type == wkbMultiPoint25D)
    {
	render_as = 1;
    } else if (g->type == wkbLineString OR g->type == wkbMultiLineString OR 
	       g->type == wkbLineString25D OR g->type == wkbMultiLineString25D)
    {
	render_as = 2;
    } else if (g->type == wkbPolygon OR g->type == wkbMultiPolygon OR 
	       g->type == wkbPolygon25D OR g->type == wkbMultiPolygon25D)
    {
	render_as = 3;
    }

    if (render_override)
	render_as = render_override;

    switch (render_as) {
    case 1:
    {
	int i;
	for (i = 0; i < g->n_parts; i++) {
	    int j;
	    for (j = 0; j < g->parts[i].n; j++) {
		ral_point p = g->parts[i].nodes[j];
		if (RAL_POINT_IN_RECTANGLE(p, gd->world)) {
		    ral_cell c = ral_grid_point2cell(gd, p);
		    if (ft == OFTInteger)
			RAL_INTEGER_GRID_CELL(gd, c) = i_value;
		    else
			RAL_REAL_GRID_CELL(gd, c) = d_value;
		}
	    }
	}
	break;
    }
    case 2:
    {
	int i;
	for (i = 0; i < g->n_parts; i++) {
	    int j;
	    for (j = 0; j < g->parts[i].n - 1; j++) {
		/* draw line from g->parts[i].nodes[j] to g->parts[i].nodes[j+1] */
		/* clip */
		ral_line l;
		l.begin = g->parts[i].nodes[j];
		l.end = g->parts[i].nodes[j+1];
		if (ral_clip_line_to_rect(&l,gd->world)) {
		    ral_cell c1 = ral_grid_point2cell(gd, l.begin);
		    ral_cell c2 = ral_grid_point2cell(gd, l.end);
		    gd->datatype == RAL_INTEGER_GRID ? 
			ral_integer_grid_line(gd, c1, c2, i_value) :
			ral_real_grid_line(gd, c1, c2, d_value);
		}
	    }
	}
	break;
    }
    case 3:
    {
	ral_grid_filled_polygon(gd, g, i_value, d_value);
	break;
    }
    default:
	RAL_CHECKM(0, ral_msg("render_as is %i", render_as));
    }
    return 1;
fail:
    ral_geometry_destroy(&g);
    return 0;
}


int ral_grid_rasterize_layer(ral_grid *gd, OGRLayerH l, int value_field, int render_override)
{
    OGRFieldType ft = OFTInteger;
    OGRFeatureH f;

    if (value_field > -1)
	ft = OGR_Fld_GetType(OGR_FD_GetFieldDefn(OGR_L_GetLayerDefn(l), value_field));

    OGR_L_SetSpatialFilterRect(l, 
			       gd->world.min.x, gd->world.min.y, 
			       gd->world.max.x, gd->world.max.y);

    OGR_L_ResetReading(l);
    while ((f = OGR_L_GetNextFeature(l))) {
	RAL_CHECK(ral_grid_rasterize_feature(gd, f, value_field, ft, render_override));
	OGR_F_Destroy(f);
    }

    return 1;
fail:
    return 0;
}
#endif


ral_cell_integer_values *ral_integer_grid_get_line(ral_grid *gd, ral_cell c1, ral_cell c2)
{
    ral_cell_integer_values *data = NULL;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_CHECK(data = ral_cell_integer_values_create((int)(sqrt((double)(c2.i-c1.i)*(double)(c2.i-c1.i)+(double)(c2.j-c1.j)*(double)(c2.j-c1.j))+1)));
    RAL_LINE(gd, c1, c2, data, ral_add_cell_integer_value);
    return data;
 fail:
    ral_cell_integer_values_destroy(&data);
    return NULL;
}


ral_cell_real_values *ral_real_grid_get_line(ral_grid *gd, ral_cell c1, ral_cell c2)
{
    ral_cell_real_values *data = NULL;
    RAL_CHECKM(gd->datatype == RAL_REAL_GRID, RAL_ERRSTR_ARG_REAL);
    RAL_CHECK(data = ral_cell_real_values_create((int)(sqrt((double)(c2.i-c1.i)*(double)(c2.i-c1.i)+(double)(c2.j-c1.j)*(double)(c2.j-c1.j))+1)));
    RAL_LINE(gd, c1, c2, data, ral_add_cell_real_value);
    return data;
 fail:
    ral_cell_real_values_destroy(&data);
    return NULL;
}


ral_cell_integer_values *ral_integer_grid_get_rect(ral_grid *gd, ral_cell c1, ral_cell c2)
{
    ral_cell c;
    ral_cell_integer_values *data = NULL;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_CHECK(data = ral_cell_integer_values_create((abs(c2.i-c1.i)+1)*(abs(c2.j-c1.j+1)+1)));
    if (c2.i < c1.i) swap(c1.i, c2.i, c.i);
    if (c2.j < c1.j) swap(c1.j, c2.j, c.j);
    for (c.i = max(0,c1.i); c.i < min(gd->M, c2.i+1); c.i++)
	for (c.j = max(0,c1.j); c.j < min(gd->N, c2.j+1); c.j++)
	    ral_add_cell_integer_value(gd, c, data);
    return data;
 fail:
    ral_cell_integer_values_destroy(&data);
    return NULL;
}


ral_cell_real_values *ral_real_grid_get_rect(ral_grid *gd, ral_cell c1, ral_cell c2)
{
    ral_cell c;
    ral_cell_real_values *data = NULL;
    RAL_CHECKM(gd->datatype == RAL_REAL_GRID, RAL_ERRSTR_ARG_REAL);
    RAL_CHECK(data = ral_cell_real_values_create((abs(c2.i-c1.i)+1)*(abs(c2.j-c1.j+1)+1)));
    if (c2.i < c1.i) swap(c1.i, c2.i, c.i);
    if (c2.j < c1.j) swap(c1.j, c2.j, c.j);
    for (c.i = max(0,c1.i); c.i < min(gd->M, c2.i+1); c.i++)
	for (c.j = max(0,c1.j); c.j < min(gd->N, c2.j+1); c.j++)
	    ral_add_cell_real_value(gd, c, data);
    return data;
fail:
    ral_cell_real_values_destroy(&data);
    return NULL;
}

ral_cell_integer_values *ral_cell_integer_values_create(int size)
{
    ral_cell_integer_values *data = NULL;
    RAL_CHECKM(data = RAL_MALLOC(ral_cell_integer_values), RAL_ERRSTR_OOM);
    data->max_size = size;
    data->size = 0;
    data->cells = NULL;
    data->values = NULL;
    RAL_CHECKM(data->cells = RAL_CALLOC(size, ral_cell), RAL_ERRSTR_OOM);
    RAL_CHECKM(data->values = RAL_CALLOC(size, RAL_INTEGER), RAL_ERRSTR_OOM);
    return data;
fail:
    ral_cell_integer_values_destroy(&data);
    return NULL;
}

void ral_cell_integer_values_destroy(ral_cell_integer_values **data)
{
    if (*data) {
	if ((*data)->cells) free((*data)->cells);
	if ((*data)->values) free((*data)->values);
	free(*data);
	*data = NULL;
    }
}

void ral_add_cell_integer_value(ral_grid *gd, ral_cell d, ral_cell_integer_values *data)
{
    if (data->size < data->max_size) {
	data->cells[data->size] = d;
	data->values[data->size] = RAL_INTEGER_GRID_CELL(gd, d);
	data->size++;
    }
}

ral_cell_real_values *ral_cell_real_values_create(int size)
{
    ral_cell_real_values *data = NULL;
    RAL_CHECKM(data = RAL_MALLOC(ral_cell_real_values), RAL_ERRSTR_OOM);
    data->max_size = size;
    data->size = 0;
    data->cells = NULL;
    data->values = NULL;
    RAL_CHECKM(data->cells = RAL_CALLOC(size, ral_cell), RAL_ERRSTR_OOM);
    RAL_CHECKM(data->values = RAL_CALLOC(size, RAL_REAL), RAL_ERRSTR_OOM);
    return data;
fail:
    ral_cell_real_values_destroy(&data);
    return NULL;
}

void ral_cell_real_values_destroy(ral_cell_real_values **data)
{
    if (*data) {
	if ((*data)->cells) free((*data)->cells);
	if ((*data)->values) free((*data)->values);
	free(*data);
	*data = NULL;
    }
}

void ral_add_cell_real_value(ral_grid *gd, ral_cell d, ral_cell_real_values *data)
{
    if (data->size < data->max_size) {
	data->cells[data->size] = d;
	data->values[data->size] = RAL_REAL_GRID_CELL(gd, d);
	data->size++;
    }
}

ral_cell_integer_values *ral_integer_grid_get_circle(ral_grid *gd, ral_cell c, int r)
{
    ral_cell_integer_values *data = NULL;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_CHECK(data = ral_cell_integer_values_create((2*r+1)*(2*r+1)));
    RAL_FILLED_CIRCLE(gd, c, r, data, ral_add_cell_integer_value);
    return data;
 fail:
    ral_cell_integer_values_destroy(&data);
    return NULL;
}


ral_cell_real_values *ral_real_grid_get_circle(ral_grid *gd, ral_cell c, int r)
{
    ral_cell_real_values *data = NULL;
    RAL_CHECKM(gd->datatype == RAL_REAL_GRID, RAL_ERRSTR_ARG_REAL);
    RAL_CHECK(data = ral_cell_real_values_create((2*r+1)*(2*r+1)));
    RAL_FILLED_CIRCLE(gd, c, r, data, ral_add_cell_real_value);
    return data;
 fail:
    ral_cell_real_values_destroy(&data);
    return NULL;
}


/* after gdImageFill in gd.c of http://www.boutell.com/gd/ */
void ral_integer_grid_floodfill(ral_grid *gd, ral_grid *done, ral_cell c, RAL_INTEGER pen, int connectivity)
{
    int lastBorder;
    int old;
    int leftLimit, rightLimit;
    int i2;
    old = RAL_INTEGER_GRID_CELL(gd, c);
    if (old == pen) {
	/* Nothing to be done */
        if (done) RAL_INTEGER_GRID_CELL(done, c) = 1;
	return;
    }
    /* Seek up */
    leftLimit = (-1);
    for (i2 = c.i; (i2 >= 0); i2--) {
	if (RAL_INTEGER_GRID_AT(gd, i2, c.j) != old) {
	    break;
	}
	RAL_INTEGER_GRID_AT(gd, i2, c.j) = pen;
	if (done) RAL_INTEGER_GRID_AT(done, i2, c.j) = 1;
	if (connectivity == 8)
	    leftLimit = max(0,i2-1);
	else
	    leftLimit = i2;
    }
    if (leftLimit == (-1)) {
	return;
    }
    /* Seek down */
    if (connectivity == 8)
	rightLimit = min(gd->M-1,c.i+1);
    else
	rightLimit = c.i;
    for (i2 = (c.i+1); (i2 < gd->M); i2++) {	
	if (RAL_INTEGER_GRID_AT(gd, i2, c.j) != old) {
	    break;
	}
	RAL_INTEGER_GRID_AT(gd, i2, c.j) = pen;
	if (done) RAL_INTEGER_GRID_AT(done, i2, c.j) = 1;
	if (connectivity == 8)
	    rightLimit = min(gd->M-1,i2+1);
	else
	    rightLimit = i2;
    }
    /* Look at columns right and left and start paints */
    /* right */
    if (c.j > 0) {
	ral_cell c2;
	c2.j = c.j-1;
	lastBorder = 1;
	for (c2.i = leftLimit; (c2.i <= rightLimit); c2.i++) {
	    int a;
	    a = RAL_INTEGER_GRID_CELL(gd, c2);
	    if (lastBorder) {
		if (a == old) {	
		    ral_integer_grid_floodfill(gd, done, c2, pen, connectivity);
		    lastBorder = 0;
		}
	    } else if (a != old) {
		lastBorder = 1;
	    }
	}
    }
    /* left */
    if (c.j < ((gd->N) - 1)) {
	ral_cell c2;
	c2.j = c.j+1;
	lastBorder = 1;
	for (c2.i = leftLimit; (c2.i <= rightLimit); c2.i++) {
	    int a;
	    a = RAL_INTEGER_GRID_CELL(gd, c2);
	    if (lastBorder) {
		if (a == old) {
		    ral_integer_grid_floodfill(gd, done, c2, pen, connectivity);
		    lastBorder = 0;
		}
	    } else if (a != old) {
		lastBorder = 1;
	    }
	}
    }
}

void ral_real_grid_floodfill(ral_grid *gd, ral_grid *done, ral_cell c, RAL_REAL pen, int connectivity)
{
    int lastBorder;
    double old;
    int leftLimit, rightLimit;
    int i2;
    old = RAL_REAL_GRID_CELL(gd, c);
    if (old == pen) {
	/* Nothing to be done */
        if (done) RAL_INTEGER_GRID_CELL(done, c) = 1;
	return;
    }
    /* Seek up */
    leftLimit = (-1);
    for (i2 = c.i; (i2 >= 0); i2--) {
	if (RAL_REAL_GRID_AT(gd, i2, c.j) != old) {
	    break;
	}
	RAL_REAL_GRID_AT(gd, i2, c.j) = pen;
	if (done) RAL_INTEGER_GRID_AT(done, i2, c.j) = 1;
	if (connectivity == 8)
	    leftLimit = max(0,i2-1);
	else
	    leftLimit = i2;
    }
    if (leftLimit == (-1)) {
	return;
    }
    /* Seek down */
    if (connectivity == 8)
	rightLimit = min(gd->M-1,c.i+1);
    else
	rightLimit = c.i;
    for (i2 = (c.i+1); (i2 < gd->M); i2++) {	
	if (RAL_REAL_GRID_AT(gd, i2, c.j) != old) {
	    break;
	}
	RAL_REAL_GRID_AT(gd, i2, c.j) = pen;
	if (done) RAL_INTEGER_GRID_AT(done, i2, c.j) = 1;
	if (connectivity == 8)
	    rightLimit = min(gd->M-1,i2+1);
	else
	    rightLimit = i2;
    }
    /* Look at columns right and left and start paints */
    /* right */
    if (c.j > 0) {
	ral_cell c2;
	c2.j = c.j-1;
	lastBorder = 1;
	for (c2.i = leftLimit; (c2.i <= rightLimit); c2.i++) {
	    double a;
	    a = RAL_REAL_GRID_CELL(gd, c2);
	    if (lastBorder) {
		if (a == old) {	
		    ral_real_grid_floodfill(gd, done, c2, pen, connectivity);
		    lastBorder = 0;
		}
	    } else if (a != old) {
		lastBorder = 1;
	    }
	}
    }
    /* left */
    if (c.j < ((gd->N) - 1)) {
	ral_cell c2;
	c2.j = c.j+1;
	lastBorder = 1;
	for (c2.i = leftLimit; (c2.i <= rightLimit); c2.i++) {
	    double a;
	    a = RAL_REAL_GRID_CELL(gd, c2);
	    if (lastBorder) {
		if (a == old) {
		    ral_real_grid_floodfill(gd, done, c2, pen, connectivity);
		    lastBorder = 0;
		}
	    } else if (a != old) {
		lastBorder = 1;
	    }
	}
    }
}


int ral_grid_floodfill(ral_grid *gd, ral_cell c, RAL_INTEGER pen_integer, RAL_REAL pen_real, int connectivity)
{
    switch (gd->datatype) {
    case RAL_INTEGER_GRID: 
	ral_integer_grid_floodfill(gd, NULL, c, pen_integer, connectivity);
	break;
    case RAL_REAL_GRID:
	ral_real_grid_floodfill(gd, NULL, c, pen_real, connectivity);
    }
    return 1;
}


int ral_integer_grid2list(ral_grid *gd, ral_cell **c, RAL_INTEGER **value, size_t *size)
{
    ral_cell d;
    *size = 0;
    *c = NULL;
    *value = NULL;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_FOR(d, gd) {
	if (RAL_INTEGER_GRID_DATACELL(gd, d))
	    (*size)++;
    }
    RAL_CHECKM(*c = RAL_CALLOC(*size, ral_cell), RAL_ERRSTR_OOM);
    RAL_CHECKM(*value = RAL_CALLOC(*size, RAL_INTEGER), RAL_ERRSTR_OOM);
    *size = 0;
    RAL_FOR(d, gd) {
	if (RAL_INTEGER_GRID_DATACELL(gd, d)) {
	    (*c)[(*size)] = d;
	    (*value)[(*size)++] = RAL_INTEGER_GRID_CELL(gd, d);
	}
    } 
    return 1;
 fail:
    if (*c) free(*c);
    if (*value) free(*value);
    *size = 0;
    return 0;
}


int ral_real_grid2list(ral_grid *gd, ral_cell **c, RAL_REAL **value, size_t *size)
{
    ral_cell d;
    *size = 0;
    *c = NULL;
    *value = NULL;
    RAL_CHECKM(gd->datatype == RAL_REAL_GRID, RAL_ERRSTR_ARG_REAL);
    RAL_FOR(d, gd) {
	if (RAL_REAL_GRID_DATACELL(gd, d))
	    (*size)++;
    }
    RAL_CHECKM(*c = RAL_CALLOC(*size, ral_cell), RAL_ERRSTR_OOM);
    RAL_CHECKM(*value = RAL_CALLOC(*size, RAL_REAL), RAL_ERRSTR_OOM);
    *size = 0;
    RAL_FOR(d, gd) {
	if (RAL_REAL_GRID_DATACELL(gd, d)) {
	    (*c)[(*size)] = d;
	    (*value)[(*size)++] = RAL_REAL_GRID_CELL(gd, d);
	}
    } 
    return 1;
 fail:
    if (*c) free(*c);
    if (*value) free(*value);
    *size = 0;
    return 0;
}


void ral_grid_histogram(ral_grid *gd, double *h, int *c, int n)
{
    ral_cell p;
    int k;
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(p, gd) {
	    if (RAL_INTEGER_GRID_DATACELL(gd, p)) {
		k = 0;
		while (RAL_INTEGER_GRID_CELL(gd, p) > h[k] AND k < n) k++;
		c[k]++;
	    }
	}
    } else if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(p, gd) {
	    if (RAL_REAL_GRID_DATACELL(gd, p)) {
		k = 0;
		while (RAL_REAL_GRID_CELL(gd, p) > h[k] AND k < n) k++;
		c[k]++;
	    }
	}
    }
}


ral_hash *ral_grid_contents(ral_grid *gd) 
{
    ral_cell p;
    ral_hash *hash = ral_hash_create(200);
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_CHECK(hash);
    RAL_FOR(p, gd) {
	int *count;
	if (RAL_INTEGER_GRID_NODATACELL(gd,p)) continue;
	RAL_HASH_LOOKUP(hash, RAL_INTEGER_GRID_CELL(gd, p), &count, ral_hash_int_item);
	if (count)
	    (*count)++;
	else
	    RAL_HASH_INSERT(hash, RAL_INTEGER_GRID_CELL(gd, p), 1, ral_hash_int_item);
    }
    return hash;
 fail:
    ral_hash_destroy(&hash);
    return NULL;
}


ral_hash *ral_grid_zonal_count(ral_grid *gd, ral_grid *zones)
{
    ral_cell p;
    ral_hash *counts = NULL;
    RAL_CHECKM(ral_grid_overlayable(gd, zones), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(zones->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ZONING_INTEGER);
    RAL_CHECK(counts = ral_hash_create(200));
    RAL_FOR(p, gd) {
	int *count;
	if (RAL_INTEGER_GRID_NODATACELL(zones,p) OR RAL_GRID_NODATACELL(gd,p)) continue;
	RAL_HASH_LOOKUP(counts, RAL_INTEGER_GRID_CELL(zones, p), &count, ral_hash_int_item);
	if (count)
	    (*count)++;
	else
	    RAL_HASH_INSERT(counts, RAL_INTEGER_GRID_CELL(zones, p), 1, ral_hash_int_item);
    }
    return counts;
 fail:
    ral_hash_destroy(&counts);
    return NULL;
}


ral_hash *ral_grid_zonal_count_of(ral_grid *gd, ral_grid *zones, RAL_INTEGER value)
{
    ral_cell p;
    ral_hash *counts = NULL;
    RAL_CHECKM(ral_grid_overlayable(gd, zones), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_CHECKM(zones->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ZONING_INTEGER);
    RAL_CHECK(counts = ral_hash_create(200));
    RAL_FOR(p, gd) {
	int *count;
	if (RAL_INTEGER_GRID_NODATACELL(zones, p) OR 
	    RAL_INTEGER_GRID_NODATACELL(gd, p) OR
	    RAL_INTEGER_GRID_CELL(gd, p) != value)  continue;
	RAL_HASH_LOOKUP(counts, RAL_INTEGER_GRID_CELL(zones, p), &count, ral_hash_int_item);
	if (count)
	    (*count)++;
	else
	    RAL_HASH_INSERT(counts, RAL_INTEGER_GRID_CELL(zones, p), 1, ral_hash_int_item);
    }
    return counts;
 fail:
    ral_hash_destroy(&counts);
    return NULL;
}


ral_hash *ral_grid_zonal_sum(ral_grid *gd, ral_grid *zones)
{
    ral_cell p;
    ral_hash *sums = NULL;
    RAL_CHECKM(ral_grid_overlayable(gd, zones), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(zones->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ZONING_INTEGER);
    RAL_CHECK(sums = ral_hash_create(200));
    RAL_FOR(p, gd) {
	double *sum;
	if (RAL_INTEGER_GRID_NODATACELL(zones,p) OR RAL_GRID_NODATACELL(gd,p)) continue;
	RAL_HASH_LOOKUP(sums, RAL_INTEGER_GRID_CELL(zones, p), &sum, ral_hash_double_item);
	if (sum)
	    *sum += RAL_GRID_CELL(gd, p);
	else
	    RAL_HASH_INSERT(sums, RAL_INTEGER_GRID_CELL(zones, p), RAL_GRID_CELL(gd, p), ral_hash_double_item);
    }
    return sums;
 fail:
    ral_hash_destroy(&sums);
    return NULL;
}


ral_hash *ral_grid_zonal_range(ral_grid *gd, ral_grid *zones)
{
    ral_cell p;
    ral_hash *ranges = NULL;
    RAL_CHECKM(ral_grid_overlayable(gd, zones), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(zones->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ZONING_INTEGER);
    RAL_CHECK(ranges = ral_hash_create(200));
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(p, gd) {
	    ral_integer_range *range;
	    if (RAL_INTEGER_GRID_NODATACELL(zones,p) OR RAL_INTEGER_GRID_NODATACELL(gd,p)) continue;
	    RAL_HASH_LOOKUP(ranges, RAL_INTEGER_GRID_CELL(zones, p), &range, ral_hash_integer_range_item);
	    if (range) {
		range->min = min(RAL_INTEGER_GRID_CELL(gd, p), range->min);
		range->max = max(RAL_INTEGER_GRID_CELL(gd, p), range->max);
	    } else {
		ral_integer_range range;
		range.max = range.min = RAL_INTEGER_GRID_CELL(gd, p);
		RAL_HASH_INSERT(ranges, RAL_INTEGER_GRID_CELL(zones, p), range, ral_hash_integer_range_item);
	    }
	}
    } else {
	RAL_FOR(p, gd) {
	    ral_real_range *range;
	    if (RAL_REAL_GRID_NODATACELL(zones,p) OR RAL_REAL_GRID_NODATACELL(gd,p)) continue;
	    RAL_HASH_LOOKUP(ranges, RAL_REAL_GRID_CELL(zones, p), &range, ral_hash_real_range_item);
	    if (range) {
		range->min = min(RAL_REAL_GRID_CELL(gd, p), range->min);
		range->max = max(RAL_REAL_GRID_CELL(gd, p), range->max);
	    } else {
	        ral_real_range range;
		range.max = range.min = RAL_REAL_GRID_CELL(gd, p);
		RAL_HASH_INSERT(ranges, RAL_REAL_GRID_CELL(zones, p), range, ral_hash_real_range_item);
	    }
	}
    }
    return ranges;
 fail:
    ral_hash_destroy(&ranges);
    return NULL;
}


ral_hash *ral_grid_zonal_min(ral_grid *gd, ral_grid *zones)
{
    ral_cell p;
    ral_hash *mins = NULL;
    RAL_CHECKM(ral_grid_overlayable(gd, zones), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(zones->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ZONING_INTEGER);
    RAL_CHECK(mins = ral_hash_create(200));
    RAL_FOR(p, gd) {
	double *min;
	if (RAL_INTEGER_GRID_NODATACELL(zones,p) OR RAL_GRID_NODATACELL(gd,p)) continue;
	RAL_HASH_LOOKUP(mins, RAL_INTEGER_GRID_CELL(zones, p), &min, ral_hash_double_item);
	if (min) {
	    if (RAL_GRID_CELL(gd, p) < *min) *min = RAL_GRID_CELL(gd, p);
	} else {
	    RAL_HASH_INSERT(mins, RAL_INTEGER_GRID_CELL(zones, p), RAL_GRID_CELL(gd, p), ral_hash_double_item);
	}
    }
    return mins;
 fail:
    ral_hash_destroy(&mins);
    return NULL;
}


ral_hash *ral_grid_zonal_max(ral_grid *gd, ral_grid *zones)
{
    ral_cell p;
    ral_hash *maxs = NULL;
    RAL_CHECKM(ral_grid_overlayable(gd, zones), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(zones->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ZONING_INTEGER);
    RAL_CHECK(maxs = ral_hash_create(200));
    RAL_FOR(p, gd) {
	double *max;
	if (RAL_INTEGER_GRID_NODATACELL(zones,p) OR RAL_GRID_NODATACELL(gd,p)) continue;
	RAL_HASH_LOOKUP(maxs, RAL_INTEGER_GRID_CELL(zones, p), &max, ral_hash_double_item);
	if (max) {
	    if (RAL_GRID_CELL(gd, p) > *max) *max = RAL_GRID_CELL(gd, p);
	} else {
	    RAL_HASH_INSERT(maxs, RAL_INTEGER_GRID_CELL(zones, p), RAL_GRID_CELL(gd, p), ral_hash_double_item);
	}
    }
    return maxs;
 fail:
    ral_hash_destroy(&maxs);
    return NULL;
}


/*
  mean and variance are calculated recursively, the algorithm is as in Statistics::Descriptive.pm
  division by n-1 is used for variance
*/
ral_hash *ral_grid_zonal_mean(ral_grid *gd, ral_grid *zones)
{
    ral_cell p;
    ral_hash *counts = NULL, *means = NULL;
    RAL_CHECKM(ral_grid_overlayable(gd, zones), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(zones->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ZONING_INTEGER);
    RAL_CHECK(counts = ral_hash_create(200));
    RAL_CHECK(means = ral_hash_create(200));
    RAL_FOR(p, gd) {
	double *mean;
	int *n;
	if (RAL_INTEGER_GRID_NODATACELL(zones,p) OR RAL_GRID_NODATACELL(gd,p)) continue;
	RAL_HASH_LOOKUP(means, RAL_INTEGER_GRID_CELL(zones, p), &mean, ral_hash_double_item);
	if (mean) {
	    RAL_HASH_LOOKUP(counts, RAL_INTEGER_GRID_CELL(zones, p), &n, ral_hash_int_item);
	    (*n)++;
	    *mean += (RAL_GRID_CELL(gd, p) - *mean) / *n;
	} else {
	    RAL_HASH_INSERT(means, RAL_INTEGER_GRID_CELL(zones, p), RAL_GRID_CELL(gd, p), ral_hash_double_item);
	    RAL_HASH_INSERT(counts, RAL_INTEGER_GRID_CELL(zones, p), 1, ral_hash_int_item);
	}
    }
    ral_hash_destroy(&counts);
    return means;
 fail:
    ral_hash_destroy(&counts);
    ral_hash_destroy(&means);
    return NULL;
}


ral_hash *ral_grid_zonal_variance(ral_grid *gd, ral_grid *zones)
{
    ral_cell p;
    ral_hash *counts = NULL, *means = NULL, *variances = NULL;
    int i;
    RAL_CHECKM(ral_grid_overlayable(gd, zones), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(zones->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ZONING_INTEGER);
    RAL_CHECK(counts = ral_hash_create(200));
    RAL_CHECK(means = ral_hash_create(200));
    RAL_CHECK(variances = ral_hash_create(200));
    RAL_FOR(p, gd) {
	double oldmean;
	int *n;
	double *m, *variance;
	RAL_INTEGER zone;
	double data_value;
	if (RAL_INTEGER_GRID_NODATACELL(zones,p) OR RAL_GRID_NODATACELL(gd,p)) continue;
	zone = RAL_INTEGER_GRID_CELL(zones, p);
	data_value = RAL_GRID_CELL(gd, p);
	RAL_HASH_LOOKUP(variances, zone, &variance, ral_hash_double_item);
	if (variance) {
	    RAL_HASH_LOOKUP(means, zone, &m, ral_hash_double_item);
	    RAL_HASH_LOOKUP(counts, zone, &n, ral_hash_int_item);
	    (*n)++;
	    oldmean = *m;
	    *m += (data_value - oldmean) / *n;
	    *variance += (data_value - oldmean) * (data_value - *m);
	} else {
	    RAL_HASH_INSERT(variances, zone, 0, ral_hash_double_item);
	    RAL_HASH_INSERT(means, zone, data_value, ral_hash_double_item);
	    RAL_HASH_INSERT(counts, zone, 1, ral_hash_int_item);
	}
    }
    for (i = 0; i < counts->size; i++)
	if (counts->table[i]) {
	    ral_hash_int_item *a;
	    for (a = (ral_hash_int_item *)counts->table[i]; a; a = a->next) {
		double *variance;
		RAL_HASH_LOOKUP(variances, a->key, &variance, ral_hash_double_item);
		if (a->value > 1) *variance /= (a->value - 1);
	    }
	}
    ral_hash_destroy(&counts);
    ral_hash_destroy(&means);
    return variances;
 fail:
    ral_hash_destroy(&counts);
    ral_hash_destroy(&means);
    ral_hash_destroy(&variances);
    return NULL;
}


int ral_grid_zonal_contents(ral_grid *gd, ral_grid *zones, ral_hash ***table, ral_hash *index)
{
    int i = 0, n = 0;
    int overlay = ral_grid_overlayable(gd, zones);
    ral_cell c;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    /*RAL_CHECKM(ral_grid_overlayable(gd, zones), RAL_ERRSTR_ARGS_OVERLAYABLE);*/
    RAL_FOR(c, zones) {
	int *tmp;
	if (RAL_INTEGER_GRID_NODATACELL(zones, c)) continue;
	RAL_HASH_LOOKUP(index, RAL_INTEGER_GRID_CELL(zones, c), &tmp, ral_hash_int_item);
	if (!tmp) {
	    RAL_HASH_INSERT(index, RAL_INTEGER_GRID_CELL(zones, c), i, ral_hash_int_item);
	    i++;
	}
    }
    n = i;
    RAL_CHECK(*table = ral_hash_array_create(100, n));
    RAL_FOR(c, zones) {
	int *ix;
	if (RAL_INTEGER_GRID_NODATACELL(zones, c)) continue;
	RAL_HASH_LOOKUP(index, RAL_INTEGER_GRID_CELL(zones, c), &ix, ral_hash_int_item);
	if (ix) {
	    
	    if (overlay) {

		int *count;
		RAL_HASH_LOOKUP((*table)[*ix], RAL_INTEGER_GRID_CELL(gd, c), &count, ral_hash_int_item);
		if (count)
		    (*count)++;
		else
		    RAL_HASH_INSERT((*table)[*ix], RAL_INTEGER_GRID_CELL(gd, c), 1, ral_hash_int_item);

	    } else {

		ral_point p = ral_grid_cell2point(zones, c);
		ral_cell gd_c = ral_grid_point2cell(gd, p);
		
		if (RAL_GRID_CELL_IN(gd, gd_c)) {

		    int *count;
		    RAL_HASH_LOOKUP((*table)[*ix], RAL_INTEGER_GRID_CELL(gd, gd_c), &count, ral_hash_int_item);
		    if (count)
			(*count)++;
		    else
			RAL_HASH_INSERT((*table)[*ix], RAL_INTEGER_GRID_CELL(gd, gd_c), 1, ral_hash_int_item);

		}

	    }

	} else {
	    /*should never get here*/
	}
    }
    return 1;
 fail:
    ral_hash_array_destroy(table, n);
    return 0;
}


void ral_rgrow(ral_grid *zones, ral_grid *grow, ral_cell c, int connectivity)
{
    if (connectivity == 8) {
	int dir;
	for (dir = 1; dir < 9; dir++) {
	    ral_cell t = ral_cell_move(c, dir);
	    if (RAL_GRID_CELL_IN(zones, t) AND 
		RAL_INTEGER_GRID_CELL(grow, t) AND 
		RAL_INTEGER_GRID_CELL(zones, t) != RAL_INTEGER_GRID_CELL(zones, c)) {
		RAL_INTEGER_GRID_CELL(zones, t) = RAL_INTEGER_GRID_CELL(zones, c);
		ral_rgrow(zones, grow, t, connectivity);
	    }
	}
    } else {
	int dir;
	for (dir = 1; dir < 9; dir += 2) {
	    ral_cell t = ral_cell_move(c, dir);
	    if (RAL_GRID_CELL_IN(zones, t) AND 
		RAL_INTEGER_GRID_CELL(grow, t) AND
		RAL_INTEGER_GRID_CELL(zones, t) != RAL_INTEGER_GRID_CELL(zones, c)) {
		RAL_INTEGER_GRID_CELL(zones, t) = RAL_INTEGER_GRID_CELL(zones, c);
		ral_rgrow(zones, grow, t, connectivity);
	    }
	}
    }
}


int ral_grid_grow_zones(ral_grid *zones, ral_grid *grow, int connectivity)
{
    ral_cell c;
    RAL_CHECKM(zones->datatype == RAL_INTEGER_GRID AND grow->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    RAL_CHECKM(ral_grid_overlayable(zones, grow), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_FOR(c, zones) {
	if (RAL_INTEGER_GRID_NODATACELL(zones, c)) continue;
	ral_rgrow(zones, grow, c, connectivity);
    }
    return 1;
 fail:
    return 0;
}

int ral_resize_c(int **c, int oldsize, int newsize)
{
    int i, *tmp;
    if (*c == NULL) {
	RAL_CHECKM(*c = RAL_CALLOC(newsize, int), RAL_ERRSTR_OOM);
    } else {
	RAL_CHECKM(tmp = RAL_REALLOC(*c, newsize, int), RAL_ERRSTR_OOM);
	*c = tmp;
	for (i=oldsize;i<newsize;i++) (*c)[i] = 0;
    }
    return 1;
 fail:
    if (*c) free(*c);
    return 0;
}


int ral_grid_neighbors(ral_grid *gd, ral_hash ***b, int **c, int *n)
{
    ral_hash *contents = NULL;
    ral_cell d;
    int i, j;
    *b = NULL;
    *n = 0;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_CHECK(contents = ral_grid_contents(gd));
    *n = ral_hash_count(contents);
    RAL_CHECK(*b = ral_hash_array_create(100, *n));
    RAL_CHECKM(*c = RAL_CALLOC(*n, int), RAL_ERRSTR_OOM);
    j = 0;
    for (i = 0; i < contents->size; i++) {
	ral_hash_int_item *a = (ral_hash_int_item *)contents->table[i];
	while (a) {
	    (*c)[j] = a->key;
	    a->value = j;
	    j++;
	    a = a->next;
	}
    }
    RAL_FOR(d, gd) {
	int *i, z = RAL_INTEGER_GRID_CELL(gd, d), dir;
	RAL_HASH_LOOKUP(contents, z, &i, ral_hash_int_item);
	if (!i) continue;
	RAL_DIRECTIONS(dir) {
	    ral_cell t = ral_cell_move(d, dir);
	    if (RAL_GRID_CELL_IN(gd, t)) { /* MASKING!!! */
		int *na, a = RAL_INTEGER_GRID_CELL(gd, t);
		RAL_HASH_LOOKUP((*b)[*i], a, &na, ral_hash_int_item);
		if (na)
		    (*na)++;
		else
		    RAL_HASH_INSERT((*b)[*i], a, 1, ral_hash_int_item);
	    }
	}
    }
    ral_hash_destroy(&contents);
    return 1;
 fail:
    ral_hash_array_destroy(b, *n);
    ral_hash_destroy(&contents);
    return 0;
}


ral_grid *ral_grid_bufferzone(ral_grid *gd, int z, double w)
{
    ral_grid *grid;
    ral_cell c;
    int r = round(w);
    if (!(grid = ral_grid_create_like(gd, RAL_INTEGER_GRID))) return NULL;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_FOR(c, gd) {
	if (RAL_INTEGER_GRID_CELL(gd, c) == z)
	    RAL_FILLED_CIRCLE(grid, c, r, 1, RAL_INTEGER_GRID_SET_CELL);
    }
    return grid;
 fail:
    ral_grid_destroy(&grid);
    return NULL;
}


long ral_grid_count(ral_grid *gd)
{
    ral_cell c;
    long count = 0;
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		count++;
    } else {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		count++;
    }
    return count;
}


long ral_grid_count_of(ral_grid *gd, RAL_INTEGER value)
{
    ral_cell c;
    long count = 0;
    RAL_CHECKM(gd->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARG_INTEGER);
    RAL_FOR(c, gd)
	if (RAL_INTEGER_GRID_DATACELL(gd, c) AND RAL_INTEGER_GRID_CELL(gd, c) == value)
	    count++;
 fail:
    return count;
}


double ral_grid_sum(ral_grid *gd)
{
    ral_cell c;
    double sum = 0;
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c))
		sum += RAL_INTEGER_GRID_CELL(gd, c);
    } else if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c))
		sum += RAL_REAL_GRID_CELL(gd, c);
    }
    return sum;
}


double ral_grid_mean(ral_grid *gd)
{
    ral_cell c;
    double mean = 0;
    int n = 0;
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
		n++;
		mean += (RAL_INTEGER_GRID_CELL(gd, c) - mean) / n;
	    }
    } else if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c)) {
		n++;
		mean += (RAL_REAL_GRID_CELL(gd, c) - mean) / n;
	    }
    } 
    return mean;
}


double ral_grid_variance(ral_grid *gd)
{
    ral_cell c;
    double variance = 0, mean = 0;
    int n = 0;
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_INTEGER_GRID_DATACELL(gd, c)) {
		double oldmean = mean;
		n++;
		mean += (RAL_INTEGER_GRID_CELL(gd, c) - oldmean) / n;
		variance += (RAL_INTEGER_GRID_CELL(gd, c) - oldmean) * (RAL_INTEGER_GRID_CELL(gd, c) - mean);
	    }
    } else if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd)
	    if (RAL_REAL_GRID_DATACELL(gd, c)) {
		double oldmean = mean;
		n++;
		mean += (RAL_REAL_GRID_CELL(gd, c) - oldmean) / n;
		variance += (RAL_REAL_GRID_CELL(gd, c) - oldmean) * (RAL_REAL_GRID_CELL(gd, c) - mean);
	    }
    } 
    if (n > 1) variance /= (n - 1);
    return variance;
}


#define RAL_COMPARISON \
    { if (RAL_INTEGER_GRID_DATACELL(gd, x)) {				      \
	    double t = RAL_DISTANCE_BETWEEN_CELLS(c, x);	      \
	    if (d < 0 OR t < d) {				      \
		d = t;						      \
		ret = x;					      \
	    }							      \
	}							      \
    }

#define RAL_RCOMPARISON						\
    { if (RAL_REAL_GRID_DATACELL(gd, x)) {				\
	    double t = RAL_DISTANCE_BETWEEN_CELLS(c, x);	\
	    if (d < 0 OR t < d) {				\
		d = t;						\
		ret = x;					\
	    }							\
	}							\
    }


ral_cell ral_grid_nearest_neighbor(ral_grid *gd, ral_cell c)
{
    int r = 1;
    double d = -1;
    ral_cell ret = {-1, -1};
    if (gd->datatype == RAL_INTEGER_GRID) {
	/* the first candidate */
	while (d < 0 AND r < min(gd->M, gd->N)) {
	    ral_cell x;
	    int imin = c.i-r, jmin = c.j-r, imax = c.i+r+1, jmax = c.j+r+1;
	    int left = 1, right = 1, top = 1, bottom = 1;
	    if (imin < 0) {imin = 0;top = 0;}
	    if (jmin < 0) {jmin = -1;left = 0;}
	    if (imax > gd->M) {imax = gd->M;bottom = 0;}
	    if (jmax > gd->N) {jmax = gd->N+1;right = 0;}
	    if (left) {
		x.j = jmin;
		for (x.i = imin; x.i < imax; x.i++) RAL_COMPARISON;
	    }
	    if (right) {
		x.j = jmax-1;
		for (x.i = imin; x.i < imax; x.i++) RAL_COMPARISON;
	    }
	    if (top) {
		x.i = imin;
		for (x.j = jmin+1; x.j < jmax-1; x.j++) RAL_COMPARISON;
	    }
	    if (bottom) {
		x.i = imax - 1;
		for (x.j = jmin+1; x.j < jmax-1; x.j++) RAL_COMPARISON;
	    }
	    r++;
	}
	RAL_CHECKM(d >= 0, RAL_ERRSTR_NO_DATA_IN_GRID);
	/* we must now enlarge the rectangle until it is
	   larger than d and check */
	while (r < d) {
	    ral_cell x;
	    int imin = c.i-r, jmin = c.j-r, imax = c.i+r+1, jmax = c.j+r+1;
	    int left = 1, right = 1, top = 1, bottom = 1;
	    if (imin < 0) {imin = 0;top = 0;}
	    if (jmin < 0) {jmin = -1;left = 0;}
	    if (imax > gd->M) {imax = gd->M;bottom = 0;}
	    if (jmax > gd->N) {jmax = gd->N+1;right = 0;}
	    if (left) {
		x.j = jmin;
		for (x.i = imin; x.i < imax; x.i++) RAL_COMPARISON;
	    }
	    if (right) {
		x.j = jmax-1;
		for (x.i = imin; x.i < imax; x.i++) RAL_COMPARISON;
	    }
	    if (top) {
		x.i = imin;
		for (x.j = jmin+1; x.j < jmax-1; x.j++) RAL_COMPARISON;
	    }
	    if (bottom) {
		x.i = imax - 1;
		for (x.j = jmin+1; x.j < jmax-1; x.j++) RAL_COMPARISON;
	    }
	    r++;
	}
    } else if (gd->datatype == RAL_REAL_GRID) {
	while (d < 0 AND r < min(gd->M, gd->N)) {
	    ral_cell x;
	    int imin = c.i-r, jmin = c.j-r, imax = c.i+r+1, jmax = c.j+r+1;
	    int left = 1, right = 1, top = 1, bottom = 1;
	    if (imin < 0) {imin = 0;top = 0;}
	    if (jmin < 0) {jmin = -1;left = 0;}
	    if (imax > gd->M) {imax = gd->M;bottom = 0;}
	    if (jmax > gd->N) {jmax = gd->N+1;right = 0;}
	    if (left) {
		x.j = jmin;
		for (x.i = imin; x.i < imax; x.i++) RAL_RCOMPARISON;
	    }
	    if (right) {
		x.j = jmax-1;
		for (x.i = imin; x.i < imax; x.i++) RAL_RCOMPARISON;
	    }
	    if (top) {
		x.i = imin;
		for (x.j = jmin+1; x.j < jmax-1; x.j++) RAL_RCOMPARISON;
	    }
	    if (bottom) {
		x.i = imax - 1;
		for (x.j = jmin+1; x.j < jmax-1; x.j++) RAL_RCOMPARISON;
	    }
	    r++;
	}
	RAL_CHECKM(d >= 0, RAL_ERRSTR_NO_DATA_IN_GRID);
	/* we must now enlarge the rectangle until it is
	   larger than d and check */
	while (r < d) {
	    ral_cell x;
	    int imin = c.i-r, jmin = c.j-r, imax = c.i+r+1, jmax = c.j+r+1;
	    int left = 1, right = 1, top = 1, bottom = 1;
	    if (imin < 0) {imin = 0;top = 0;}
	    if (jmin < 0) {jmin = -1;left = 0;}
	    if (imax > gd->M) {imax = gd->M;bottom = 0;}
	    if (jmax > gd->N) {jmax = gd->N+1;right = 0;}
	    if (left) {
		x.j = jmin;
		for (x.i = imin; x.i < imax; x.i++) RAL_RCOMPARISON;
	    }
	    if (right) {
		x.j = jmax-1;
		for (x.i = imin; x.i < imax; x.i++) RAL_RCOMPARISON;
	    }
	    if (top) {
		x.i = imin;
		for (x.j = jmin+1; x.j < jmax-1; x.j++) RAL_RCOMPARISON;
	    }
	    if (bottom) {
		x.i = imax - 1;
		for (x.j = jmin+1; x.j < jmax-1; x.j++)RAL_RCOMPARISON;
	    }
	    r++;
	}
    } else {
	RAL_CHECKM(0, RAL_ERRSTR_DATATYPE);
    }
 fail:
    return ret;
}


ral_grid *ral_grid_distances(ral_grid *gd)
{
    ral_grid *d = NULL;
    ral_cell c;
    RAL_CHECK(d = ral_grid_create_like(gd, RAL_REAL_GRID));
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd) {
	    if (!RAL_INTEGER_GRID_DATACELL(gd, c)) {
		ral_cell nn = ral_grid_nearest_neighbor(gd, c);
		RAL_CHECK(nn.i >= 0);
		RAL_REAL_GRID_CELL(d, c) = RAL_DISTANCE_BETWEEN_CELLS(c, nn) * gd->cell_size;
	    }
	}
    } else if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd) {
	    if (!RAL_REAL_GRID_DATACELL(gd, c)) {
		ral_cell nn = ral_grid_nearest_neighbor(gd, c);
		RAL_CHECK(nn.i >= 0);
		RAL_REAL_GRID_CELL(d, c) = RAL_DISTANCE_BETWEEN_CELLS(c, nn) * gd->cell_size;
	    }
	}
    } else {
	RAL_CHECKM(0, RAL_ERRSTR_DATATYPE);
    }
    return d;
 fail:
    ral_grid_destroy(&d);
    return NULL;
}


ral_grid *ral_grid_directions(ral_grid *gd)
{
    ral_grid *d = NULL;
    ral_cell c;
    RAL_CHECK(d = ral_grid_create_like(gd, RAL_REAL_GRID));
    if (gd->datatype == RAL_INTEGER_GRID) {
	RAL_FOR(c, gd) {
	    if (!RAL_INTEGER_GRID_DATACELL(gd, c)) {
		ral_cell nn = ral_grid_nearest_neighbor(gd, c);
		RAL_CHECK(nn.i >= 0);
		RAL_REAL_GRID_CELL(d, c) = atan2(c.i-nn.i, nn.j-c.j);
	    }
	}
    } else if (gd->datatype == RAL_REAL_GRID) {
	RAL_FOR(c, gd) {
	    if (!RAL_REAL_GRID_DATACELL(gd, c)) {
		ral_cell nn = ral_grid_nearest_neighbor(gd, c);
		RAL_CHECK(nn.i >= 0);
		RAL_REAL_GRID_CELL(d, c) = atan2(c.i-nn.i, nn.j-c.j);
	    }
	}
    } else {
	RAL_CHECKM(0, RAL_ERRSTR_DATATYPE);
    }
    return d;
 fail:
    ral_grid_destroy(&d);
    return NULL;
}


ral_grid *ral_grid_nn(ral_grid *gd)
{
    ral_cell c;
    ral_grid *n = NULL;
    RAL_CHECK(n = ral_grid_create_copy(gd, 0));
    switch (gd->datatype) {
    case RAL_INTEGER_GRID: {
	RAL_FOR(c, gd) {
	    if (!RAL_INTEGER_GRID_DATACELL(gd, c)) {
		ral_cell nn = ral_grid_nearest_neighbor(gd, c);
		RAL_CHECK(nn.i >= 0);
		RAL_INTEGER_GRID_CELL(n, c) = RAL_INTEGER_GRID_CELL(n, nn);
	    }
	}
	break;
    } 
    case RAL_REAL_GRID: {
	RAL_FOR(c, gd) {
	    if (!RAL_REAL_GRID_DATACELL(gd, c)) {
		ral_cell nn = ral_grid_nearest_neighbor(gd, c);
		RAL_CHECK(nn.i >= 0);
		RAL_REAL_GRID_CELL(n, c) = RAL_REAL_GRID_CELL(n, nn);
	    }
	}
    }
    }
    return n;
 fail:
    ral_grid_destroy(&n);
    return NULL;
}

int ral_grid_zones(ral_grid *gd, ral_grid *z, double ***tot, int **c, int **k, int *n)
{
    ral_cell d;
    int i, j, *itot = NULL;
    ral_hash *table = NULL;
    RAL_CHECKM(ral_grid_overlayable(gd, z), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECK(table = ral_grid_contents(z));
    *n = ral_hash_count(table);
    RAL_CHECKM(*tot = RAL_CALLOC(*n, double *), RAL_ERRSTR_OOM);
    RAL_CHECKM(itot = RAL_CALLOC(*n, int), RAL_ERRSTR_OOM);
    RAL_CHECKM(*c = RAL_CALLOC(*n, int), RAL_ERRSTR_OOM);
    RAL_CHECKM(*k = RAL_CALLOC(*n, int), RAL_ERRSTR_OOM);
    j = 0;
    for (i = 0; i < table->size; i++) {
	ral_hash_int_item *a = (ral_hash_int_item *)table->table[i];
	while (a) {
	    (*c)[j] = a->key;
	    (*k)[j] = a->value;
	    a->value = j;
	    j++;
	    a = a->next;
	}
    }
    for (i = 0; i < *n; i++) {
	RAL_CHECKM((*tot)[i] = RAL_CALLOC((*k)[i], double), RAL_ERRSTR_OOM);
    }
    RAL_FOR(d, z) {
	if (RAL_INTEGER_GRID_DATACELL(z, d) AND RAL_GRID_DATACELL(gd, d)) {
	    int *value;
	    RAL_HASH_LOOKUP(table, RAL_INTEGER_GRID_CELL(z, d), &value, ral_hash_int_item);
	    if (value) {
		(*tot)[*value][itot[*value]] = RAL_GRID_CELL(gd, d);
		itot[*value]++;
	    }
	}
    }
    for (i = 0; i < *n; i++) 
	(*k)[i] = itot[i];
    free(itot);
    return 1;
 fail:
    if (**tot) {
	for (i = 0; i < *n; i++)
	    if ((*tot)[i]) free((*tot)[i]);
	free(**tot);
    }
    if (itot) free(itot);
    if (*c) free(*c);
    if (*k) free(*k);
    return 0;
}

/* from wikipedia.org */

#define RAL_INFINITY 10e9

typedef struct {
    float weight;
    int dest;
} ral_DijkEdge;

typedef struct {
    ral_DijkEdge* connections; /* An array of edges which has this as the starting node */
    int numconnect;
    float distance;
    int isDead;
} ral_DijkVertex;

void ral_Dijkstra(ral_DijkVertex *graph, int nodecount, int source) 
{
    int i;
    for(i = 0; i < nodecount; i++) {
        if(i == source) {
            graph[i].distance = 0;
            graph[i].isDead = 0;
        } else {
            graph[i].distance = RAL_INFINITY;
            graph[i].isDead = 0;
         }
    }
    for(i = 0; i < nodecount; i++) {
        int next = 0;
        float min = 2*RAL_INFINITY;
	int j;
        for(j = 0; j < nodecount; j++) {
            if(!graph[j].isDead AND graph[j].distance < min) {
                next = j;
                min = graph[j].distance;
            }
        }
        for(j = 0; j < graph[next].numconnect; j++) {
            if(graph[graph[next].connections[j].dest].distance >
               graph[next].distance + graph[next].connections[j].weight)
            {
                graph[graph[next].connections[j].dest].distance =
                    graph[next].distance + graph[next].connections[j].weight;
            }
        }
        graph[next].isDead = 1;
    }
}

ral_grid *ral_grid_dijkstra(ral_grid *w, ral_cell c)
{
    /* 
       in w are the weights, i,j is the destination 
       the cost to travel from a ral_cell a to neighboring ral_cell b in w is the value
       of w at a times 0.5 or sqrt(2)/2 + value of w at b times 0.5 or sqrt(2)/2
       if the value at w is < 1 the ral_cell cannot be entered
    */
    /* put to graph all cells in w having value > 1 */
    int nodecount = 0;
    int source = -1;
    ral_DijkVertex *graph = NULL;
    int *cell2node = NULL;
    int node;

    ral_grid *cost = NULL;

    RAL_CHECK(cost = ral_grid_create_like(w, RAL_REAL_GRID));
    ral_grid_set_all_integer(cost, -1);
    RAL_REAL_GRID_CELL(cost, c) = 0;

    RAL_CHECKM(cell2node = RAL_CALLOC(w->M*w->N, int), RAL_ERRSTR_OOM);
    {
	ral_cell d;
	RAL_FOR(d, w) {
	    if (RAL_GRID_CELL(w, d) >= 1) {
		cell2node[RAL_GRID_INDEX(d.i, d.j, w->N)] = nodecount;
		if ((d.i == c.i) AND (d.j == c.j)) source = nodecount;
		nodecount++;
	    } else {
		cell2node[RAL_GRID_INDEX(d.i, d.j, w->N)] = -1;
	    }
	}
    }
    RAL_CHECKM(graph = RAL_CALLOC(nodecount, ral_DijkVertex), RAL_ERRSTR_OOM);
    
    for (node = 0; node < nodecount; node++)
	graph[node].connections = NULL;
    node = 0;

    RAL_FOR(c, w) {
	if (RAL_GRID_CELL(w, c) >= 1) {
	    int dir;
	    graph[node].numconnect = 0;
	    RAL_DIRECTIONS(dir) {
		ral_cell d = ral_cell_move(c, dir);
		if (RAL_GRID_CELL_IN(w, d) AND (RAL_GRID_CELL(w, d) >= 1))
		    graph[node].numconnect++;
	    }
	    if (graph[node].numconnect) {
		int connect = 0;
		RAL_CHECKM(graph[node].connections = 
			   RAL_CALLOC(graph[node].numconnect, ral_DijkEdge), RAL_ERRSTR_OOM);
		RAL_DIRECTIONS(dir) {
		    ral_cell d = ral_cell_move(c, dir);
		    if (RAL_GRID_CELL_IN(w, d) AND (RAL_GRID_CELL(w, d) >= 1)) {
			/* weight to go from c -> d */
			graph[node].connections[connect].weight = 
			    RAL_DISTANCE_UNIT(dir)/2 * (RAL_GRID_CELL(w, c) + RAL_GRID_CELL(w, d));
			graph[node].connections[connect].dest = cell2node[RAL_GRID_INDEX(d.i, d.j, w->N)];
			connect++;
		    }
		}
	    }
	    node++;
	}
    }

    if (source >= 0) 
	ral_Dijkstra(graph, nodecount, source);

    RAL_FOR(c, cost) {
	if (cell2node[RAL_GRID_INDEX(c.i, c.j, cost->N)] >= 0)
	    RAL_REAL_GRID_CELL(cost, c) = graph[cell2node[RAL_GRID_INDEX(c.i, c.j, cost->N)]].distance;
	else 
	    RAL_REAL_GRID_CELL(cost, c) = -1;
    }

    goto ok;
 fail:
    ral_grid_destroy(&cost);
 ok:
    if (cell2node) free(cell2node);
    if (graph) {
	for (node = 0; node < nodecount; node++) {
	    if (graph[node].connections) free(graph[node].connections);
	}
	free(graph);
    }
    return cost;
}

int ral_grid_print(ral_grid *gd)
{
    int i, j;
    if (gd->datatype == RAL_INTEGER_GRID) {
	for (i = 0; i < gd->M; i++) {
	    for (j = 0; j < gd->N; j++) {
		printf("%i ",RAL_INTEGER_GRID_AT(gd, i, j));
	    }
	    printf("\n");
	}
    } else if (gd->datatype == RAL_REAL_GRID) {
	for (i = 0; i < gd->M; i++) {
	    for (j = 0; j < gd->N; j++) {
		printf("%f ",RAL_REAL_GRID_AT(gd, i, j));
	    }
	    printf("\n");
	}
    } 
    return 1;
}

int ral_grid_save_ascii(ral_grid *gd, char *outfile)
{
    const char *fct = "ral_gd2a";
    FILE *f = fopen(outfile,"w");
    if (!f) {
	fprintf(stderr,"%s: %s: %s\n", fct, outfile, strerror(errno)); 
	return 0;
    }
    /* the header */
    fprintf(f,"ncols         %i\n",gd->N);
    fprintf(f,"nrows         %i\n",gd->M);
    fprintf(f,"xllcorner     %lf\n",gd->world.min.x);
    fprintf(f,"yllcorner     %lf\n",gd->world.min.y);
    fprintf(f,"cellsize      %lf\n",gd->cell_size);

    switch (gd->datatype) {
    case RAL_INTEGER_GRID: {
	ral_cell c;
	fprintf(f,"NODATA_value  %i\n", RAL_INTEGER_GRID_NODATA_VALUE(gd));
	for (c.i = 0; c.i < gd->M; c.i++) {
	    for (c.j = 0; c.j < gd->N; c.j++) {
		fprintf(f,"%i ",RAL_INTEGER_GRID_CELL(gd, c));
	    }
	    fprintf(f,"\n");
	}
	break;
    } 
    case RAL_REAL_GRID: {
	ral_cell c;
	fprintf(f,"NODATA_value  %f\n", RAL_REAL_GRID_NODATA_VALUE(gd));
	for (c.i = 0; c.i < gd->M; c.i++) {
	    for (c.j = 0; c.j < gd->N; c.j++) {
		fprintf(f,"%f ",RAL_REAL_GRID_CELL(gd, c));
	    }
	    fprintf(f,"\n");
	}
    }
    }

    fclose(f);
    return 1;
}
