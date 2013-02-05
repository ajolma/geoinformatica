#include "config.h"
#include "msg.h"
#include "ral/ral.h"

/* counterclockwise from Sedgewick: Algorithms in C */
int ral_ccw(ral_point p0, ral_point p1, ral_point p2)
{
    double dx1, dx2, dy1, dy2;
    dx1 = p1.x - p0.x; dy1 = p1.y - p0.y;
    dx2 = p2.x - p0.x; dy2 = p2.y - p0.y;
    if (dx1*dy2 > dy1*dx2) return +1;
    if (dx1*dy2 < dy1*dx2) return -1;
    if ((dx1*dx2 < 0) OR (dy1*dy2 < 0)) return -1;
    if ((dx1*dx1+dy1*dy1) < (dx2*dx2+dy2*dy2)) return +1;
    return 0;
}

/* from Sedgewick: Algorithms in C */
int ral_intersect(ral_line l1, ral_line l2)
{
    return ((ral_ccw(l1.begin, l1.end, l2.begin)
	     *ral_ccw(l1.begin, l1.end, l2.end)) <= 0)
	&& ((ral_ccw(l2.begin, l2.end, l1.begin)
	     *ral_ccw(l2.begin, l2.end, l1.end)) <= 0);
}


int ral_clip_line_to_rect(ral_line *l, ral_rectangle r)
{
    if (RAL_POINT_IN_RECTANGLE(l->begin,r) AND RAL_POINT_IN_RECTANGLE(l->end,r))
	return 1;
    if (((l->begin.x <= r.min.x) AND (l->end.x <= r.min.x)) OR
	((l->begin.x >= r.max.x) AND (l->end.x >= r.max.x)) OR
	((l->begin.y <= r.min.y) AND (l->end.y <= r.min.y)) OR
	((l->begin.y >= r.max.y) AND (l->end.y >= r.max.y)))
	return 0;
    /* scissors */
    if (l->begin.x != l->end.x) {
	double k = (l->end.y - l->begin.y)/(l->end.x - l->begin.x);
	if (l->begin.x <= r.min.x) {
	    l->begin.y = l->begin.y + k*(r.min.x - l->begin.x);
	    l->begin.x = r.min.x;
	} else if (l->end.x <= r.min.x) {
	    l->end.y = l->begin.y + k*(r.min.x - l->begin.x);
	    l->end.x = r.min.x;
	} if (l->begin.x >= r.max.x) {
	    l->begin.y = l->begin.y + k*(r.max.x - l->begin.x);
	    l->begin.x = r.max.x;
	} if (l->end.x >= r.max.x) {
	    l->end.y = l->begin.y + k*(r.max.x - l->begin.x);
	    l->end.x = r.max.x;
	}
	if (l->begin.y <= r.min.y) {
	    l->begin.x = l->begin.x + (r.min.y - l->begin.y)/k;
	    l->begin.y = r.min.y;
	} else if (l->end.y <= r.min.y) {
	    l->end.x = l->begin.x + (r.min.y - l->begin.y)/k;
	    l->end.y = r.min.y;
	} if (l->begin.y >= r.max.y) {
	    l->begin.x = l->end.x + (r.max.y - l->end.y)/k;
	    l->begin.y = r.max.y;
	} if (l->end.y >= r.max.y) {
	    l->end.x = l->begin.x + (r.max.y - l->begin.y)/k;
	    l->end.y = r.max.y;
	}
    } else {
	l->begin.y = min(max(l->begin.y,r.min.y),r.max.y);
	l->end.y = min(max(l->end.y,r.min.y),r.max.y);
    }
    return 1;
}


int ral_polygon_init(ral_polygon p, int n)
{
    p.nodes = NULL;
    RAL_CHECKM(p.nodes = RAL_CALLOC(n, ral_point), RAL_ERRSTR_OOM);
    p.n = n;
    return 1;
 fail:
    return 0;
}


void ral_polygon_free(ral_polygon p)
{
    if (p.nodes) free(p.nodes);
    p.nodes = NULL;
}


/*
  from http://exaflop.org/docs/cgafaq/cga2.html: It returns 1 for
  strictly interior points, 0 for strictly exterior, and 0 or 1 for
  points on the boundary. The boundary behavior is complex but
  determined; | in particular, for a partition of a region into
  polygons, each point | is "in" exactly one polygon.
 */
int ral_pnpoly(ral_point p, ral_polygon P)
{
    int i, j, c = 0;
    for (i = 0, j = P.n-1; i < P.n; j = i++) {
	if ((((P.nodes[i].y <= p.y) AND (p.y < P.nodes[j].y)) OR
	     ((P.nodes[j].y <= p.y) AND (p.y < P.nodes[i].y))) AND
	    (p.x < (P.nodes[j].x - P.nodes[i].x) * (p.y - P.nodes[i].y) / 
	     (P.nodes[j].y - P.nodes[i].y) + P.nodes[i].x))
	    c = !c;
    }
    return c;
}

/*
   Return whether a polygon in 2D is concave or convex
   return 0 for incomputables eg: colinear points
          CONVEX == 1
          CONCAVE == -1
   It is assumed that the polygon is simple
   (does not intersect itself or have holes)
   http://astronomy.swin.edu.au/~pbourke/geometry/clockwise/source1.c
*/
int ral_convex(ral_polygon p)
{
    int i,j,k;
    int flag = 0;
    double z;

    if (p.n < 3)
	return(0);

    for (i=0;i<p.n;i++) {
	j = (i + 1) % p.n;
	k = (i + 2) % p.n;
	z  = (p.nodes[j].x - p.nodes[i].x) * (p.nodes[k].y - p.nodes[j].y);
	z -= (p.nodes[j].y - p.nodes[i].y) * (p.nodes[k].x - p.nodes[j].x);
	if (z < 0)
	    flag |= 1;
	else if (z > 0)
	    flag |= 2;
	if (flag == 3)
	    return(RAL_CONCAVE);
    }
    if (flag != 0)
	return(RAL_CONVEX);
    else
	return(0);
}

/* from the same page */
double ral_polygon_area(ral_polygon p)
{
    int i;
    double A = 0;
    for (i=0;i<p.n-1;i++) {
	A += p.nodes[i].x * p.nodes[i+1].y - p.nodes[i+1].x * p.nodes[i].y;
    }
    return A/2;
}

void ral_sort_nodes(ral_polygon p, int *nodes, int begin, int end)
{
    if (end > begin) {
	int pivot = nodes[begin];
	int l = begin + 1;
	int r = end;
	int temp;
	while (l < r) {
	    if (p.nodes[nodes[l]].y <= p.nodes[pivot].y) {
		l++;
	    } else {
		r--;
		swap(nodes[l], nodes[r], temp);
	    }
	}
	l--;
	swap(nodes[begin], nodes[l], temp);
	ral_sort_nodes(p, nodes, begin, l);
	ral_sort_nodes(p, nodes, r, end);
    }
}

void ral_sort_double(double *array, int begin, int end)
{
    if (end > begin) {
	double pivot = array[begin];
	int l = begin + 1;
	int r = end;
	double temp;
	while (l < r) {
	    if (array[l] <= pivot) {
		l++;
	    } else {
		r--;
		swap(array[l], array[r], temp);
	    }
	}
	l--;
	swap(array[begin], array[l], temp);
	ral_sort_double(array, begin, l);
	ral_sort_double(array, r, end);
    }
}

void ral_active_edge_tables_destroy(ral_active_edge_table **aet, int n)
{
    int i;
    if (!*aet) return;
    for (i = 0; i < n; i++) {
	if ((*aet)[i].nodes) free((*aet)[i].nodes);
	if ((*aet)[i].active_edges) free((*aet)[i].active_edges);
    }
    free(*aet);
    *aet = NULL;
}

ral_active_edge_table *ral_get_active_edge_tables(ral_polygon *p, int n)
{
    ral_active_edge_table *aet;
    int i;
    RAL_CHECKM(aet = RAL_CALLOC(n, ral_active_edge_table), RAL_ERRSTR_OOM);
    for (i = 0; i < n; i++) {
	aet[i].p = &(p[i]);
	aet[i].aet_begin = 0;
	aet[i].scanline_at = 0;
	aet[i].nodes = NULL;
	aet[i].active_edges = NULL;
    }
    for (i = 0; i < n; i++) {
	RAL_CHECKM(aet[i].nodes = RAL_CALLOC(p[i].n-1, int), RAL_ERRSTR_OOM);
	RAL_CHECKM(aet[i].active_edges = RAL_CALLOC(p[i].n-1, int), RAL_ERRSTR_OOM);
    }
    for (i = 0; i < n; i++) {
	int j;
	for (j = 0; j < p[i].n-1; j++) { /* the last node is the same as first, skip that */
	    aet[i].nodes[j] = j;
	    aet[i].active_edges[j] = 0;
	}
	ral_sort_nodes(p[i], aet[i].nodes, 0, p[i].n-1); /* smallest to biggest */
    }
    return aet;
 fail:
    ral_active_edge_tables_destroy(&aet, n);
    return NULL;
}

void ral_delete_scanline(double **x)
{
    free(*x);
    *x = NULL;
}

int ral_scanline_at(ral_active_edge_table *aet_list, int n, double y, double **x, int *nx)
{
    int i;
    *nx = 0;
    *x = NULL;

    for (i = 0; i < n; i++) { /* working on polygon aet_list[i].p */

	ral_active_edge_table *aet = &(aet_list[i]);

	/* process all nodes from current scanline_at to nodes whose y is <= y */
	while ((aet->scanline_at < aet->p->n-1) AND 
	       (aet->p->nodes[ aet->nodes[aet->scanline_at] ].y <= y)) {

	    int prev_node = aet->nodes[aet->scanline_at];
	    int next_node = aet->nodes[aet->scanline_at];
	    if (prev_node < 1)
		prev_node = aet->p->n-2; /* the last node is the same as first */
	    else
		prev_node--;
	    if (next_node >= aet->p->n-2)
		next_node = 0;
	    else
		next_node++;

	    /* process node aet->nodes[aet->scanline_at] */

	    /* incoming node is already in aet if outgoing node of prev node is */

	    /* outgoing node is already in aet if incoming node of next node is */

	    if (!(aet->active_edges[prev_node] & 2) AND !(aet->active_edges[next_node] & 1)) {

		/* if neither node is in (this is minimum node), just add them */
		aet->active_edges[aet->nodes[aet->scanline_at]] = 3;

	    } else if ((aet->active_edges[prev_node] & 2) AND (aet->active_edges[next_node] & 1)) {

		/* if both are in (this is maximum node), just remove them */
		aet->active_edges[prev_node] &= 1;
		aet->active_edges[next_node] &= 2;

	    } else if (aet->active_edges[prev_node] & 2) {

		/* remove the outgoing from the prev and add outgoing to this */
		aet->active_edges[prev_node] &= 1;
		aet->active_edges[aet->nodes[aet->scanline_at]] = 2;

	    } else { /*if (aet->active_edges[next_node] & 1) {*/

		/* remove the incoming from the next and add incoming to this */
		aet->active_edges[next_node] &= 2;
		aet->active_edges[aet->nodes[aet->scanline_at]] = 1;

	    }

	    (aet->scanline_at)++;
	}

	/* check if we can forget some nodes with small y */
	while ((aet->aet_begin < aet->scanline_at) AND (aet->active_edges[aet->nodes[aet->aet_begin]] == 0)) {
	    aet->aet_begin++;
	}

	/* collect all x values from active edges */
	{
	    int j,n = 0;
	    for (j = aet->aet_begin; j < aet->scanline_at; j++) {
		int status = aet->active_edges[ aet->nodes[j] ];
		if (status == 3)
		    n += 2;
		else if (status > 0)
		    n++;
	    }
	    if (n > 0) {
		RAL_CHECKM(*x = RAL_REALLOC(*x, *nx+n, double), RAL_ERRSTR_OOM);
		n = *nx;
		for (j = aet->aet_begin; j < aet->scanline_at; j++) {
		    
		    int node = aet->nodes[j];
		    
		    /* x is the x of the intersection of line y = y, and the edge */
		    
		    if (aet->active_edges[node] & 1) { 
			
			/* incoming edge of the node is in aet */
			
			ral_point *nodes = aet->p->nodes;
			int prev_node = node;
			if (prev_node < 1)
			    prev_node = aet->p->n-2; /* the last node is the same as first */
			else
			prev_node--;
		    
			if (nodes[node].y == nodes[prev_node].y)
			    (*x)[n] = min(nodes[node].x,nodes[prev_node].x);
			else if (nodes[node].x == nodes[prev_node].x)
			    (*x)[n] = nodes[node].x;
			else 
			    (*x)[n] = nodes[node].x + 
				(y-nodes[node].y)*(nodes[prev_node].x-nodes[node].x)/
				(nodes[prev_node].y-nodes[node].y);			
			n++;

		    }

		    if (aet->active_edges[node] & 2) { 

			/* outgoing edge of node aet->nodes[j] is in aet */
			
			ral_point *nodes = aet->p->nodes;
			int next_node = node;
			if (next_node >= aet->p->n-2)
			    next_node = 0;
			else
			    next_node++;
		    
			if (nodes[node].y == nodes[next_node].y)
			    (*x)[n] = min(nodes[node].x,nodes[next_node].x);
			else if (nodes[node].x == nodes[next_node].x)
			    (*x)[n] = nodes[node].x;
			else 
			    (*x)[n] = nodes[node].x + 
				(y-nodes[node].y)*(nodes[next_node].x-nodes[node].x)/
				(nodes[next_node].y-nodes[node].y);
			n++;
			
		    }

		}
		*nx = n;
	    }
	    
	}
    }
    ral_sort_double(*x, 0, *nx); /* smallest to biggest */
    return 1;
 fail:
    return 0;
}

#ifdef RAL_HAVE_GDAL
ral_geometry *ral_geometry_create(int n_points, int n_parts)
{
    ral_geometry *g = NULL;
    RAL_CHECKM(g = RAL_MALLOC(ral_geometry), RAL_ERRSTR_OOM);
    g->points = NULL;
    g->n_points = n_points;
    g->parts = NULL;
    g->n_parts = n_parts;
    g->part_types = NULL;
    RAL_CHECKM(g->points = RAL_CALLOC(n_points, ral_point), RAL_ERRSTR_OOM);
    RAL_CHECKM(g->parts = RAL_CALLOC(n_parts, ral_polygon), RAL_ERRSTR_OOM);
    RAL_CHECKM(g->part_types = RAL_CALLOC(n_parts, OGRwkbGeometryType), RAL_ERRSTR_OOM);
    return g;
 fail:
    ral_geometry_destroy(&g);
    return NULL;
}


void ral_geometry_destroy(ral_geometry **g)
{
    if (!(*g)) return;
    if ((*g)->points) free((*g)->points);
    if ((*g)->parts) free((*g)->parts);
    if ((*g)->part_types) free((*g)->part_types);
    free(*g);
    *g = NULL;
}


typedef struct {
    int points;
    int parts;
} ral_counts;

ral_counts ral_get_counts(OGRGeometryH geom)
{
    ral_counts c = {0,0};
    int k = OGR_G_GetGeometryCount(geom);
    if (k) {
	int i;
	for (i = 0; i < k; i++) {
	    ral_counts x = ral_get_counts(OGR_G_GetGeometryRef(geom, i));
	    c.points += x.points;
	    c.parts += x.parts;
	}
    } else {
	c.points += OGR_G_GetPointCount(geom);
	c.parts++;
    }
    return c;
}

void ral_fill_geometry(OGRGeometryH geom, ral_geometry *g, ral_counts *c)
{
    int k = OGR_G_GetGeometryCount(geom);
    if (k) {
	int i;
	for (i = 0; i < k; i++) {
	    ral_fill_geometry(OGR_G_GetGeometryRef(geom, i), g, c);
	}
    } else {
	int i;
	int k = OGR_G_GetPointCount(geom);
	g->part_types[c->parts] = OGR_G_GetGeometryType(geom);
	g->parts[c->parts].nodes = &(g->points[c->points]);
	g->parts[c->parts].n = k;
	for (i = 0; i < k; i++) {
	    g->points[c->points+i].x = OGR_G_GetX(geom, i);
	    g->points[c->points+i].y = OGR_G_GetY(geom, i);
	    g->points[c->points+i].z = OGR_G_GetZ(geom, i);
	    /* todo: M */
	}
	c->points+=k;
	c->parts++;
    }
}

ral_geometry *ral_geometry_create_from_OGR(OGRGeometryH geom)
{
    /* geometry = array of geometries or array of points */
    ral_counts c;
    ral_geometry *g = NULL;
    RAL_CHECK(geom);
    c = ral_get_counts(geom);
    RAL_CHECK(g = ral_geometry_create(c.points, c.parts));
    g->type = OGR_G_GetGeometryType(geom);
    c.points = 0;
    c.parts = 0;
    ral_fill_geometry(geom, g, &c);
    return g;
 fail:
    ral_geometry_destroy(&g);
    return NULL;
}


ral_layer *ral_layer_create(int n_geometries)
{
    ral_layer *l = NULL;
    RAL_CHECKM(l = RAL_MALLOC(ral_layer), RAL_ERRSTR_OOM);
    l->g = NULL;
    l->n = n_geometries;
    RAL_CHECKM(l->g = RAL_CALLOC(n_geometries, ral_geometry), RAL_ERRSTR_OOM);
    return l;
 fail:
    ral_layer_destroy(&l);
    return NULL;
}


void ral_layer_destroy(ral_layer **l)
{
    if (*l) free(*l);
    *l = NULL;
}
#endif
