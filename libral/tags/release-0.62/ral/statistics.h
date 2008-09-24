#ifndef RAL_STATISTICS_H
#define RAL_STATISTICS_H

/**\file ral/statistics.h
   \brief Geostatistical methods
*/

/**\brief sample variogram */
typedef struct {
    double *lag;
    /** variogram value */
    double *y;
    /** number of observations associated with lag[i] */
    double *n;
    int size;
} ral_variogram;

typedef ral_variogram *ral_variogram_handle;

ral_variogram_handle RAL_CALL ral_variogram_create(int size);
void RAL_CALL ral_variogram_destroy(ral_variogram **variogram);

/** computes a sample variogram y(h) */
ral_variogram_handle RAL_CALL ral_grid_variogram(ral_grid *gd, double max_lag, int lags);

/**\brief estimated value */
typedef struct {
    /** estimated value */
    double f;
    /** estimation variance */
    double s2;
} ral_estimate;

typedef ral_estimate *ral_estimate_handle;

typedef double ral_variogram_function(double lag, double *param);

/** computes the estimated value and its expected error at point p from data values within range in gd */
ral_estimate_handle RAL_CALL ral_grid_krige(ral_grid *gd, ral_cell p, ral_variogram_function S, double *param, double range);

/** spherical variogram function */
double ral_spherical(double lag, double *param);

#endif
