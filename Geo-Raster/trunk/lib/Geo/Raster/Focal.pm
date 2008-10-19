## @class Geo::Raster::Focal
# @brief Adds focal operations into Geo::Raster
# @note Although the methods have the prefix Geo::Raster::Focal these
# are really Geo::Raster methods.
package Geo::Raster;

## @method void set(@cell, $value)
#
# @brief A focal set.
#
# @param[in] cell The center cell of the focal area.
# @param[in] value A reference to a focal array of values.

## @method @get(@cell, $distance)
# 
# @brief A focal get.
#
# If the cell has a nodata or it is out-of-world value undef is returned.
# @param[in] cell The center cell of the focal area.
# @param[in] distance Integer value that specifies the focal area. The
# focal area is a rectangle, whose side is 2*distance+1 wide.
# @return Values of the cell or its neighborhood cells.

## @method Geo::Raster focal_sum(listref mask)
#
# @brief Compute the focal sum for the whole raster.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal sum is computed.
# @return The focal sums for the entire raster. If no return value is 
# needed then the focal sums are given to this grids cells.

## @method $focal_sum(listref mask, @cell)
#
# @brief Compute the focal sum for a single cell.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal sum is computed.
# @param[in] cell Array having a single cells grid coordinates (i, j) for which the 
# focal sum is to be computed.
# @return The focal sum for the single cell.
sub focal_sum {
    my $self = shift;
    my $mask = shift;
    if (@_) {
	my($i, $j) = @_;
	my $x = ral_grid_focal_sum($self->{GRID}, $i, $j, $mask);
	return $x;
    } else {
	my $grid = ral_grid_focal_sum_grid($self->{GRID}, $mask);
	if (defined wantarray) {
	    $grid = new Geo::Raster($grid);
	    return $grid;
	} else {
	    ral_grid_destroy($self->{GRID});
	    $self->{GRID} = $grid;
	    _attributes($self);
	}
    }
}

## @method Geo::Raster focal_mean(listref mask)
#
# @brief Compute the focal mean for the whole raster.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal mean is computed.
# @return The focal means for the entire raster. If no return value is 
# needed then the focal means are given to this grids cells.

## @method $focal_mean(listref mask, @cell)
#
# @brief Compute the focal mean for a single cell.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal mean is computed.
# @param[in] cell Array having a single cells grid coordinates (i, j) for which the 
# focal mean is to be computed.
# @return The focal mean for the single cell.
sub focal_mean {
    my $self = shift;
    my $mask = shift;
    if (@_) {
	my($i, $j) = @_;
	my $x = ral_grid_focal_mean($self->{GRID}, $i, $j, $mask);
	return $x;
    } else {
	my $grid = ral_grid_focal_mean_grid($self->{GRID}, $mask);
	if (defined wantarray) {
	    $grid = new Geo::Raster($grid);
	    return $grid;
	} else {
	    ral_grid_destroy($self->{GRID});
	    $self->{GRID} = $grid;
	    _attributes($self);
	}
    }
}

## @method Geo::Raster focal_variance(listref mask)
#
# @brief Compute the focal variance for the whole raster.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal variance is computed.
# @return The focal variances for the entire raster. If no return value is 
# needed then the focal variances are given to this grids cells.

## @method $focal_variance(listref mask, @cell)
#
# @brief Compute the focal variance for a single cell.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal variance is computed.
# @param[in] cell Array having a single cells grid coordinates (i, j) for which the 
# focal variance is to be computed.
# @return The focal variance for the single cell.
sub focal_variance {
    my $self = shift;
    my $mask = shift;
    if (@_) {
	my($i, $j) = @_;
	my $x = ral_grid_focal_variance($self->{GRID}, $i, $j, $mask);
	return $x;
    } else {
	my $grid = ral_grid_focal_variance_grid($self->{GRID}, $mask);
	if (defined wantarray) {
	    $grid = new Geo::Raster($grid);
	    return $grid;
	} else {
	    ral_grid_destroy($self->{GRID});
	    $self->{GRID} = $grid;
	    _attributes($self);
	}
    }
}

## @method Geo::Raster focal_count(listref mask)
#
# @brief Compute the focal count for the whole raster.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal count is computed.
# @return The focal counts for the entire raster. If no return value is 
# needed then the focal counts are given to this grids cells.

## @method $focal_count(listref mask, @cell)
#
# @brief Compute the focal count for a single cell.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal count is computed.
# @param[in] cell Array having a single cells grid coordinates (i, j) for which the 
# focal count is to be computed.
# @return The focal count for the single cell.
sub focal_count {
    my $self = shift;
    my $mask = shift;
    if (@_) {
	my($i, $j) = @_;
	my $x = ral_grid_focal_count($self->{GRID}, $i, $j, $mask);
	return $x;
    } else {
	my $grid = ral_grid_focal_count_grid($self->{GRID}, $mask);
	if (defined wantarray) {
	    $grid = new Geo::Raster($grid);
	    return $grid;
	} else {
	    ral_grid_destroy($self->{GRID});
	    $self->{GRID} = $grid;
	    _attributes($self);
	}
    }
}

## @method Geo::Raster focal_count_of(listref mask, $value)
#
# @brief Compute the focal count of the given value for the whole raster.
# @param[in] mask The mask is [[],[],...[]], i.e., a 2D table that determines the
# focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal count of the value is 
# computed.
# @param[in] value Value whose apperance times are calculated.
# @return The focal counts of the value for the entire raster. If no return 
# value is needed then the focal of the value counts are given to this grids 
# cells.

## @method $focal_count_of(listref mask, $value, @cell)
#
# @brief Compute the focal count of the given value for a single cell.
# @param[in] mask The mask is [[],[],...[]], i.e., a 2D table that determines the
# focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal count of the value is 
# computed.
# @param[in] value Value whose apperance times are calculated.
# @param[in] cell Array having a single cells grid coordinates (i, j) for which the 
# focal count is to be computed.
# @return The focal count of the value for the single cell.
sub focal_count_of {
    my $self = shift;
    my $mask = shift;
    my $value = shift;
    if (@_) {
	my($i, $j) = @_;
	my $x = ral_grid_focal_count_of($self->{GRID}, $i, $j, $mask, $value);
	return $x;
    } else {
	my $grid = ral_grid_focal_count_of_grid($self->{GRID}, $mask, $value);
	if (defined wantarray) {
	    $grid = new Geo::Raster($grid);
	    return $grid;
	} else {
	    ral_grid_destroy($self->{GRID});
	    $self->{GRID} = $grid;
	    _attributes($self);
	}
    }
}

## @method @focal_range(listref mask, array cell)
#
# @brief Compute the focal range for the given cell.
# @param[in] mask The mask is [[],[],...[]], i.e., a 2D table that determines the
# focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal range is computed.
# @param[in] cell An array having the grid coordinates (i, j).
# @return Returns the range as an array (min, max).
sub focal_range {
    my($self, $mask, $i, $j) = @_;
    my $x = ral_grid_focal_range($self->{GRID}, $i, $j, $mask);
    return @$x;
}

sub spread {
    my($self, $mask) = @_;
    my $grid = ral_grid_spread($self->{GRID}, $mask);
    if (defined wantarray) {
	$grid = new Geo::Raster($grid);
	return $grid;
    } else {
	ral_grid_destroy($self->{GRID});
	$self->{GRID} = $grid;
	_attributes($self);
    }
}

sub spread_random {
    my($self, $mask) = @_;
    my $grid = ral_grid_spread_random($self->{GRID}, $mask);
    if (defined wantarray) {
	$grid = new Geo::Raster($grid);
	return $grid;
    } else {
	ral_grid_destroy($self->{GRID});
	$self->{GRID} = $grid;
	_attributes($self);
    }
}

1;
