#ifndef RAL_GRID_H
#define RAL_GRID_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <math.h>

/**\file ral/grid.h
   \brief a grid structure and methods

   The coordinate system of a grid is (i=0, j=0) is top left, height
   or i = 0..M-1, width or j = 0..N-1. (x=0, y=0) is bottom left
   corner of bottom left cell. This library works on logical
   datatypes: a grid is either an integer grid or real number grid, it
   is up to the user (the one compiling libral) to decide which actual
   datatypes to use. Other logical datatypes that one might want are
   boolean and complex number but these are not even planned for now.

   Generally, if macro or function specifies integer or real grid then
   it expects an integer or real grid and may not check it. In
   constructors integer or real refers to the type of the constructed
   grid.

   Many methods work in-place, i.e., change the parameter grid (self).
   All comparison operations silently transform the first argument
   REAL grid into an INTEGER (functionally a boolean) grid.
*/

#define RAL_MSG_BUF_SIZE 1024

#define RAL_MALLOC(type) (type*)malloc(sizeof(type))
#define RAL_CALLOC(count, type) (type*)calloc((count), sizeof(type))
#define RAL_REALLOC(pointer, count, type) (type*)realloc((pointer), (count)*sizeof(type))
#define RAL_FREE(pointer) { if(pointer){ free(pointer); pointer = NULL; } }

/**
   check if an exception has happened which has created a message already
*/
#define RAL_CHECK(test) { if (!(test)) { goto fail; } }

/**
   generate an exception with a message
*/
#ifdef MSVC
#define RAL_CHECKM(test, msg) { if (!(test)) { \
    ral_set_msg(msg); \
    goto fail; } }
#else
#define RAL_CHECKM(test, msg) { if (!(test)) { \
    char tmp[RAL_MSG_BUF_SIZE]; \
    snprintf(tmp, RAL_MSG_BUF_SIZE-1, "%s: %s", __PRETTY_FUNCTION__, msg); \
    ral_set_msg(tmp); \
    goto fail; } }
#endif

#ifdef RAL_HAVE_GDAL
/** a function that can be installed as a CPLErrorHandler and that reports GDAL errors as ral msg's */
void CPL_DLL CPL_STDCALL ral_cpl_error(CPLErr eclass, int code, const char *msg);
#endif

typedef char *string_handle;

void RAL_CALL ral_set_msg(char *msg);

string_handle RAL_CALL ral_msg(const char *format, ...);

/** check for exceptions, use this outside libral or in main */
int RAL_CALL ral_has_msg();

/** get the message and clear the exception flag, if exception flag is not on, returns NULL */
string_handle RAL_CALL ral_get_msg();

#define AND &&
#define OR ||

#define SQRT2 1.414213562

#define RAL_EPSILON 1.0E-6

#define EVEN(a) ((a) % 2 == 0)
#undef ODD
#define ODD(n) ((n) & 1)

#undef max
#define max(x, y) ((x)>(y) ? (x) : (y))
#undef min
#define min(x, y) ((x)<(y) ? (x) : (y))

#define swap(a, b, temp) \
    {(temp) = (a);(a) = (b);(b) = (temp);}

#define round(x) \
    ((x)<0 ? ((long)((x)-0.5)) : ((long)((x)+0.5)))

/** data type constants,
    INTEGER, INTEGER_MIN, INTEGER_MAX, and REAL are defined in ral_config.h
*/
#define RAL_INTEGER_GRID 1
#define RAL_REAL_GRID 2

/**\brief address of a cell of a grid */
typedef struct {
    int i;
    int j;
} ral_cell;

typedef ral_cell *ral_cell_handle;

#define RAL_SAME_CELL(a, b) \
    ((a).i == (b).i AND (a).j == (b).j)

#define RAL_DISTANCE_BETWEEN_CELLS(a, b) \
    (sqrt(((double)((b).i)-(double)((a).i)) * \
	   ((double)((b).i)-(double)((a).i)) + \
	   ((double)((b).j)-(double)((a).j)) * \
	   ((double)((b).j)-(double)((a).j))))

ral_cell_handle RAL_CALL ral_cell_create();
void RAL_CALL ral_cell_destroy(ral_cell **c);

/**\brief window in a grid */
typedef struct {
    ral_cell up_left; 
    ral_cell down_right;
} ral_window;

#define RAL_WINDOW_HEIGHT(w) ((w).down_right.i-(w).up_left.i+1)
#define RAL_WINDOW_WIDTH(w) ((w).down_right.j-(w).up_left.j+1)

#define RAL_N 1
#define RAL_NE 2
#define RAL_E 3
#define RAL_SE 4
#define RAL_S 5
#define RAL_SW 6
#define RAL_W 7
#define RAL_NW 8

#define RAL_FLAT_AREA -1
#define RAL_PIT_CELL 0

#define RAL_DIRECTIONS(dir) \
    for ((dir) = 1; (dir) < 9; (dir)++)

#define RAL_DISTANCE_UNIT(dir) \
    (EVEN((dir)) ? SQRT2 : 1)

/** 1 up, 2 up-right, 3 right, 4 down-right, etc */
ral_cell RAL_CALL ral_cell_move(ral_cell c, int dir); 

/** 1: b is straigt up from a, ... */
int RAL_CALL ral_cell_dir(ral_cell a, ral_cell b); 

#define RAL_NEXT_DIR(d) \
    ((d) > 7 ? 1 : (d) + 1)

#define RAL_PREV_DIR(d) \
    ((d) > 1 ? (d) - 1 : 8)

#define RAL_INV_DIR(d) \
    ((d) > 4 ? (d) - 4 : (d) + 4)

/**\brief rectangular grid of integer or real values for geospatial data */
typedef struct ral_grid {
    /** this is assumed always to be a valid type */
    int datatype;
    /** height or rows */
    int M;
    /** width or columns */
    int N;
    /** cell width == cell height */
    double cell_size;
    /** min.x is the left edge of first cell in line,
       max.x is the right edge of the last cell in a line */
    ral_rectangle world;
    /** null or a pointer to RAL_INTEGER or RAL_REAL */
    void *nodata_value;
    /** may be NULL only if M == N == 0 */
    void *data;
    /** masks only a part of the grid for operations */
    struct ral_grid *mask;
} ral_grid;

typedef ral_grid *ral_grid_handle;

/** the main costructor, cell_size, world, and nodata_value are left to default values
    created grid is integer grid unless datatype == RAL_REAL_GRID
 */
ral_grid_handle RAL_CALL ral_grid_create(int datatype, int M, int N);

/** an exact copy except data is not copied,
    returned grid is of same type as gd unless datatype is non-zero and differs from that of gd
*/
ral_grid_handle RAL_CALL ral_grid_create_like(ral_grid *gd, int datatype);

/** an exact copy,
   rounding may cause a failure,
   returned grid is of same type as gd unless datatype is non-zero
*/
ral_grid_handle RAL_CALL ral_grid_create_copy(ral_grid *gd, int datatype);

void RAL_CALL ral_grid_destroy(ral_grid **gd);

#ifdef RAL_HAVE_GDAL
/** gets a piece of a GDAL raster by GDALRasterIO,
    creates either a RAL_INTEGER or RAL_REAL grid,
    returns NULL with error message or 
    NULL without an error if the clip_region does not overlap datasets bbox
*/
ral_grid_handle RAL_CALL ral_grid_create_using_GDAL(GDALDatasetH dataset, int band, ral_rectangle clip_region, double cell_size);
#endif

/** write the contents of the raster into a binary file, does _not_ create a header file
 */
int RAL_CALL ral_grid_write(ral_grid *gd, char *filename);

int RAL_CALL ral_grid_get_height(ral_grid *gd);
int RAL_CALL ral_grid_get_width(ral_grid *gd);
int RAL_CALL ral_grid_get_datatype(ral_grid *gd);

double RAL_CALL ral_grid_get_cell_size(ral_grid *gd);
ral_rectangle RAL_CALL ral_grid_get_world(ral_grid *gd);

int RAL_CALL ral_grid_has_nodata_value(ral_grid *gd);

/** if user asks for integer nodata_value from a real grid,
    the answer is a rounded real value which may fail
*/
int RAL_CALL ral_grid_get_integer_nodata_value(ral_grid *gd, RAL_INTEGER *nodata_value);
int RAL_CALL ral_grid_get_real_nodata_value(ral_grid *gd, RAL_REAL *nodata_value);

/** rounding may be done
 */
int RAL_CALL ral_grid_set_integer_nodata_value(ral_grid *gd, RAL_INTEGER nodata_value);
int RAL_CALL ral_grid_set_real_nodata_value(ral_grid *gd, RAL_REAL nodata_value);

void RAL_CALL ral_grid_remove_nodata_value(ral_grid *gd);

ral_grid_handle RAL_CALL ral_grid_get_mask(ral_grid *gd);
void RAL_CALL ral_grid_set_mask(ral_grid *gd, ral_grid *mask);
void RAL_CALL ral_grid_clear_mask(ral_grid *gd);


#define RAL_FOR(c, gd) \
    for((c).i=0;(c).i<(gd)->M;(c).i++) for((c).j=0;(c).j<(gd)->N;(c).j++) \
    if (!(gd)->mask OR (RAL_GRID_CELL_IN((gd)->mask, (c)) AND RAL_INTEGER_GRID_CELL((gd)->mask, (c))))

#define RAL_GRID_INDEX(i, j, N) (j)+(N)*(i)

#define RAL_INTEGER_GRID_AT(gd, i, j) \
    (((RAL_INTEGER *)((gd)->data))[RAL_GRID_INDEX((i),(j),((gd)->N))])

#define RAL_REAL_GRID_AT(gd, i, j) \
    (((RAL_REAL *)((gd)->data))[RAL_GRID_INDEX((i),(j),((gd)->N))])

#define RAL_INTEGER_GRID_CELL(gd, c) \
    (((RAL_INTEGER *)((gd)->data))[RAL_GRID_INDEX(((c).i),((c).j),((gd)->N))])

#define RAL_REAL_GRID_CELL(gd, c) \
    (((RAL_REAL *)((gd)->data))[RAL_GRID_INDEX(((c).i),((c).j),((gd)->N))])

#define RAL_GRID_CELL(gd, c) \
    ((gd)->datatype == RAL_INTEGER_GRID ? RAL_INTEGER_GRID_CELL(gd, c) : RAL_REAL_GRID_CELL(gd, c))

#define RAL_GRID_CELL_IN(gd, c) \
    ((c).i >= 0 AND (c).j >= 0 AND (c).i < (gd)->M AND (c).j < (gd)->N)

#define RAL_GRID_CELL_OUT(gd, c) \
    ((c).i < 0 OR (c).j < 0 OR (c).i >= (gd)->M OR (c).j >= (gd)->N)

#define RAL_INTEGER_GRID_NODATA_VALUE(gd) ((gd)->nodata_value ? *((RAL_INTEGER *)((gd)->nodata_value)) : 0)

#define RAL_REAL_GRID_NODATA_VALUE(gd) ((gd)->nodata_value ? *((RAL_REAL *)((gd)->nodata_value)) : 0)

#define RAL_GRID_NODATA_VALUE(gd) \
    ((gd)->datatype == RAL_INTEGER_GRID ? RAL_INTEGER_GRID_NODATA_VALUE(gd) : RAL_REAL_GRID_NODATA_VALUE(gd))

#define RAL_INTEGER_GRID_DATACELL(gd, c) \
    ((gd)->nodata_value ? (RAL_INTEGER_GRID_CELL((gd), (c)) != RAL_INTEGER_GRID_NODATA_VALUE(gd)) : TRUE)

#define RAL_REAL_GRID_DATACELL(gd, c) \
    ((gd)->nodata_value ? (RAL_REAL_GRID_CELL((gd), (c)) != RAL_REAL_GRID_NODATA_VALUE(gd)) : TRUE)

#define RAL_GRID_DATACELL(gd, c) \
    ((gd)->nodata_value ? \
        ((gd)->datatype == RAL_INTEGER_GRID ? \
            (RAL_INTEGER_GRID_CELL((gd), (c)) != RAL_INTEGER_GRID_NODATA_VALUE(gd)) : \
            (RAL_REAL_GRID_CELL((gd), (c)) != RAL_REAL_GRID_NODATA_VALUE(gd))) : TRUE)

#define RAL_GRID_NODATACELL(gd, c) \
    ((gd)->nodata_value ? \
        ((gd)->datatype == RAL_INTEGER_GRID ? RAL_INTEGER_GRID_NODATACELL(gd, c) : \
            RAL_REAL_GRID_NODATACELL(gd, c)) : FALSE)

#define RAL_INTEGER_GRID_NODATACELL(gd, c) (!(RAL_INTEGER_GRID_DATACELL(gd, c)))

#define RAL_REAL_GRID_NODATACELL(gd, c) (!(RAL_REAL_GRID_DATACELL(gd, c)))

#define RAL_GRID_POINT_IN(gd, p) \
    ((p).x >= (gd)->world.min.x AND (p).y >= (gd)->world.min.y AND \
     (p).x <= (gd)->world.max.x AND (p).y <= (gd)->world.max.y)

#define RAL_GRID_POINT_OUT(gd, p) \
    ((p).x < (gd)->world.min.x OR (p).y < (gd)->world.min.y OR \
     (p).x > (gd)->world.max.x OR (p).y > (gd)->world.max.y)

/** result is misleading unless gd->nodata_value! should assert.. */
#define RAL_INTEGER_GRID_SETNODATACELL(gd, c) \
    (RAL_INTEGER_GRID_CELL((gd), (c)) = (gd)->nodata_value ? *((RAL_INTEGER *)((gd)->nodata_value)) : 0)

/** result is misleading unless gd->nodata_value! should assert.. */
#define RAL_REAL_GRID_SETNODATACELL(gd, c) \
    (RAL_REAL_GRID_CELL((gd), (c)) = (gd)->nodata_value ? *((RAL_REAL *)((gd)->nodata_value)) : 0)

/** coerces the grid into a new data_type */
int RAL_CALL ral_grid_coerce(ral_grid *gd, int data_type);

/** are the two grids of same size and of (approximately) from same geographical area */
int RAL_CALL ral_grid_overlayable(ral_grid *g1, ral_grid *g2);

void RAL_CALL ral_grid_set_bounds_csnn(ral_grid *gd, double cell_size, double minX, double minY);
void RAL_CALL ral_grid_set_bounds_csnx(ral_grid *gd, double cell_size, double minX, double maxY);
void RAL_CALL ral_grid_set_bounds_csxn(ral_grid *gd, double cell_size, double maxX, double minY);
void RAL_CALL ral_grid_set_bounds_csxx(ral_grid *gd, double cell_size, double maxX, double maxY);
void RAL_CALL ral_grid_set_bounds_nxn(ral_grid *gd, double minX, double maxX, double minY);
void RAL_CALL ral_grid_set_bounds_nxx(ral_grid *gd, double minX, double maxX, double maxY);
void RAL_CALL ral_grid_set_bounds_nnx(ral_grid *gd, double minX, double minY, double maxY);
void RAL_CALL ral_grid_set_bounds_xnx(ral_grid *gd, double maxX, double minY, double maxY);

void RAL_CALL ral_grid_copy_bounds(ral_grid *from, ral_grid *to);

/** exactly at maxX returns M, and at maxY returns N 
    no checks: the cell and point may well be outside of the grid world
*/
ral_cell RAL_CALL ral_grid_point2cell(ral_grid *gd, ral_point p);

/** the returned point is the center of the cell */
ral_point RAL_CALL ral_grid_cell2point(ral_grid *gd, ral_cell c);

/** the returned point is the up left corner of the cell */
ral_point RAL_CALL ral_grid_cell2point_upleft(ral_grid *gd, ral_cell c);

int RAL_CALL ral_grid_get_real(ral_grid *gd, ral_cell c, RAL_REAL *x);
int RAL_CALL ral_grid_get_integer(ral_grid *gd, ral_cell c, RAL_INTEGER *x);
int RAL_CALL ral_grid_set_real(ral_grid *gd, ral_cell c, RAL_REAL x);
int RAL_CALL ral_grid_set_integer(ral_grid *gd, ral_cell c, RAL_INTEGER x);
int RAL_CALL ral_grid_set_nodata(ral_grid *gd, ral_cell c);

int RAL_CALL ral_grid_set_all_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_grid_set_all_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_set_all_nodata(ral_grid *gd);

ral_grid_handle RAL_CALL ral_grid_round(ral_grid *gd);

typedef void *ral_handle;

ral_handle RAL_CALL ral_grid_get_focal(ral_grid *gd, ral_cell c, int d);
void RAL_CALL ral_grid_set_focal(ral_grid *gd, ral_cell c, void *x, int *mask, int d);

/** focal method: mask is a 1+2*delta x 1+2*delta sized 0/1 raster, organized left->right, top->down 
    @return the number of cell values used for computing the sum
*/
int RAL_CALL ral_integer_grid_focal_sum(ral_grid *grid, ral_cell cell, int *mask, int delta, int *sum);

/** focal method: mask is a 1+2*delta x 1+2*delta sized 0/1 raster, organized left->right, top->down 
    @return the number of cell values used for computing the sum
*/
int RAL_CALL ral_real_grid_focal_sum(ral_grid *grid, ral_cell cell, int *mask, int delta, double *sum);

/** focal method: mask is a 1+2*delta x 1+2*delta sized 0/1 raster, organized left->right, top->down
    @return the number of cell values used for computing the mean
*/
int RAL_CALL ral_grid_focal_mean(ral_grid *grid, ral_cell cell, int *mask, int delta, double *mean);

/** focal method: mask is a 1+2*delta x 1+2*delta sized 0/1 raster, organized left->right, top->down 
    @return the number of cell values used for computing the variance
*/
int RAL_CALL ral_grid_focal_variance(ral_grid *grid, ral_cell cell, int *mask, int delta, double *variance);

/** focal method: mask is a 1+2*delta x 1+2*delta sized 0/1 raster, organized left->right, top->down 
    @return the number of cells with defined values
*/
int RAL_CALL ral_grid_focal_count(ral_grid *grid, ral_cell cell, int *mask, int delta);

/** focal method: mask is a 1+2*delta x 1+2*delta sized 0/1 raster, organized left->right, top->down 
    This method is defined only for integer grids.
    @return the number of cells with specified value
*/
int RAL_CALL ral_grid_focal_count_of(ral_grid *grid, ral_cell cell, int *mask, int delta, RAL_INTEGER value);

/** focal method: mask is a 1+2*delta x 1+2*delta sized 0/1 raster, organized left->right, top->down
    Computes the range of the values of the cells with values.
    @return the number of cell values used for computing the range
*/
int RAL_CALL ral_integer_grid_focal_range(ral_grid *grid, ral_cell cell, int *mask, int delta, ral_integer_range *range);

/** focal method: mask is a 1+2*delta x 1+2*delta sized 0/1 raster, organized left->right, top->down 
    Computes the range of the values of the cells with values.
    @return the number of cell values used for computing the range
*/
int RAL_CALL ral_real_grid_focal_range(ral_grid *grid, ral_cell cell, int *mask, int delta, ral_real_range *range);

/** focal method: kernel is a 1+2*delta x 1+2*delta sized 0/1 raster, organized left->right, top->down 
    @return the number of cell values used for computing the g value
*/
int RAL_CALL ral_grid_convolve(ral_grid *grid, ral_cell cell, double *kernel, int delta, double *g);

ral_grid_handle RAL_CALL ral_grid_focal_sum_grid(ral_grid *grid, int *mask, int delta);
ral_grid_handle RAL_CALL ral_grid_focal_mean_grid(ral_grid *grid, int *mask, int delta);
ral_grid_handle RAL_CALL ral_grid_focal_variance_grid(ral_grid *grid, int *mask, int delta);
ral_grid_handle RAL_CALL ral_grid_focal_count_grid(ral_grid *grid, int *mask, int delta);
ral_grid_handle RAL_CALL ral_grid_focal_count_of_grid(ral_grid *grid, int *mask, int delta, RAL_INTEGER value);

/** spread the values at each cell according to the weights mask */
ral_grid_handle RAL_CALL ral_grid_spread(ral_grid *grid, double *mask, int delta);
/** spread the individuals at each cell to their neighborhood; defined only for integer grids */
ral_grid_handle RAL_CALL ral_grid_spread_random(ral_grid *grid, double *mask, int delta);

ral_grid_handle RAL_CALL ral_grid_convolve_grid(ral_grid *grid, double *kernel, int delta);

int RAL_CALL ral_integer_grid_get_value_range(ral_grid *gd, ral_integer_range *range);
int RAL_CALL ral_real_grid_get_value_range(ral_grid *gd, ral_real_range *range);

/** makes a binary grid: 1: there is data (GD_DATACELL), 0: there is no data */
int RAL_CALL ral_grid_data(ral_grid *gd);

int RAL_CALL ral_grid_not(ral_grid *gd);
int RAL_CALL ral_grid_and_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_or_grid(ral_grid *gd1, ral_grid *gd2);

int RAL_CALL ral_grid_add_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_add_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_grid_add_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_sub_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_mult_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_mult_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_grid_mult_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_div_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_div_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_real_div_grid(RAL_REAL x, ral_grid *gd);
int RAL_CALL ral_integer_div_grid(RAL_INTEGER x, ral_grid *gd);
int RAL_CALL ral_grid_div_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_modulus_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_integer_modulus_grid(RAL_INTEGER x, ral_grid *gd);
int RAL_CALL ral_grid_modulus_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_power_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_real_power_grid(RAL_REAL x, ral_grid *gd);
int RAL_CALL ral_grid_power_grid(ral_grid *gd1, ral_grid *gd2);

int RAL_CALL ral_grid_abs(ral_grid *gd);
int RAL_CALL ral_grid_acos(ral_grid *gd);
int RAL_CALL ral_grid_atan(ral_grid *gd);
int RAL_CALL ral_grid_atan2(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_ceil(ral_grid *gd);
int RAL_CALL ral_grid_cos(ral_grid *gd);
int RAL_CALL ral_grid_cosh(ral_grid *gd);
int RAL_CALL ral_grid_exp(ral_grid *gd);
int RAL_CALL ral_grid_floor(ral_grid *gd);
int RAL_CALL ral_grid_log(ral_grid *gd);
int RAL_CALL ral_grid_log10(ral_grid *gd);
int RAL_CALL ral_grid_pow_real(ral_grid *gd, RAL_REAL b);
int RAL_CALL ral_grid_pow_integer(ral_grid *gd, RAL_INTEGER b);
int RAL_CALL ral_grid_sin(ral_grid *gd);
int RAL_CALL ral_grid_sinh(ral_grid *gd);
int RAL_CALL ral_grid_sqrt(ral_grid *gd);
int RAL_CALL ral_grid_tan(ral_grid *gd);
int RAL_CALL ral_grid_tanh(ral_grid *gd);

int RAL_CALL ral_grid_lt_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_gt_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_le_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_ge_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_eq_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_ne_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_cmp_real(ral_grid *gd, RAL_REAL x);

int RAL_CALL ral_grid_lt_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_grid_gt_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_grid_le_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_grid_ge_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_grid_eq_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_grid_ne_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_grid_cmp_integer(ral_grid *gd, RAL_INTEGER x);

int RAL_CALL ral_grid_lt_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_gt_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_le_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_ge_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_eq_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_ne_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_cmp_grid(ral_grid *gd1, ral_grid *gd2);

int RAL_CALL ral_grid_min_real(ral_grid *gd, RAL_REAL x);
int RAL_CALL ral_grid_max_real(ral_grid *gd, RAL_REAL x);

int RAL_CALL ral_grid_min_integer(ral_grid *gd, RAL_INTEGER x);
int RAL_CALL ral_grid_max_integer(ral_grid *gd, RAL_INTEGER x);

int RAL_CALL ral_grid_min_grid(ral_grid *gd1, ral_grid *gd2);
int RAL_CALL ral_grid_max_grid(ral_grid *gd1, ral_grid *gd2);

/** the new value of each cell is a random portion of that value using uniform distribution [0..1] */
void RAL_CALL ral_grid_random(ral_grid *gd);

ral_grid_handle RAL_CALL ral_grid_cross(ral_grid *a, ral_grid *b);

/** if a then b = c */
int RAL_CALL ral_grid_if_then_real(ral_grid *a, ral_grid *b, RAL_REAL c);
/** if a then b = c */
int RAL_CALL ral_grid_if_then_integer(ral_grid *a, ral_grid *b, RAL_INTEGER c);
/** if a then b = c else d */
int RAL_CALL ral_grid_if_then_else_real(ral_grid *a, ral_grid *b, RAL_REAL c, RAL_REAL d);
/** if a then b = c else d */
int RAL_CALL ral_grid_if_then_else_integer(ral_grid *a, ral_grid *b, RAL_INTEGER c, RAL_INTEGER d);
/** if a then b = c */
int RAL_CALL ral_grid_if_then_grid(ral_grid *a, ral_grid *b, ral_grid *c);

/** if a == k then b = v */
int RAL_CALL ral_grid_zonal_if_then_real(ral_grid *a, ral_grid *b, RAL_INTEGER *k, RAL_REAL *v, int n);
/** if a == k then b = v */
int RAL_CALL ral_grid_zonal_if_then_integer(ral_grid *a, ral_grid *b, RAL_INTEGER *k, RAL_INTEGER *v, int n);

/** template is a 3x3 mask, if there is a match, set gd[cell] = new_val, nodata has no effect */
int RAL_CALL ral_grid_apply_templ(ral_grid *gd, int *templ, int new_val);

/** 
    - value(cell_t+1) = sum(i=0..8; k[i]*value[neighbor]) neighbor 0 is the cell itself 
    - k _has to_ point to a 9 element table of RAL_REAL's (for real grids) or RAL_INTEGER (for integer grids)
*/
ral_grid_handle RAL_CALL ral_grid_ca_step(ral_grid *gd, void *k);

/** the n-valued map s->d should be sorted to ascending order */
int RAL_CALL ral_grid_map(ral_grid *gd, int *s, int *d, int n);

/** The n-valued map s->d should be sorted to ascending order and it
 should not contain overlaps. default may be NULL. The range
 which is mapped is s_min <= s < s_max */
int RAL_CALL ral_grid_map_integer_grid(ral_grid *gd, int *s_min, int *s_max, int *d, int n, int *deflt);

/** The n-valued map s->d should be sorted to ascending order and it
 should not contain overlaps. default may be NULL. The range which is
 mapped is s_min <= s < s_max */
int RAL_CALL ral_grid_map_real_grid(ral_grid *gd, double *s_min, double *s_max, double *d, int n, double *deflt);

void RAL_CALL ral_integer_grid_reclassify(ral_grid *gd, ral_hash *h);
/** x defines n bins (but is n-1 long), which will be mapped to y values in the return grid */
ral_grid_handle RAL_CALL ral_real_grid_reclassify(ral_grid *gd, RAL_REAL *x, RAL_INTEGER *y, int n);

double RAL_CALL ral_grid_zonesize(ral_grid *gd, ral_cell c);

/** a scanline method, suitable in general for a single area */
ral_grid_handle RAL_CALL ral_grid_borders(ral_grid *gd);  

/** a recursive algorithm, suitable for multiple areas */
ral_grid_handle RAL_CALL ral_grid_borders_recursive(ral_grid *gd); 

ral_grid_handle RAL_CALL ral_grid_areas(ral_grid *gd, int k);

int RAL_CALL ral_grid_connect(ral_grid *gd);

int RAL_CALL ral_grid_number_of_areas(ral_grid *gd, int connectivity);

/** 
    - the returned grid has no data outside of gd, g1, or g2 
    - in join data from g1 takes precedence over data from g2
*/
ral_grid_handle RAL_CALL ral_grid_clip(ral_grid *gd, ral_window w);
ral_grid_handle RAL_CALL ral_grid_join(ral_grid *g1, ral_grid *g2);

/** 
    - pick values from src to dest, the picking method is simple look up
    - based on the center point of a cell
    - fails if src is real and dest is int and src contains too large numbers
*/
int RAL_CALL ral_grid_pick(ral_grid *dest, ral_grid *src);

/** 
   - scale gd into a new grid of size M,N with tr, pick defines how
   - pick: 1 => mean, 2 => variance, 10 => min, 11 => max, 20 => count_of
   - the value of a cell in the new grid is computed from all cells in gd,
   which contribute to it, value is needed if the computation is 
   a count of cells having a given value
   i.e. it is more or less assumed that the new grid has smaller cellsize than the old one
*/
ral_grid_handle RAL_CALL ral_grid_transform(ral_grid *gd, double tr[], int M, int N, int pick, int value);


/** drawing methods, these DO NOT check the datatype */
void RAL_CALL ral_real_grid_line(ral_grid *gd, ral_cell c1, ral_cell c2, RAL_REAL pen);

/** drawing methods, these DO NOT check the datatype */
void RAL_CALL ral_integer_grid_line(ral_grid *gd, ral_cell c1, ral_cell c2, RAL_INTEGER pen);

/** drawing methods, these DO NOT check the datatype */
void RAL_CALL ral_real_grid_filled_rect(ral_grid *gd, ral_cell c1, ral_cell c2, RAL_REAL pen);

/** drawing methods, these DO NOT check the datatype */
void RAL_CALL ral_integer_grid_filled_rect(ral_grid *gd, ral_cell c1, ral_cell c2, RAL_INTEGER pen);

/** Bresenham as presented in Foley & Van Dam */
#define RAL_LINE(grid, cell1, cell2, pen, assignment)	\
    {						        \
	ral_cell c;					\
	int di, dj, incr1, incr2, d,			\
	    iend, jend, idirflag, jdirflag;		\
	cell1.i = max(min(cell1.i,grid->M-1),0);	\
	cell1.j = max(min(cell1.j,grid->N-1),0);	\
	cell2.i = max(min(cell2.i,grid->M-1),0);	\
	cell2.j = max(min(cell2.j,grid->N-1),0);	\
	di = abs(cell2.i-cell1.i);			\
	dj = abs(cell2.j-cell1.j);			\
	if (dj <= di) {					\
	    d = 2*dj - di;				\
	    incr1 = 2*dj;				\
	    incr2 = 2 * (dj - di);			\
	    if (cell1.i > cell2.i) {			\
		c.i = cell2.i;				\
		c.j = cell2.j;				\
		jdirflag = (-1);			\
		iend = cell1.i;				\
	    } else {					\
		c.i = cell1.i;				\
		c.j = cell1.j;				\
		jdirflag = 1;				\
		iend = cell2.i;				\
	    }						\
	    assignment(grid, c, pen);			\
	    if (((cell2.j - cell1.j) * jdirflag) > 0) {	\
		while (c.i < iend) {			\
		    c.i++;				\
		    if (d <0) {				\
			d+=incr1;			\
		    } else {				\
			c.j++;				\
			d+=incr2;			\
		    }					\
		    assignment(grid, c, pen);		\
		}					\
	    } else {					\
		while (c.i < iend) {			\
		    c.i++;				\
		    if (d <0) {				\
			d+=incr1;			\
		    } else {				\
			c.j--;				\
			d+=incr2;			\
		    }					\
		    assignment(grid, c, pen);		\
		}					\
	    }						\
	} else {					\
	    d = 2*di - dj;				\
	    incr1 = 2*di;				\
	    incr2 = 2 * (di - dj);			\
	    if (cell1.j > cell2.j) {			\
		c.j = cell2.j;				\
		c.i = cell2.i;				\
		jend = cell1.j;				\
		idirflag = (-1);			\
	    } else {					\
		c.j = cell1.j;				\
		c.i = cell1.i;				\
		jend = cell2.j;				\
		idirflag = 1;				\
	    }						\
	    assignment(grid, c, pen);			\
	    if (((cell2.i - cell1.i) * idirflag) > 0) {	\
		while (c.j < jend) {			\
		    c.j++;				\
		    if (d <0) {				\
			d+=incr1;			\
		    } else {				\
			c.i++;				\
			d+=incr2;			\
		    }					\
		    assignment(grid, c, pen);		\
		}					\
	    } else {					\
		while (c.j < jend) {			\
		    c.j++;				\
		    if (d <0) {				\
			d+=incr1;			\
		    } else {				\
			c.i--;				\
			d+=incr2;			\
		    }					\
		    assignment(grid, c, pen);		\
		}					\
	    }						\
	}						\
    }

/** from somewhere in the net, does not look very good if r is small(?) */
#define RAL_FILLED_CIRCLE(grid, cell, r, pen, assignment)	\
    {								\
	int a, b, di, dj, r2 = r*r;				\
	di = max(-r, -cell.i);					\
	a = r2 - di*di;						\
	while (1) {						\
	    dj = max(-r, -cell.j);				\
	    b = dj*dj;						\
	    while (1) {						\
		ral_cell d;					\
		d.i = cell.i+di;				\
		d.j = cell.j+dj;				\
		if (d.j >= (grid)->N) break;			\
		if (b < a) assignment(grid, d, pen);		\
		dj++;						\
		if (dj > r) break;				\
		b += 2*dj - 1;					\
	    }							\
	    di++;						\
	    if (di > r OR cell.i+di >= (grid)->M) break;	\
	    a -= 2*di - 1;					\
	}							\
    }

#define RAL_REAL_GRID_SET_CELL(grid, cell, value) RAL_REAL_GRID_CELL((grid), (cell)) = (value)

#define RAL_INTEGER_GRID_SET_CELL(grid, cell, value) RAL_INTEGER_GRID_CELL((grid), (cell)) = (value)

int RAL_CALL ral_grid_filled_polygon(ral_grid *gd, ral_geometry *g, RAL_INTEGER pen_integer, RAL_REAL pen_real);

#ifdef RAL_HAVE_GDAL
/** 
    - value_field -1 => use value 1 
    - render_override: 0: no effect, 1: as points, 2: as lines, 3: as polygons
*/
int RAL_CALL ral_grid_rasterize_feature(ral_grid *gd, OGRFeatureH f, int value_field, OGRFieldType ft, int render_override);
int RAL_CALL ral_grid_rasterize_layer(ral_grid *gd, OGRLayerH l, int value_field, int render_override);
#endif

/**\brief a collection of cells from an integer grid */
typedef struct {
    ral_cell *cells;
    RAL_INTEGER *values;
    int size;
    int max_size;
} ral_cell_integer_values;

typedef ral_cell_integer_values *ral_cell_integer_values_handle;

ral_cell_integer_values_handle RAL_CALL ral_cell_integer_values_create(int size);
void RAL_CALL ral_cell_integer_values_destroy(ral_cell_integer_values **data);
void RAL_CALL ral_add_cell_integer_value(ral_grid *gd, ral_cell d, ral_cell_integer_values *data);

/**\brief a collection of cells from a real valued grid */
typedef struct {
    ral_cell *cells;
    RAL_REAL *values;
    int size;
    int max_size;
} ral_cell_real_values;

typedef ral_cell_real_values *ral_cell_real_values_handle;

ral_cell_real_values_handle RAL_CALL ral_cell_real_values_create(int size);
void RAL_CALL ral_cell_real_values_destroy(ral_cell_real_values **data);
void RAL_CALL ral_add_cell_real_value(ral_grid *gd, ral_cell d, ral_cell_real_values *data);

ral_cell_integer_values_handle RAL_CALL ral_integer_grid_get_line(ral_grid *gd, ral_cell c1, ral_cell c2);
ral_cell_real_values_handle RAL_CALL ral_real_grid_get_line(ral_grid *gd, ral_cell c1, ral_cell c2);
ral_cell_integer_values_handle RAL_CALL ral_integer_grid_get_rect(ral_grid *gd, ral_cell c1, ral_cell c2);
ral_cell_real_values_handle RAL_CALL ral_real_grid_get_rect(ral_grid *gd, ral_cell c1, ral_cell c2);
ral_cell_integer_values_handle RAL_CALL ral_integer_grid_get_circle(ral_grid *gd, ral_cell c, int r);
ral_cell_real_values_handle RAL_CALL ral_real_grid_get_circle(ral_grid *gd, ral_cell c, int r);

/**
   - marks (0/1) the flooded area in "done" grid if given - it may be null or an integer grid 
   - connectivity is either 8 or 4
*/
void RAL_CALL ral_integer_grid_floodfill(ral_grid *gd, ral_grid *done, ral_cell c, RAL_INTEGER pen, int connectivity);

/**
   - marks (0/1) the flooded area in "done" grid if given - it may be null or an integer grid 
   - connectivity is either 8 or 4
*/
void RAL_CALL ral_real_grid_floodfill(ral_grid *gd, ral_grid *done, ral_cell c, RAL_REAL pen, int connectivity);

/** puts values of data cells from the rid into a list ((ral_cell,value)(cell,value)...) */
int RAL_CALL ral_integer_grid2list(ral_grid *gd, ral_cell **c, RAL_INTEGER **value, size_t *size);

/** puts values of data cells from the rid into a list ((ral_cell,value)(cell,value)...) */
int RAL_CALL ral_real_grid2list(ral_grid *gd, ral_cell **c, RAL_REAL **value, size_t *size);

/** bins are in h (n long), fills c (n+1 long), works for both integer and real grids */
void RAL_CALL ral_grid_histogram(ral_grid *gd, double *h, int *c, int n);

/** returns a hash int=>int, works only for integer grids */
ral_hash_handle RAL_CALL ral_grid_contents(ral_grid *gd);

/*********** ZONAL FUNCTIONS ***********/

ral_hash_handle RAL_CALL ral_grid_zonal_count(ral_grid *gd, ral_grid *zones);
ral_hash_handle RAL_CALL ral_grid_zonal_count_of(ral_grid *gd, ral_grid *zones, RAL_INTEGER value);
ral_hash_handle RAL_CALL ral_grid_zonal_sum(ral_grid *gd, ral_grid *zones);
ral_hash_handle RAL_CALL ral_grid_zonal_range(ral_grid *gd, ral_grid *zones);
ral_hash_handle RAL_CALL ral_grid_zonal_min(ral_grid *gd, ral_grid *zones); /** deprecated, use ral_grid_zonal_range */
ral_hash_handle RAL_CALL ral_grid_zonal_max(ral_grid *gd, ral_grid *zones); /** deprecated, use ral_grid_zonal_range */
ral_hash_handle RAL_CALL ral_grid_zonal_mean(ral_grid *gd, ral_grid *zones);
ral_hash_handle RAL_CALL ral_grid_zonal_variance(ral_grid *gd, ral_grid *zones);

int RAL_CALL ral_grid_zonal_contents(ral_grid *gd, ral_grid *zones, ral_hash ***table, ral_hash *index);

/**
   each zone in the zones grid is iteratively "grown" to areas
   designated by the (binary) grid grow 
*/
int RAL_CALL ral_grid_grow_zones(ral_grid *zones, ral_grid *grow, int connectivity);

/**
   - b will contain the neighboring zones of each zone
   - b's size is n
   - c will contain the ones
   - c's size is n
*/
int RAL_CALL ral_grid_neighbors(ral_grid *gd, ral_hash ***b, int **c, int *n);

/** 
   a buffer zone around cells with value z
   returns a binary grid
*/
ral_grid_handle RAL_CALL ral_grid_bufferzone(ral_grid *gd, int z, double w);

/** count, sum, mean, and variance of all cell values (except of 'nodata' cells)*/
long RAL_CALL ral_grid_count(ral_grid *gd);
long RAL_CALL ral_grid_count_of(ral_grid *gd, RAL_INTEGER value);
double RAL_CALL ral_grid_sum(ral_grid *gd);
double RAL_CALL ral_grid_mean(ral_grid *gd);
double RAL_CALL ral_grid_variance(ral_grid *gd);

/** the returned grid has in the 'nodata' cells of gd
    the distance to the nearest data cell in gd
*/
ral_grid_handle RAL_CALL ral_grid_distances(ral_grid *gd);

/** the returned grid has in the 'nodata' cells of gd
    the direction to the nearest data cell in gd
*/
ral_grid_handle RAL_CALL ral_grid_directions(ral_grid *gd);

/** returns the nearest cell to cell c containing data
 */
ral_cell RAL_CALL ral_grid_nearest_neighbor(ral_grid *gd, ral_cell c);

/** nearest neighbor interpolation, each 'nodata' cell will get the value of
    its nearest neighbor (in distance sense) 
*/
ral_grid_handle RAL_CALL ral_grid_nn(ral_grid *gd); 

/** Creates a table of tables, where there is one table for each zone.
    - gd is either the grid from which the values are picked
    - z is the zones grid (has to be an integer grid)
    - tot is the table of tables
    - c is the zone values
    - k contains the sizes of the tables in the table
    -n is the size of the table of the tables 
*/
int RAL_CALL ral_grid_zones(ral_grid *gd, ral_grid *z, double ***tot, int **c, int **k, int *n);

/** calculates a cost-to-go raster from a cost raster and target location */
ral_grid_handle RAL_CALL ral_grid_dijkstra(ral_grid *w, ral_cell c);

/** printf all rows */
int RAL_CALL ral_grid_print(ral_grid *gd);

int RAL_CALL ral_grid_save_ascii(ral_grid *gd, char *outfile);

#endif
