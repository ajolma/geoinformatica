#include "config.h"
#include "msg.h"
#include "ral.h"

ral_variogram_handle RAL_CALL ral_variogram_create(int size)
{
    ral_variogram *variogram = NULL;
    RAL_CHECKM(variogram = RAL_MALLOC(ral_variogram), RAL_ERRSTR_OOM);
    variogram->lag = NULL;
    variogram->y = NULL;
    variogram->n = NULL;
    variogram->size = size;
    RAL_CHECKM(variogram->lag = RAL_CALLOC(size, double), RAL_ERRSTR_OOM);
    RAL_CHECKM(variogram->y = RAL_CALLOC(size, double), RAL_ERRSTR_OOM);
    RAL_CHECKM(variogram->n = RAL_CALLOC(size, double), RAL_ERRSTR_OOM);
    return variogram;
 fail:
    ral_variogram_destroy(&variogram);
    return NULL;
}

void RAL_CALL ral_variogram_destroy(ral_variogram **variogram)
{
    if (*variogram) {
	RAL_FREE((*variogram)->lag);
	RAL_FREE((*variogram)->y);
	RAL_FREE((*variogram)->n);
	RAL_FREE(*variogram);
    }
}

ral_variogram_handle RAL_CALL ral_grid_variogram(ral_grid *gd, double max_lag, int lags)
{
    ral_cell a;
    int *n = RAL_CALLOC(lags, int);
    double *sum = RAL_CALLOC(lags, double);
    ral_variogram *variogram = NULL;
    double delta = max_lag / lags;
    int d = floor(max_lag/gd->cell_size);
    RAL_CHECKM(n && sum, RAL_ERRSTR_OOM);
    RAL_FOR(a, gd) {
	if (RAL_GRID_DATACELL(gd, a)) {
	    ral_cell b;
	    for (b.i = a.i - d; b.i <= a.i + d; b.i++)
		for (b.j = a.j - d; b.j <= a.j + d; b.j++) {
		    /* note: not checking whether b is masked out */
		    if (RAL_GRID_CELL_IN(gd, b) AND RAL_GRID_DATACELL(gd, b)) {
			int k = floor(RAL_DISTANCE_BETWEEN_CELLS(a, b)*gd->cell_size/delta);
			if (k < lags) {
			    double h = RAL_GRID_CELL(gd, a) - RAL_GRID_CELL(gd, b);
			    n[k]++;
			    sum[k] += h*h;
			}
		    }
		}
	}
    }
    RAL_CHECK(variogram = ral_variogram_create(lags));
    {
	int i;
	double lag = delta/2;
	for (i = 0; i < lags; i++) {
	    variogram->lag[i] = lag;
	    lag += delta;
	    variogram->y[i] = sum[i]/(2*n[i]);
	    variogram->n[i] = n[i];
	}
    }
    free(n);
    free(sum);
    return variogram;
 fail:
    RAL_FREE(n);
    RAL_FREE(sum);
    return NULL;
}

typedef struct {
    ral_cell *c;
    int n;
    int k;
    int size;
} ral_cell_array;

ral_cell_array *ral_cell_array_create(int size);
void ral_cell_array_destroy(ral_cell_array **a);

ral_cell_array *ral_cell_array_create(int size)
{
    ral_cell_array *a = RAL_MALLOC(ral_cell_array);
    RAL_CHECKM(a, RAL_ERRSTR_OOM);
    a->n = 0;
    a->k = size;
    a->size = size;
    a->c = RAL_CALLOC(size, ral_cell);
    RAL_CHECKM(a->c, RAL_ERRSTR_OOM);
    return a;
 fail:
    ral_cell_array_destroy(&a);
    return NULL;
}

void ral_cell_array_destroy(ral_cell_array **a)
{
    if (*a) {
	RAL_FREE((*a)->c);
	RAL_FREE(*a);
    }
}

int ral_cell_array_add(ral_cell_array *a, ral_cell c)
{
    if (a->n >= a->size) {
	RAL_CHECKM(a->c = RAL_REALLOC(a->c, a->size += a->k, ral_cell), RAL_ERRSTR_OOM);
    }
    a->c[a->n++] = c;
    return 1;
 fail:
    return 0;
}

/* from http://www.me.unm.edu/~bgreen/ME360/Solving%20Linear%20Equations.pdf */

void ral_normal(double *a, double *b, int m);
void ral_pivot(double *a, double *b, int m);
void ral_forelm(double *a, double *b, int m);
void ral_baksub(double *a, double *b, double *x, int m);

/* Here are a series of routines that solve multiple linear equations
   using the Gaussian Elimination technique */
void ral_gauss(double *x, double *a, double *b, int m)
{
    /* Normalize the matrix */
    ral_normal (a, b, m);
    /* Arrange the equations for diagonal dominance */
    ral_pivot (a, b, m);
    /* Put into upper triangular form */
    ral_forelm (a, b, m);
    /* Do the back substitution for the solution */
    ral_baksub (a, b, x, m);
}

/* This routine normalizes each row of the matrix so that the largest
   term in a row has an absolute value of one */
void ral_normal(double *a, double *b, int m)
{
    int i;
    for (i = 0; i < m; i++)
    {
	double big = 0.0;
	int j;
	for (j = 0; j < m; j++)
	    if (big < fabs(a[i*m+j])) big = fabs(a[i*m+j]);
	for (j = 0; j < m; j++)
	    a[i*m+j] = a[i*m+j] / big;
	b[i] = b[i] / big;
    }
}

/* This routine attempts to rearrange the rows of the matrix so
   that the maximum value in each row occurs on the diagonal. */
void ral_pivot(double *a, double *b, int m)
{
    int i;
    double temp;
    for (i = 0; i < m-1; i++)
    {
	int ibig = i, j;
	for (j = i+1; j < m; j++)
	    if (fabs (a[ibig*m+i]) < fabs (a[j*m+i])) ibig = j;
	if (ibig != i)
	{
	    for (j = 0; j < m; j++)
	    {
		temp = a[ibig*m+j];
		a[ibig*m+j] = a[i*m+j];
		a[i*m+j] = temp;
	    }
	    temp = b[ibig];
	    b[ibig] = b[i];
	    b[i] = temp;
	}
    }
}

/* This routine does the forward sweep to put the matrix in to upper
   triangular form */
void ral_forelm(double *a, double *b, int m)
{
    int i;
    for (i = 0; i < m-1; i++)
    {
	int j;
	for (j = i+1; j < m; j++)
	{
	    if (a[i*m+i] != 0.0)
	    {
		double fact = a[j*m+i] / a[i*m+i];
		int k;
		for (k = 0; k < m; k++)
		    a[j*m+k] -= a[i*m+k] * fact;
		b[j] -= b[i]*fact;
	    }
	}
    }
}

/* This routine does the back substitution to solve the equations */
void ral_baksub(double *a, double *b, double *x, int m)
{
    int i, j;
    double sum;
    for (j = m-1; j >= 0; j--)
    {
	sum = 0.0;
	for (i = j+1; i < m; i++)
	    sum += x[i] * a[j*m+i];
	x[j] = (b[j] - sum) / a[j*m+j];
    }
}

ral_estimate *ral_grid_krige(ral_grid *gd, ral_cell p, ral_variogram_function S, double *param, double range)
{
    /* pick values */
    int delta = floor(range/gd->cell_size);
    ral_cell c;
    int i, j, n;
    int k = 0;
    ral_cell_array *a = NULL;
    double *w = NULL; /* weights */
    double *d = NULL; /* distances between cells */
    double *b = NULL;
    ral_estimate *estimate = NULL;

    RAL_CHECKM(estimate = RAL_MALLOC(ral_estimate), RAL_ERRSTR_OOM);
    RAL_CHECK(a = ral_cell_array_create(100));
    
    /* cells with values in the range */
    for (c.i = p.i - delta; c.i <= p.i + delta; c.i++)
	for (c.j = p.j - delta; c.j <= p.j + delta; c.j++) {
	    /* note: not checking if c is masked out */
	    if (RAL_GRID_CELL_IN(gd, c) AND RAL_GRID_DATACELL(gd, c)) {
		double s = RAL_DISTANCE_BETWEEN_CELLS(p, c)*gd->cell_size;
		if (s < range) {
		    RAL_CHECK(ral_cell_array_add(a, c));
		}
	    }
	}
   
    n = a->n+2; /* cells + slack */
    RAL_CHECKM(w = RAL_CALLOC(n, double), RAL_ERRSTR_OOM);
    RAL_CHECKM(d = RAL_CALLOC(n*n, double), RAL_ERRSTR_OOM);
    RAL_CHECKM(b = RAL_CALLOC(n, double), RAL_ERRSTR_OOM);
    
    for (i = 0; i < n-1; i++) {
	b[i] = S(RAL_DISTANCE_BETWEEN_CELLS(a->c[i], p)*gd->cell_size, param);
	d[i*n] = 0;
	for (j = i+1; j < n-1; j++) {
	    d[i*n+j] = S(RAL_DISTANCE_BETWEEN_CELLS(a->c[i], a->c[j])*gd->cell_size, param);
	}
    }
    for (j = 0; j < n-1; j++)
	d[(n-1)*n+j] = 1;
    d[n*n-1] = 0;
    b[n-1] = 1;

    ral_gauss(w, d, b, n);
    estimate->f = 0;
    estimate->s2 = 0;
    for (i = 0; i < n-1; i++) {
	estimate->f += w[i]*RAL_GRID_CELL(gd, a->c[i]);
	estimate->s2 += w[i]*b[i];
    }
    estimate->s2 += w[n-1];
    ral_cell_array_destroy(&a);
    free(w);
    free(d);
    free(b);
    return estimate;
 fail:
    ral_cell_array_destroy(&a);
    RAL_FREE(w);
    RAL_FREE(d);
    RAL_FREE(b);
    RAL_FREE(estimate);
    return NULL;
}

double ral_spherical(double lag, double *r)
{
    double h;
    if (lag == 0)
	return 0;
    if (lag >= *r)
	return 1;
    h = lag/(*r);
    return h * (1.5 - 0.5 * h * h);
}
