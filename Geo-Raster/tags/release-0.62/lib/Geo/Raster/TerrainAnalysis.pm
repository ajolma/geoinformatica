## @class Geo::Raster::TerrainAnalysis
# @brief Adds terrain analysis methods into Geo::Raster
package Geo::Raster;

use UNIVERSAL qw(isa);

## @method Geo::Raster aspect()
#
# @brief This DEM method computes the aspect (in radians, computing clockwise 
# starting from north) for each cell. For flat cells sets -1.
# @return In void context (no return grid is wanted) the method changes this 
# grid, otherwise the method returns a new grid with the aspect ratios.
sub aspect {
    my $self = shift;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_dem_aspect($self->{GRID}));
	return $g;
    } else {
	$self->_new_grid(ral_dem_aspect($self->{GRID}));
    }
}

## @method @fit_surface($z_factor)
#
# @brief The DEM method fits a 9-term quadratic polynomial to a 3*3
# neighborhood for each pixel of the grid.
#
# The 9-term quadratic polynomial:
#
# z = Ax^2y^2 + Bx^2y + Cxy^2 + Dx^2 + Ey^2 + Fxy + Gx + Hy + I  
#
# @see Moore et al. 1991. Hydrol. Proc. 5, 3-30.
# @param[in] z_factor is the unit of z divided by the unit of x and y, the
# default value of z_factor is 1.
# @return Array of 9 Geo::Raster grids, one for each parameter.
sub fit_surface {
    my($dem, $z_factor) = @_;
    $z_factor = 1 unless $z_factor;
    my $a = ral_dem_fit_surface($dem->{GRID}, $z_factor);
    my @ret;
    if ($a and @$a) {
	for my $a (@$a) {
	    my $b = Geo::Raster->new($a);
	    push @ret, $b;
	}
    }
    return @ret;
}

## @method Geo::Raster slope(scalar z_factor)
#
# @brief This DEM method computes the slope (in radians) for each cell.
# @param[in] z_factor is the unit of z divided by the unit of x and y, the
# default value of z_factor is 1.
# @return In void context (no return grid is wanted) the method changes this 
# grid, otherwise the method returns a new grid with the slope ratios.
sub slope {
    my $self = shift;
    my $z_factor = shift;
    $z_factor = 1 unless $z_factor;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_dem_slope($self->{GRID}, $z_factor));
	return $g;
    } else {
	$self->_new_grid(ral_dem_slope($self->{GRID}, $z_factor));
    }
}

## @method Geo::Raster fdg(%opt) 
#
# @brief This, possibly iterative, DEM method returns a flow direction grid
# (fdg) that is computed from the DEM. 
# @param[in] opt Named parameters include:
# - <I>method</I>=>string (optional). The default method is 'D8', other supported 
# methods are 'Rho8' and 'many'. 
# - <I>drain_all</I>=>boolean (optional). Default is false. Initiates if true an 
# iteration, which resolves the drainage of all flat areas and pit cells.
# @return In void context (no return grid is wanted) the method changes this 
# grid, otherwise the method returns a new grid.
sub fdg {
    my($dem, %opt) = @_;
    if (!$opt{method}) {
	$opt{method} = 'D8';
	print STDERR "fdg: WARNING: method not set, using '$opt{method}'\n" unless $opt{quiet};
    }
    my $method;
    if ($opt{method} eq 'D8') {
	$method = 1;
    } elsif ($opt{method} eq 'Rho8') {
	$method = 2;
    } elsif ($opt{method} eq 'many') {
	$method = 3;
    } else {
	croak "fdg: $opt{method}: unsupported method";
    }
    my $fdg = ral_dem_fdg($dem->{GRID}, $method);
    
    if ($opt{drain_all}) {
	$fdg->drain_flat_areas($dem, method=>'m');
	$fdg->drain_flat_areas($dem, method=>'o');
	my $c = $fdg->contents();
	my $pits = $$c{0} || 0;
	my $flats = $$c{-1} || 0;
	print STDERR "drain_all: $pits pit and $flats flat cells remain\n" unless $opt{quiet};
	my $i = 1;
	while ($pits > 0 or $flats > 0) {
	    ral_fdg_drain_depressions($fdg->{GRID}, $dem->{GRID});
	    $c = $fdg->contents();
	    my $pits_last_time = $pits;
	    my $flats_last_time = $flats;
	    $pits = $$c{0} || 0;
	    $flats = $$c{-1} || 0;
	    if ($pits_last_time == $pits and $flats_last_time == $flats) {
		print STDERR "drain_all: bailing out, there is no progress!\n";
		last;
	    }
	    print STDERR "drain_all: iteration $i: $pits pit and $flats flat cells remain\n" unless $opt{quiet};
	    $i++;
	}
    }
    
    if (defined wantarray) {
	$fdg = new Geo::Raster $fdg;
	return $fdg;
    } else {
	$dem->_new_grid($fdg);
    }
}

## @method @outlet(@cell)
# @brief A FDG method. Return the outlet of the catchment.
sub outlet {
    my($fdg, @cell) = @_;
    my $cell = _find_outlet($fdg->{GRID}, @cell);
    return @{$cell};
}

## @method Geo::Raster ucg()
#
# @brief Puts into each grid a byte telling which cells in the neighborhood are 
# higher (upslope cells).
#
# @return In void context (no return grid is wanted) the method changes this 
# grid, otherwise the method returns a new grid with the directions to the 
# upslope cells (ucg == upslope cell grid).
sub ucg {
    my($dem) = @_;
    my $ucg = ral_dem_ucg($dem->{GRID});
    if (defined wantarray) {
	$ucg = new Geo::Raster $ucg;
	return $ucg;
    } else {
	$dem->_new_grid($ucg);
    }
}

## @method @upstream(Geo::Raster streams, array cell)
#
# @brief This FDG method returns the directions (as looked up from the FDG
# self) of the upstream cells of the specified cell.
#
# Example of getting directions to the upstream cells:
# @code
#($up,@up) = $fdg->upstream($streams,@cell);
# @endcode
#
# @param[in] streams An binary grid indicating where upstream cells can be. Should 
# have the same dimension as the FDG-grid.
# @param[in] cell Array having the i- and j-coordinates of the cell.
# @return An array where the first element is the direction (from FDG) 
# of the upstream stream cell and the second an array containing the directions 
# to the other upstream cells.

## @method @upstream(array cell)
# 
# @brief This FDG method returns the directions (as looked up from the FDG
# self) of the upstream cells of the specified cell.
#
# Example of getting directions to the upstream cells:
# @code
#(@up) = $fdg->upstream(@cell);
# @endcode
#
# @param[in] cell Array having the i- and j-coordinates of the cell.
# @return Array which contains the directions to the upstream cells.
sub upstream { 
    my $fdg = shift;
    my $streams;
    my @cell;
    if ($#_ > 1) {
	($streams,@cell) = @_;
    } else {
	@cell = @_;
    }
    my @up;
    my $d;
    for $d (1..8) {
	my @test = $fdg->movecell(@cell, $d);
	next unless @test;
	my $u = $fdg->get(@test);
	next if $streams and !($streams->get(@test));
	if ($u == ($d - 4 <= 0 ? $d + 4 : $d - 4)) {
	    push @up, $d;
	}
    }
    return @up;
}

## @method Geo::Raster drain_flat_areas(Geo::Raster dem, hash params)
#
# @brief This flow direction grid (fdg) method routes water off from flat
# areas (and stores the routing into the fdg).
#
# The method uses either "one pour point" (short "o") or 
# "multiple pour points" (short "m"). The first
# method, which is the default, finds the lowest or nodata cell just
# outside the flat area and, if the cell is lower than the flat area
# or a nodatacell, drains the whole area there, or into the flat area
# cell (which is made a pit cell), which is next to the cell in
# question. This method is guaranteed to produce a FDG without flat
# areas. The second method drains the flat area cells iteratively into
# their lowest non-higher neighboring cells having flow direction
# resolved.
# This method modifies the object to which it is applied or returns a
# new object depending on the context it is invoked.
# @param[in] dem a DEM-grid.
# @param[in] params named parameters, may be:
# - <I>method</I>=>string (optional). Default is "one pour point" (short "o") 
# and as alternative method can be used "multiple pour points" (short "m").
# - <I>quiet</I>=>boolean (optional). Tells if the method should print error 
# messages.
# @return In void context (no return grid is wanted) the method changes this 
# flow direction grid, otherwise the method returns a new FDG.
sub drain_flat_areas {
    my($fdg, $dem, %opt) = @_;
    croak "drain_flat_areas: no DEM supplied" unless $dem and ref($dem);
    if (defined wantarray) {
	$fdg = new Geo::Raster $fdg;
    }
    if (!$opt{method}) {
	$opt{method} = 'one pour point';
	print STDERR "drain_flat_areas: Warning: method not set, using '$opt{method}'\n" unless $opt{quiet};
    }
    if ($opt{method} =~ /^m/) {
	my $n = ral_fdg_drain_flat_areas1($fdg->{GRID}, $dem->{GRID});
	print STDERR "drain_flat_areas (m): $n flat areas drained\n" unless $opt{quiet};
    } elsif ($opt{method} =~ /^o/) {
	my $n = ral_fdg_drain_flat_areas2($fdg->{GRID}, $dem->{GRID});
	print STDERR "drain_flat_areas (o): $n flat areas drained\n" unless $opt{quiet};
    } else {
	croak "drain_flat_areas: $opt{method}: unknown method";
    }
    return $fdg if defined wantarray;
}

## @method Geo::Raster raise_pits(hash opt)
#
# @brief This DEM method raises the single pit cells to the level of their
# neighbors (the lowest of the neighbors).
# @param[in] opt Has named parameters: 
# - <I>z_limit</I>=>number (optional). A threshold value indicating how big 
# differences a pit can have to its lowest neighbor. If the diffenrence is less 
# than the the z_limit, then the pit is not raised. Default is 0 (no difference 
# allowed).
# - <I>quiet</I>=>boolean (optional). Tells if the method should print error 
# messages.
# @return In void context (no return grid is wanted) the method changes this 
# DEM grid, otherwise the method returns a new DEM.
sub raise_pits {
    my($dem, %opt) = @_;
    $opt{z_limit} = 0 unless defined($opt{z_limit});
    $dem = new Geo::Raster $dem if defined wantarray;
    my $n = ral_dem_raise_pits($dem->{GRID}, $opt{z_limit});
    print STDERR "raise_pits: $n pit cells raised\n" unless $opt{quiet};
    return $dem if defined wantarray;
}

## @method lower_peaks(%opt)
# 
# This DEM method lowers the single peak cells to the level of their
# neighbors (the highest of the neighbors).
#
# @param[in] opt Has named parameters: 
# - <I>z_limit</I>=>number (optional). A threshold value indicating how big 
# differences a cell can have to its heighest neighbor. If the diffenrence is 
# less than the the z_limit, then the peak is not lowered. Default is 0 (no 
# difference allowed).
# - <I>quiet</I>=>boolean (optional). Tells if the method should print error 
# messages.
# @return In void context (no return grid is wanted) the method changes this 
# DEM grid, otherwise the method returns a new DEM.
sub lower_peaks {
    my($dem, %opt) = @_;
    $opt{z_limit} = 0 unless defined($opt{z_limit});
    $dem = new Geo::Raster $dem if defined wantarray;
    my $n = ral_dem_lower_peaks($dem->{GRID}, $opt{z_limit});
    print STDERR "lower_peaks: $n peak cells lowered\n" unless $opt{quiet};
    return $dem if defined wantarray;
}

## @method Geo::Raster depressions(Geo::Raster fdg, $inc_m)
#
# @brief Creates a depression grid.
#
# A depression (or a ``pit'') is a connected (in the FDG sense) area in the DEM, 
# which is lower than all its neighbors. To find and look at all the depressions 
# use this method, which returns a grid:
# @code
# $depressions = $dem->depressions($fdg, $inc_m);
# @endcode
# 
# @param[in] fdg (optional) Reference to an flow direction grid. The default is to 
# calculate it using the D8 method and then route flow through flat areas using 
# the methods "multiple pour points" and "one pour point" (in this order).
# @param[in] inc_m (optional). The depressions grid is a 
# binary grid unless $inc_m is given and is 1. Default is 0.   
# @return Returns a new grid with the depressions.
sub depressions {
    my($dem, $fdg, $inc_m) = @_;
    $inc_m = 0 unless defined($inc_m) and $inc_m;
    return new Geo::Raster(ral_dem_depressions($dem->{GRID}, $fdg->{GRID}, $inc_m));
}

## @method Geo::Raster fill_depressions(%opt)
# 
# @brief This method can be called for a grid containing a digital elevation model 
# (DEM), and it fills all depressions and drains all flat areas of that DEM.
#
# Filling means raising the depression cells to the elevation of the lowest lying
# cell just outside the depression. The filling procedure often needs to be run 
# several times over the grid to remove all removable depressions. This method 
# automatically re-runs the filling procedure a sufficient number of times until
# no depressions can be removed between two consequtive runs. Typically a 
# completely depressionless DEM is produced.
#
# Flat areas are drained using consequtive runs of the methods 'multiple pour points' 
# and 'one pour point' (in this order). See also manual entry for 'drain_flat_areas'. 
#
# Filling depressions and draining flats is repeated alternatively until a 
# depressionless and flat free DEM is produced (when possible). The method alters the 
# DEM grid for which it was invoked, and returns a hydrologically continuous flow 
# direction grid. By completion - unless surpressed using the 'quiet' option - the 
# method prints out the number of remaining depression (pit) cells and flat cells.   
#
# @param[in] opt
# - <I>quiet</I>=>boolean (optional). Suppresses all output if set to true (1). Default is false.
#
# @return A hydrologically continuous flow direction grid
#
# Examples of use:
# @code
# $fdg = $dem->fill_depressions();
# $fdg = $dem->fill_depressions(quiet=>1);
# @endcode
sub fill_depressions {
    my($dem, %opt) = @_;
    if ($opt{no_iteration}) {
	croak "fill_depressions: FDG needed if non-iterative" unless $opt{fdg};
	$dem = new Geo::Raster $dem if defined wantarray;
	ral_dem_fill_depressions($dem->{GRID}, $opt{fdg}->{GRID});
	return $dem if defined wantarray;
	return;
    }
    if ($opt{fdg}) {
	return ral_dem_fill_depressions($dem->{GRID}, $opt{fdg}->{GRID});
    } else {
	my $fdg = $dem->fdg(method=>'D8', quiet=>$opt{quiet});
	$fdg->drain_flat_areas($dem, method=>'m', quiet=>$opt{quiet});
	$fdg->drain_flat_areas($dem, method=>'o', quiet=>$opt{quiet});
	my $c = $fdg->contents();
	my $pits = $$c{0} || 0;
	my $flats = $$c{-1} || 0;
	print STDERR "fill_depressions: $pits pit and $flats flat cells remain\n" unless $opt{quiet};
	my $i = 1;
	while ($pits > 0 or $flats > 0) {
	    ral_dem_fill_depressions($dem->{GRID}, $fdg->{GRID});
	    $fdg = $dem->fdg( method=>'D8', quiet=>$opt{quiet});
	    $fdg->drain_flat_areas($dem, method=>'m', quiet=>$opt{quiet});
	    $fdg->drain_flat_areas($dem, method=>'o', quiet=>$opt{quiet});
	    $c = $fdg->contents();
	    my $pits_last_time = $pits;
	    my $flats_last_time = $flats;
	    $pits = $$c{0} || 0;
	    $flats = $$c{-1} || 0;
	    if ($pits_last_time == $pits and $flats_last_time == $flats) {
		print STDERR "fill_depressions: bailing out, there is no progress!\n";
		last;
	    }
	    print STDERR "fill_depressions: iteration $i: $pits pit and $flats flat cells remain\n" unless $opt{quiet};
	    $i++;
	}
	return $fdg;
    }
}

## @method breach(%opt)
#
# @brief This iterative DEM method applies the breaching method on all
# depressions and drains all flat areas. 
#
# Depressions may be removed by filling or by breaching. Breaching means 
# lowering the elevation of the ``dam'' cells.  The breaching is tried at the 
# lowest cell on the rim of the depression which has the steepest descent away 
# from the depression (if there are more than one lowest cells) and the steepest 
# descent into the depression (if there are more than one lowest cells with 
# identical slope out)
#
# The treatment of flat areas and depressions in automated drainage 
# analysis of raster digital elevation models. Hydrol. Process. 12, 843-855; 
# the breaching algorithm implemented here is close to but not the same as 
# theirs - the biggest difference being that the depression cells are not raised 
# here). Breaching is often limited to a certain number of cells. Both of these 
# methods change the DEM. Both methods need to be run iteratively to remove all 
# removable depressions. Only the filling method is guaranteed to produce a 
# depressionless DEM.
#
# Example of non-iterative versions of the method:
# @code
# $dem->breach($fdg, $limit);
# @endcode
#
# Named parameters include:
# @param[in] opt Can have named parameters:
# - <I>limit</I> (optional). Maximum amount of cells to be breached. Default is 
# to not limit the breaching ($limit == 0).
# - <I>fdg</I> (optional). Reference to an flow direction grid. Should not 
# contain flat areas. The default is to 
# calculate it using the D8 method and then route flow through flat areas using 
# the methods "multiple pour points" and "one pour point" (in this order).
# If the $fdg is not given it is calculated as above in the depressions method 
# and the depressions are removed iteratively until all depressions are removed 
# or the number of depressions does not diminish in one iteration loop.
# - <I>no_iteration</I>=>boolean. Tells the metdos if it should work 
# non-iteratively. The FDG id needed if non-iterative approach is wanted.
# - <I>quiet</I>=>boolean (optional). Tells if the method should not print error 
# messages.
# @return Returns a flow direction grid (without flat or pit cells) (dem if
# non-iterative)
# @see Martz, L.W. and Garbrecht, J. 1998.
sub breach {
    my($dem, %opt) = @_;
    $opt{limit} = 0 unless defined($opt{limit});
    if ($opt{no_iteration}) {
	croak "breach: FDG needed if non-iterative" unless $opt{fdg};
	my $g = ral_dem_breach($dem->{GRID}, $opt{fdg}->{GRID}, $opt{limit});
	if (defined wantarray) {
	    return new Geo::Raster $g;
	} else {
	    $dem->_new_grid($g);
	    return;
	}
    }
    if ($opt{fdg}) {
	return ral_dem_breach($dem->{GRID}, $opt{fdg}->{GRID}, $opt{limit});
    } else {
	my $fdg = $dem->fdg(method=>'D8', quiet=>$opt{quiet});
	$fdg->drain_flat_areas($dem, method=>'m', quiet=>$opt{quiet});
	$fdg->drain_flat_areas($dem, method=>'o', quiet=>$opt{quiet});
	my $c = $fdg->contents();
	my $pits = $$c{0} || 0;
	my $flats = $$c{-1} || 0;
	print STDERR "breach: $pits pit and $flats flat cells remain\n" unless $opt{quiet};
	my $i = 1;
	while ($pits > 0 or $flats > 0) {
	    ral_dem_breach($dem->{GRID}, $fdg->{GRID}, $opt{limit});
	    $fdg = $dem->fdg(method=>'D8', quiet=>$opt{quiet});
	    $fdg->drain_flat_areas($dem, method=>'m', quiet=>$opt{quiet});
	    $fdg->drain_flat_areas($dem, method=>'o', quiet=>$opt{quiet});
	    $c = $fdg->contents();
	    my $pits_last_time = $pits;
	    my $flats_last_time = $flats;
	    $pits = $$c{0} || 0;
	    $flats = $$c{-1} || 0;
	    if ($pits_last_time == $pits and $flats_last_time == $flats) {
		print STDERR "breach: bailing out, there is no progress!\n";
		last;
	    }
	    print STDERR "breach: iteration $i: $pits pit and $flats flat cells remain\n" unless $opt{quiet};
	    $i++;
	}
	return $fdg;
    }
}

## @method Geo::Raster drain_depressions(Geo::Raster dem)
#
# @brief This FDG method drains all depressions by changing the flowpath from
# the pit to the lowest pour point on the depression. The DEM remains
# unchanged.
# @param[in] dem Geo::Raster as an Digital Elevation Model.
# @return In void context (no return grid is wanted) the method changes this 
# flow direction grid, otherwise the method returns a new FDG.
sub drain_depressions {
    my($fdg, $dem) = @_;
    $fdg = new Geo::Raster $fdg if defined wantarray;
    ral_fdg_drain_depressions($fdg->{GRID}, $dem->{GRID});
    return $fdg if defined wantarray;
}

## @method route(Geo::Raster dem, Geo::Raster fdg, Geo::Raster flow, Geo::Raster k, Geo::Raster d, $f, $r)
#
# @brief This method routes water downstream.
#
# The method should be used for a grid having the current water quantities for 
# each cell.
#
# The method is recursive and routes water from each cell downslope if water 
# from all its upslope cells have been routed downslope.
#
# The catchment tree is traversed using the flow direction grid, which thus 
# must contain only valid directions (no pits nor flat area cells).
#
# Example of routing water out from a catchment:
# @code
# $water_grid->route($dem_grid, $fdg_grid, $flow_grid, $k_grid, $d_grid, $f, $r);
# @endcode
#
# @param[in] dem The elevation of the ground as an real grid.
# @param[in] fdg The flow directions of the ground as an integer grid. Defines 
# into which direction the water flows.
# @param[out] flow The amount of water routed forward from this grid (leaving 
# each cell).
# @param[in] k Values to be added to the slope.
# @param[in] d Values to be used for multiplying the effect of slopes (current?).
# @param[in] f (optional). If true then water is routed from each cell to all of 
# its neighbors having the same or lower elevation, else if false only to a 
# single cell pointed by FDG. Default value is 1 (true).
# @param[in] r (optional). Unit of z dived by the unit of x and y. By default is 1.
# @note All the grids have to be overlayable and all grids except the flow 
# direction grid have to have as datatype real.
sub route {
    my($water, $dem, $fdg, $flow, $k, $d, $f, $r) = @_;
    $f = 1 unless defined $f;
    $r = 1 unless defined $r;
    croak ("usage: $water->route($dem, $fdg, $flow, $k, $d, $f, $r)") unless $flow;
    return water_route($water->{GRID}, $dem->{GRID}, $fdg->{GRID}, $flow->{GRID}, $k->{GRID}, $d->{GRID}, $f, $r);
}

## @method Geo::Raster path($i, $j, Geo::Raster stop)
# 
# @brief This FDG method returns the path from the given cell to the end of
# the path as a raster. 
#
# The end of the path is where flow direction is not specified, where it goes 
# out of the boundaries, or where the stop grid is > 0.
#
# @param[in] i The beginning cells i-coordinate.
# @param[in] j The beginning cells j-coordinate.
# @param[in] stop (optional) Grid defining where a path can not pass and must end
# (like a well for water :) ).
# @return Returns the path from the given cell to the end of
# the path as grid. 
sub path {
    my($fdg, $i, $j, $stop) = @_;
    my $g = ral_fdg_path($fdg->{GRID}, $i, $j, $stop ? $stop->{GRID} : undef);
    if (defined wantarray) {
	return new Geo::Raster $g;
    } else {
	$fdg->_new_grid($g);
    }
}

## @method Geo::Raster path_length(Geo::Raster stop, Geo::Raster op)
#
# @brief This FDG method returns a raster, where the value of each cell is
# the length of the path from that cell to the end of the path.
#
# The path is assumed to go from a center point of a cell to another
# center point. The length is not recorded if op is nodata. The length
# is calculated in the raster units.
# @param[in] stop (optional)
# @param[in] op (optional)
# @return In void context (no return grid is wanted) the method changes this 
# flow direction grid, otherwise the method returns a new FDG.
sub path_length {
    my($fdg, $stop, $op) = @_;
    my $g = ral_fdg_path_length($fdg->{GRID}, $stop ? $stop->{GRID} : undef, $op ? $op->{GRID} : undef);
    if (defined wantarray) {
	return new Geo::Raster $g;
    } else {
	$fdg->_new_grid($g);
    }
}

## @method Geo::Raster path_sum(Geo::Raster stop, Geo::Raster op)
# 
# @brief This FDG method returns a raster, where the value of each cell is
# the weighted (with length) sum along the path from that cell to the
# end of the path.
#
# The path is assumed to go from a center point of a
# cell to another center point. The length is not recorded if op is
# nodata. The length is calculated in the raster units.
# @param[in] stop (optional) Grid defining where a path can not pass and must end.
# @param[in] op Weight of the cells value, which is summed.
# Must be overlayable with this flow direction grid. 
# @return In void context (no return grid is wanted) the method changes this 
# flow direction grid, otherwise the method returns a new FDG.
sub path_sum {
    my($fdg, $stop, $op) = @_;
    my $g = ral_fdg_path_sum($fdg->{GRID}, $stop ? $stop->{GRID} : undef, $op->{GRID});
    if (defined wantarray) {
	return new Geo::Raster $g;
    } else {
	$fdg->_new_grid($g);
    }
}

## @method Geo::Raster upslope_sum(Geo::Raster a, $b)
# 
# @brief This FDG method computes the sum of the cell values from the upslope
# cells for all cells of the operand raster. 
# 
# @param[in] a The operand raster grid.
# @param[in] b (optional). Boolean value specifying whether the cell itself is 
# included into the upslope area. By default 1 (true).
# @return In void context (no return grid is wanted) the method changes this 
# flow direction grid, otherwise the method returns a new FDG.
# @note DO NOT call if the FDG contains loops.
sub upslope_sum {
    my($fdg, $a, $b) = @_;
    my $op = ref $a ? $a : $b;
    my $include_self = ref $a ? $b : $a;
    $include_self = 1 unless defined $include_self;
    croak "usage: \$fdg->upslope_sum(\$op); where \$op is a raster whose values are to be summed" 
	unless $op and $op->{GRID};
    my $g = ral_fdg_upslope_sum($fdg->{GRID}, $op->{GRID}, $include_self);
    if (defined wantarray) {
	return new Geo::Raster $g;
    } else {
	$fdg->_new_grid($g);
    }
}

## @method Geo::Raster upslope_count(Geo::Raster a, $b)
# 
# @brief This FDG method computes the count of the upslope cells for all
# cells of the operand raster. 
#
# @param[in] a The operand raster grid. The operand may be used to specify which 
# cells to count and which not (the nodata cells are not counted).
# @param[in] b Boolean value, which specifies whether the cell itself is included 
# into the upslope area (default is yes). 
# @return In void context (no return grid is wanted) the method changes this 
# flow direction grid, otherwise the method returns a new FDG.
# @note DO NOT call if the FDG contains loops.
sub upslope_count {
    my($fdg, $a, $b) = @_;
    my $op = ref $a ? $a : $b;
    my $include_self = ref $a ? $b : $a;
    $include_self = 1 unless defined $include_self;
    my $g = $op ? 
	ral_fdg_upslope_count($fdg->{GRID}, $op->{GRID}, $include_self) : 
	ral_fdg_upslope_count_without_op($fdg->{GRID}, $include_self);
    if (defined wantarray) {
	return new Geo::Raster $g;
    } else {
	$fdg->_new_grid($g);
    }
}

## @method Geo::Raster kill_extra_outlets(Geo::Raster lakes, Geo::Raster uag)
# 
# @brief This FDG method checks its sanity against the lakes in the terrain,
# so that no flow paths exit and enter the same lake again. 
#
# The FDG is modified (or a new FDG is returned) so that each lake has only one
# outlet.
# @param[in] lakes an integer raster of the lakes in the terrain (each lake may have 
# its own id)
# @param[in] uag (optional) Upslope area grid.
# @return In void context (no return grid is wanted) the method changes this 
# flow direction grid, otherwise the method returns a new FDG.
sub kill_extra_outlets {
    my ($fdg, $lakes, $uag) = @_;
    $fdg = new Geo::Raster $fdg if defined wantarray;
    $uag = $fdg->upslope_count unless $uag;
    ral_fdg_kill_extra_outlets($fdg->{GRID}, $lakes->{GRID}, $uag->{GRID});
    return $fdg if defined wantarray;
}

## @method Geo::Raster catchment(array cell, scalar m)
#
# @brief This FDG method computes the catchment area of the given cell and
# marks it on the returned raster using m.
# @param[in] cell The i- and j-coordinates of the cell.
# @param[in] m (optional). Number used to mark the cells belonging to the 
# catchment. By default 1 (true). 
# @return Returns the catchment as Geo::Raster. Alternatively returns a list 
# containing the catchment Geo::Raster and the size of the catchment.

## @method Geo::Raster catchment(Geo::Raster catchment, array cell, scalar m)
#
# @brief This FDG method computes the catchment area of the given cell and
# marks it on the given raster using m.
# @param[out] catchment
# @param[in] cell The i- and j-coordinates of the cell.
# @param[in] m (optional). Number used to mark the cells belonging to the 
# catchment. By default 1 (true).
# @return Returns the catchment Geo::Raster, which is the given grid, with the
# catchment cells marked. Alternatively returns a list containing the catchment 
# Geo::Raster, which is the given grid with the catchment cells marked, 
# and the size of the catchment.
sub catchment {
    my $fdg = shift;
    my $i = shift;
    my ($M, $N) = $fdg->size();
    my ($j, $m, $catchment);
    if (isa($i, 'Geo::Raster')) {
	$catchment = $i;
	$i = shift;
	$j = shift;
	$m = shift;
    } else {
	$catchment = new Geo::Raster(like=>$fdg);
	$j = shift;
	$m = shift;
    }
    $m = 1 unless defined($m);
    my $size = ral_fdg_catchment($fdg->{GRID}, $catchment->{GRID}, $i, $j, $m);
    return wantarray ? ($catchment, $size) : $catchment;
}

## @method Geo::Raster distance_to_pit(scalar steps)
# 
# @brief This FDG method computes the distance to the outlet of the
# catchment.
# @param[in] steps (optional) Boolean telling if the distances between pixels along 
# the path are calculated in pixel units and not in grid units. By default 
# false (0).
# @return Returns a new grid with the distances.
sub distance_to_pit {
    my $fdg = shift;
    my $steps = shift;
    my $g = ral_fdg_distance_to_pit($fdg->{GRID}, $steps);
    return unless $g;
    my $ret = new Geo::Raster $g;
    return $ret;
}

## @method Geo::Raster distance_to_channel(Geo::Raster streams, $steps)
#
# @brief Returns a new grid whose cell values represent the distance to nearest 
# channel along the flow path (defined by this flow direction grid).
#
# Example of usage:
# @code 
# $d = $fdg->distance_to_channel($open_water_grid,[$steps])
# @endcode
#
# @param[in] streams A raster grid having non-zero values for channels.
# @param[in] steps (optional) Boolean telling if the distances between pixels along 
# the path are calculated in pixel units and not in grid units. By default 
# false (0).
# @return Returns a new grid with the distances.
sub distance_to_channel {
    my $fdg = shift;
    my $streams = shift;
    my $steps = shift;
    my $g = ral_fdg_distance_to_channel($fdg->{GRID}, $streams->{GRID}, $steps);
    return unless $g;
    return new Geo::Raster $g;
}

# does not make sense??
sub distance_to_divide {
    my $fdg = shift;
    my $steps = shift;
    my $g = ral_fdg_distance_to_divide($fdg->{GRID}, $steps);
    return unless $g;
    return new Geo::Raster $g;
}

## @method Geo::Raster prune(Geo::Raster fdg, Geo::Raster lakes, $min_length, @cell)
# 
# @brief This streams method removes streams shorter than min_length (in grid
# scale!).
#
# Example of removing streams shorter than min_lenght:
# @code
# $streams->prune($fdg_grid, $lakes_grid, $min_lenght, $i, $j);
# @endcode
# @param[in] fdg Flow direction grid, which gives the flow directions of the stream.
# @param[in] lakes (optional) Raster grid defining lakes.
# @param[in] min_length Minimum length of an stream to be not deleted.
# @param[in] cell (optional) The cells i- and j-coordinates, from where the method
# begins to remove too short streams (the root of that stream tree). If not 
# given then all streams are pruned if they are too short.
# @return In void context (no return grid is wanted) the method changes this 
# streams grid, otherwise returns a new grid with only the longer streams.
sub prune {
    my $streams = shift;
    my $fdg = shift;
    my $lakes;
    my $min_length = shift;
    if (isa($min_length, 'Geo::Raster')) {
	$lakes = $min_length;
	$min_length = shift;
    }
    my $i = shift;
    my $j = shift;
    $min_length = 1.5*$streams->{CELL_SIZE} unless defined($min_length);
    $streams = new Geo::Raster $streams if defined wantarray;
    $i = -1 unless defined $i;
    if ($lakes) {
	ral_streams_prune($streams->{GRID}, $fdg->{GRID}, $lakes->{GRID}, $i, $j, $min_length);
    } else {
	ral_streams_prune_without_lakes($streams->{GRID}, $fdg->{GRID}, $i, $j, $min_length);
    }
    return $streams if defined wantarray;
}

## @method Geo::Raster number_streams(Geo::Raster fdg, Geo::Raster lakes, @cell, $sid)
#
# @brief This streams method numbers streams with unique id.
# @param[in] fdg Flow direction grid, which gives the flow directions of the stream.
# @param[in] lakes (optional) Raster grid defining lakes.
# @param[in] cell (optional) The cells i- and j-coordinates, from where the method
# begins to number the streams (the root of that stream tree). If not 
# given then all streams are pruned if they are too short.
# @param[in] sid Id number for the first found stream, the next streams will get
# higher unique numbers.
sub number_streams {
    my $streams = shift;
    my $fdg = shift;
    my $lakes;
    my $i = shift;
    if (isa($i, 'Geo::Raster')) {
	$lakes = $i;
	$i = shift;
    }
    my $j = shift;
    my $sid = shift;
    $sid = 1 unless defined($sid);
    $streams = new Geo::Raster $streams if defined wantarray;
    $i = -1 unless defined $i;
    ral_streams_number($streams->{GRID}, $fdg->{GRID}, $i, $j, $sid);
    if ($lakes) {
	$sid = $streams->max() + 1;
	ral_streams_break($streams->{GRID}, $fdg->{GRID}, $lakes->{GRID}, $sid);
    }
    return $streams if defined wantarray;
}

## @method Geo::Raster subcatchments(Geo::Raster fdg, Geo::Raster lakes, array cell, scalar head)
#
# @brief This streams raster method divides the catchment into subcatchments
# defined by the stream network.
#
# Example of usage:
# @code
# $subcatchments = $streams->subcatchments($fdg, $i, $j);
# @endcode
# or 
# @code
# ($subcatchments, $topo) = $streams->subcatchments($fdg, $lakes, $i, $j);
# @endcode
#
# @param[in] fdg The FDG from which the streams raster has been computed.
# @param[in] lakes (optional) Raster grid defining lakes.
# @param[in] cell (optional) The cells i- and j-coordinates, which is the outlet 
# point of the whole catchment.
# @param[in] head (optional) 0 or 1, if 1 the algorithm divides the
# catchment of a headstream to head and regular subcatchment. Head
# catchment drains into the last cell of the stream.
# @return Returns a subcatchments raster or a subcatchments raster and
# topology, topology is a reference to a hash of
# $upstream_element=>$downstream_element associations.
sub subcatchments {
    my $streams = shift;
    my $fdg = shift;
    my $lakes;
    my $i = shift;
    if (isa($i, 'Geo::Raster')) {
	$lakes = $i;
	$i = shift;
    }
    my $j = shift;
    my $headwaters = shift;
    $headwaters = 0 unless defined($headwaters);
    if ($lakes) {
	my $subs = new Geo::Raster(like=>$streams);
	$i = -1 unless defined $i;
	my $r = ral_ws_subcatchments($subs->{GRID}, 
				     $streams->{GRID}, 
				     $fdg->{GRID}, 
				     $lakes->{GRID}, $i, $j, $headwaters);
	
	# drainage structure:
	# head -> stream (if exist)
	# sub -> lake or stream
	# lake -> stream
	# stream -> lake or stream

	my %ds;

	for my $key (keys %{$r}) {
	    ($i, $j) = split /,/, $key;
	    my($i_down, $j_down) = split /,/, $r->{$key};
	    my $sub = $subs->get($i, $j);
	    my $stream = $streams->get($i, $j);
	    my $lake = $lakes->get($i, $j);
	    my $sub_down = $subs->get($i_down, $j_down);
	    my $stream_down = $streams->get($i_down, $j_down);
	    my $lake_down = $lakes->get($i_down, $j_down);
	    if ($lake <= 0) {
		if ($lake_down > 0) {
		    $ds{"sub $sub $i $j"} = "stream $stream";
		} elsif ($stream != $stream_down or ($i == $i_down and $j == $j_down)) {
		    $ds{"sub $sub $i $j"} = "stream $stream";
		    $ds{"stream $stream $i $j"} = "stream $stream_down";
		} else {
		    $ds{"head $sub $i $j"} = "stream $stream";
		}
	    } else {
		$ds{"sub $sub $i $j"} = "lake $lake";
		$ds{"lake $lake $i $j"} = "stream $stream_down";
	    }
	    if ($lake_down > 0) {
		$ds{"stream $stream $i $j"} = "lake $lake_down";
	    }
	}

	return wantarray ? ($subs,\%ds) : $subs;
    } else {
	$i = -1 unless defined $i;
	return new Geo::Raster(ral_streams_subcatchments($streams->{GRID}, $fdg->{GRID}, $i, $j));
    }
}

## @method save_catchment_structure(hashref topology, $streams, $lakes, $ogr_datasource, $ogr_layer)
#
# @brief Saves the subcatchment structure as a vector layer.
# @param[in] topology Reference to an hash having as keys = type id i j, and as 
# values = type id.
# @param[in] streams Raster grid defining streams.
# @param[in] lakes (optional) Raster grid defining lakes.
# @param[in] ogr_datasource is an OGR datasource name, e.g., a directory.
# @param[in] ogr_layer Name for the new layer.
sub save_catchment_structure {
    my ($self, $topology, $streams, $lakes, $ogr_datasource, $ogr_layer) = @_;

    my $cell_size = $self->cell_size();

    my ($minX, $minY, $maxX, $maxY) = $self->world();

    my $datasource = Geo::OGR::Open($ogr_datasource, 1) or 
	croak "can't open '$ogr_datasource' as an OGR datasource";

    my $osr;
    #$osr = new osr::SpatialReference;
    #$osr->SetWellKnownGeogCS('WGS84');

    my $catchment = $datasource->CreateLayer($ogr_layer, $osr, $Geo::OGR::wkbPolygon);
    my $defn = new Geo::OGR::FieldDefn('element', $Geo::OGR::OFTInteger);
    $defn->SetWidth(5);
    $catchment->CreateField($defn);
    $defn = new Geo::OGR::FieldDefn('type', $Geo::OGR::OFTString);
    $defn->SetWidth(10);
    $catchment->CreateField($defn);
    $defn = new Geo::OGR::FieldDefn('down', $Geo::OGR::OFTInteger);
    $defn->SetWidth(5);
    $catchment->CreateField($defn);
    $defn = new Geo::OGR::FieldDefn('type_down', $Geo::OGR::OFTString);
    $defn->SetWidth(10);
    $catchment->CreateField($defn);
    my $schema = $catchment->GetLayerDefn();

    my $layer = $self*1;
    my ($minval, $maxval) = $layer->value_range();

    # add only lakes which exist in the structure
    # use unique id's for different subcatchment types, lakes, and streams
    # lakes and subcatchments fill the area completely
    # streams are add-ons
    # so we need two polygonize passes

    my %subs;
    my %streams;
    my %lake_maps;
    my %stream_maps;

    # topology, keys = type id i j, values = type id
    for my $key (keys %$topology) {
	if ($key =~ /^(\w+) (\d+) \d+ \d+/) {
	    my $type = $1;
	    my $element = $2;
	    if ($topology->{$key} =~ /^(\w+) (\d+)/) {
		if ($type eq 'stream') {
		    $maxval++;
		    $stream_maps{$element} = $maxval;
		    $element = $maxval;
		    $streams{$element}{type_down} = $1;
		    $streams{$element}{down} = $2;
		} else {
		    if ($type eq 'lake') {
			$maxval++;
			$lake_maps{$element} = $maxval;
			$layer->if($lakes == $element, $maxval);
			$element = $maxval;
		    }
		    $subs{$element}{type} = $type;
		    $subs{$element}{type_down} = $1;
		    $subs{$element}{down} = $2;
		}
	    }
	}
    }
    for my $element_storage (\%subs, \%streams) {
	for my $element (keys %$element_storage) {
	    my $down = $element_storage->{$element}{down};
	    if ($element_storage->{$element}{type_down} eq 'lake') {
		$element_storage->{$element}{down} = $lake_maps{$down} if $lake_maps{$down};
	    } elsif ($element_storage->{$element}{type_down} eq 'stream') {
		$element_storage->{$element}{down} = $stream_maps{$down} if $stream_maps{$down};
	    }
	}
    }

    # polygonize and add subcatchment and lake polygons

    my $polygons = $layer->polygonize();

    for my $k (keys %$polygons) {
	my $element = $polygons->{$k}->{value};
	
	next unless $subs{$element};
	
	my $f = new Geo::OGR::Feature($schema);
	my $g = new Geo::OGR::Geometry($Geo::OGR::wkbPolygon);
	my $r = new Geo::OGR::Geometry($Geo::OGR::wkbLinearRing);
	
	my $path = the_border_of_a_polygon($polygons->{$k}->{lines});
	
	for my $point (@$path) {
	    $r->AddPoint($minX + $point->[1] * $cell_size, $maxY - $point->[0] * $cell_size);
	}
	
	$g->AddGeometry($r);
	$g->CloseRings;
	$f->SetGeometry($g);
	$f->SetField(0, $element);
	$f->SetField(1, $subs{$element}{type});
	$f->SetField(2, $subs{$element}{down});
	$f->SetField(3, $subs{$element}{type_down});
	$catchment->CreateFeature($f);	
    }

    # polygonize and add streams

    $layer = $streams*($self>0);
    for my $lake (keys %lake_maps) {
	$layer->if($lakes == $lake, 0);
    }
    $polygons = $layer->polygonize();

    for my $k (keys %$polygons) {
	my $element = $polygons->{$k}->{value};
	$element = $stream_maps{$element};
	
	next unless $streams{$element};
	
	my $f = new Geo::OGR::Feature($schema);
	my $g = new Geo::OGR::Geometry($Geo::OGR::wkbPolygon);
	my $r = new Geo::OGR::Geometry($Geo::OGR::wkbLinearRing);
	
	my $path = the_border_of_a_polygon($polygons->{$k}->{lines});
	
	for my $point (@$path) {
	    $r->AddPoint($minX + $point->[1] * $cell_size, $maxY - $point->[0] * $cell_size);
	}
	
	$g->AddGeometry($r);
	$g->CloseRings;
	$f->SetGeometry($g);
	$f->SetField(0, $element);
	$f->SetField(1, 'stream');
	$f->SetField(2, $streams{$element}{down});
	$f->SetField(3, $streams{$element}{type_down});
	$catchment->CreateFeature($f);	
    }
    $catchment->SyncToDisk;
}

## @method void vectorize_streams(Geo::Raster fdg, $i, $j)
#
# @brief The method creates an OGR-layer from this streams raster grid.
# @param fdg The FDG from which the streams raster has been computed.
# @param i The cells i-coordinate, from where the method begins to vectorize
# the streams (the root of that stream tree).
# @param j The cells j-coordinate, from where the method begins to vectorize
# the streams (the root of that stream tree).
# @note The FDG has to be overlayable with this grid.
# @todo This method is still unfinished.
sub vectorize_streams {
    my ($self, $fdg, $i, $j, $ogr_datasource, $ogr_layer) = @_;
    ral_streams_vectorize($self->{GRID}, $fdg->{GRID}, $i, $j);
}

## @method compare_dem_derived_ws_attribs(Geo::Raster uag, Geo::Raster dem, $filename, $iname, $ielev, $idarea)
#
# @todo Documentation
sub compare_dem_derived_ws_attribs {
    my ($self, $uag, $dem, $filename, $iname, $ielev, $idarea) = @_;
    #my ($self, $filename) = @_;
    (my $fileBaseName, my $dirName, my $fileExtension) = fileparse($filename,('\.shp'));
    #my $jep = $fileBaseName.$fileExtension;
    #print STDERR "$dirName and $jep\n";
    ral_compare_dem_derived_ws_attribs($self->{GRID}, $uag->{GRID}, $dem->{GRID}, $dirName, $fileBaseName, $iname, $ielev, $idarea);
}

1;
