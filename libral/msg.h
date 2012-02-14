/* msg.h things that are needed to compile RAL but are not part of its API */

#include <errno.h>
#include <string.h>
#include <stdarg.h>

#ifndef M_PI
#define M_PI        3.14159265358979323846
#endif

#define RAL_ERRSTR_DATATYPE "grid must be an integer or real number grid"
#define RAL_ERRSTR_OOM "memory allocation error"
#define RAL_ERRSTR_DBZ "divide by zero"
#define RAL_ERRSTR_LOG "logarithm of a non-positive number attempted"
#define RAL_ERRSTR_IOB "integer out of bounds"
#define RAL_ERRSTR_COB "cell is not on grid"
#define RAL_ERRSTR_POB "point not in grid"
#define RAL_ERRSTR_ARGS_OVERLAYABLE "the argument grids must be overlayable"
#define RAL_ERRSTR_ARGS_REAL "the argument grid(s) must be real number grid(s)"
#define RAL_ERRSTR_ARGS_INTEGER "the argument grid(s) must be integer grid(s)"
#define RAL_ERRSTR_ARG_REAL "the argument must be a real number grid"
#define RAL_ERRSTR_ARG_INTEGER "the argument must be an integer grid"
#define RAL_ERRSTR_ZONING_INTEGER "the zoning grid must be an integer grid"
#define RAL_ERRSTR_ONLY_INT_IS_BOOLEAN "only an integer grid can be a boolean grid"
#define RAL_ERRSTR_NO_DATA_IN_GRID "no data in the grid"
#define RAL_ERRSTR_BAD_CLIP_REGION "bad clip region"
#define RAL_ERRSTR_CANNOT_JOIN "cannot join"

#define RAL_ERRSTR_FDG_INTEGER "FDG must be an integer grid"
#define RAL_ERRSTR_STREAMS_INTEGER "streams grid must be an integer grid"
#define RAL_ERRSTR_BORDERWALK_OUT "can't start borderwalk from cell (%i,%i) because it is not on the area"
#define RAL_ERRSTR_BORDERWALK_BAD_OUT "borderwalk: the cell (%i,%i) (to direction %i from %i,%i) is on the area"
#define RAL_ERRSTR_STREAMS_SUBCATCHMENTS "the argument cell is not a stream cell or not on the grid"
#define RAL_ERRSTR_LOOP "there is a loop in the system"
#define RAL_ERRSTR_NO_OUTLET "lake %i (at cell %i,%i) has no outlet"

#define RAL_ERRSTR_ALPHA_IS_INTEGER "Alpha grid must be an integer (0...255) grid"

#define RAL_ERRSTR_NULL_GEOM "OGR_F_GetGeometryRef returned a null geometry"
