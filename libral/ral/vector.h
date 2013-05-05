#ifndef RAL_VECTOR_H
#define RAL_VECTOR_H

/**\file ral/vector.h
   \brief A system of points, lines, rectangles, and polygons. 
*/

/**\brief an XYZM point */
typedef struct _ral_point ral_point;
typedef ral_point *ral_point_handle;

ral_point_handle RAL_CALL ral_point_create();
void RAL_CALL ral_point_destroy(ral_point **p);

void ral_point_set_x(ral_point *p, double x);
void ral_point_set_y(ral_point *p, double y);

double ral_point_get_x(ral_point *p);
double ral_point_get_y(ral_point *p);

/**\brief two points: begin and end */
typedef struct _ral_line ral_line;

/**\brief two points: SW and NE corners */
typedef struct _ral_rectangle ral_rectangle;

int RAL_CALL ral_clip_line_to_rect(ral_line *l, ral_rectangle *r);

/**\brief an array of points (nodes) */
typedef struct _ral_polygon ral_polygon;
typedef ral_polygon *ral_polygon_handle;

ral_polygon_handle RAL_CALL ral_polygon_create(int n);
void RAL_CALL ral_polygon_destroy(ral_polygon **p);

int RAL_CALL ral_pnpoly(ral_point *p, ral_polygon *P);

#define RAL_CONVEX 1
#define RAL_CONCAVE -1

int RAL_CALL ral_convex(ral_polygon *p);
double RAL_CALL ral_polygon_area(ral_polygon *p);

/**\brief for rendering a polygon with holes */
typedef struct _ral_active_edge_table ral_active_edge_table;

typedef ral_active_edge_table *ral_active_edge_table_handle;

void RAL_CALL ral_active_edge_tables_destroy(ral_active_edge_table **aet, int n);

/** 
    Returns a list of aet's, one for each polygon.
    The list should be processed from min y to max y.
*/
ral_active_edge_table_handle RAL_CALL ral_get_active_edge_tables(ral_polygon **p, int n);

/** returns an ordered list of x's at y from the aet's */
int RAL_CALL ral_scanline_at(ral_active_edge_table *aet_list, int n, double y, double **x, int *nx);
void RAL_CALL ral_delete_scanline(double **x);

/**\brief an array of points, which represent a simple geometry */
typedef struct _ral_geometry ral_geometry;
typedef ral_geometry *ral_geometry_handle;

ral_geometry_handle RAL_CALL ral_geometry_create(int n_points, int n_parts);
#ifdef RAL_HAVE_GDAL
ral_geometry_handle RAL_CALL ral_geometry_create_from_OGR(OGRGeometryH geom);
#endif
void RAL_CALL ral_geometry_destroy(ral_geometry **g);

int RAL_CALL ral_geometry_get_n_parts(ral_geometry_handle g);
int RAL_CALL ral_geometry_get_n_points(ral_geometry_handle g, int part);
ral_point_handle RAL_CALL ral_geometry_get_point(ral_geometry_handle g, int part, int point);

/**\brief an array of geometries */
typedef struct _ral_layer ral_layer;
typedef ral_layer *ral_layer_handle;

ral_layer_handle RAL_CALL ral_layer_create(int n_geometries);
void RAL_CALL ral_layer_destroy(ral_layer **l);

#endif
