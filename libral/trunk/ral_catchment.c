#include "config.h"
#include "msg.h"
#include "ral.h"

/* 
   a border cell of an area is a grid cell which has at least one cell
   in its 8-neighborhood which has a different value than the area
   value or the cell is on the border of the grid
   
   this algorithm walks the border of an area and tests each
   bordercell with a given test function
*/
/* 
   return 1 if ok, and 0 in the case of an error (report it!)
 */
typedef int ral_testfct(void *fctparam1, ral_cell c); 
/* 
   should return a boolean value indicating whether the cell is area cell 
*/
typedef int ral_areafct(void *fctparam1, ral_cell c); 
/* 
   a is the place where to start walking
   out is a direction which is away from the area whose border is to be walked
*/
int ral_borderwalk(ral_cell a, int out, void *fctparam1, ral_areafct is_area, ral_testfct test)
{
    ral_cell c = a;
    int da = 0;
    int d = out;
    /* search for the first direction which is 
       clockwise an area cell just after direction out */
    ral_cell t = ral_cell_move(c, out);

    /* is a on the area? */
    RAL_CHECKM(is_area(fctparam1, c), ral_msg(RAL_ERRSTR_BORDERWALK_OUT, c.i, c.j));

    /* is out really off the area? */
    RAL_CHECKM(!is_area(fctparam1, t), ral_msg(RAL_ERRSTR_BORDERWALK_BAD_OUT, t.i, t.j, out, c.i, c.j));

    while (!is_area(fctparam1, t)) {
	d = RAL_NEXT_DIR(d);
	if (d == out) /* a is the area */
	    break;
	t = ral_cell_move(c, d);
    }
    RAL_CHECK(test(fctparam1, c));

    if (d == out) /* a is the area */
	return 1;
    while (1) {
	t = ral_cell_move(c, d);
	while (!is_area(fctparam1, t)) {
	    d = RAL_NEXT_DIR(d);
	    /* there _IS_ a 8-neighbor which is on the area */
	    t = ral_cell_move(c, d);
	}
	/* this is a ghost by feng shui definition, 
	   i.e. this prefers walking to dir 1, 3, 5, or 7 */
	if (EVEN(d)) {
	    int od = RAL_NEXT_DIR(d);
	    t = ral_cell_move(c, od);
	    if (is_area(fctparam1, t))
		d = od;
	}
	/* test if we are done */
	if (RAL_SAME_CELL(c, a)) {
	    if (d == da)
		return 1;
	    else if (!da)
		da = d;
	}
	c = ral_cell_move(c, d);

	RAL_CHECK(test(fctparam1, c));
	d += 6;
	if (d > 8) d -= 8;
    }
    /* should never be here */
 fail:
    return 0;
}


/*

  Fits a 9-term quadratic polynomial 

  NOTE: assumes dx = dy as in grid

z = A * x^2y^2 + B * x^2y + C * xy^2 + D * x^2 + E * y^2 + F * xy + G * x + H *y + I

a[1] = A
a[2] = B
a[3] = C
a[4] = D
a[5] = E
a[6] = F
a[7] = G
a[8] = H
a[9] = I

  to a 3*3 square grid centered at the center point of cell c

  z's:   1 2 3
         4 5 6
         7 8 9

  ^
  |
y |
  |
   ---> 
    x

z1 =  1 * A +  1 * B + -1 * C + 1 * D + 1 * E + -1 * F + -1 * G +  1 * H + I
z2 =  0 * A +  0 * B +  0 * C + 0 * D + 1 * E +  0 * F +  0 * G +  1 * H + I
z3 =  1 * A +  1 * B +  1 * C + 1 * D + 1 * E +  1 * F +  1 * G +  1 * H + I
z4 =  0 * A +  0 * B +  0 * C + 1 * D + 0 * E +  0 * F + -1 * G +  0 * H + I
z5 =  0 * A +  0 * B +  0 * C + 0 * D + 0 * E +  0 * F +  0 * G +  0 * H + I
z6 =  0 * A +  0 * B +  0 * C + 1 * D + 0 * E +  0 * F +  1 * G +  0 * H + I
z7 =  1 * A + -1 * B + -1 * C + 1 * D + 1 * E +  1 * F + -1 * G + -1 * H + I
z8 =  0 * A +  0 * B +  0 * C + 0 * D + 1 * E +  0 * F +  0 * G + -1 * H + I
z9 =  1 * A + -1 * B +  1 * C + 1 * D + 1 * E + -1 * F +  1 * G + -1 * H + I

A =  0.25 * z1 +  0.5 * z2 + 0.25 * z3 + -0.5 * z4 +  1 * z5 + -0.5 * z6 +  0.25 * z7 + -0.5 * z8 +  0.25 * z9
B =  0.25 * z1 + -0.5 * z2 + 0.25 * z3 +  0   * z4 +  0 * z5 +  0   * z6 + -0.25 * z7 +  0.5 * z8 + -0.25 * z9
C = -0.25 * z1 +  0   * z2 + 0.25 * z3 +  0.5 * z4 +  0 * z5 + -0.5 * z6 + -0.25 * z7 +  0   * z8 +  0.25 * z9
D =  0    * z1 +  0   * z2 + 0    * z3 +  0.5 * z4 + -1 * z5 +  0.5 * z6 +  0    * z7 +  0   * z8 +  0    * z9
E =  0    * z1 +  0.5 * z2 + 0    * z3 +  0   * z4 + -1 * z5 +  0   * z6 +  0    * z7 +  0.5 * z8 +  0    * z9
F = -0.25 * z1 +  0   * z2 + 0.25 * z3 +  0   * z4 +  0 * z5 +  0   * z6 +  0.25 * z7 +  0   * z8 + -0.25 * z9
G =  0    * z1 +  0   * z2 + 0    * z3 + -0.5 * z4 +  0 * z5 +  0.5 * z6 +  0    * z7 +  0   * z8 +  0    * z9
H =  0    * z1 +  0.5 * z2 + 0    * z3 +  0   * z4 +  0 * z5 +  0   * z6 +  0    * z7 + -0.5 * z8 +  0    * z9
I =  0    * z1 +  0   * z2 + 0    * z3 +  0   * z4 +  1 * z5 +  0   * z6 +  0    * z7 +  0   * z8 +  0    * z9

z_factor is the unit of z divided by the unit of x and y

*/

int ral_fitpoly(ral_grid *dem, double a[], ral_cell c, double z_factor) 
{
    int ix = 1;
    int ii, jj;
    double z[10];
    z[0] = 0;
    for (ii = c.i-1; ii <= c.i+1; ii++) {
	for (jj = c.j-1; jj <= c.j+1; jj++) {
	    ral_cell c2;
	    if (ii < 0) {
		c2.i = 0;
	    } else if (ii > dem->M-1) {
		c2.i = dem->M-1;
	    } else {
		c2.i = ii;
	    }
	    if (jj < 0) {
		c2.j = 0;
	    } else if (jj > dem->N-1) {
		c2.j = dem->N-1;
	    } else {
		c2.j = jj;
	    }
	    if (RAL_GRID_DATACELL(dem, c2)) 
		z[ix] =  RAL_GRID_CELL(dem, c2);
	    else
		z[ix] = RAL_GRID_CELL(dem, c);
	    z[ix] *= (z_factor / dem->cell_size);
	    ix++;
	}
    }
    a[0] = 0;
    a[1] =  0.25 * z[1] +  0.5 * z[2] + 0.25 * z[3] -  0.5 * z[4] + z[5] -  0.5 * z[6] +  0.25 * z[7] -  0.5 * z[8] +  0.25 * z[9];
    a[2] =  0.25 * z[1] -  0.5 * z[2] + 0.25 * z[3]                                    -  0.25 * z[7] +  0.5 * z[8] -  0.25 * z[9];
    a[3] = -0.25 * z[1]               + 0.25 * z[3] +  0.5 * z[4]        -  0.5 * z[6] -  0.25 * z[7]               +  0.25 * z[9];
    a[4] =                                             0.5 * z[4] - z[5] +  0.5 * z[6]                                            ;
    a[5] =                 0.5 * z[2]                             - z[5]                              +  0.5 * z[8]               ;
    a[6] = -0.25 * z[1]               + 0.25 * z[3]                                    +  0.25 * z[7]               -  0.25 * z[9];
    a[7] =                                            -0.5 * z[4]        +  0.5 * z[6]                                            ;
    a[8] =                 0.5 * z[2]                                                                 -  0.5 * z[8]               ;
    a[9] =                                                          z[5]                                                          ;
    return 1;
}


/*
        j
        ->      ^
     i |        | 0  -> Pi/2   | Pi   <- 3*Pi/2
       V                       V
  
*/
double ral_aspect(double a[]) 
{
    double asp;
    if (fabs(a[8]) < RAL_EPSILON) {
	if (fabs(a[7]) < RAL_EPSILON) return -1;
	if (a[7] < 0) return M_PI/2.0;
	return 3.0/2.0 * M_PI;
    }
    if (fabs(a[7]) < RAL_EPSILON) {
	if (a[8] > 0) return M_PI;
	if (a[7] >= 0) return 2.0 * M_PI;
	return 0;
    }
    asp = M_PI - atan2(a[8]/a[7],1) + M_PI/2.0 * (a[7]/fabs(a[7]));
    if (asp<0) return 0;
    if (asp>2*M_PI) return 2*M_PI;
    return asp;
}


ral_grid *ral_dem_aspect(ral_grid *dem)
{
    ral_grid *ag = NULL;
    ral_cell c;
    RAL_CHECK(ag = ral_grid_create_like(dem, RAL_REAL_GRID));
    RAL_FOR(c, dem) {
	if (RAL_GRID_DATACELL(dem, c)) {
	    double a[10];
	    ral_fitpoly(dem, a, c, 1);
	    RAL_REAL_GRID_CELL(ag, c) = ral_aspect(a);
	} else {
	    RAL_REAL_GRID_SETNODATACELL(ag, c);
	}
    }
    return ag;
 fail:
    ral_grid_destroy(&ag);
    return NULL;
}


int ral_dem_fit_surface(ral_grid *dem, double z_factor, ral_grid ***params)
{
    int i;
    ral_cell c;
    RAL_CHECKM(*params = RAL_CALLOC(9, ral_grid *), RAL_ERRSTR_OOM);
    for (i = 0; i < 9; i++)
	RAL_CHECK((*params)[i] = ral_grid_create_like(dem, RAL_REAL_GRID));
    RAL_FOR(c, dem) {
	if (RAL_GRID_DATACELL(dem, c)) {
	    double a[10];
	    ral_fitpoly(dem, a, c, z_factor);
	    for (i = 0; i < 9; i++)
		RAL_REAL_GRID_CELL((*params)[i], c) = a[i+1];
	} else {
	    for (i = 0; i < 9; i++)
		RAL_REAL_GRID_SETNODATACELL((*params)[i], c);
	}
    }
    return 1;
 fail:
    if (params) {
	for (i = 0; i < 9; i++)
	    if ((*params)[i])
		ral_grid_destroy(&((*params)[i]));
	free(*params);
	*params = NULL;
    }
    return 0;
}


ral_grid *ral_dem_slope(ral_grid *dem, double z_factor)
{
    ral_grid *sg = NULL;
    ral_cell c;
    RAL_CHECK(sg = ral_grid_create_like(dem, RAL_REAL_GRID));
    RAL_FOR(c, dem) {
	if (RAL_GRID_DATACELL(dem, c)) {
	    double a[10];
	    ral_fitpoly(dem, a, c, z_factor);
	    RAL_REAL_GRID_CELL(sg, c) = atan(sqrt(a[7]*a[7]+a[8]*a[8]));
	} else {
	    RAL_REAL_GRID_SETNODATACELL(sg, c);
	}
    }
    return sg;
 fail:
    ral_grid_destroy(&sg);
    return NULL;
}


double ral_flatness_threshold(ral_grid *dem)
{
    if (dem->datatype == RAL_INTEGER_GRID)
	return 0;
    else
	return 0.0; /* there is a problem draining flat areas if this is left non-zero */
}


ral_grid *ral_dem_fdg(ral_grid *dem, int method) 
{
    ral_grid *fdg = NULL;
    ral_cell c;
    double dz = ral_flatness_threshold(dem);
    RAL_CHECK(fdg = ral_grid_create_like(dem, RAL_INTEGER_GRID));
    ral_grid_set_integer_nodata_value(fdg, -9999);
    RAL_FOR(c, dem) {
	if (RAL_GRID_NODATACELL(dem, c)) 
	    RAL_INTEGER_GRID_SETNODATACELL(fdg, c);
	else {
	    /* 
	       test for all eight-neighbors of c and 
	       remember the direction to the one with steepest descent to 
	       if a nodata available flow there
	       if on the border of the grid, flow outside
	    */
	    int dir, found = 0, dir_t = 0, has_non_higher = 0, many = 0;
	    double zc = RAL_GRID_CELL(dem, c), descent = 0;

	    RAL_DIRECTIONS(dir) {
		ral_cell t = ral_cell_move(c, dir);
		if (RAL_GRID_CELL_IN(dem, t) AND RAL_GRID_DATACELL(dem, t)) {
		    double zt = RAL_GRID_CELL(dem, t);
		    if (zt < zc - dz) {
			double coeff = 1;
			if (EVEN(dir)) {
			    if (method == RAL_RHO8) {
				double rho = ((double)rand()) / RAND_MAX;
				coeff = 1.0/(2.0-rho);
			    } else {
				coeff = sqrt(1.0/2.0);
			    }
			}
			if (!found OR coeff*(zc-zt) > descent) {
			    found = 1;
			    descent = coeff*(zc-zt);
			    dir_t = dir;
			}
			many |= 1 << (dir-1); /* bits in the byte tell downslope cells */
		    } else if (zt <= zc + dz) {
			has_non_higher = 1;
		    }
		} else {
		    found = 1;
		    dir_t = dir;
		    many = 1 << (dir-1);
		    break;
		}
	    }
	    if (found) {
		if (method == RAL_MANY8)
		    dir = many;
		else
		    dir = dir_t;
	    } else if (has_non_higher)
		dir = RAL_FLAT_AREA;
	    else 
		dir = RAL_PIT_CELL;
	    RAL_INTEGER_GRID_CELL(fdg, c) = dir;
	}
    }
    return fdg;
 fail:
    ral_grid_destroy(&fdg);
    return NULL;
}


int ral_fdg_is_outlet(ral_grid *fdg, ral_cell c)
{
    if (RAL_GRID_CELL_IN(fdg, c) AND RAL_GRID_DATACELL(fdg, c) AND RAL_GRID_CELL(fdg, c) > 0) {
	c = RAL_FLOW(fdg, c);
	if (RAL_GRID_CELL_OUT(fdg, c) OR RAL_GRID_NODATACELL(fdg, c))
	    return 1;
    }
    return 0;
}


ral_cell ral_fdg_outlet(ral_grid *fdg, ral_cell c)
{
    ral_cell previous = c;
    while (RAL_GRID_CELL_IN(fdg, c) AND RAL_GRID_DATACELL(fdg, c) AND RAL_GRID_CELL(fdg, c) > 0) {
	previous = c;
	c = RAL_FLOW(fdg, c);
    }
    return previous;
}


ral_grid *ral_dem_ucg(ral_grid *dem) 
{
    ral_grid *ucg = NULL;
    ral_cell c;
    double dz = ral_flatness_threshold(dem);
    RAL_CHECK(ucg = ral_grid_create_like(dem, RAL_INTEGER_GRID));
    RAL_FOR(c, dem) {
	if (RAL_GRID_NODATACELL(dem, c)) 
	    RAL_INTEGER_GRID_SETNODATACELL(ucg, c);
	else {
	    int dir, many = 0;
	    double zc = RAL_GRID_CELL(dem, c);
	    RAL_DIRECTIONS(dir) {
		ral_cell t = ral_cell_move(c, dir);
		if (RAL_GRID_CELL_IN(dem, t) AND RAL_GRID_DATACELL(dem, t)) {
		    double zt = RAL_GRID_CELL(dem, t);
		    if (zt > zc + dz) {
			many |= 1 << (dir-1); /* bits in the byte tell upslope cells */
		    } 
		}
	    }
	    RAL_INTEGER_GRID_CELL(ucg, c) = many;
	}
    }
    return ucg;
 fail:
    ral_grid_destroy(&ucg);
    return NULL;
}


int ral_init_pour_point_struct(ral_pour_point_struct *pp, ral_grid *fdg, ral_grid *dem, ral_grid *mark)
{
    RAL_CHECKM(mark,"mark grid is required");
    RAL_CHECKM((!dem OR ral_grid_overlayable(fdg, dem)) AND ral_grid_overlayable(fdg, mark), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID AND mark->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    pp->fdg = fdg;
    pp->dem = dem;
    pp->mark = mark;
    if (dem) pp->dz = ral_flatness_threshold(dem);
    pp->bc_found = 0;
    pp->test_inner = 1;
    pp->pp_found = 0;
    pp->pour_to_nodata = 0;
    return 1;
 fail:
    return 0;
}



#define IS_FLAT_AND_NOT_MARKED(pp,t) (RAL_GRID_CELL_IN((pp)->fdg, (t)) AND \
                       RAL_INTEGER_GRID_DATACELL((pp)->fdg, (t)) AND \
                       !RAL_INTEGER_GRID_CELL((pp)->mark, (t)) AND \
                       (RAL_INTEGER_GRID_CELL((pp)->fdg, (t)) == RAL_FLAT_AREA))


void ral_markflat(ral_pour_point_struct *pp, ral_cell c)
{
    int upLimit,downLimit;
    ral_cell t = c;

    if (!IS_FLAT_AND_NOT_MARKED(pp, c)) return;

    /* Seek up for the last flat cell */
    
    for (t.i = c.i; t.i >= 0; t.i--) {
	if (!IS_FLAT_AND_NOT_MARKED(pp, t)) break;
	RAL_INTEGER_GRID_CELL(pp->mark, t) = 1;
	pp->counter++;
    }
    if (!pp->bc_found) {
	pp->bc_found = 1;
	pp->dir_out = 1;	
	pp->bc = t;
	if (pp->bc.i < 0) pp->bc.i++;
	if (!RAL_INTEGER_GRID_CELL(pp->mark, pp->bc)) pp->bc.i++;
    }
    upLimit = max(0,t.i);

    /* Seek down and mark and count */
    for (t.i = c.i+1; t.i < pp->mark->M; t.i++) {    
	if (!IS_FLAT_AND_NOT_MARKED(pp, t)) break;
	RAL_INTEGER_GRID_CELL(pp->mark, t) = 1;
	pp->counter++;
    }
    downLimit = min(pp->mark->M-1,t.i);

    /* Look at columns right and left */
    /* left */
    if (c.j > 0) {
	int lastBorder = 1;
	t.j = c.j-1;
	for (t.i = upLimit; t.i <= downLimit; t.i++) {
	    int a = IS_FLAT_AND_NOT_MARKED(pp, t);
	    if (lastBorder) {
		if (a) {
		    ral_markflat(pp, t);
		    lastBorder = 0;
		}
	    } else if (!a) {
		lastBorder = 1;
	    }
	}
    }

    /* right */
    if (c.j < (pp->mark->N - 1)) {
	int lastBorder = 1;
	t.j = c.j+1;
	for (t.i = upLimit; t.i <= downLimit; t.i++) {
	    int a = IS_FLAT_AND_NOT_MARKED(pp, t);
	    if (lastBorder) {
		if (a) {
		    ral_markflat(pp, t);
		    lastBorder = 0;
		}
	    } else if (!a) {
		lastBorder = 1;
	    }
	}
    }
}


/* this is called for each candidate inner pour point (border cell) */
int ral_test_pour_point(void *fctparam1, ral_cell c) {
    ral_pour_point_struct *pp = (ral_pour_point_struct *)fctparam1;
    int d, d_in;
    double zc, slope_in = 0;
    ral_cell c_in;

    zc = RAL_GRID_CELL(pp->dem, c);
    d_in = RAL_INTEGER_GRID_CELL(pp->fdg, c);
    c_in = ral_cell_move(c, d_in);

    /* this border cell might also be a pour to nodata cell */
    if (d_in AND RAL_GRID_CELL_IN(pp->fdg, c_in) AND RAL_INTEGER_GRID_DATACELL(pp->fdg, c_in)) 
	slope_in = (zc - RAL_GRID_CELL(pp->dem, c_in))/RAL_DISTANCE_UNIT(d_in);

    if (pp->pour_to_nodata) {
	if (zc < pp->z_ipp)
	    pp->z_ipp = zc;
    } else {
	for (d = 1; d < 9; d++) {
	    ral_cell t = ral_cell_move(c, d);
	    double zt, slope_out;
	    if (RAL_GRID_CELL_OUT(pp->fdg, t) OR RAL_INTEGER_GRID_NODATACELL(pp->fdg, t)) {
		pp->pp_found = 1;
		pp->ipp = c;
		pp->z_ipp = zc;
		pp->in2out = d;
		pp->pour_to_nodata = 1;
		break;
	    }
	    if (RAL_INTEGER_GRID_CELL(pp->mark, t)) continue;
	    zt = RAL_GRID_CELL(pp->dem, t);
	    slope_out = (zc - zt)/RAL_DISTANCE_UNIT(d);
	    if (!pp->pp_found OR 
		(pp->test_inner AND 
		 (zc < pp->z_ipp OR 
		  (zc == pp->z_ipp AND slope_out > pp->slope_out) OR
		  (zc == pp->z_ipp AND slope_out == pp->slope_out AND d_in AND slope_in > pp->slope_in))) OR
		(!pp->test_inner AND 
		 (zt < pp->z_opp OR 
		  (zt == pp->z_opp AND RAL_DISTANCE_UNIT(d) < pp->dio)))) {
		pp->pp_found = 1;
		pp->ipp = c;
		pp->z_ipp = zc;
		pp->slope_in = slope_in;
		pp->slope_out = slope_out;
		pp->dio = RAL_DISTANCE_UNIT(d);
		pp->in2out = d;
		pp->opp = t;
		pp->z_opp = zt;
	    }
	}
    }
    return 1;
}


int ral_is_marked(void *fctparam1, ral_cell c) {
    return RAL_GRID_CELL_IN(((ral_pour_point_struct *)fctparam1)->mark, c) AND 
	RAL_INTEGER_GRID_CELL(((ral_pour_point_struct *)fctparam1)->mark, c);
}


void ral_drain_flat_area_to_pour_point(ral_pour_point_struct *pp, ral_cell c, int dir_for_c) 
{
    int upLimit,downLimit;
    int at_up_4_or_6 = 0;
    int at_down_2_or_8 = 0;
    ral_cell t = c;
    
    if (!RAL_INTEGER_GRID_CELL(pp->mark, c)) return;

    if (dir_for_c > 0) RAL_INTEGER_GRID_CELL(pp->fdg, c) = dir_for_c;

    /* Seek up */
    for (t.i = c.i; t.i >= 0; t.i--) {
	if (!RAL_INTEGER_GRID_CELL(pp->mark, t)) {
	    at_up_4_or_6 = 1;
	    break;	    
	}
	RAL_INTEGER_GRID_CELL(pp->mark, t) = 0;
	if (t.i < c.i) RAL_INTEGER_GRID_CELL(pp->fdg, t) = 5; /* down */
    }
    upLimit = max(0,t.i);

    /* Seek down */
    for (t.i = c.i+1; t.i < pp->mark->M; t.i++) {    
	if (!RAL_INTEGER_GRID_CELL(pp->mark, t)) {
	    at_down_2_or_8 = 1;
	    break;
	}
	RAL_INTEGER_GRID_CELL(pp->mark, t) = 0;
	RAL_INTEGER_GRID_CELL(pp->fdg, t) = 1; /* up */
    }
    downLimit = min(pp->mark->M-1,t.i);

    /* Look at columns right and left */
    /* left */
    if (c.j > 0) {
	int lastBorder = 1;
	t.j = c.j-1;
	for (t.i = upLimit; t.i <= downLimit; t.i++) {
	    int a;
	    if ((t.i == upLimit) AND at_up_4_or_6) {
		dir_for_c = 4;
	    } else if ((t.i == downLimit) AND at_down_2_or_8) {
		dir_for_c = 2;
	    } else {
		dir_for_c = 3;
	    }
	    a = RAL_INTEGER_GRID_CELL(pp->mark, t);
	    if (lastBorder) {
		if (a) {
		    ral_drain_flat_area_to_pour_point(pp, t, dir_for_c);
		    lastBorder = 0;
		}
	    } else if (!a) {
		lastBorder = 1;
	    }
	}
    }

    /* right */
    if (c.j < (pp->mark->N - 1)) {
	int lastBorder = 1;
	t.j = c.j+1;
	for (t.i = upLimit; t.i <= downLimit; t.i++) {
	    int a;
	    if ((t.i == upLimit) AND at_up_4_or_6) {
		dir_for_c = 6;
	    } else if ((t.i == downLimit) AND at_down_2_or_8) {
		dir_for_c = 8;
	    } else {
		dir_for_c = 7;
	    }
	    a = RAL_INTEGER_GRID_CELL(pp->mark, t);
	    if (lastBorder) {
		if (a) {
		    ral_drain_flat_area_to_pour_point(pp, t, dir_for_c);
		    lastBorder = 0;
		}
	    } else if (!a) {
		lastBorder = 1;
	    }
	}
    }
}


void ral_raise_area(ral_pour_point_struct *pp, ral_cell c, double z)
{
    int lastBorder;
    int leftLimit, rightLimit;
    ral_cell t;
    /* Seek up */
    leftLimit = (-1);
    t.j = c.j;
    for (t.i = c.i; (t.i >= 0); t.i--) {
	if (!(RAL_INTEGER_GRID_DATACELL(pp->fdg, t) AND RAL_INTEGER_GRID_CELL(pp->mark, t))) {
	    break;
	}
	RAL_INTEGER_GRID_CELL(pp->mark, t) = 0;
	ral_grid_set_real(pp->dem, t, z); /* dem may be int or float */
	leftLimit = max(0,t.i-1);
    }
    if (leftLimit == (-1)) {
	return;
    }
    /* Seek down */
    rightLimit = min(pp->dem->M-1,c.i+1);
    for (t.i = (c.i+1); (t.i < pp->dem->M); t.i++) {	
	if (!(RAL_INTEGER_GRID_DATACELL(pp->fdg, t) AND RAL_INTEGER_GRID_CELL(pp->mark, t))) {
	    break;
	}
	RAL_INTEGER_GRID_CELL(pp->mark, t) = 0;
	ral_grid_set_real(pp->dem, t, z); /* dem may be int or float */
	rightLimit = min(pp->dem->M-1,t.i+1);
    }
    /* Look at columns right and left and start paints */
    /* right */
    if (c.j > 0) {
	t.j = c.j-1;
	lastBorder = 1;
	for (t.i = leftLimit; (t.i <= rightLimit); t.i++) {
	    int a = (RAL_INTEGER_GRID_DATACELL(pp->fdg, t) AND RAL_INTEGER_GRID_CELL(pp->mark, t));
	    if (lastBorder) {
		if (a) {	
		    ral_raise_area(pp, t, z);
		    lastBorder = 0;
		}
	    } else if (!a) {
		lastBorder = 1;
	    }
	}
    }
    /* left */
    if (c.j < ((pp->dem->N) - 1)) {
	t.j = c.j+1;
	lastBorder = 1;
	for (t.i = leftLimit; (t.i <= rightLimit); t.i++) {
	    int a = (RAL_INTEGER_GRID_DATACELL(pp->fdg, t) AND RAL_INTEGER_GRID_CELL(pp->mark, t));
	    if (lastBorder) {
		if (a) {
		    ral_raise_area(pp, t, z);
		    lastBorder = 0;
		}
	    } else if (!a) {
		lastBorder = 1;
	    }
	}
    }
}


int ral_flat_and_pit_cells(ral_grid *fdg)
{
    ral_cell c;
    int count = 0;
    RAL_FOR(c, fdg)
	if (RAL_INTEGER_GRID_CELL(fdg, c) == RAL_FLAT_AREA OR RAL_INTEGER_GRID_CELL(fdg, c) == RAL_PIT_CELL) count++;
    return count;
}


int ral_fdg_drain_flat_areas1(ral_grid *fdg, ral_grid *dem) 
{
    double dz = ral_flatness_threshold(dem);
    double zf; /* elevation of the flat area */
    ral_cell c;
    int done = -1;
    int fixed_flats = 0;
    RAL_CHECKM(ral_grid_overlayable(fdg, dem), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_FDG_INTEGER);
    while (done != fixed_flats) {
	done = fixed_flats;
	RAL_FOR(c, fdg) {
	    if (RAL_INTEGER_GRID_CELL(fdg, c) == RAL_FLAT_AREA OR RAL_INTEGER_GRID_CELL(fdg, c) == RAL_PIT_CELL) {	    
		/* 
		   are there non-higher neigbors with dge resolved?
		   or are there outside cells in the neighborhood?
		*/
		double zl = 0, zt;
		int dir = 0, d, invdir = 5;
		int is_on_border = 0;
		zf = RAL_GRID_CELL(dem, c);
		for (d = 1; d < 9; d++) {
		    int dt;
		    ral_cell t = ral_cell_move(c, d);
		    if (RAL_GRID_CELL_OUT(fdg, t) OR RAL_INTEGER_GRID_NODATACELL(fdg, t)) {
			is_on_border = d;
			continue;
		    }
		    zt = RAL_GRID_CELL(dem, t);
		    dt = RAL_INTEGER_GRID_CELL(fdg, t);
		    if (dt > 0 AND dt != invdir AND
			zt <= zf + dz AND
			(!dir OR zt < zl)) {
			zl = zt;
			dir = d;
		    }
		    invdir++;
		    if (invdir > 8) invdir = 1;
		}
		if (dir) {
		    RAL_INTEGER_GRID_CELL(fdg, c) = dir;
		    fixed_flats++;
		} else if (is_on_border) {
		    RAL_INTEGER_GRID_CELL(fdg, c) = is_on_border;
		    fixed_flats++;
		}
	    }
	}
    }
    return fixed_flats;
 fail:
    return -1;
}


int ral_fdg_drain_flat_areas2(ral_grid *fdg, ral_grid *dem) 
{
    ral_cell c;
    int fixed_flats = 0;
    ral_pour_point_struct pp;
    RAL_CHECK(ral_init_pour_point_struct(&pp, fdg, dem, ral_grid_create_like(fdg, RAL_INTEGER_GRID)));
    pp.dz = -1; /* do not go beyond flat areas defined by the FDG */
    RAL_FOR(c, fdg) {
	if (RAL_INTEGER_GRID_CELL(fdg, c) != RAL_FLAT_AREA) continue;

	pp.zf = RAL_GRID_CELL(pp.dem, c);

	/* mark the flat area and find a definitive border cell */
	pp.bc_found = 0;
	pp.counter = 0;
	ral_markflat(&pp, c);

	/* walk the border */
	pp.test_inner = 0;
	pp.pp_found = 0;
	pp.pour_to_nodata = 0;
	RAL_CHECK(ral_borderwalk(pp.bc, pp.dir_out, &pp, &ral_is_marked, &ral_test_pour_point));

	/* if the elevation of the outer pour point is not higher than inner pour point */
	/* or the outer pour point is nodata */
	/* drain there, else make inner pour point a pit cell */
	if (pp.pour_to_nodata OR pp.z_opp <= RAL_GRID_CELL(pp.dem, pp.ipp))
	    RAL_INTEGER_GRID_CELL(pp.fdg, pp.ipp) = pp.in2out;
	else
	    RAL_INTEGER_GRID_CELL(pp.fdg, pp.ipp) = RAL_PIT_CELL;

	/* starting from the inner pour point make the whole flat area
	   drain into it, this unmarks the flat area along the way */

	ral_drain_flat_area_to_pour_point(&pp, pp.ipp, 0); 

	fixed_flats++;
    }
    ral_grid_destroy(&pp.mark);
    return fixed_flats;
 fail:
    ral_grid_destroy(&pp.mark);
    return -1;
}

int ral_dem_raise_pits(ral_grid *dem, double z_limit)
{
    ral_cell c;
    int pits_filled = 0;
    RAL_FOR(c, dem) {
	int d, f = 0;
	double zc, z_lowest_nbor = 0;
	if (RAL_GRID_NODATACELL(dem, c)) continue;
	zc = RAL_GRID_CELL(dem, c);
	RAL_DIRECTIONS(d) {
	    ral_cell t = ral_cell_move(c, d);
	    if (RAL_GRID_CELL_IN(dem, t) AND RAL_GRID_DATACELL(dem, t)) {
		double zt = RAL_GRID_CELL(dem, t);
		if (!f OR zt < z_lowest_nbor) {
		    f = 1;
		    z_lowest_nbor = zt;
		    if (z_lowest_nbor < zc + z_limit) {
			f = 0;
			break;
		    }
		}
	    }
	}
	if (f) {
	    ral_grid_set_real(dem, c, z_lowest_nbor);
	    pits_filled++;
	}
    }
    return pits_filled;
}


int ral_dem_lower_peaks(ral_grid *dem, double z_limit)
{
    ral_cell c;
    int peaks_cut = 0;
    RAL_FOR(c, dem) {
	int d, f = 0;
	double zc, z_highest_nbor = 0;
	if (RAL_GRID_NODATACELL(dem, c)) continue;
	zc = RAL_GRID_CELL(dem, c);
	RAL_DIRECTIONS(d) {
	    ral_cell t = ral_cell_move(c, d);
	    if (RAL_GRID_CELL_IN(dem, t) AND RAL_GRID_DATACELL(dem, t)) {
		double zt = RAL_GRID_CELL(dem, t);
		if (!f OR zt > z_highest_nbor) {
		    f = 1;
		    z_highest_nbor = zt;
		    if (z_highest_nbor > zc - z_limit) {
			f = 0;
			break;
		    }
		}
	    }
	}
	if (f) {
	    ral_grid_set_real(dem, c, z_highest_nbor);
	    peaks_cut++;
	}
    }
    return peaks_cut;
}


/* mark upslope cells with number m to pp->mark, non recursive, this fct is used a lot */
long ral_mark_upslope_cells(ral_pour_point_struct *pp, ral_cell c, int m)
{
    long size = 0;
    
    ral_cell root = c;
    while (1) {
	ral_cell up;
	int go_up = 0;
	int dir;
	RAL_DIRECTIONS(dir) {
	    up = ral_cell_move(c, dir);
	    if (RAL_GRID_CELL_IN(pp->fdg, up) AND 
		RAL_INTEGER_GRID_DATACELL(pp->fdg, up) AND 
		RAL_INTEGER_GRID_CELL(pp->fdg, up) == RAL_INV_DIR(dir)) {
		if (!RAL_INTEGER_GRID_CELL(pp->mark, up)) {
		    go_up = 1;
		    break;
		}
	    }
	}
	if (go_up)
	    c = up;
	else {
	    RAL_INTEGER_GRID_CELL(pp->mark, c) = m;

	    /* remember the topmost cell (min i) so that direction is away from the area */
	    if (!pp->bc_found OR c.i < pp->bc.i) {
		pp->bc_found = 1;
		pp->bc = c;
		pp->dir_out = RAL_N;
	    }
    
	    size++;
	    if RAL_SAME_CELL(c, root) return size;
	    c = ral_cell_move(c, RAL_INTEGER_GRID_CELL(pp->fdg, c));
	}
    }
}


long ral_fdg_catchment(ral_grid *fdg, ral_grid *mark, ral_cell c, int m)
{
    ral_pour_point_struct pp;
    RAL_CHECK(ral_init_pour_point_struct(&pp, fdg, NULL, mark));
    RAL_CHECKM(RAL_GRID_CELL_IN(fdg, c), RAL_ERRSTR_COB);
    return ral_mark_upslope_cells(&pp, c, m);
 fail:
    return 0;
}


ral_grid *ral_fdg_depressions(ral_grid *fdg, int inc_m)
{
    long m = 1;
    ral_cell c;
    ral_grid *mark = NULL;
    ral_pour_point_struct pp;
    RAL_CHECK(mark = ral_grid_create_like(fdg, RAL_INTEGER_GRID));
    RAL_CHECK(ral_init_pour_point_struct(&pp, fdg, NULL, mark));
    RAL_FOR(c, fdg) {
	if (RAL_INTEGER_GRID_CELL(fdg, c) == RAL_PIT_CELL) {
	    ral_mark_upslope_cells(&pp, c, m);
	    if (inc_m) m++;
	    RAL_CHECKM(m < RAL_INTEGER_MAX, RAL_ERRSTR_IOB);
	}
    }
    return mark;
 fail:
    ral_grid_destroy(&mark);
    return NULL;
}


int ral_fillpit(ral_pour_point_struct *pp, ral_cell c, double zmax)
{
    int size = 1;
    int dir, invdir = 5;
    ral_grid_set_real(pp->dem, c, zmax);
    RAL_DIRECTIONS(dir) {
	ral_cell t = ral_cell_move(c, dir);
	double zt;
	if (!RAL_GRID_CELL_IN(pp->dem, t) OR !RAL_INTEGER_GRID_DATACELL(pp->fdg, t))
	    continue;
	zt = RAL_GRID_CELL(pp->dem, t);
	if (RAL_INTEGER_GRID_CELL(pp->fdg, t) == invdir AND zt < zmax)
	    size += ral_fillpit(pp, t, zmax);
	invdir++;
	if (invdir > 8) invdir = 1;
    }
    return size;
}


int ral_dem_fill_depressions(ral_grid *dem, ral_grid *fdg)
{
    ral_cell c;
    int pits_filled = 0;
    ral_pour_point_struct pp;
    RAL_CHECK(ral_init_pour_point_struct(&pp, fdg, dem, ral_grid_create_like(fdg, RAL_INTEGER_GRID)));
    RAL_FOR(c, fdg) {
	if (RAL_INTEGER_GRID_CELL(fdg, c) == RAL_PIT_CELL) {

	    double zmax;

	    pp.bc_found = 0;
	    ral_mark_upslope_cells(&pp, c, 1);

	    pp.pp_found = 0;
	    pp.pour_to_nodata = 0;
	    RAL_CHECK(ral_borderwalk(pp.bc, pp.dir_out, &pp, &ral_is_marked, &ral_test_pour_point));

	    ral_integer_grid_floodfill(pp.mark, NULL, c, 0, 8);

	    zmax = RAL_GRID_CELL(dem, pp.ipp);
	    if (!pp.pour_to_nodata) zmax = max(zmax, RAL_GRID_CELL(dem, pp.opp));
	    ral_fillpit(&pp, c, zmax);
	    
	    pits_filled++;
	    RAL_CHECKM(pits_filled < INT_MAX, RAL_ERRSTR_IOB);
	} 
    }
    ral_grid_destroy(&pp.mark);
    return pits_filled;
 fail:
    ral_grid_destroy(&pp.mark);
    return -1;
}


/* fdg should have only pits and valid dirs */
int ral_dem_breach(ral_grid *dem, ral_grid *fdg, int limit)
{
    ral_cell c;
    ral_pour_point_struct pp;
    RAL_CHECK(ral_init_pour_point_struct(&pp, fdg, dem, ral_grid_create_like(fdg, RAL_INTEGER_GRID)));
    RAL_FOR(c, fdg) {
	if (RAL_INTEGER_GRID_CELL(fdg, c) == RAL_PIT_CELL) {

	    double z1 = RAL_GRID_CELL(dem, c), z2, l_in, l_out, l;
	    ral_cell flow;
	    int dir, b_count = 0;

	    pp.bc_found = 0;
	    ral_mark_upslope_cells(&pp, c, 1);

	    pp.pp_found = 0;
	    pp.pour_to_nodata = 0;
	    RAL_CHECK(ral_borderwalk(pp.bc, pp.dir_out, &pp, &ral_is_marked, &ral_test_pour_point));
	    ral_integer_grid_floodfill(pp.mark, NULL, c, 0, 8);

	    /* The breach should now be done from ipp to the pit cell
	       (elev = z1) and from opp to the border of data or to
	       cell with elev same or lower than pit elev (elev =
	       z2). Take z1 and z2 and interpolate z's along the
	       breach. */

	    flow = pp.ipp;
	    l_in = 0;
	    while (!RAL_SAME_CELL(flow, c)) {
		if (RAL_GRID_CELL(dem, flow) > z1 + pp.dz) b_count++;
		l_in += RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(fdg, flow));
		flow = RAL_FLOW(fdg, flow);
	    }
	    
	    if (pp.pour_to_nodata) {
		z2 = RAL_GRID_CELL(dem, pp.ipp);
		l_out = 0;
	    } else {
		l_out = RAL_DISTANCE_UNIT(pp.in2out);
		flow = pp.opp;
		b_count++;
		while (1) {
		    z2 = RAL_GRID_CELL(dem, flow);
		    if (z2 <= z1 + pp.dz) break;
		    flow = RAL_FLOW(fdg, flow);
		    b_count++;
		    /* stop searching for the end of breaching if */
		    if (RAL_GRID_CELL_OUT(fdg, flow) OR RAL_GRID_NODATACELL(fdg, flow) OR RAL_INTEGER_GRID_CELL(fdg, flow) < 1) break;
		    l_out += RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(fdg, flow));
		}
	    }

	    /* give up if breaching would require too many cells to be
	       breached or z2 > z1 and not drain to nodata */
	    if (limit > 0 AND b_count > limit) continue;
	    if (z1 < z2-pp.dz AND RAL_GRID_CELL_IN(fdg, flow) AND RAL_GRID_DATACELL(fdg, flow)) continue;
	    
	    flow = pp.ipp;
	    dir = pp.in2out;
	    l = 0;
	    if (RAL_SAME_CELL(flow, c)) {
		RAL_INTEGER_GRID_CELL(fdg, flow) = dir;
	    } else {
		while (!RAL_SAME_CELL(flow, c)) {
		    int tmp = RAL_INTEGER_GRID_CELL(fdg, flow);
		    ral_cell down = RAL_FLOW(fdg, flow);
		    
		    double z = z1 < z2-pp.dz ? z1 : z1 - (z1-z2)*(l_in-l)/(l_in+l_out);
		    ral_grid_set_real(dem, flow, z);
		    
		    /* invert the path */
		    RAL_INTEGER_GRID_CELL(fdg, flow) = dir;
		    dir = RAL_INV_DIR(tmp);
		    
		    l += RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(fdg, flow));
		    flow = down;
		}
	    }
		     
	    if (!pp.pour_to_nodata) {
		l = RAL_DISTANCE_UNIT(pp.in2out);
		flow = pp.opp;
		while (1) {
		    double old_z = RAL_GRID_CELL(dem, flow), z;
		    if (old_z <= z1 + pp.dz) break;
		    z = z1 < z2-pp.dz ? z1 : z1 - (z1-z2)*(l_in+l)/(l_in+l_out);
		    ral_grid_set_real(dem, flow, z);
		    flow = RAL_FLOW(fdg, flow);
		    /* stop breaching if */
		    if (RAL_GRID_CELL_OUT(fdg, flow) OR RAL_GRID_NODATACELL(fdg, flow) OR RAL_INTEGER_GRID_CELL(fdg, flow) < 1) break;
		    l += RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(fdg, flow));
		}
	    }

	} 
    }
    ral_grid_destroy(&pp.mark);
    return 1;
 fail:
    ral_grid_destroy(&pp.mark);
    return 0;
}


int ral_fdg_drain_depressions(ral_grid *fdg, ral_grid *dem) 
{
    ral_cell c;
    int fixed_pits = 0;
    ral_pour_point_struct pp;
    RAL_CHECK(ral_init_pour_point_struct(&pp, fdg, dem, ral_grid_create_like(fdg, RAL_INTEGER_GRID)));
    RAL_FOR(c, fdg) {
	if (RAL_INTEGER_GRID_CELL(fdg, c) != RAL_PIT_CELL) continue;
	
	pp.bc_found = 0;
	ral_mark_upslope_cells(&pp, c, 1);
	
	/* walk the border, start from border set by mark_upslope_cells (min i) */
	pp.pp_found = 0;
	pp.pour_to_nodata = 0;
	RAL_CHECK(ral_borderwalk(pp.bc, pp.dir_out, &pp, &ral_is_marked, &ral_test_pour_point));

	if (!RAL_SAME_CELL(pp.ipp, c)) {
	    /* invert the path from the pour point to the pit point */
	    /* from pour_point to pit */
	    ral_cell a = pp.ipp;
	    int da = RAL_INTEGER_GRID_CELL(pp.fdg, a);
	    ral_cell b = ral_cell_move(a, da);
	    int db = RAL_INTEGER_GRID_CELL(pp.fdg, b);
	    while (db) {
		RAL_INTEGER_GRID_CELL(pp.fdg, b) = RAL_INV_DIR(da);
		a = b;
		da = db;
		b = ral_cell_move(a, da);
		db = RAL_INTEGER_GRID_CELL(pp.fdg, b); 
	    }
	    RAL_INTEGER_GRID_CELL(pp.fdg, b) = RAL_INV_DIR(da);
	}

	RAL_INTEGER_GRID_CELL(pp.fdg, pp.ipp) = pp.in2out;
	ral_integer_grid_floodfill(pp.mark, NULL, c, 0, 8);
	fixed_pits++;
    }
    ral_grid_destroy(&pp.mark);
    return fixed_pits;
 fail:
    ral_grid_destroy(&pp.mark);
    return -1;
}


#define RAL_ON_PATH(fdg, c, stop)			\
    (RAL_GRID_CELL_IN((fdg), (c)) AND			\
     RAL_INTEGER_GRID_DATACELL((fdg), (c)) AND		\
     RAL_INTEGER_GRID_CELL((fdg), (c)) > 0 AND		\
     RAL_INTEGER_GRID_CELL((fdg), (c)) < 9 AND		\
     (!(stop) OR (RAL_GRID_DATACELL((stop), (c)) AND	\
		  RAL_GRID_CELL((stop), (c)) <= 0)))

ral_grid *ral_fdg_path(ral_grid *fdg, ral_cell c, ral_grid *stop)
{
    ral_grid *path = NULL;
    if (stop) RAL_CHECKM(ral_grid_overlayable(fdg, stop), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_FDG_INTEGER);
    RAL_CHECK(path = ral_grid_create_like(fdg, RAL_INTEGER_GRID));
    if (!ral_grid_has_nodata_value(path))
	RAL_CHECK(ral_grid_set_real_nodata_value(path, -9999));
    RAL_CHECK(ral_grid_set_all_nodata(path));
    while (RAL_ON_PATH(fdg, c, stop)) {
	
	RAL_INTEGER_GRID_CELL(path, c) = 1;
	c = RAL_FLOW(fdg, c);

    }
    return path;
 fail:
    ral_grid_destroy(&path);
    return NULL;
}


ral_grid *ral_fdg_path_length(ral_grid *fdg, ral_grid *stop, ral_grid *op)
{
    ral_grid *path_length;
    ral_cell c;
    if (stop) RAL_CHECKM(ral_grid_overlayable(fdg, stop), RAL_ERRSTR_ARGS_OVERLAYABLE);
    if (op) RAL_CHECKM(ral_grid_overlayable(fdg, op), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_FDG_INTEGER);

    RAL_CHECK(path_length = ral_grid_create_like(fdg, RAL_REAL_GRID));
    if (!ral_grid_has_nodata_value(path_length))
	RAL_CHECK(ral_grid_set_real_nodata_value(path_length, -9999));
    RAL_CHECK(ral_grid_set_all_nodata(path_length));

    RAL_FOR(c, fdg) {

	int prev_dir = -1;
	double length = 0;
	ral_cell prev;
	ral_cell d = c;

	if (RAL_INTEGER_GRID_NODATACELL(fdg, c) OR
	    RAL_INTEGER_GRID_CELL(fdg, c) < 1 OR
	    RAL_INTEGER_GRID_CELL(fdg, c) > 8)
	    continue;
	
	while (RAL_ON_PATH(fdg, d, stop)) {

	    /* within d but two directions */
	    if (!op OR (RAL_GRID_DATACELL(op, d))) {
		    
		if (prev_dir > 0)
		    length += RAL_DISTANCE_UNIT(prev_dir) / 2.0;
	    
		length += RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(fdg, d)) / 2.0;

	    }

	    prev_dir = RAL_INTEGER_GRID_CELL(fdg, d);
	    prev = d;
	    d = RAL_FLOW(fdg, d);

	}

	if (!op OR (RAL_GRID_CELL_IN(op, d) AND RAL_GRID_DATACELL(op, d)))
	    
	    length += RAL_DISTANCE_UNIT(prev_dir) / 2.0;

	RAL_REAL_GRID_CELL(path_length, c) = length * fdg->cell_size;

    }

    return path_length;
 fail:
    ral_grid_destroy(&path_length);
    return NULL;
}


ral_grid *ral_fdg_path_sum(ral_grid *fdg, ral_grid *stop, ral_grid *op)
{
    ral_grid *path_sum;
    ral_cell c;
    if (stop) RAL_CHECKM(ral_grid_overlayable(fdg, stop), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(ral_grid_overlayable(fdg, op), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_FDG_INTEGER);

    RAL_CHECK(path_sum = ral_grid_create_like(fdg, RAL_REAL_GRID));
    if (!ral_grid_has_nodata_value(path_sum))
	RAL_CHECK(ral_grid_set_real_nodata_value(path_sum, -9999));
    RAL_CHECK(ral_grid_set_all_nodata(path_sum));

    RAL_FOR(c, fdg) {

	int prev_dir = -1;
	double sum = 0;
	ral_cell prev;
	ral_cell d = c;

	if (RAL_INTEGER_GRID_NODATACELL(fdg, c) OR
	    RAL_INTEGER_GRID_CELL(fdg, c) < 1 OR
	    RAL_INTEGER_GRID_CELL(fdg, c) > 8)
	    continue;
	
	while (RAL_ON_PATH(fdg, d, stop)) {
	    
	    /* within d but two directions */
	    if (RAL_GRID_DATACELL(op, d)) {
		
		if (prev_dir > 0)
		    sum += RAL_GRID_CELL(op, d) * RAL_DISTANCE_UNIT(prev_dir) / 2.0;
	    
		sum += RAL_GRID_CELL(op, d) * RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(fdg, d)) / 2.0;

	    }
	    
	    prev_dir = RAL_INTEGER_GRID_CELL(fdg, d);
	    prev = d;
	    d = RAL_FLOW(fdg, d);
	    
	}

	if (RAL_GRID_CELL_IN(op, d) AND RAL_GRID_DATACELL(op, d))
	    
	    sum += RAL_GRID_CELL(op, d) * RAL_DISTANCE_UNIT(prev_dir) / 2.0;

	RAL_REAL_GRID_CELL(path_sum, c) = sum;

    }

    return path_sum;
 fail:
    ral_grid_destroy(&path_sum);
    return NULL;
}


ral_grid *ral_fdg_upslope_sum(ral_grid *fdg, ral_grid *op, int include_self)
{
    ral_grid *sum_grid = NULL;
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(fdg, op), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_FDG_INTEGER);
    RAL_CHECK(sum_grid = ral_grid_create_like(fdg, RAL_REAL_GRID));
    if (!ral_grid_has_nodata_value(sum_grid))
	RAL_CHECK(ral_grid_set_real_nodata_value(sum_grid, -9999));
    RAL_CHECK(ral_grid_set_all_nodata(sum_grid));
    RAL_FOR(c, fdg) {
	ral_cell d;
	/* nodata or already computed? */
	if (!RAL_INTEGER_GRID_DATACELL(fdg, c) OR RAL_REAL_GRID_DATACELL(sum_grid, c))
	    continue;
	/* visit all upslope cells with d and compute the sum */
	d = c;
	while (1) {
	    ral_cell up;
	    double sum = 0;
	    /* can we compute the sum from immediately upstream cells? */
	    int go_up = 0;
	    int dir;
	    RAL_DIRECTIONS(dir) {
		up = ral_cell_move(d, dir);
		if (RAL_GRID_CELL_IN(fdg, up) AND 
		    RAL_INTEGER_GRID_DATACELL(fdg, up) AND 
		    RAL_INTEGER_GRID_CELL(fdg, up) == RAL_INV_DIR(dir)) {
		    if (RAL_REAL_GRID_NODATACELL(sum_grid, up)) {
			/* at least one upslope cell has non-resolved upslope sum */
			go_up = 1;
			break;
		    } else {
			sum += RAL_REAL_GRID_CELL(sum_grid, up);
			if (!include_self AND RAL_GRID_DATACELL(op, up))
			    sum += RAL_GRID_CELL(op, up);
		    }
		}
	    }
	    if (go_up)
		d = up;
	    else {
		if (include_self AND RAL_GRID_DATACELL(op, d))
		    sum += RAL_GRID_CELL(op, d);
		RAL_REAL_GRID_CELL(sum_grid, d) = sum;
		if RAL_SAME_CELL(d, c) break;
		d = RAL_FLOW(fdg, d);
	    }
	}
    }
    return sum_grid;
 fail:
    ral_grid_destroy(&sum_grid);
    return NULL;
}


ral_grid *ral_fdg_upslope_count(ral_grid *fdg, ral_grid *op, int include_self)
{
    ral_grid *count_grid = NULL;
    ral_cell c;
    if (op) RAL_CHECKM(ral_grid_overlayable(fdg, op), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_FDG_INTEGER);
    RAL_CHECK(count_grid = ral_grid_create_like(fdg, RAL_REAL_GRID));
    if (!ral_grid_has_nodata_value(count_grid))
	RAL_CHECK(ral_grid_set_real_nodata_value(count_grid, -9999));
    RAL_CHECK(ral_grid_set_all_nodata(count_grid));
    RAL_FOR(c, fdg) {
	ral_cell d;
	/* nodata or already computed? */
	if (!RAL_INTEGER_GRID_DATACELL(fdg, c) OR RAL_REAL_GRID_DATACELL(count_grid, c))
	    continue;
	/* visit all upslope cells with d and compute the sum */
	d = c;
	while (1) {
	    ral_cell up;
	    double count = 0;
	    /* can we compute the count from immediately upstream cells? */
	    int go_up = 0;
	    int dir;
	    RAL_DIRECTIONS(dir) {
		up = ral_cell_move(d, dir);
		if (RAL_GRID_CELL_IN(fdg, up) AND 
		    RAL_INTEGER_GRID_DATACELL(fdg, up) AND 
		    RAL_INTEGER_GRID_CELL(fdg, up) == RAL_INV_DIR(dir)) {
		    if (RAL_REAL_GRID_NODATACELL(count_grid, up)) {
			/* at least one upslope cell has non-resolved upslope count */
			go_up = 1;
			break;
		    } else {
			count += RAL_REAL_GRID_CELL(count_grid, up);
			if (!include_self AND (!op OR RAL_GRID_DATACELL(op, up)))
			    count += 1;
		    }
		}
	    }
	    if (go_up)
		d = up;
	    else {
		if (include_self) {
		    if (!op OR RAL_GRID_DATACELL(op, d)) 
			count += 1;
		}
		RAL_REAL_GRID_CELL(count_grid, d) = count;
		if RAL_SAME_CELL(d, c) break;
		d = RAL_FLOW(fdg, d);
	    }
	}
    }
    return count_grid;
 fail:
    ral_grid_destroy(&count_grid);
    return NULL;
}


ral_grid_handle RAL_CALL ral_water_route(ral_grid *water, ral_grid *dem, ral_grid *fdg, ral_grid *k, double r)
{
    ral_cell c;
    ral_grid *f = NULL;
    RAL_CHECKM(ral_grid_overlayable(water, dem) AND 
	       (!fdg OR ral_grid_overlayable(water, fdg)) AND 
	       ral_grid_overlayable(water, k), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM((water->datatype == RAL_REAL_GRID) AND 
	       (!fdg OR (fdg->datatype == RAL_INTEGER_GRID)) AND 
	       (k->datatype == RAL_REAL_GRID), RAL_ERRSTR_ARGS_REAL);
    RAL_CHECK(f = ral_grid_create_like(water, RAL_REAL_GRID));

    RAL_FOR(c, water) {

	double S = RAL_REAL_GRID_CELL(water, c);

	if (fdg AND RAL_INTEGER_GRID_DATACELL(fdg, c)) {
	    
	    ral_cell down = ral_cell_move(c, RAL_INTEGER_GRID_CELL(fdg, c));

	    if (RAL_GRID_CELL_OUT(fdg, down) OR RAL_INTEGER_GRID_NODATACELL(fdg, down))
		RAL_REAL_GRID_CELL(f, c) -= S;
	    else {
		double u = RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(fdg, c));
		double slope = r * (RAL_GRID_CELL(dem, c) - RAL_GRID_CELL(dem, down)) / (dem->cell_size * u);
		double dS = RAL_REAL_GRID_CELL(k, c) * sqrt(slope) * S;
		RAL_REAL_GRID_CELL(f, c) -= dS;
		RAL_REAL_GRID_CELL(f, down) += dS;
	    }

	} else if (RAL_GRID_DATACELL(dem, c)) {

	    int dir;
	    for (dir = 1; dir < 9; dir += 2) { /* N, E, S, W */
		ral_cell down = ral_cell_move(c, dir);
		if (RAL_GRID_CELL_OUT(water, down) OR RAL_INTEGER_GRID_NODATACELL(water, down))
		    RAL_REAL_GRID_CELL(f, c) -= S;
		else {
		    double slope = r * (RAL_GRID_CELL(dem, c) - RAL_GRID_CELL(dem, down)) / dem->cell_size;
		    double dS = RAL_REAL_GRID_CELL(k, c) * sqrt(slope) * S;
		    if (slope > 0) {
			RAL_REAL_GRID_CELL(f, c) -= dS;
			RAL_REAL_GRID_CELL(f, down) += dS;
		    }
		}
	    }
	}
    }
    return f;
 fail:
    if (f) ral_grid_destroy(&f);
    return NULL;
}


typedef struct {
    ral_grid *fdg;             /* flow dir grid */
    ral_grid *dem;             /* dem grid */
    ral_grid *flat;            /* all flat area */
    ral_grid *ss;              /* slope sums */
    ral_grid *uag;
    double dz;             /* flatness threshold */
} ral_cuag2_struct;


int ral_find_flats(ral_cuag2_struct *pp) 
{
    ral_cell c;
    RAL_FOR(c, pp->fdg) {
	if (RAL_GRID_DATACELL(pp->fdg, c)) {
	    double zc = RAL_GRID_CELL(pp->dem, c);
	    int dir, is_flat = 1;
	    RAL_DIRECTIONS(dir) {
		ral_cell t = ral_cell_move(c, dir);
		double zt = RAL_GRID_CELL(pp->dem, t);
		/* this marks pits as flat but there shouldn't be any pits */
		if (RAL_GRID_CELL_IN(pp->fdg, t) AND RAL_GRID_DATACELL(pp->fdg, t) AND zt < zc - pp->dz) {
		    is_flat = 0;
		    break;
		}
	    }
	    RAL_INTEGER_GRID_CELL(pp->flat, c) = is_flat;
	} else {
	    RAL_INTEGER_GRID_SETNODATACELL(pp->flat, c);
	}
    }
    return 1;
}


int ral_slope_sums(ral_cuag2_struct *pp)
{
    ral_cell c;
    RAL_FOR(c, pp->fdg) {
	if (RAL_GRID_DATACELL(pp->fdg, c)) {
	    double zc = RAL_GRID_CELL(pp->dem, c);
	    double slope_sum = 0;
	    int dir;
	    RAL_DIRECTIONS(dir) {
		ral_cell t = ral_cell_move(c, dir);
		double zt;
		if (RAL_GRID_CELL_IN(pp->fdg, t) AND 
		    RAL_INTEGER_GRID_DATACELL(pp->fdg, t) AND
		    (zt = RAL_GRID_CELL(pp->dem, t)) < zc - pp->dz)
		    slope_sum += (zc - zt)/RAL_DISTANCE_UNIT(dir);
	    }
	    RAL_REAL_GRID_CELL(pp->ss, c) = slope_sum;
	} else {
	    RAL_REAL_GRID_SETNODATACELL(pp->ss, c);
	}
    }
    return 1;
}


int ral_cuag2(ral_cuag2_struct *pp, ral_cell c, int recursion) 
{
    int dir, invdir = 5;
    double ua = 1; 
    /* upslope area is 1 + that part of higher lying cells that comes
       to this cell

       if this cell is on flat area (i.e. the lowest 8-neighbor has
       the same z as this) then use the fdg to find the upslope cells
       and portion is 1 if the upslope cell is flat otherwise use the
       portion coeff */
    double zc = RAL_GRID_CELL(pp->dem, c);
    RAL_DIRECTIONS(dir) {
	ral_cell t = ral_cell_move(c, dir);
	if (RAL_GRID_CELL_IN(pp->fdg, t) AND RAL_INTEGER_GRID_DATACELL(pp->fdg, t)) {
	    double zt = RAL_GRID_CELL(pp->dem, t);
	    if (fabs(zc - zt) <= pp->dz AND RAL_INTEGER_GRID_CELL(pp->flat, t) AND RAL_INTEGER_GRID_CELL(pp->fdg, t) == invdir) {
		if (RAL_REAL_GRID_CELL(pp->uag, t) > 0 OR !recursion) {
		    ua += RAL_REAL_GRID_CELL(pp->uag, t);
		} else {
		    ua += RAL_REAL_GRID_CELL(pp->uag, t) = ral_cuag2(pp, t, 1);
		}
	    } else if (zt > zc + pp->dz) {
		if (RAL_REAL_GRID_CELL(pp->uag, t) > 0 OR !recursion)
		    ua += ((zt - zc)/RAL_DISTANCE_UNIT(dir))/RAL_REAL_GRID_CELL(pp->ss, t)*RAL_REAL_GRID_CELL(pp->uag, t);
		else {
		    RAL_REAL_GRID_CELL(pp->uag, t) = ral_cuag2(pp, t, 1);
		    ua += ((zt - zc)/RAL_DISTANCE_UNIT(dir))/RAL_REAL_GRID_CELL(pp->ss, t)*RAL_REAL_GRID_CELL(pp->uag, t);
		}
	    }
	}
	invdir++;
	if (invdir > 8) invdir = 1;
    }
    return ua;
}


int ral_mb(ral_pour_point_struct *pp, ral_grid *streams, ral_cell c, int k) 
{
    ral_cell c0 = c;
    int d = RAL_INTEGER_GRID_CELL(pp->fdg, c); /* direction at current cell */
    int n = 1;                /* nr. of possible directions to go */
    ral_cell c2 = c;              /* moving cursor */
    int d2 = d; 
    /* seek to the end of this stream */
    while (n == 1) {
	int dt = d2; /* test direction */
	dt = RAL_NEXT_DIR(dt);
	n = 0;
	c = c2;
	d = d2;
	while (dt != d) { /* test all directions */
	    ral_cell t = c; /* test cell */
	    int di = RAL_INV_DIR(dt); /* upstream cell has this fd */
	    t = ral_cell_move(t, dt);
	    if (RAL_GRID_CELL_IN(pp->fdg, t) AND 
		RAL_INTEGER_GRID_DATACELL(streams, t) AND RAL_INTEGER_GRID_CELL(streams, t) AND RAL_INTEGER_GRID_CELL(pp->fdg, t) == di) {
		n++;
		c2 = t;
		d2 = di;
	    }
	    dt++;
	    if (dt > 8) {
		dt = 1;
		if (d == 0) break;
	    }
	}
    }
    if (n > 1) { /* junction, recurse to all upstream streams */
	int dt = RAL_NEXT_DIR(d);
	while (dt != d) { /* test all directions */
	    ral_cell t = c; /* test cell */
	    int di = RAL_INV_DIR(dt); /* upstream cell has this fd */
	    t = ral_cell_move(t, dt);
	    if (RAL_GRID_CELL_IN(pp->fdg, t) AND 
		RAL_INTEGER_GRID_DATACELL(streams, t) AND RAL_INTEGER_GRID_CELL(streams, t) AND 
		RAL_INTEGER_GRID_CELL(pp->fdg, t) == di) {
		if (!(k = ral_mb(pp, streams, t, k))) 
		    return 0;
	    }
	    dt++;
	    if (dt > 8) {
		dt = 1;
		if (d == 0) break;
	    }
	}
    }
    /* now mark this subcatchment and we are done */
    ral_mark_upslope_cells(pp, c0, k);
    k++;
    return k;
}


ral_grid *ral_streams_subcatchments(ral_grid *streams, ral_grid *fdg, ral_cell c) 
{
    int k = 1;
    ral_pour_point_struct pp;
    RAL_CHECKM((streams->datatype = RAL_INTEGER_GRID) AND (fdg->datatype = RAL_INTEGER_GRID), RAL_ERRSTR_ARGS_INTEGER);
    RAL_CHECKM(RAL_GRID_CELL_IN(streams, c) AND (RAL_INTEGER_GRID_CELL(streams, c) != 0), RAL_ERRSTR_STREAMS_SUBCATCHMENTS);
    RAL_CHECK(ral_init_pour_point_struct(&pp, fdg, NULL, ral_grid_create_like(fdg, RAL_INTEGER_GRID)));
    RAL_CHECK(k = ral_mb(&pp, streams, c, k));
    return pp.mark;
 fail:
    ral_grid_destroy(&pp.mark);
    return NULL;
}


ral_grid *ral_streams_subcatchments2(ral_grid *streams, ral_grid *fdg)
{
    int k = 1;
    ral_cell c;
    ral_pour_point_struct pp;
    RAL_CHECKM((streams->datatype = RAL_INTEGER_GRID) AND (fdg->datatype = RAL_INTEGER_GRID), RAL_ERRSTR_ARGS_INTEGER);
    RAL_CHECK(ral_init_pour_point_struct(&pp, fdg, NULL, ral_grid_create_like(fdg, RAL_INTEGER_GRID)));
    RAL_FOR(c, fdg) {
	if (ral_fdg_is_outlet(fdg, c))
	    RAL_CHECK(k = ral_mb(&pp, streams, c, k));
    }
    return pp.mark;
 fail:
    ral_grid_destroy(&pp.mark);
    return NULL;
}


int ral_upstream_cells_of(ral_grid *streams, ral_grid *fdg, ral_cell c, ral_cell u[]) 
{
    int n = 0;
    int dir;
    RAL_DIRECTIONS(dir) {
	ral_cell t = ral_cell_move(c, dir);
	if (RAL_GRID_CELL_IN(streams, t) AND RAL_INTEGER_GRID_DATACELL(streams, t) AND 
	    RAL_INTEGER_GRID_CELL(streams, t) AND RAL_INTEGER_GRID_CELL(fdg, t) == RAL_INV_DIR(dir)) {
	    u[n] = t;
	    n++;
	}
    }
    return n;
}


int ral_number_tree(ral_grid *streams, ral_grid *fdg, ral_cell c, int k) 
{
    while (1) {
	/* move along the stream from b onwards */    
	int n;
	ral_cell u[8];  /* upstream cells */
	RAL_INTEGER_GRID_CELL(streams, c) = k;
	n = ral_upstream_cells_of(streams, fdg, c, u);

	if (n == 0) break; /* b is the end cell of the stream */

	if (n == 1) { /* b is a stream cell */
	    c = u[0];

	} else { /* a cell where two or more streams join */
	    int i;
	    for (i = 0; i < n; i++)
		k = ral_number_tree(streams, fdg, u[i], k+1);
	    break;
	}

    }
    return k;
}

void ral_mark_tree(ral_grid *streams, ral_grid *fdg, ral_cell c, int index) 
{
  while (1) {
    /* move up the stream from c onwards */    
    int n;
    ral_cell u[8];  /* upstream cells */
    RAL_INTEGER_GRID_CELL(streams, c) = index;
    n = ral_upstream_cells_of(streams, fdg, c, u);
    
    if (n == 0) break; /* c is the end cell of the stream */
    
    if (n == 1) { /* c is a stream cell */
      c = u[0];
      
    } else { /* a cell where two or more streams join */
      int i;
      for (i = 0; i < n; i++)
	ral_mark_tree(streams, fdg, u[i], index);
      break;
    }
  }
}


int ral_streams_number(ral_grid *streams, ral_grid *fdg, ral_cell c, int sid0) 
{
    RAL_CHECKM(ral_grid_overlayable(streams, fdg), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_FDG_INTEGER);
    RAL_CHECKM(streams->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_STREAMS_INTEGER);
    RAL_CHECKM(RAL_GRID_CELL_IN(streams, c), RAL_ERRSTR_COB);
    ral_number_tree(streams, fdg, c, sid0);
    return 1;
 fail:
    return 0;
}


int ral_streams_number2(ral_grid *streams, ral_grid *fdg, int sid0) 
{
    ral_cell c;
    RAL_CHECKM(ral_grid_overlayable(streams, fdg), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_FDG_INTEGER);
    RAL_CHECKM(streams->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_STREAMS_INTEGER);
    RAL_FOR(c, fdg) {
	if (ral_fdg_is_outlet(fdg, c))
	    sid0 = ral_number_tree(streams, fdg, c, sid0)+1;
    }
    return 1;
 fail:
    return 0;
}


#ifdef RAL_HAVE_GDAL
int ral_create_streams_vector(ral_grid *streams, ral_grid *fdg, ral_cell c, int k, \
			      OGRFeatureH hFeat, OGRGeometryH hGeom, OGRLayerH hLayer) 
{
  int n;
  double dist, maxdist = 1000000000000.0;
  ral_point p;
  ral_cell d, u[8];  /* upstream cells */

  dist = RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(fdg, c))*ral_grid_get_cell_size(streams);  
  while (1) {
    /* move along the stream from c onwards */    
    p = ral_grid_cell2point(streams, c);
    OGR_G_AddPoint_2D(hGeom, p.x, p.y);
    dist += RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(fdg, c))*ral_grid_get_cell_size(streams);
    RAL_INTEGER_GRID_CELL(streams, c) = k;
    n = ral_upstream_cells_of(streams, fdg, c, u);
    
    if (n == 0) { /* b is the end cell of the stream */
      OGR_F_SetGeometry(hFeat, hGeom); 
      OGR_L_CreateFeature(hLayer, hFeat);  
      OGR_G_DestroyGeometry(hGeom);  
      OGR_F_Destroy(hFeat);
      break; 
    }    

    if (n == 1) { /* b is a stream cell */
      c = u[0];
      if (dist > maxdist) {
	k++;
	OGR_F_SetGeometry(hFeat, hGeom); 
	OGR_L_CreateFeature(hLayer, hFeat);  
	OGR_G_DestroyGeometry(hGeom);  
	OGR_F_Destroy(hFeat);
	hFeat = OGR_F_Create(OGR_L_GetLayerDefn(hLayer)); 
	OGR_F_SetFieldInteger(hFeat, 0, k);
	d = RAL_FLOW(fdg, c);
	OGR_F_SetFieldInteger(hFeat, 1, RAL_INTEGER_GRID_CELL(streams, d));
	hGeom = OGR_G_CreateGeometry(wkbLineString);
	OGR_G_AddPoint_2D(hGeom, p.x, p.y);
	dist = RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(fdg, c))*ral_grid_get_cell_size(streams);
      }
      
    } else { /* a cell where two or more streams join */
      int i;
      OGR_F_SetGeometry(hFeat, hGeom); 
      OGR_L_CreateFeature(hLayer, hFeat);  
      OGR_G_DestroyGeometry(hGeom);  
      OGR_F_Destroy(hFeat);
      for (i = 0; i < n; i++) {
	hFeat = OGR_F_Create(OGR_L_GetLayerDefn(hLayer)); 
	OGR_F_SetFieldInteger(hFeat, 0, k+1);
	d = RAL_FLOW(fdg, c);
	OGR_F_SetFieldInteger(hFeat, 1, RAL_INTEGER_GRID_CELL(streams, d)); 
	hGeom = OGR_G_CreateGeometry(wkbLineString);
	OGR_G_AddPoint_2D(hGeom, p.x, p.y);
	k = ral_create_streams_vector(streams, fdg, u[i], k+1, hFeat, hGeom, hLayer);
      }
      break;
    }
  }
  return k;
}

int ral_streams_vectorize(ral_grid *streams, ral_grid *fdg, int row, int col)
{
  const char *pszDriverName = "ESRI Shapefile";
  ral_cell c;
  ral_grid *str;
  OGRSFDriverH hDr;
  OGRDataSourceH hDS;
  OGRLayerH hLayer;
  OGRFieldDefnH hFldDefn;
  OGRFeatureH hFeat;
  OGRGeometryH hGeom;

  RAL_CHECKM(ral_grid_overlayable(streams, fdg), RAL_ERRSTR_ARGS_OVERLAYABLE);
  str = ral_grid_create_copy(streams, RAL_INTEGER_GRID);
  c.i = row;
  c.j = col;
  OGRRegisterAll();
  hDr = OGRGetDriverByName(pszDriverName);
  /* CHECK IF DRIVER IS NULL */
  hDS = OGR_Dr_CreateDataSource(hDr, "c:\\testOGR.shp", NULL);
  /*CHECK IF DATASOURCE IS NULL*/
  hLayer = OGR_DS_CreateLayer(hDS, "test", NULL, wkbUnknown, NULL);
  /*CHECK IF LAYER IS NULL*/
  hFldDefn = OGR_Fld_Create("StreamID", OFTInteger);
  OGR_Fld_SetWidth(hFldDefn, 32);
  OGR_L_CreateField(hLayer, hFldDefn, TRUE);
  hFldDefn = OGR_Fld_Create("FlowsTo", OFTInteger);
  OGR_Fld_SetWidth(hFldDefn, 32);
  OGR_L_CreateField(hLayer, hFldDefn, TRUE);
  /*CHECK IF  RETURNED OGREEROR TELLS SOMETHINGI*/
  hFeat = OGR_F_Create(OGR_L_GetLayerDefn(hLayer));
  OGR_F_SetFieldInteger(hFeat, 0, 1); 
  OGR_F_SetFieldInteger(hFeat, 1, 0); 
  hGeom = OGR_G_CreateGeometry(wkbLineString);
  ral_create_streams_vector(str, fdg, c, 1, hFeat, hGeom, hLayer);

  ral_grid_destroy(&str);
  OGR_DS_Destroy(hDS);
  return 1;

 fail:
  /* if (str) ral_gddestroy(str);*/
  return 0;
}
#endif

typedef struct {
    ral_grid *lakes;
    ral_grid *streams;
    ral_grid *fdg;
    ral_grid *uag;
    ral_grid *mark;
    int lid;       /* lake, whose next-to-shore cells we are boating */
    int sid;       /* stored stream id */
    int nsid;      /* next available stream id */
    double min_l;  /* min_l in pruning */
    int outlet_found;
    double max_ua; /* maximum upslope area */
    ral_cell outlet;   /* the cell with max_ua */
    int bc_found;  /* as bc in ral_pour_point_struct */
    ral_cell bc;
    int dir_out;
    int counter;
} ral_lakedata;


int ral_rprune(ral_lakedata *ld, ral_cell a, double from_origin_to_a, int *was_pruned);


/* borderwalk do-your-thing functions for lakedata struct: */

int ral_prunelake(void *fctparam1, ral_cell c) 
{
    ral_lakedata *ld = (ral_lakedata *)fctparam1;
    int dir;

    if (RAL_INTEGER_GRID_CELL(ld->mark, c)) return 1;
    RAL_INTEGER_GRID_CELL(ld->mark, c) = 1;
    
    /* neighboring non-lake stream cells */
    RAL_DIRECTIONS(dir) {

	ral_cell t = ral_cell_move(c, dir);

	if (RAL_GRID_CELL_OUT(ld->lakes, t) OR (RAL_INTEGER_GRID_CELL(ld->lakes, t) == ld->lid)) continue;

	if (RAL_INTEGER_GRID_DATACELL(ld->streams, t) AND RAL_INTEGER_GRID_CELL(ld->streams, t)) {

	    /* does the stream cell flow into this cell? */
	    
	    if (RAL_SAME_CELL(c, RAL_FLOW(ld->fdg, t))) {
		
		/* the test cell flows into the lake, prune this stream */
		RAL_CHECK(ral_rprune(ld, t, RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(ld->fdg, t)) * ld->fdg->cell_size, NULL));

	    }
	    
	}
    }
    return 1;
 fail:
    return 0;
}


int ral_lakearea(void *fctparam1, ral_cell c)
{
   return RAL_GRID_CELL_IN(((ral_lakedata *)fctparam1)->lakes, c) AND 
	RAL_INTEGER_GRID_DATACELL(((ral_lakedata *)fctparam1)->lakes, c) AND 
	RAL_INTEGER_GRID_CELL(((ral_lakedata *)fctparam1)->lakes, c) == ((ral_lakedata *)fctparam1)->lid;
}


/* 
   renumber the stream upstream from cell c with id id 
   stop at a lake if it is given 
*/
void ral_renumber_stream(ral_grid *streams, ral_grid *fdg, ral_grid *lakes, ral_cell c, int id) 
{
    while (1) {
	/* move along the arc from c onwards */    
	int k;
	ral_cell u[8]; /* upstream cells */
	RAL_INTEGER_GRID_CELL(streams, c) = id;
	k = ral_upstream_cells_of(streams, fdg, c, u);
	if (k == 0) break; /* c is an end cell of a stream */
	if (k == 1) {      /* c is a stream cell */
	    if (lakes AND RAL_INTEGER_GRID_DATACELL(lakes, u[0]) AND RAL_INTEGER_GRID_CELL(lakes, u[0])) 
		break;
	    c = u[0];
	} else             /* a cell where two or more streams join */
	    break;
    }
}


int ral_rprune(ral_lakedata *ld, ral_cell a, double from_origin_to_a, int *was_pruned) 
{
    ral_cell b = a;
    double l = from_origin_to_a;
    if (was_pruned) *was_pruned = 0;
    if (ld->lakes AND RAL_INTEGER_GRID_DATACELL(ld->lakes, a) AND RAL_INTEGER_GRID_CELL(ld->lakes, a)) { /* on a lake */
	int lid = ld->lid;
	ld->lid = RAL_INTEGER_GRID_CELL(ld->lakes, a);
	/* look for streams that flow into the lake  */
	RAL_CHECK(ral_borderwalk(a, RAL_INTEGER_GRID_CELL(ld->fdg, a), ld, &ral_lakearea, &ral_prunelake));
	ld->lid = lid;
	return 1;
    }
    while (1) {

	/* move along the stream from a onwards */
	int n;

	ral_cell u[8];  /* upstream cells */

	RAL_CHECKM(!RAL_INTEGER_GRID_CELL(ld->mark, b), RAL_ERRSTR_LOOP);

	RAL_INTEGER_GRID_CELL(ld->mark, b) = 1;

	n = ral_upstream_cells_of(ld->streams, ld->fdg, b, u);

	if (n == 0) { /* b is the end cell of the stream */

	    if (l < ld->min_l) { /* this stream is too short, prune it */
		ral_cell x = b;
		while (1) {
		    RAL_INTEGER_GRID_CELL(ld->streams, x) = 0;
		    if (RAL_SAME_CELL(x, a)) break;
		    x = RAL_FLOW(ld->fdg, x);
		}
		if (was_pruned) *was_pruned = 1;
	    }
	    break;

	} else if (n == 1) { /* b is a regular stream cell */

	    if (ld->lakes AND RAL_INTEGER_GRID_DATACELL(ld->lakes, u[0]) AND RAL_INTEGER_GRID_CELL(ld->lakes, u[0])) { 
		/* with a lake cell just upstream */	
		/* backup lid, there may be lakes behind the lakes */
		int lid = ld->lid;
		ld->lid = RAL_INTEGER_GRID_CELL(ld->lakes, u[0]);
		/* look for streams that flow into the lake  */
		RAL_CHECK(ral_borderwalk(u[0], RAL_INTEGER_GRID_CELL(ld->fdg, u[0]), ld, &ral_lakearea, &ral_prunelake));
		ld->lid = lid;
		break;
	    } else {
		l += RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(ld->fdg, u[0])) * ld->fdg->cell_size;
		b = u[0];
	    }

	} else { /* b is a cell where two or more streams join */

	    int i;
	    for (i = 0; i < n; i++) {
		if (ld->lakes AND RAL_INTEGER_GRID_DATACELL(ld->lakes, u[i]) AND RAL_INTEGER_GRID_CELL(ld->lakes, u[i])) {
		    /* backup lid, there may be lakes behind the lakes */
		    int lid = ld->lid;
		    ld->lid = RAL_INTEGER_GRID_CELL(ld->lakes, u[i]);
		    RAL_CHECK(ral_borderwalk(u[i], RAL_INTEGER_GRID_CELL(ld->fdg, u[0]), ld, &ral_lakearea, &ral_prunelake));
		    ld->lid = lid;
		} else {
		    double l_zero = RAL_DISTANCE_UNIT(RAL_INTEGER_GRID_CELL(ld->fdg, u[i]))*ld->fdg->cell_size;
		    /* join the remaining upstream stream if there is now no junction */
		    int pruned;
		    RAL_CHECK(ral_rprune(ld, u[i], l_zero, &pruned));
		    if (pruned AND n == 2) {
			int j = i == 0 ? 1 : 0;
			ral_renumber_stream(ld->streams, ld->fdg, NULL, u[j], RAL_INTEGER_GRID_CELL(ld->streams, b));
		    }
		}
	    }
	    break;

	}

    }
    return 1;
 fail:
    return 0;
}


int ral_streams_prune(ral_grid *streams, ral_grid *fdg, ral_grid *lakes, ral_cell c, double min_l) 
{
    ral_lakedata ld;
    ld.lakes = lakes;
    ld.streams = streams;
    ld.fdg = fdg;
    ld.mark = NULL;
    ld.min_l = min_l;
    RAL_CHECKM(ral_grid_overlayable(streams, fdg) AND (!lakes OR ral_grid_overlayable(streams, lakes)), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_FDG_INTEGER);
    RAL_CHECKM(streams->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_STREAMS_INTEGER);
    RAL_CHECKM(!lakes OR lakes->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    RAL_CHECKM(RAL_GRID_CELL_IN(streams, c), RAL_ERRSTR_COB);
    RAL_CHECK(ld.mark = ral_grid_create_like(fdg, RAL_INTEGER_GRID));
    RAL_CHECK(ral_rprune(&ld, c, 0, NULL));
    ral_grid_destroy(&ld.mark);
    return 1;
 fail:
    ral_grid_destroy(&ld.mark);
    return 0;
}


int ral_streams_prune2(ral_grid *streams, ral_grid *fdg, ral_grid *lakes, double min_l)
{
    ral_cell c;
    ral_lakedata ld;
    ld.lakes = lakes;
    ld.streams = streams;
    ld.fdg = fdg;
    ld.mark = NULL;
    ld.min_l = min_l;
    RAL_CHECKM(ral_grid_overlayable(streams, fdg) AND (!lakes OR ral_grid_overlayable(streams, lakes)), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_FDG_INTEGER);
    RAL_CHECKM(streams->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_STREAMS_INTEGER);
    RAL_CHECKM(!lakes OR lakes->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    RAL_CHECK(ld.mark = ral_grid_create_like(fdg, RAL_INTEGER_GRID));
    RAL_FOR(c, fdg) {
	if (ral_fdg_is_outlet(fdg, c))
	    RAL_CHECK(ral_rprune(&ld, c, 0, NULL));
    }
    ral_grid_destroy(&ld.mark);
    return 1;
 fail:
    ral_grid_destroy(&ld.mark);
    return 0;
}


int ral_testlake(void *fctparam1, ral_cell c)
{
    ral_lakedata *ld = (ral_lakedata *)fctparam1;
    int dir;
    
    /* neighboring non-lake stream cells */
    RAL_DIRECTIONS(dir) {

	ral_cell t = ral_cell_move(c, dir);

	if (RAL_GRID_CELL_OUT(ld->lakes, t) OR (RAL_INTEGER_GRID_CELL(ld->lakes, t) == ld->lid)) continue;

	if (RAL_INTEGER_GRID_CELL(ld->streams, t) == ld->sid) {

	    /* it is a stream cell with same id, 
	       does the stream flow into this lake? */
	    
	    if (RAL_SAME_CELL(c, RAL_FLOW(ld->fdg, t))) {
		
		/* the test cell flows into the lake, renumber this stream */

		ral_renumber_stream(ld->streams, ld->fdg, NULL, t, ld->nsid);
		ld->nsid++;
		
	    }
	}
    }
    return 1;
}


int ral_streams_break(ral_grid *streams, ral_grid *fdg, ral_grid *lakes, int nsid) 
{
    ral_cell a;
    ral_lakedata ld;

    ld.lakes = lakes;
    ld.streams = streams;
    ld.fdg = fdg;
    ld.nsid = nsid;

    RAL_CHECKM(ral_grid_overlayable(streams, fdg) AND ral_grid_overlayable(streams, lakes), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID AND streams->datatype == RAL_INTEGER_GRID AND lakes->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);

    RAL_FOR(a, fdg) {
	if (RAL_INTEGER_GRID_DATACELL(lakes, a) AND RAL_INTEGER_GRID_CELL(lakes, a) AND 
	    RAL_INTEGER_GRID_DATACELL(streams, a) AND RAL_INTEGER_GRID_CELL(streams, a)) {
		
	    /* cells of interest: a stream leaving a lake */

	    ral_cell f = RAL_FLOW(fdg, a);                   /* the cell into which the stream flows to */
	    if (RAL_GRID_CELL_OUT(fdg, a) OR RAL_SAME_CELL(f, a)) 
	      continue;                              /* no flow */
	    ld.lid = RAL_INTEGER_GRID_CELL(lakes, a);             /* lake id */
	    ld.sid = RAL_INTEGER_GRID_CELL(streams, a);           /* stream id */
	    if (RAL_INTEGER_GRID_CELL(lakes, f) == ld.lid) continue; /* the stream is not an outflow */

	    RAL_CHECK(ral_borderwalk(a, RAL_INTEGER_GRID_CELL(fdg, a), &ld, &ral_lakearea, &ral_testlake));
	}
    }
    return 1;
 fail:
    return 0;
}

int ral_outlet(ral_lakedata *ld, ral_cell c) 
{
    ral_cell f = RAL_FLOW(ld->fdg, c);          
    if (RAL_GRID_CELL_OUT(ld->fdg, f))
	return 1;
    return RAL_INTEGER_GRID_CELL(ld->lakes, f) != ld->lid;
}

int ral_findoutlet(void *fctparam1, ral_cell c)
{
    ral_lakedata *ld = (ral_lakedata *)fctparam1;
    if (ral_outlet(ld, c)) {
	double ua = RAL_GRID_CELL(ld->uag, c);
	if (!ld->outlet_found OR ua > ld->max_ua) {
	    ld->outlet_found = 1;
	    ld->max_ua = ua;
	    ld->outlet = c;
	}
    }
    return 1;
}

void ral_drain_lake_to_outlet(ral_lakedata *ld, ral_cell c, int dir_for_c) 
{
    int upLimit,downLimit;
    int at_up_4_or_6 = 0;
    int at_down_2_or_8 = 0;
    ral_cell t = c;
    
    if (RAL_INTEGER_GRID_CELL(ld->lakes, t) != ld->lid) return;

    if (dir_for_c > 0) RAL_INTEGER_GRID_CELL(ld->fdg, c) = dir_for_c;

    /* Seek up */
    for (t.i = c.i; t.i >= 0; t.i--) {
	if (RAL_INTEGER_GRID_CELL(ld->lakes, t) != ld->lid) {
	    at_up_4_or_6 = 1;
	    break;	    
	}
	RAL_INTEGER_GRID_CELL(ld->mark, t) = 1;
	if (t.i < c.i) RAL_INTEGER_GRID_CELL(ld->fdg, t) = 5; /* down */
    }
    upLimit = max(0,t.i);

    /* Seek down */
    for (t.i = c.i+1; t.i < ld->lakes->M; t.i++) {    
	if (RAL_INTEGER_GRID_CELL(ld->lakes, t) != ld->lid) {
	    at_down_2_or_8 = 1;
	    break;
	}
	RAL_INTEGER_GRID_CELL(ld->mark, t) = 1;
	RAL_INTEGER_GRID_CELL(ld->fdg, t) = 1; /* up */
    }
    downLimit = min(ld->lakes->M-1,t.i);

    /* Look at columns right and left */
    /* left */
    if (c.j > 0) {
	int lastBorder = 1;
	t.j = c.j-1;
	for (t.i = upLimit; t.i <= downLimit; t.i++) {
	    int a;
	    if ((t.i == upLimit) AND at_up_4_or_6) {
		dir_for_c = 4;
	    } else if ((t.i == downLimit) AND at_down_2_or_8) {
		dir_for_c = 2;
	    } else {
		dir_for_c = 3;
	    }
	    a = RAL_INTEGER_GRID_CELL(ld->lakes, t) == ld->lid AND !RAL_INTEGER_GRID_CELL(ld->mark, t);
	    if (lastBorder) {
		if (a) {
		    ral_drain_lake_to_outlet(ld, t, dir_for_c);
		    lastBorder = 0;
		}
	    } else if (!a) {
		lastBorder = 1;
	    }
	}
    }

    /* right */
    if (c.j < (ld->lakes->N - 1)) {
	int lastBorder = 1;
	t.j = c.j+1;
	for (t.i = upLimit; t.i <= downLimit; t.i++) {
	    int a;
	    if ((t.i == upLimit) AND at_up_4_or_6) {
		dir_for_c = 6;
	    } else if ((t.i == downLimit) AND at_down_2_or_8) {
		dir_for_c = 8;
	    } else {
		dir_for_c = 7;
	    }
	    a = RAL_INTEGER_GRID_CELL(ld->lakes, t) == ld->lid AND !RAL_INTEGER_GRID_CELL(ld->mark, t);
	    if (lastBorder) {
		if (a) {
		    ral_drain_lake_to_outlet(ld, t, dir_for_c);
		    lastBorder = 0;
		}
	    } else if (!a) {
		lastBorder = 1;
	    }
	}
    }
}

int ral_fdg_kill_extra_outlets(ral_grid *fdg, ral_grid *lakes, ral_grid *uag) 
{
    ral_cell c;
    ral_lakedata ld;

    ld.lakes = lakes;
    ld.fdg = fdg;
    ld.uag = uag;
    ld.mark = NULL;

    RAL_CHECKM(ral_grid_overlayable(lakes, fdg) AND ral_grid_overlayable(lakes, uag), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(fdg->datatype == RAL_INTEGER_GRID AND lakes->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    RAL_CHECK(ld.mark = ral_grid_create_like(fdg, RAL_INTEGER_GRID));

    RAL_FOR(c, fdg) {

	/* check all lakes once */
	if (RAL_INTEGER_GRID_DATACELL(lakes, c) AND RAL_INTEGER_GRID_CELL(lakes, c) AND !RAL_INTEGER_GRID_CELL(ld.mark, c)) {
	    
	    /* cells of interest: flow out of a lake */
	    /* find the one and only outlet: 
	       the one with largest upslope area */

	    ld.lid = RAL_INTEGER_GRID_CELL(lakes, c);

	    /* set border cell (bc) */
	    ld.bc = c;
	    while (RAL_GRID_CELL_IN(lakes, ld.bc) AND 
		   RAL_INTEGER_GRID_DATACELL(lakes, ld.bc) AND 
		   RAL_INTEGER_GRID_CELL(lakes, ld.bc) == ld.lid)
		ld.bc.i--;
	    ld.bc.i++;
	    ld.dir_out = 1;

	    ld.outlet_found = 0;
	    RAL_CHECK(ral_borderwalk(ld.bc, ld.dir_out, &ld, &ral_lakearea, &ral_findoutlet));
	    RAL_CHECKM(ld.outlet_found, ral_msg(RAL_ERRSTR_NO_OUTLET, RAL_INTEGER_GRID_CELL(lakes, c), c.i, c.j));

	    /* kill other outlets and mark */
	    ral_drain_lake_to_outlet(&ld, ld.outlet, 0);
	}

    }
    ral_grid_destroy(&ld.mark);
    return 1;
fail:
    ral_grid_destroy(&ld.mark);
    return 0;
}


void ral_catchment_destroy(ral_catchment **c)
{
    if (*c) {
	if ((*c)->outlet) free((*c)->outlet);
	if ((*c)->down) free((*c)->down);
	free(*c);
	*c = NULL;
    }
}


ral_cell ral_catchment_down(ral_catchment *c, ral_cell outlet)
{
    int i;
    ral_cell down = {-1, -1};
    for (i = 0; i < c->n; i++) {
	if (RAL_SAME_CELL(outlet, c->outlet[i])) return c->down[i];
    }
    return down;
}


int ral_catchment_add(ral_catchment *c, ral_cell outlet, ral_cell down) 
{
    ral_cell test;
    RAL_CHECK(c);
    if (c->size == 0) {
	c->size = c->delta;
	RAL_CHECKM(c->outlet = RAL_CALLOC(c->size, ral_cell), RAL_ERRSTR_OOM);
	RAL_CHECKM(c->down = RAL_CALLOC(c->size, ral_cell), RAL_ERRSTR_OOM);
	c->n = 0;
    } else if (c->n >= c->size) {
	ral_cell *tmp;
	c->size += c->delta;
	RAL_CHECKM(tmp = RAL_REALLOC(c->outlet, c->size, ral_cell), RAL_ERRSTR_OOM);
	c->outlet = tmp;
	RAL_CHECKM(tmp = RAL_REALLOC(c->down, c->size, ral_cell), RAL_ERRSTR_OOM);
	c->down = tmp;
    }
    /* testing for loops down -> -> outlet */
    if (!RAL_SAME_CELL(down, outlet)) {
	do {
	    test = ral_catchment_down(c, down);
	    RAL_CHECKM(!RAL_SAME_CELL(test, outlet), RAL_ERRSTR_LOOP);
	} while (test.i > 0);
    }
    c->outlet[c->n] = outlet;
    c->down[c->n] = down;
    c->n++;
    return 1;
 fail:
    return 0;
}


typedef struct {
    ral_pour_point_struct pp;
    /* fill these when calling tree or lake */
    ral_catchment *catchment;
    ral_grid *subs;
    ral_grid *streams;
    ral_grid *lakes;
    int k;
    int headwaters; /* are headwaters marked as separate subs */
    /* these are needed only in internal routines */
    int lid;
    ral_cell a;
    ral_cell last_stream_section_end;
} ral_treedata;


int ral_tree(ral_treedata *td, ral_cell a);
int ral_lake(ral_treedata *td, ral_cell a);


ral_catchment *ral_catchment_create(ral_grid *subs, ral_grid *streams, ral_grid *fdg, ral_grid *lakes, ral_cell outlet, int headwaters)
{
    ral_treedata td = {{NULL, NULL, NULL, 0, 0, 
			{-1, -1}, 0, 0, 1, 0, {-1, -1}, 0.0, 0.0, 0.0, 0, 0, 0, {-1, -1}, 0}, 
		       NULL, NULL, NULL, NULL, 1, 0};
    ral_catchment *catchment = RAL_MALLOC(ral_catchment);
    catchment->size = 0;
    catchment->delta = 50;	
    catchment->outlet = NULL;
    catchment->down = NULL;
    td.pp.fdg = fdg;
    td.pp.mark = subs;
    td.catchment = catchment;
    td.subs = subs;
    td.lakes = lakes;
    td.headwaters = headwaters;
    RAL_CHECKM(ral_grid_overlayable(subs, streams) AND 
	       ral_grid_overlayable(subs, fdg) AND 
	       ral_grid_overlayable(subs, lakes), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(subs->datatype = RAL_INTEGER_GRID AND 
	       streams->datatype == RAL_INTEGER_GRID AND
	       fdg->datatype == RAL_INTEGER_GRID AND
	       lakes->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    RAL_CHECKM(RAL_GRID_CELL_IN(subs, outlet), RAL_ERRSTR_COB);
    RAL_CHECK(streams = ral_grid_create_copy(streams, 0));
    td.streams = streams;
    td.last_stream_section_end = outlet;
    RAL_CHECK(ral_tree(&td, outlet));
    ral_mark_upslope_cells(&(td.pp), outlet, td.k);
    RAL_CHECK(ral_catchment_add(td.catchment, outlet, outlet));
    ral_grid_destroy(&streams);
    return catchment;
 fail:
    ral_grid_destroy(&streams);
    ral_catchment_destroy(&catchment);
    return NULL;
}


ral_catchment *ral_catchment_create_complete(ral_grid *subs, ral_grid *streams, ral_grid *fdg, ral_grid *lakes, int headwaters)
{
    ral_cell c;
    ral_treedata td = {{NULL, NULL, NULL, 0, 0, 
			{-1, -1}, 0, 0, 1, 0, {-1, -1}, 0.0, 0.0, 0.0, 0, 0, 0, {-1, -1}, 0}, 
		       NULL, NULL, NULL, NULL, 1, 0};
    ral_catchment *catchment = RAL_MALLOC(ral_catchment);
    catchment->size = 0;
    catchment->delta = 50;	
    catchment->outlet = NULL;
    catchment->down = NULL;
    td.pp.fdg = fdg;
    td.pp.mark = subs;
    td.catchment = catchment;
    td.subs = subs;
    td.lakes = lakes;
    td.headwaters = headwaters;
    RAL_CHECKM(ral_grid_overlayable(subs, streams) AND 
	       ral_grid_overlayable(subs, fdg) AND 
	       ral_grid_overlayable(subs, lakes), RAL_ERRSTR_ARGS_OVERLAYABLE);
    RAL_CHECKM(subs->datatype = RAL_INTEGER_GRID AND 
	       streams->datatype == RAL_INTEGER_GRID AND
	       fdg->datatype == RAL_INTEGER_GRID AND
	       lakes->datatype == RAL_INTEGER_GRID, RAL_ERRSTR_ARGS_INTEGER);
    RAL_CHECK(streams = ral_grid_create_copy(streams, 0));
    td.streams = streams;
    RAL_FOR(c, fdg) {
	if (ral_fdg_is_outlet(fdg, c)) {
	    td.last_stream_section_end = c;
	    RAL_CHECK(ral_tree(&td, c));
	    ral_mark_upslope_cells(&(td.pp), c, td.k);
	    RAL_CHECK(ral_catchment_add(td.catchment, c, c));
	}
    }
    ral_grid_destroy(&streams);
    return catchment;
 fail:
    ral_grid_destroy(&streams);
    ral_catchment_destroy(&catchment);
    return NULL;
    
}


/* callback for the treedata struct */

int ral_testlake2(void *fctparam1, ral_cell c)
{
    ral_treedata *td = (ral_treedata *)fctparam1;
    int d;
    
    /* neighboring non-lake stream cells */
    for (d = 1; d < 9; d++) {

	ral_cell t = ral_cell_move(c, d);

	if (RAL_GRID_CELL_OUT(td->lakes, t) OR (RAL_INTEGER_GRID_CELL(td->lakes, t) == td->lid)) continue;

	if (RAL_INTEGER_GRID_DATACELL(td->streams, t) AND RAL_INTEGER_GRID_CELL(td->streams, t) > 0) { 

	    /* it is an unvisited stream cell, 
	       does the stream flow into this lake? */
	    
	    if (RAL_SAME_CELL(RAL_FLOW(td->pp.fdg, t), c)) {

		/* the test cell flows into the lake */
		
		td->last_stream_section_end = t;
		RAL_CHECK(ral_tree(td, t));
		ral_mark_upslope_cells(&(td->pp), t, td->k);
		td->k++;
		RAL_CHECK(ral_catchment_add(td->catchment, t, td->a));
	    }
	    
	}
    }
    return 1;
 fail:
    return 0;
}


int ral_lakearea2(void *fctparam1, ral_cell c)
{
    ral_treedata *td = (ral_treedata *)fctparam1;
    if (RAL_GRID_CELL_OUT(td->lakes, c) OR RAL_GRID_NODATACELL(td->lakes, c))
	return 0;
    return RAL_INTEGER_GRID_CELL(td->lakes, c) == td->lid;
}


int ral_tree(ral_treedata *td, ral_cell a) 
{
    /* arc a..b , k is a running number for the subcatchments
       this is a recursive function
       let a = b = root point when calling from outside
    */
    ral_cell b = a;
    if (RAL_INTEGER_GRID_DATACELL(td->lakes, a) AND RAL_INTEGER_GRID_CELL(td->lakes, a)) { /* on a lake */
	RAL_CHECK(ral_lake(td, a));
	ral_mark_upslope_cells(&(td->pp), a, td->k);
	td->k++;
	return 1;
    }
    while (1) {
	/* move along the arc from b onwards */    
	int c;
	ral_cell u[8]; /* upstream cells of b */
    
	/* check for loops, visited stream cells are marked by
	   multiplying them by -1 this has no effect to the original
	   streams grid since we use a copy here */

	if (RAL_INTEGER_GRID_DATACELL(td->streams, b)) {
	    RAL_CHECKM(RAL_INTEGER_GRID_CELL(td->streams, b) >= 0, RAL_ERRSTR_LOOP);
	    RAL_INTEGER_GRID_CELL(td->streams, b) *= -1;
	}

	c = ral_upstream_cells_of(td->streams, td->pp.fdg, b, u);

	if (c == 0) { /* b is an end cell of an arc */
	    if (td->headwaters) {
		ral_mark_upslope_cells(&(td->pp), b, td->k);
		td->k++;
		RAL_CHECK(ral_catchment_add(td->catchment, b, td->last_stream_section_end));
	    }
	    break;
	} else if (c == 1) {      /* b is an arc cell */
	    if (RAL_INTEGER_GRID_DATACELL(td->lakes, u[0]) AND RAL_INTEGER_GRID_CELL(td->lakes, u[0])) { /* but on a lake */
		RAL_CHECK(ral_lake(td, u[0]));
		ral_mark_upslope_cells(&(td->pp), u[0], td->k);
		td->k++;
		RAL_CHECK(ral_catchment_add(td->catchment, u[0], a));
		break;
	    } else { /* regular arc point */
		b = u[0];
	    }
	} else {           /* b is a cell where two or more arcs join */
	    int l;
	    for (l = 0; l < c; l++) {
		if (RAL_INTEGER_GRID_DATACELL(td->lakes, u[l]) AND RAL_INTEGER_GRID_CELL(td->lakes, u[l])) { /* a lake cell */
		    RAL_CHECK(ral_lake(td, u[l]));
		} else {
		    td->last_stream_section_end = u[l];
		    RAL_CHECK(ral_tree(td, u[l]));
		}
		ral_mark_upslope_cells(&(td->pp), u[l], td->k);
		td->k++;
		RAL_CHECK(ral_catchment_add(td->catchment, u[l], a));
	    }
	    break;
	}
    }

    return 1;
 fail:
    return 0;
}


int ral_lake(ral_treedata *td, ral_cell a) 
{
    /* backup the old values: */
    int lid = td->lid; 
    ral_cell a_copy = td->a;

    td->lid = RAL_INTEGER_GRID_CELL(td->lakes, a);  /* lake id */    
    td->a = a;

    RAL_CHECK(ral_borderwalk(a, RAL_INTEGER_GRID_CELL(td->pp.fdg, a), td, &ral_lakearea2, &ral_testlake2));

    /* return the old values */
    td->lid = lid; 
    td->a = a_copy;
    return 1;
 fail:
    return 0;
}

#ifdef RAL_HAVE_GDAL
int ral_compare_dem_derived_ws_attribs(ral_grid *str, ral_grid *uag, ral_grid *dem, char *dir,
				       char *basename, int iname, int ielev, int idarea)
{
  char *name, *outfile, *shppath;
  double darea1, darea2, gridarea, dist, elev1, elev2;
  FILE *fpw;
  ral_cell c1, c2;
  ral_point p;
  OGRDataSourceH hDS;
  OGRLayerH hLayer;
  OGRFeatureH hFeat;
  OGRGeometryH hGeom;
  
  fprintf(stderr,"dir: %s\n",dir);
  fprintf(stderr,"basename: %s\n",basename);
  outfile = (char *)malloc((strlen(dir) + strlen("compare_out.txt") + 1)*sizeof(char));
  shppath = (char *)malloc((strlen(dir) + strlen(basename) + strlen(".shp") + 1)*sizeof(char));
  strcpy(outfile, dir);
  strcat(outfile, "compare_out.txt");
  strcpy(shppath, dir);
  strcat(shppath, basename);
  strcat(shppath, ".shp");
  fprintf(stderr,"outname: %s\n",outfile);
  fprintf(stderr,"shppath: %s\n",shppath);
  fpw = fopen(outfile,"w");
  fprintf(fpw, "name\tdist\telev1\telev2\tdarea1\tdarea2\n"); 
  RAL_CHECKM(ral_grid_overlayable(str, uag), RAL_ERRSTR_ARGS_OVERLAYABLE);
  RAL_CHECKM(ral_grid_overlayable(str, dem), RAL_ERRSTR_ARGS_OVERLAYABLE);
  OGRRegisterAll();
  hDS = OGROpen(shppath,0,NULL);
  hLayer = OGR_DS_GetLayerByName(hDS, basename);
  OGR_L_ResetReading(hLayer);  
  gridarea = ral_grid_get_cell_size(str)*ral_grid_get_cell_size(str);
  while ((hFeat = OGR_L_GetNextFeature(hLayer)) != NULL) {
    hGeom = OGR_F_GetGeometryRef(hFeat);
    name = OGR_F_GetFieldAsString(hFeat,iname);  	
    elev1 = OGR_F_GetFieldAsDouble(hFeat,ielev);  	
    darea1 = OGR_F_GetFieldAsDouble(hFeat,idarea);  	
    p.x = OGR_G_GetX(hGeom, 0);
    p.y = OGR_G_GetY(hGeom, 0);
    c1 = ral_grid_point2cell(str, p);
    if (RAL_GRID_DATACELL(str, c1)) {
      c2.i = c1.i;
      c2.j = c1.j;
    } else 
      c2 = ral_grid_nearest_neighbor(str, c1);
    dist =  RAL_DISTANCE_BETWEEN_CELLS(c1, c2)*ral_grid_get_cell_size(str);
    darea2 = RAL_GRID_CELL(uag, c2)*gridarea;
    elev2 = RAL_GRID_CELL(dem, c2);
    fprintf(fpw, "%s\t%8.3f\t%8.3f\t%8.3f\t%8.3f\t%8.3f\n", name, dist, elev1, elev2, darea1, darea2); 
  }
  free(outfile);
  free(shppath);
  fclose(fpw);
  return 1;

 fail:
    return 0;
}
#endif
