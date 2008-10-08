## @class Geo::Raster::Image
# @brief Adds graphics, image analysis etc. methods into Geo::Raster
package Geo::Raster;

use UNIVERSAL qw(isa);

## @method Geo::Raster frame($with)
#
# @brief Changing the border grid cell values to the given value.
# 
# Example of framing a grid
# @code
# $framed_grid = $grid->frame($with);
# @endcode
# where $with is a scalar and the border cells of $grid is set to that value.
# @param[in] with A value that is given to the border cells.
# @return If a return value is wanted, then the method returns a new grid based 
# on this objects type and grid size with the border values changed to the given 
# parameter value, but values inside the borders are not copied to the new 
# raster grid.
sub frame {
    my $self = shift;
    my $with = shift;
    my($datatype, $M, $N) = ($self->attributes())[0..2];
    if (defined wantarray) {
	my $g = new Geo::Raster($datatype, $M, $N);
	ral_grid_copy_bounds($self->{GRID}, $g->{GRID});
	$self = $g;
    }
    my($i, $j);
    for $i (0..$M-1) {
	$self->set($i, 0, $with);
	$self->set($i, $N-1, $with);
    }
    for $j (1..$N-2) {
	$self->set(0, $j, $with);
	$self->set($M-1, $j, $with);
    }
    return $self if defined wantarray;
}

## @method Geo::Raster convolve(listref mask)
# 
# @brief Compute the convolution for the whole raster grid.
# @param[in] mask The mask is [[],[],...[]], i.e., a 2D table that determines the
# focal area over which convolution is calculated. The table is read from left 
# to right, top to down, and its center element is the cell for which the value 
# is computed.
# @return The convolutions for the entire raster grid. If no return 
# value is needed then the convolution results are given to this grids cells.

## @method $convolve(listref mask, array cell)
# 
# @brief Compute the convolution for the cell.
# @param[in] mask The mask is [[],[],...[]], i.e., a 2D table that determines the
# focal area over which convolution is calculated. The table is read from left 
# to right, top to down, and its center element is the cell for which the value 
# is computed.
# @param[in] cell An array having the grid coordinates (i, j) of the cell.
# @return The convolution result.
sub convolve {
    my $self = shift;
    my $mask = shift;
    if (@_) {
	my($i, $j) = @_;
	my $x = ral_grid_convolve($self->{GRID}, $i, $j, $mask);
	return $x;
    } else {
	my $grid = ral_grid_convolve_grid($self->{GRID}, $mask);
	if (defined wantarray) {
	    $grid = new Geo::Raster($grid);
	    return $grid;
	} else {
	    ral_grid_destroy($self->{GRID});
	    $self->{GRID} = $grid;
	    attributes($self);
	}
    }
}

## @method listref line($i1, $j1, $i2, $j2)
#
# @brief Returns the cell coordinates and values as an array belonging to the 
# line.
# 
# Example of getting cells belonging to the line:
# @code
# \@line = $grid->line($i1, $j1, $i2, $j2);
# @endcode
# 
# @param[in] i1 The i-coordinate of the lines starting point.
# @param[in] j1 The j-coordinate of the lines starting point.
# @param[in] i2 The i-coordinate of the lines ending point.
# @param[in] j2 The j-coordinate of the lines ending point.
# @return Returns a reference to an array having the the coordinates and values 
# of the cells belonging to the line in format: (i1, j1, val1, i2, j2, val2, i3, ...).
# @note This method works for both integer and real valued rasters.

## @method void line($i1, $j1, $i2, $j2, $pen)
#
# @brief Drawing a line to a grid with the given value.
# 
# Example of drawing a line to a grid:
# @code
# $grid->line($i1, $j1, $i2, $j2, $pen);
# @endcode
# 
# @param[in] i1 The i-coordinate of the lines starting point.
# @param[in] j1 The j-coordinate of the lines starting point.
# @param[in] i2 The i-coordinate of the lines ending point.
# @param[in] j2 The j-coordinate of the lines ending point.
# @param[in] pen Value to give to the cells of the line.
# @note This method works for both integer and real valued rasters.
sub line {
    my($self, $i1, $j1, $i2, $j2, $pen) = @_;
    unless (defined $pen) {
	return ($self->{GRID}, $i1, $j1, $i2, $j2);
    } else {
	ral_grid_line($self->{GRID}, $i1, $j1, $i2, $j2, $pen);
    }
}


sub transect {
    my($self, $geom, $delta) = @_;
    croak "usage: \$raster->transect(\$geometry, \$delta)" 
	unless isa($geom, 'Geo::OGR::Geometry') and (defined $delta and $delta > 0);
    my @transect;
    if ($geom->GetGeometryCount) {
	for (0..$geom->GetGeometryCount-1) {
	    my $t = $self->transect($geom->GetGeometryRef($_), $delta);
	    push @transect, $t;
	}
    } else {
	my $i;
	my $l = 0;
	my $n = $geom->GetPointCount;

	my $x0 = $geom->GetX(0);
	my $y0 = $geom->GetY(0);

	for $i (0..$n-2) {
	    push @transect, [$l, $self->get($self->w2g($x0, $y0))];

	    my $x1 = $geom->GetX($i+1);
	    my $y1 = $geom->GetY($i+1);	    

	    my $d = CORE::sqrt(($x1-$x0)**2+($y1-$y0)**2);
	    my $l0 = $l;
	    if ($d > $delta) {
		my $dx = $delta * ($x1-$x0)/$d;
		my $dy = $delta * ($y1-$y0)/$d;
		
		my $x = $x0;
		my $y = $y0;
		for (1..int($d/$delta)) {
		    $x += $dx;
		    $y += $dy;
		    $l += $delta;
		    push @transect, [$l, $self->get($self->w2g($x, $y))];
		}

	    }

	    $x0 = $x1;
	    $y0 = $y1;
	    $l = $l0+$d;
	}
	push @transect, [$l, $self->get($self->w2g($x0, $y0))];
    }
    return \@transect;
}

## @method listref rect($i1, $j1, $i2, $j2)
#
# @brief Returns the cell coordinates and values as an array belonging inside 
# the given rectangle.
# 
# Example of getting cells belonging inside the rectangle:
# @code
# \@rectangle = $grid->rect($i1, $j1, $i2, $j2);
# @endcode
# 
# @param[in] i1 The i-coordinate of the rectangles upper left corner cell.
# @param[in] j1 The j-coordinate of the rectangles upper left corner cell.
# @param[in] i2 The i-coordinate of the rectangles lower right corner cell.
# @param[in] j2 The j-coordinate of the rectangles lower right corner cell.
# @return Returns a reference to an array having the the coordinates and values 
# of the cells belonging inside the rectangle in format: (i1, j1, val1, i2, j2, 
# val2, i3, ...).
# @note This method works for both integer and real valued rasters.

## @method void rect($i1, $j1, $i2, $j2, $pen)
#
# @brief Drawing a filled rectangle to a grid with the given value.
# 
# Example of drawing a filled rectangle to a grid:
# @code
# $grid->rect($i1, $j1, $i2, $j2, $pen);
# @endcode
# 
# @param[in] i1 The i-coordinate of the rectangles upper left corner cell.
# @param[in] j1 The j-coordinate of the rectangles upper left corner cell.
# @param[in] i2 The i-coordinate of the rectangles lower right corner cell.
# @param[in] j2 The j-coordinate of the rectangles lower right corner cell.
# @param[in] pen Value to give to the cells of the rectangle.
# @note This method works for both integer and real valued rasters.
sub rect {
    my($self, $i1, $j1, $i2, $j2, $pen) = @_;
    unless (defined $pen) {
	return ral_grid_get_rect($self->{GRID}, $i1, $j1, $i2, $j2);
    } else {
	ral_grid_filled_rect($self->{GRID}, $i1, $j1, $i2, $j2, $pen);
    }
}

## @method listref circle($i, $j, $r)
#
# @brief Returns the cell coordinates and values as an array belonging inside 
# the given circle.
# 
# Example of getting cells belonging inside the circle:
# @code
# \@circle = $grid->circle($i, $j, $r);
# @endcode
# 
# @param[in] i The i-coordinate of the circles center point.
# @param[in] j The j-coordinate of the circles center point.
# @param[in] r The radius of the circle.
# @return Returns a reference to an array having the the coordinates and values 
# of the cells belonging inside the circle in format: (i1, j1, val1, i2, j2, 
# val2, i3, ...).
# @note This method works for both integer and real valued rasters.

## @method void circle($i, $j, $r, $pen)
#
# @brief Drawing a filled rectangle to a grid with the given value.
# 
# Example of drawing a filled circle to a grid:
# @code
# $grid->circle($i, $j, $r, $pen);
# @endcode
# 
# @param[in] i The i-coordinate of the circles center point.
# @param[in] j The j-coordinate of the circles center point.
# @param[in] r The radius of the circle.
# @param[in] pen Value to give to the cells of the circle.
# @note This method works for both integer and real valued rasters.
sub circle {
    my($self, $i, $j, $r, $pen) = @_;
    unless (defined $pen) {
	return ral_grid_get_circle($self->{GRID}, $i, $j, $r);
    } else {
	ral_grid_filled_circle($self->{GRID}, $i, $j, $r, $pen);
    }
}

## @method void floodfill($i, $j, $pen, $connectivity)
#
# @brief Changes the values for all cells that have the same value as the 
# given cell and are connected to the given cell trough cells having the 
# same value as the given cell.
#
# @param[in] i The i-coordinate of the cell from where to begin to change the values.
# @param[in] j The j-coordinate of the cell from where to begin to change the values.
# @param[in] pen Value to give to those cells that have the same value as the 
# given cell and also are connected to the given cell trough cells having the 
# same value as the given cell.
# @param[in] connectivity (optional). Connectivity between cells as a number:4 
# or 8. If connectivity is not given then 8-connectivity is used.
# @note This method works for both integer and real valued rasters.
# @todo Test for this method
sub floodfill {
    my($self, $i, $j, $pen, $connectivity) = @_;
    $connectivity = 8 unless $connectivity;
    ral_grid_floodfill($self->{GRID}, $i, $j, $pen, $connectivity);
}

## @method Geo::Raster thin(%opt)
#
# @brief 
#
# This is an implementation of the algorithm in Jang, B-K., Chin,
# R.T. 1990. Analysis of Thinning Algorithms Using Mathematical
# Morphology. IEEE Trans. Pattern Analysis and Machine
# Intelligence. 12(6). 541-551. (Same as in Grass but done in a bit
# different, and more generic way, I believe). 
#
# The thinning algorithm defines a set of structuring templates and
# applies them in several passes until there are no matches or until the
# maxiterations is reached. Trimming means certain structuring templates
# are applied to kill emerging short limbs which appear because of the
# noise in the grid.
# 
# Exple of thinning:
# @code
# $thinned_img = $img->thin(%options);
# @endcode
# or
# @code
# $img->thin(%options);
# @endcode
#
# @param[in] opt Includes as named parameters:
# - <I>algorithm</I> => character (optional). By default "B", the other option 
# is "A".
# - <I>trimming</I> => binary (optional). By default 0, the other option is 1. 
# Trimming removes artificial branches which grow on the side of wide lines in 
# thinnning, but it also shortens a bit the real branches.
# - <I>maxiterations</I> => integer (optional). By default 0 (no maximum, will 
# iterate until no cells are deleted).
# - <I>width</I> => double (optional). Used to define the maximum iterations 
# count. In case the width is given then the maxiterations is set to 
# int(width/2).
# @return In void context (no return grid is wanted) the method changes this 
# grid, otherwise the method returns a new grid with the thinning done.
# @note The thinned grid must be a binary grid.
sub thin {
    my($self, %opt) = @_;
    $self = Geo::Raster::new($self) if defined wantarray;
    my @D1 = (+0,+0,-1,
	      +0,+1,+1,
	      -1,+1,-1);
    my @D2 = (-1,+0,+0,
	      +1,+1,+0,
	      -1,+1,-1);
    my @D3 = (-1,+1,-1,
	      +1,+1,+0,
	      -1,+0,+0);
    my @D4 = (-1,+1,-1,
	      +0,+1,+1,
	      +0,+0,-1);
    my @E1 = (-1,+0,-1,
	      +1,+1,+1,
	      -1,+1,-1);
    my @E2 = (-1,+1,-1,
	      +1,+1,+0,
	      -1,+1,-1);
    my @E3 = (-1,+1,-1,
	      +1,+1,+1,
	      -1,+0,-1);
    my @E4 = (-1,+1,-1,
	      +0,+1,+1,
	      -1,+1,-1);
    # G are the trimming templates
    my @G1 = (-1,+1,-1,
	      +0,+1,+0,
	      +0,+0,+0);
    my @G2 = (+0,+0,+1,
	      +0,+1,+0,
	      +0,+0,+0);
    my @G3 = (+0,+0,-1,
	      +0,+1,+1,
	      +0,+0,-1);
    my @G4 = (+0,+0,+0,
	      +0,+1,+0,
	      +0,+0,+1);
    my @G5 = (+0,+0,+0,
	      +0,+1,+0,
	      -1,+1,-1);
    my @G6 = (+0,+0,+0,
	      +0,+1,+0,
	      +1,+0,+0);
    my @G7 = (-1,+0,+0,
	      +1,+1,+0,
	      -1,+0,+0);
    my @G8 = (+1,+0,+0,
	      +0,+1,+0,
	      +0,+0,+0);
    my @trimmer = (\@G1,\@G2,\@G3,\@G4,\@G5,\@G6,\@G7,\@G8);
    my $algorithm = $opt{algorithm};
    $algorithm = 'B' unless $algorithm;
    my $trimming = $opt{trimming};
    $trimming = 0 unless $trimming;
    my $maxiterations = $opt{maxiterations};
    $maxiterations = 0 unless $maxiterations;
    my $width = $opt{width};
    $maxiterations = int($width/2) if $width;
    my @thinner;
    if ($algorithm eq 'B') {
	if ($trimming) {
	    @thinner = (\@D1,\@D2,\@E1,@trimmer,
			\@D2,\@D3,\@E2,@trimmer,
			\@D3,\@D4,\@E3,@trimmer,
			\@D4,\@D1,\@E4,@trimmer);
	} else {
	    @thinner = (\@D1, \@D2, \@E1, \@D2, \@D3, \@E2,
			\@D3, \@D4, \@E3, \@D4, \@D1, \@E4);
	}
    } elsif ($algorithm eq 'A') {
	if ($trimming) {
	    @thinner = (\@D1, \@E1, @trimmer,
			\@D2, \@E2, @trimmer,
			\@D3, \@E3, @trimmer,
			\@D4, \@E4, @trimmer);
	} else {
	    @thinner = (\@D1, \@E1, \@D2, \@E2, \@D3, \@E3, \@D4, \@E4);
	}
    } else {
	croak "thin: $algorithm: unknown algorithm";
    }
    my ($m, $M, $i) = (0,0,1);
    do {
	$M = $m;
	foreach (@thinner) {
	    $m += ral_grid_applytempl($self->{GRID}, $_, 0);
	    print STDERR "#" unless $opt{quiet};
	}
	print STDERR " thinning, pass $i/$maxiterations: deleted ", $m-$M, " cells\n" unless $opt{quiet};
	$i++;
    } while ($m > $M and !($maxiterations > 0 and $i > $maxiterations));
    return $self if defined wantarray;
}

## @method Geo::Raster bordering(%opt)
#
# @brief Finding the zone borders.
# 
# The method leaves to the border cells the values of
# the zones and nullifies all cell values except the border values.
# 
# Example of borderizing with simple method into a new array:
# @code
# $borders_img = $img->borders(method=>simple);
# @endcode
# Example of applying borderizing with recursive method into this grid:
# @code
# $img->borders(method=>recursive);
# @endcode
#
# @param[in] opt A named parameter:
# - <I>method</I> => string (optional). By default the method will be 
# 'recursive', as an alernative would be 'simple'. The recursive method will
# find all areas (8-connected cells with non-zero values) and marks their 
# borders with respective values and leaves the rest of the area zero.
# @return In void context (no return grid is wanted) the method changes this 
# grid, otherwise the method returns a new grid with the bordering done.
# @note The grid has to have as datatype integer.
# @note The grids mask can be used to define the cells which are gone 
sub borders {
    my($self, %opt) = @_;
    my $method = $opt{method};
    if (!$method) {
	$method = 'recursive';
	print STDERR "border: Warning: method not set, using '$method'\n" unless $opt{quiet};
    }    
    if ($method eq 'simple') {
	if (defined wantarray) {
	    my $g = new Geo::Raster(ral_grid_borders($self->{GRID}));
	    return $g;
	} else {
	    $self->_new_grid(ral_grid_borders($self->{GRID}));
	}
    } elsif ($method eq 'recursive') {
	if (defined wantarray) {
	    my $g = new Geo::Raster(ral_grid_borders_recursive($self->{GRID}));
	    return $g;
	} else {
	    $self->_new_grid(ral_grid_borders_recursive($self->{GRID}));
	}
    } else {
	croak "border: $method: unknown method";
    }
}

## @method Geo::Raster areas($k)
#
# @brief Marks if cell belong to an area.
#
# @param[in] k (optional). A cell is part of an area if there are at least k 
# consecutive nonzero cells as neighbors and the cell has also a nonzero value. 
# By default the value is 3, in which case the smallest area is 2*2 cells.
# @return In void context (no return grid is wanted) the method changes this 
# grid, otherwise the method returns a new grid with the areas marked.
# @note The grid has to have as datatype integer.
sub areas {
    my $self = shift;
    my $k = shift;
    $k = 3 unless $k;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_grid_areas($self->{GRID}, $k));
	return $g;
    } else {
	$self->_new_grid(ral_grid_areas($self->{GRID}, $k));
    }
}

## @method Geo::Raster connect()
#
# @brief Connects broken lines.
#
# If two 8-neighbor opposite cells (1-5, 2-6, etc) of a cell are the
# same and the cell is zero, then the value of this cell is set to the
# same value.
#
# Examples of connection:
#
# <table border="0">
# <tr><td>0 1 0</td><td>    </td><td>0 1 0</td></tr>
# <tr><td>0 0 0</td><td> => </td><td>0 1 0</td></tr>
# <tr><td>0 1 0</td><td>    </td><td>0 1 0</td></tr>
# </table>
#
# <table border="0">
# <tr><td>1 0 1</td><td>    </td><td>1 0 1</td></tr>
# <tr><td>0 0 0</td><td> => </td><td>0 1 0</td></tr>
# <tr><td>0 0 1</td><td>    </td><td>0 0 1</td></tr>
# </table>
#
# @return In void context (no return grid is wanted) the method changes this 
# grid, otherwise the method returns a new grid with the areas marked.
# @note The grid has to have as datatype integer.
sub connect {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster $self;
	return ral_grid_connect($self->{GRID});
    } else {
	ral_grid_connect($self->{GRID});
    }
}

## @method Geo::Raster number_areas($connectivity)
#
# @brief Numbers all areas with a unique integer number, even if some areas have 
# the same values.
# @param[in] connectivity (optional). Connectivity between cells as a number:4 
# or 8. If connectivity is not given then 8-connectivity is used.
# @return In void context (no return grid is wanted) the method changes this 
# grid, otherwise the method returns a new grid with the unique areas.
# @note The grid has to have as datatype integer.
sub number_areas {
    my($self, $connectivity) = @_;
    $connectivity = 8 unless $connectivity;
    if (defined wantarray) {
	my $g = new Geo::Raster($self);
	if (ral_grid_number_of_areas($g->{GRID}, $connectivity)) {
	    return $g;
	}
    } else {
	ral_grid_number_of_areas($self->{GRID}, $connectivity);	
    }
}

## @method Geo::Raster transform(listref tr, $M, $N, $pick, $value)
#
# @brief Transformation (of type conversion, because just a mathematical 
# transformation) of the raster grid.
#
# If $pick is "count" then $value should be the value
# which needs to be counted -- this works only for integer grids. Result
# grid is the same type as input except for mean and variance which are
# a lways floats. Division by n-1 is used for calculating variance.
#
# In the case when $pick is not defined, the value which is stored into
# the target grid is looked up from the source grid using the equations
# above, and rounding the indexes to the nearest integer value.
#
# In the case when $pick is defined, the value which is stored into the
# target grid is calculated from the (possibly rectangular) area into
# which the i2,j2 cell maps to. NOTE: In this case the cell coordinates
# are assumed to denote the upper left corner of the cell. This makes
# it easy to keep the (x,y) of the upper left the same BUT it is
# different than the usual assumption that (i, j) denotes the center of
# the cell.
#
# Example of transforming
# @code
# $g2 = $g1->transform(\@tr, $M, $N, $pick, $value);
# @endcode
# Or, again just (changes the g1 instead of creating a new grid):
# @code
# $g1->transform(\@tr, $M, $N, $pick, $value);
# @endcode
# g2 will be of size M, N. Transformation uses equations:
#
#  i1 = ai + bi * i2 + ci * j2
#
#  j1 = aj + bj * i2 + cj * j2
#
#whose parameters are in array tr:
# @code
# @tr = (ai, bi, ci, aj, bj, cj);
# @endcode
#
# @param[in] tr Reference to an array having the affine tranformation parameters
# (i1 = tr[0] + tr[1]*i2 + tr[2]*j2, j1 = tr[3] + tr[4]*i2 + tr[5]*j2)
# @param[in] M Height of the area to transform in grid coordinates as integer.
# @param[in] N Width of the area to transform in grid coordinates as integer.
# @param[in] pick (optional) May be "mean", "variance", "min", "max", or "count". 
# @param[in] value (optional) Should be given if pick method "count" is used, in 
# which case the cells will include the amount of values.
# @return If a return value is wanted, then the method returns a new grid with
# the transformation complited.
sub transform {
    my($self, $tr, $M, $N, $pick, $value) = @_;
    $pick = $pick || 0;
    $value = $value || 0;
    unless ($pick =~ /^\d+$/) {
	my %map = (mean=>1,variance=>2,min=>10,max=>11,count=>20);
	$pick = $map{$pick};
	croak "transform: unrecognised pick method: $pick" unless $pick;
    }
    croak "transform: transformation matrix incomplete" if $#$tr<5;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_grid_transform($self->{GRID}, $tr, $M, $N, $pick, $value));
	return $g;
    } else {
	$self->_new_grid(ral_grid_transform($self->{GRID}, $tr, $M, $N, $pick, $value));
    }
}

1;
