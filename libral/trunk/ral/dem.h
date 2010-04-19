#ifndef RAL_DEM_H
#define RAL_DEM_H

/**\file ral/dem.h
   \brief methods for analysing DEMs

   fdg is a Flow Direction Grid, an integer grid with flow dirs in cells 
   - -1 denotes flat area, 
   - 0 is a pit (local minimum), 
   - 1 is up (-1,0), 
   - 2 is up-right (-1,1), 
   - 3 is right (0,1), etc
*/

/** z_factor is the unit of z dived by the unit of x and y, 
    returns the nine params of the surface in params */
int RAL_CALL ral_dem_fit_surface(ral_grid *dem, double z_factor, ral_grid ***params);

ral_grid_handle RAL_CALL ral_dem_aspect(ral_grid *dem);

/** z_factor is the unit of z dived by the unit of x and y */
ral_grid_handle RAL_CALL ral_dem_slope(ral_grid *dem, double z_factor);

#define RAL_FLOW(fdg, c) (ral_cell_move((c), RAL_INTEGER_GRID_CELL((fdg), (c))))

#define RAL_D8 1
#define RAL_RHO8 2
#define RAL_MANY8 3

/**
   all flowpaths end in a pit, a nodata cell, or outside the grid
   methods are 
   - D8: deterministic eight-neighbors
   - RHO8: stochastic eight-neighbors (Fairfield & Leymarie, WRR 27(5) 709-717)
   - MANY8: codes all 8 neighbor cells which are lower
   - default method is D8
*/
ral_grid_handle RAL_CALL ral_dem_fdg(ral_grid *dem, int method);

/**
   returns the outlet cell (cell which drains to pit, flat, nodata, or outside) 
   of the catchment in which c is 
*/
ral_cell RAL_CALL ral_fdg_outlet(ral_grid *fdg, ral_cell c);

/** 
   upslope cells grid, upslope cells are all 8-neighbors which are higher, 
   upslope cells are coded with bits in the cell value
 */
ral_grid_handle RAL_CALL ral_dem_ucg(ral_grid *dem);

/**\brief A struct used in many algorithms that work with DEMs. */
typedef struct {
    /** flow dir grid */
    ral_grid *fdg;
    /** dem grid */
    ral_grid *dem;
    /** current flat area or pit cell's catchment */
    ral_grid *mark;
    /** elevation of the flat area */
    double zf;
    /** flatness threshold */
    double dz;
    /** a border cell after marking the area, start the walk from here */
    ral_cell bc;
    /** bc is valid */
    int bc_found;
    /** direction away from the area, in topological sense?, suitable for borderwalk */
    int dir_out;
    /** when looking for the pour point, do we
	look for lowest border cell (default) or lowest cell adjacent to the area? */
    int test_inner;
    /** inner pour point found? */
    int pp_found;
    /** inner pour point */
    ral_cell ipp;
    /** elevation of the inner pour point */
    double z_ipp;
    /** slope from the inner pour point to its downslope point in the depression */
    double slope_in;
    /** slope from the inner pour point to the the outer pour point */
    double slope_out;
    /** distance from the ipp to opp */
    int dio;
    /** direction from inner_pour_point to outer_pour_point */
    int in2out;
    /** pour to nodata? */
    int pour_to_nodata;
    /** is valid only if pour_to_nodata is false */
    ral_cell opp;
    /** elevation of the outer pour point */
    double z_opp;
    int counter;
} ral_pour_point_struct;

int RAL_CALL ral_init_pour_point_struct(ral_pour_point_struct *pp, ral_grid *fdg, ral_grid *dem, ral_grid *mark);

/**
   catchment of a cell, returns the size of the catchment
*/
long RAL_CALL ral_mark_upslope_cells(ral_pour_point_struct *pp, ral_cell c, int m);

long RAL_CALL ral_fdg_catchment(ral_grid *fdg, ral_grid *mark, ral_cell c, int m);

/** 
    Drain flat areas by iteratively draining flat cells to non-higher
    lying cells whose drainagege is resolved.
*/
int RAL_CALL ral_fdg_drain_flat_areas1(ral_grid *fdg, ral_grid *dem);

/** 
    Drain flat areas to the inner pour point. Make inner pour point a
    pit if its pour point is higher else drain it to the outer pour
    point.
*/
int RAL_CALL ral_fdg_drain_flat_areas2(ral_grid *fdg, ral_grid *dem);

/** Raise single cell pits. */

int RAL_CALL ral_dem_raise_pits(ral_grid *dem, double z_limit);

/** Lower single cell peaks. */

int RAL_CALL ral_dem_lower_peaks(ral_grid *dem, double z_limit);

/**
   Return the depressions in the FDG, each depression is marked with a
   unique integer if inc_m is true.
*/
ral_grid_handle RAL_CALL ral_fdg_depressions(ral_grid *fdg, int inc_m);

/**
   fills the depressions in the dem, returns the number of filled depressions
*/
int RAL_CALL ral_dem_fill_depressions(ral_grid *dem, ral_grid *fdg);

/** An implementation of the breach algorithm in Martz and Garbrecht (1998). */
int RAL_CALL ral_dem_breach(ral_grid *dem, ral_grid *fdg, int limit);

/**  
     inverts the path from the pit cell to the lowest pour point of the depression
*/
int RAL_CALL ral_fdg_drain_depressions(ral_grid *fdg, ral_grid *dem);

/** Route water downstream. Routes to all downstream cells that share
    boundary with a cell (0 to 4 cells) unless FDG is given. Returns
    the changes in cell water storage. Amount of water routed
    downstream is computed as k*Sqrt(slope)*water. r is the unit of
    elevation divided by the unit of x and y in DEM.
 */
ral_grid_handle RAL_CALL ral_water_route(ral_grid *water, ral_grid *dem, ral_grid *fdg, ral_grid *k, double r);

/** the path as defined by the fdg (it goes through cell center
    points), the path ends at non-direction cell in fdg, at the border of
    the grid, or (if stop is given) at a cell where stop > 0 */
ral_grid_handle RAL_CALL ral_fdg_path(ral_grid *fdg, ral_cell c, ral_grid *stop);

/** the path as in ral_fdg_path, length is calculated using cell_size,
    if op is given and is nodata, that part of the path is not included */
ral_grid_handle RAL_CALL ral_fdg_path_length(ral_grid *fdg, ral_grid *stop, ral_grid *op);

/** as ral_fdg_path_length, computes the weighted sum of op along the path */
ral_grid_handle RAL_CALL ral_fdg_path_sum(ral_grid *fdg, ral_grid *stop, ral_grid *op);

/** focal sum, focal defined as upslope cells and possibly self */
ral_grid_handle RAL_CALL ral_fdg_upslope_sum(ral_grid *fdg, ral_grid *op, int include_self);

/** focal mean, focal defined as upslope cells and possibly self */
ral_grid_handle RAL_CALL ral_fdg_upslope_mean(ral_grid *fdg, ral_grid *op, int include_self);

/** focal variance, focal defined as upslope cells and possibly self */
ral_grid_handle RAL_CALL ral_fdg_upslope_variance(ral_grid *fdg, ral_grid *op, int include_self);

/** focal count, focal defined as upslope cells and possibly self, 
    if op == NULL counts all upslope cells are
 */
ral_grid_handle RAL_CALL ral_fdg_upslope_count(ral_grid *fdg, ral_grid *op, int include_self);

/** focal count_of, focal defined as upslope cells and possibly self */
ral_grid_handle RAL_CALL ral_fdg_upslope_count_of(ral_grid *fdg, ral_grid *op, int include_self, RAL_INTEGER value);

/** focal range, focal defined as upslope cells and possibly self */
ral_grid_handle RAL_CALL ral_fdg_upslope_integer_range(ral_grid *fdg, ral_grid *op, int include_self, ral_integer_range *range);

/** focal range, focal defined as upslope cells and possibly self */
ral_grid_handle RAL_CALL ral_fdg_upslope_real_range(ral_grid *fdg, ral_grid *op, int include_self, ral_real_range *range);

/** create a grid of the subcatchments defined by the streams grid, fdg grid, and root cell c
    each subcatchment is marked with unique id */
ral_grid_handle RAL_CALL ral_streams_subcatchments(ral_grid *streams, ral_grid *fdg, ral_cell c);

/** create a grid of all subcatchments defined by the streams and fdg grids
    each subcatchment is marked with unique id */
ral_grid_handle RAL_CALL ral_streams_subcatchments2(ral_grid *streams, ral_grid *fdg);

/**
   number each stream section with a unique id 
*/
int RAL_CALL ral_streams_number(ral_grid *streams, ral_grid *fdg, ral_cell c, int sid0);

/**
   number each stream section with a unique id 
*/
int RAL_CALL ral_streams_number2(ral_grid *streams, ral_grid *fdg, int sid0);

/*                          */
/* lakes grid is used below */
/*                          */

/* lakes should have (by default) only one outlet */

/** this removes other outlets from the lakes than the one with max ua by changing the fdg */
int RAL_CALL ral_fdg_kill_extra_outlets(ral_grid *fdg, ral_grid *lakes, ral_grid *uag);

/**
   pruning removes streams shorter than min_l (give min_l in grid scale)
*/
int RAL_CALL ral_streams_prune(ral_grid *streams, ral_grid *fdg, ral_grid *lakes, ral_cell c, double min_l);

/**
   pruning removes streams shorter than min_l (give min_l in grid scale)
*/
int RAL_CALL ral_streams_prune2(ral_grid *streams, ral_grid *fdg, ral_grid *lakes, double min_l);

/**
  renumbers the upstream reach of a stream which flows through a lake
  without junctions
  - break streams actually broken by a lake 
  - nsid is the first available stream id
*/
int RAL_CALL ral_streams_break(ral_grid *streams, ral_grid *fdg, ral_grid *lakes, int nsid);

/**\brief catchment structure */
typedef struct {
    /** outlet cell of catchment i, i = 0..n-1 */
    ral_cell *outlet;
    /** outlet cell of the catchment into which catchment i drains */
    ral_cell *down;
    int n;
    int size;
    int delta;
} ral_catchment;

typedef ral_catchment *ral_catchment_handle;

void RAL_CALL ral_catchment_destroy(ral_catchment **catchment);

/**
   create a catchment object and mark a subcatchment grid from 
   a flow direction grid,
   a numbered stream grid, 
   a numbered lake grid, and
   outlet cell
*/
ral_catchment_handle RAL_CALL ral_catchment_create(ral_grid *subs, ral_grid *streams, ral_grid *fdg, ral_grid *lakes, ral_cell outlet, int headwaters);

/**
   create a catchment object and mark a subcatchment grid from 
   a flow direction grid,
   a numbered stream grid, and  
   a numbered lake grid
   for all outlet cells
*/
ral_catchment_handle RAL_CALL ral_catchment_create_complete(ral_grid *subs, ral_grid *streams, ral_grid *fdg, ral_grid *lakes, int headwaters);

int RAL_CALL ral_streams_vectorize(ral_grid *streams, ral_grid *fdg, int row, int col);
int RAL_CALL ral_compare_dem_derived_ws_attribs(ral_grid *str, ral_grid *uag, ral_grid *dem, char *dir, char *basename, int iname, int ielev, int idarea);

#endif
