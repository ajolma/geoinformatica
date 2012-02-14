#ifndef RAL_VECTOR_H
#define RAL_VECTOR_H

/**\file ral/vector.h
   \brief A system of points, lines, rectangles, and polygons. 
*/

/**\brief an XYZM point */
typedef struct {
    double x;
    double y;  
    double z;
    double m;
} ral_point;

int RAL_CALL ral_ccw(ral_point p0, ral_point p1, ral_point p2);

/**\brief two points: begin and end */
typedef struct {
    ral_point begin;
    ral_point end;
} ral_line;

int RAL_CALL ral_intersect(ral_line l1, ral_line l2);

/**\brief two points: SW and NE corners */
typedef struct {
    /** bottom left or south west */
    ral_point min;
    /** top right or north east */
    ral_point max;
} ral_rectangle;

#define RAL_POINT_IN_RECTANGLE(p,r) \
(((p).x >= (r).min.x) AND ((p).x <= (r).max.x) AND \
 ((p).y >= (r).min.y) AND ((p).y <= (r).max.y))

#define RAL_RECTANGLES_OVERLAP(r1, r2) \
(!((r1.max.x < r2.min.x) OR	\
   (r1.min.y > r2.max.y) OR	\
   (r1.min.x > r2.max.x) OR	\
   (r1.max.y < r2.min.y)))

int RAL_CALL ral_clip_line_to_rect(ral_line *l, ral_rectangle r);

/**\brief an array of points (nodes) */
typedef struct {
    /** nodes[0] must be nodes[n-1] and that is the user's responsibility */
    ral_point *nodes;
    /** number of nodes */
    int n;
} ral_polygon;

int RAL_CALL ral_polygon_init(ral_polygon p, int n);
void RAL_CALL ral_polygon_finish(ral_polygon p);

int RAL_CALL ral_insideconvex(ral_point p, ral_polygon P);

int RAL_CALL ral_pnpoly(ral_point p, ral_polygon P);

#define RAL_CONVEX 1
#define RAL_CONCAVE -1

int RAL_CALL ral_convex(ral_polygon p);
double RAL_CALL ral_polygon_area(ral_polygon p);

/**\brief for rendering a polygon with holes */
typedef struct {
    ral_polygon *p;
    int aet_begin;
    int scanline_at;
    /** nodes in y order */
    int *nodes;
    /** 0 = no, 
	1 = incoming edge is in, 
	2 = outgoing edge is in, 
	3 = both are 
    */
    int *active_edges;
} ral_active_edge_table;

typedef ral_active_edge_table *ral_active_edge_table_handle;

void RAL_CALL ral_active_edge_tables_destroy(ral_active_edge_table **aet, int n);

/** 
    Returns a list of aet's, one for each polygon.
    The list should be processed from min y to max y.
*/
ral_active_edge_table_handle RAL_CALL ral_get_active_edge_tables(ral_polygon *p, int n);

/** returns an ordered list of x's at y from the aet's */
int RAL_CALL ral_scanline_at(ral_active_edge_table *aet_list, int n, double y, double **x, int *nx);
void RAL_CALL ral_delete_scanline(double **x);

/**\brief an array of points, which represent a simple geometry */
typedef struct {
    /** all actual points are only here, others are just pointers into this */
    ral_point *points;
    int n_points;
    /** parts[i].nodes points into points */
    ral_polygon *parts;
    int n_parts;
    OGRwkbGeometryType *part_types;
    OGRwkbGeometryType type;
} ral_geometry;

typedef ral_geometry *ral_geometry_handle;

ral_geometry_handle RAL_CALL ral_geometry_create(int n_points, int n_parts);
#ifdef RAL_HAVE_GDAL
ral_geometry_handle RAL_CALL ral_geometry_create_from_OGR(OGRGeometryH geom);
#endif
void RAL_CALL ral_geometry_destroy(ral_geometry **g);

/**\brief an array of geometries */
typedef struct {
    ral_geometry *g;
    int n;
} ral_layer;

typedef ral_layer *ral_layer_handle;

ral_layer_handle RAL_CALL ral_layer_create(int n_geometries);
void RAL_CALL ral_layer_destroy(ral_layer **l);

#endif
