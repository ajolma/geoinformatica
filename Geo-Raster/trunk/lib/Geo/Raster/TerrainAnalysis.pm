## @class Geo::Raster::TerrainAnalysis
# @brief Adds terrain analysis methods into Geo::Raster
#
# In this module there are methods mainly for digital elevation model
# (DEM) rasters, for flow direction (FDG) rasters, for streams
# rasters.
#
package Geo::Raster;

use UNIVERSAL qw(isa);

## @method @fit_surface($z_factor)
#
# @brief Fit a 9-term quadratic polynomial to the 3*3 neighborhood of
# each cell in a DEM.
#
# The 9-term quadratic polynomial:
#
# z = Ax^2y^2 + Bx^2y + Cxy^2 + Dx^2 + Ey^2 + Fxy + Gx + Hy + I  
#
# @see Moore et al. 1991. Hydrol. Proc. 5, 3-30.
# @param[in] z_factor is the unit of z divided by the unit of x and y, the
# default value of z_factor is 1.
# @return 9 rasters in a list, one for each parameter.
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

## @method Geo::Raster aspect()
#
# @brief Estimate aspects from a DEM.
#
# The aspect is computed from a 9-term quadratic polynomial fitted
# independently on each cell of the DEM. The aspect is stored in
# radians increasing clockwise starting from zero in north. For flat
# cells the aspect is undefined, denoted with the value -1.
# @return an aspect raster. In void context converts the DEM.
sub aspect {
    my $self = shift;
    if (defined wantarray) {
	return Geo::Raster->new(ral_dem_aspect($self->{GRID}));
    } else {
	$self->_new_grid(ral_dem_aspect($self->{GRID}));
    }
}

## @method Geo::Raster slope(scalar z_factor)
#
# @brief Estimate the slope from a DEM.
#
# The slope is computed from a 9-term quadratic polynomial fitted
# independently on each cell of the DEM. The slope is stored in
# radians.
# @param[in] z_factor The unit of z divided by the unit of x and
# y. Default is 1.
# @return a slope raster. In void context converts the DEM.
sub slope {
    my $self = shift;
    my $z_factor = shift;
    $z_factor = 1 unless $z_factor;
    if (defined wantarray) {
	return Geo::Raster->new(ral_dem_slope($self->{GRID}, $z_factor));
    } else {
	$self->_new_grid(ral_dem_slope($self->{GRID}, $z_factor));
    }
}

## @method Geo::Raster fdg(%params) 
#
# @brief Compute a flow direction raster (FDG) from a DEM.
#
# @param[in] params A hash of named parameters:
# - <I>method</I>=>string (optional). The method for computing the
# FDG. Currently supported methods are 'D8' and 'Rho8' and 'many'. D8
# selects the neighbor with steepest descent. Rho8 selects randomly,
# using the descent as a weight, a lower cell. In the 'many' method
# all lower cells are coded with the 8 bits of a byte. The directions
# are from 1 (up) to 8 (up left). Flat cells (no lower neighbors) are
# marked -1. Pit cells (all neighbor cells are higher) are marked with
# 0. The default is D8.
# - <I>drain_all</I>=>boolean (optional). Whether to use iteration to
# produce a FDG with drainage resolved for all cell. The iteration
# algorithm first applies the drain_flat_areas method using the option
# 'multiple pour points', then the same method with option 'one pour
# point'. Next the drainage of all depressions is iteratively resolved
# using the drain_depressions method. The default is false.
# - <I>quiet</I>=>boolean (optional). Whether to report the result
# (number of cells or areas drained).
# @exception - Unsupported method
# @exception - No progress in the iteration
# @return a FDG. In void context converts the DEM.
sub fdg {
    my($dem, %opt) = @_;
    $opt{method} = 'D8' unless $opt{method};
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
	my $step = 1;
	my $pits_last_time = -1;
	my $flats_last_time = -1;
	while (1) {
	    $fdg->drain_flat_areas($dem, method=>'m');
	    $fdg->drain_flat_areas($dem, method=>'o');
	    my $c = $fdg->contents();
	    my $pits = $$c{0} || 0;
	    my $flats = $$c{-1} || 0;
	    print STDERR "drain_all: iteration step $step: $pits pits and $flats flat cells\n" unless $opt{quiet};
	    return if ($pits == 0 and $flats == 0);
	    my $n = ral_fdg_drain_depressions($fdg->{GRID}, $dem->{GRID});
	    print STDERR "drain_all: iteration step $step: $n depressions fixed\n" unless $opt{quiet};
	    croak "there is no progress" if ($pits_last_time == $pits and $flats_last_time == $flats);
	    $pits_last_time = $pits;
	    $flats_last_time = $flats;	    
	    $step++;
	}
    }
    
    if (defined wantarray) {
	return Geo::Raster->new($fdg);
    } else {
	$dem->_new_grid($fdg);
    }
}

## @method Geo::Raster drain_flat_areas(Geo::Raster dem, hash params)
#
# @brief Resolve the flow direction for flat areas in a FDG.
#
# The method uses either "one pour point" (short "o") or "multiple
# pour points" (short "m") technique for resolving the drainage of
# flat area cells of a FDG.
#
# In the one pour point technique (the default) all cells on the flat
# area are drained to one pour point cell. The pour point cell is
# selected either from the border of the flat area or just outside the
# flat area depending whether the outside cell is not higher than the
# inside cell. If the pour point is on the border it is converted into
# a pit cell. Thus this technique is guaranteed to produce a flatless
# FDG but it may increase the number of pits.
#
# In the multiple pour points approach all flat cells are iteratively
# drained to any non-higher neighbor whose drainage is resolved. Thus
# this technique is not guaranteed to produce a flatless FDG.
#
# @param[in] dem The DEM.
# @param[in] params Named parameters:
# - <I>method</I>=>string (optional) Either "one pour point" (short
# "o") or "multiple pour points" (short "m"). Default is one pour
# point.
# - <I>quiet</I>=>boolean (optional) Whether to report the result
# (number of cells or areas drained).
# @exception - No DEM supplied
# @exception - Unsupported method
# @return In void context the method changes this flow direction raster,
# otherwise the method returns a new FDG.
sub drain_flat_areas {
    my($fdg, $dem, %opt) = @_;
    croak "drain_flat_areas: no DEM supplied" unless $dem and ref($dem);
    $fdg = Geo::Raster->new($fdg) if defined wantarray;
    $opt{method} = 'one pour point' unless $opt{method};
    if ($opt{method} =~ /^m/) {
	my $n = ral_fdg_drain_flat_areas1($fdg->{GRID}, $dem->{GRID});
	print STDERR "drain_flat_areas (multiple pour points): $n flat cells drained\n" unless $opt{quiet};
    } elsif ($opt{method} =~ /^o/) {
	my $n = ral_fdg_drain_flat_areas2($fdg->{GRID}, $dem->{GRID});
	print STDERR "drain_flat_areas (one pour point): $n flat areas drained\n" unless $opt{quiet};
    } else {
	croak "drain_flat_areas: $opt{method}: unknown method";
    }
    return $fdg if defined wantarray;
}

## @method Geo::Raster drain_depressions(Geo::Raster dem)
#
# @brief Scan FDG once and drain the depressions that are found.
#
# This method scans the given FDG once and drains all depressions that
# are found in the FDG by reversing the flowpath from the lowest pour
# point of the depression to the pit cell. The DEM remains unchanged.
# @param[in] dem The DEM. The DEM is not changed in the method.
# @return In a void context the method changes this FDG, otherwise the
# method returns a new FDG.
sub drain_depressions {
    my($fdg, $dem) = @_;
    $fdg = new Geo::Raster $fdg if defined wantarray;
    ral_fdg_drain_depressions($fdg->{GRID}, $dem->{GRID});
    return $fdg if defined wantarray;
}

## @method @outlet(@cell)
#
# @brief Return the outlet of a catchment in a FDG.
#
# @param[in] cell A cell on the catchment.
# @return the outlet cell of the catchment.
sub outlet {
    my($fdg, @cell) = @_;
    my $cell = _find_outlet($fdg->{GRID}, @cell);
    return @{$cell};
}

## @method Geo::Raster ucg()
#
# @brief Compute an upslope cell raster (UCG) from a FDG.
#
# In a UCG the upslope cells of a cell are coded with the 8 bits of a
# byte. The directions are from 1 (up) to 8 (up left).
#
# @return a UCG. In void context converts the FDG.
sub ucg {
    my($dem) = @_;
    my $ucg = ral_dem_ucg($dem->{GRID});
    if (defined wantarray) {
	return Geo::Raster->new($ucg);
    } else {
	$dem->_new_grid($ucg);
    }
}

## @method @upstream(Geo::Raster streams, array cell)
#
# @brief Return the direction(s) to the upslope cells of a cell in a FDG.
#
# Example of getting directions to the upstream stream cells:
# @code
# @up = $fdg->upstream($streams, $row, $column);
# @endcode
#
# @param[in] streams (optional) A streams raster.
# @param[in] cell The cell.
# @return The directions to the upstream cells. If streams raster is
# given, only directions to stream cells are returned. The directions
# are coded as usual: 1 is up, 2 is up right, etc.
sub upstream { 
    my $fdg = shift;
    my $streams;
    my @cell;
    if (@_ > 2) {
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

## @method Geo::Raster raise_pits(%params)
#
# @brief Raise each pit cell to the level of its lowest neighbor in a
# DEM.
#
# @param[in] params Named parameters: 
# - <I>z_limit</I>=>number (optional) A threshold value for how much
# lower that its neighbors a cell may be before it is raised. Default
# is 0.
# - <I>quiet</I>=>boolean (optional) Whether the method should report
# the number of cells raised.
# @return In void context the method changes this DEM, otherwise the
# method returns a new DEM.
sub raise_pits {
    my($dem, %opt) = @_;
    $opt{z_limit} = 0 unless defined($opt{z_limit});
    $dem = Geo::Raster->new($dem) if defined wantarray;
    my $n = ral_dem_raise_pits($dem->{GRID}, $opt{z_limit});
    print STDERR "raise_pits: $n pit cells raised\n" unless $opt{quiet};
    return $dem if defined wantarray;
}

## @method lower_peaks(%params)
# 
# @brief Lower each peak cell to the level of its highest neighbor in
# a DEM.
#
# @param[in] opt Named parameters:
# - <I>z_limit</I>=>number (optional) A threshold value for how much
# higher than its neighbors a cell may be before it is
# lowered. Default is 0.
# - <I>quiet</I>=>boolean (optional) Whether the method should report
# the number of cells raised.
# @return In void context the method changes this DEM, otherwise
# the method returns a new DEM.
sub lower_peaks {
    my($dem, %opt) = @_;
    $opt{z_limit} = 0 unless defined($opt{z_limit});
    $dem = Geo::Raster->new($dem) if defined wantarray;
    my $n = ral_dem_lower_peaks($dem->{GRID}, $opt{z_limit});
    print STDERR "lower_peaks: $n peak cells lowered\n" unless $opt{quiet};
    return $dem if defined wantarray;
}

## @method Geo::Raster depressions($inc_m)
#
# @brief Return depressions defined by a FDG.
#
# @param[in] inc_m (optional) A boolean value indicating whether each
# depression is marked with a unique integer. Default is false.
# @return Depressions raster.
sub depressions {
    my($fdg, $inc_m) = @_;
    $inc_m = 0 unless defined($inc_m) and $inc_m;
    return Geo::Raster->new(ral_fdg_depressions($fdg->{GRID}, $inc_m));
}

## @method scalar fill_depressions(%params)
# 
# @brief Fill the depressions in a DEM.
#
# The depressions in the DEM are filled up to the lowest cell just
# outside the depression. The depressions are obtained from a FDG.
# @param[in] params Named parameters:
# - <i>iterative</i>=>boolean (optional) Whether to run the depression
# filling algorithm iteratively until a pitless and flatless FDG is
# obtained from the DEM using the D8 method. In an iteration step a
# FDG is first computed from the DEM using the D8 method. Then the
# flat areas are removed from the FDG using first the multiple pour
# point method and then the one pour point method. The depression
# removing algorithm is then run once (one scan of the whole raster)
# on the DEM using this FDG. If the flatless FDG that is computed from
# this changed DEM is also pitless, then the iteration stops. If
# iterative is true, the DEM is changed and a pitless and flatless FDG
# is returned. Default is true.
# - <i>FDG</i>=>raster (optional unless iterative is false) The FDG
# for the depression filling algorithm. If FDG is given, the
# depression filling algorithm is run only once, i.e., one scan of the
# FDG is performed. Default is undefined.
# - <i>quiet</i>=>boolean (optional) Whether to report the progressing
# of the iteration.
# @exception - FDG is not given but iterative is false.
# @exception - There is no progress in the iteration.
# @return a DEM from which some depressions are removed (if the
# context is non-void and iterative is false), the number of filled
# depressions (if FDG is given), or a pitless and flatless FDG.
sub fill_depressions {
    my($dem, %opt) = @_;
    $opt{iterative} = 1 unless exists $opt{iterative} and not $opt{iterative};
    $opt{fdg} = $opt{FDG} if exists $opt{FDG};
    if (not $opt{iterative}) {
	croak "fill_depressions: FDG needed if not iterative" unless $opt{fdg};
	$dem = Geo::Raster->new($dem) if defined wantarray;
	ral_dem_fill_depressions($dem->{GRID}, $opt{fdg}->{GRID});
	return $dem if defined wantarray;
	return;
    }
    if ($opt{fdg}) {
	return ral_dem_fill_depressions($dem->{GRID}, $opt{fdg}->{GRID});
    } else {
	my $step = 1;
	my $pits_last_time = -1;
	my $flats_last_time = -1;
	while (1) {
	    my $fdg = $dem->fdg(method=>'D8', quiet=>0);
	    $fdg->drain_flat_areas($dem, method=>'m', quiet=>0);
	    $fdg->drain_flat_areas($dem, method=>'o', quiet=>0);
	    my $c = $fdg->contents();
	    my $pits = $$c{0} || 0;
	    my $flats = $$c{-1} || 0;
	    print STDERR "fill_depressions: iteration step $step: $pits pits and $flats flat cells\n" unless $opt{quiet};
	    return $fdg if ($pits == 0 and $flats == 0);
	    croak "there is no progress" if ($pits_last_time == $pits and $flats_last_time == $flats);
	    my $n = ral_dem_fill_depressions($dem->{GRID}, $fdg->{GRID});
	    print STDERR "fill_depressions: iteration step $step: $n depressions filled\n" unless $opt{quiet};
	    $pits_last_time = $pits;
	    $flats_last_time = $flats;
	    $step++;
	}
    }
}

## @method scalar breach(%params)
#
# @brief Breach the depressions in a DEM.
#
# Breaching is a depression removal method, which lowers the elevation
# of cells, which form a dam. Breaching is tried at the lowest cell on
# the rim of the depression which has the steepest descent away from
# the depression (if there are more than one lowest cells) and the
# steepest descent into the depression (if there are more than one
# lowest cells with identical slope out)
#
# The breaching algorithm implemented here is close to but not the
# same as in Martz and Garbrecht (1998). The biggest difference is
# that the depression cells are not raised in this implementation.
#
# @param[in] params Named parameters:
# - <I>limit</I> (optional) Maximum amount of cells (width of the dam)
# to be breached. Default is to not limit the breaching ($limit == 0).
# - <i>iterative</i>=>boolean (optional) Whether to run the breach
# algorithm iteratively until a pitless and flatless FDG is obtained
# from the DEM using the D8 method or there is no progress in the
# iteration. In an iteration step a FDG is first computed from the DEM
# using the D8 method. Then the flat areas are removed from the FDG
# using first the multiple pour point method and then the one pour
# point method. The breaching algorithm is then run once (one scan of
# the whole raster) on the DEM using this FDG. If the flatless FDG
# that is computed from this changed DEM is also pitless or there is
# no progress in the iteration, then the iteration stops. If iterative
# is true, the DEM is changed and a FDG is returned. Default is true.
# - <i>FDG</i>=>raster (optional unless iterative is false) The FDG
# for the breaching algorithm. If FDG is given it must not contain
# flat areas. The algorithm is run only once, i.e., one scan of the
# FDG is performed. Default is undefined.  - <i>quiet</i>=>boolean
# (optional) Whether to report the progressing of the iteration.
# @return a DEM from which some depressions are removed (if the
# context is non-void and iterative is false), nothing (if FDG is
# given), or a pitless and flatless FDG.
# @exception - FDG is not given but iterative is false.
# @see Martz, L.W. and Garbrecht, J. 1998. The treatment of flat areas
# and depressions in automated drainage analysis of raster digital
# elevation models. Hydrol. Process. 12, 843-855
sub breach {
    my($dem, %opt) = @_;
    $opt{fdg} = $opt{FDG} if exists $opt{FDG};
    $opt{limit} = 0 unless defined($opt{limit});
    $opt{iterative} = 1 unless exists $opt{iterative} and not $opt{iterative};
    if (not $opt{iterative}) {
	croak "breach: FDG needed if not iterative" unless $opt{fdg};
	$dem = Geo::Raster->new($dem) if defined wantarray;
	ral_dem_breach($dem->{GRID}, $opt{fdg}->{GRID}, $opt{limit});
	return $dem if defined wantarray;
	return;
    }
    if ($opt{fdg}) {
	return ral_dem_breach($dem->{GRID}, $opt{fdg}->{GRID}, $opt{limit});
    } else {
	my $step = 1;
	my $pits_last_time = -1;
	my $flats_last_time = -1;
	while (1) {
	    my $fdg = $dem->fdg(method=>'D8', quiet=>0);
	    $fdg->drain_flat_areas($dem, method=>'m', quiet=>0);
	    $fdg->drain_flat_areas($dem, method=>'o', quiet=>0);
	    my $c = $fdg->contents();
	    my $pits = $$c{0} || 0;
	    my $flats = $$c{-1} || 0;
	    print STDERR "breach: iteration step $step: $pits pits and $flats flat cells\n" unless $opt{quiet};
	    return $fdg if ($pits == 0 and $flats == 0);
	    return $fdg if ($pits_last_time == $pits and $flats_last_time == $flats);
	    my $n = ral_dem_breach($dem->{GRID}, $fdg->{GRID}, $opt{limit});
	    print STDERR "breach: iteration step $step: $n depressions filled\n" unless $opt{quiet};
	    $pits_last_time = $pits;
	    $flats_last_time = $flats;
	    $step++;
	}
    }
}

## @method Geo::Raster path(@cell, Geo::Raster stop)
# 
# @brief Return the flow path from the given FDG cell onwards.
#
# The end of the path is where flow direction is not specified, where it goes 
# out of the raster, or where the stop raster has a positive value.
#
# @param[in] cell The origin of the path.
# @param[in] stop (optional) Raster denoting end cells for paths.
# @return raster, where the path cells have the value 1 and otherwise
# no data value. In void context changes the FDG.
sub path {
    my($fdg, $i, $j, $stop) = @_;
    my $g = ral_fdg_path($fdg->{GRID}, $i, $j, $stop ? $stop->{GRID} : undef);
    if (defined wantarray) {
	return Geo::Raster->new($g);
    } else {
	$fdg->_new_grid($g);
    }
}

## @method Geo::Raster path_length(Geo::Raster stop, Geo::Raster op)
#
# @brief Compute a path length raster from a FDG.
#
# The path is assumed to go from a center point of a cell to another
# center point. The length is not recorded if op is nodata. The length
# is calculated in the raster units. A path ends at the border of the
# FDG, at a FDG cell with undefined direction, or at a cell in the
# stop raster with positive value.
# @param[in] stop (optional) Raster denoting end cells for paths.
# @param[in] op (optional) Raster denoting cells which are included in
# the length computation.
# @return a flow path length raster. In void context changes the FDG.
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
# @brief Compute a cost-to-go raster from a FDG.
#
# This FDG method returns a raster, where the value of each cell is
# the weighted (with length) sum along the path from that cell to the
# end of the path. The path is assumed to go from a center point of a
# cell to another center point. The length is not recorded if op is
# nodata. The length is calculated in the raster units.
# @param[in] stop (optional) Raster denoting end cells for paths.
# @param[in] op Weights (cost) for the summing.
# @return a cost-to-go raster. In void context changes the FDG.
sub path_sum {
    my($fdg, $stop, $op) = @_;
    my $g = ral_fdg_path_sum($fdg->{GRID}, $stop ? $stop->{GRID} : undef, $op->{GRID});
    if (defined wantarray) {
	return new Geo::Raster $g;
    } else {
	$fdg->_new_grid($g);
    }
}

## @method Geo::Raster upslope_count(Geo::Raster mask, $include_self)
# 
# @brief Compute the count of the upslope cells in a FDG.
#
# @param[in] mask (optional) Can be used to mask out cells from the
# count. Nodata cells of the mask are not included in the count.
# @param[in] include_self (optional) Boolean value, which specifies
# whether the cell itself is included in its upslope area. Default is
# true.
# @return the upslope count raster. In void context changes the FDG.
# @note DO NOT call if the FDG contains loops.
# @note This is the method for computing an upslope area raster (UAG)
# from a flow direction raster (FDG).
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

## @method Geo::Raster upslope_sum(Geo::Raster a, $include_self)
# 
# @brief Compute the sum of the values of the upslope cells in a
# raster (FDG method).
# 
# @param[in] a The operand raster.
# @param[in] include_self (optional). Boolean value specifying whether
# the cell itself is included in its upslope area. Default is true.
# @return In void context changes this flow direction raster,
# otherwise returns a new FDG.
# @note DO NOT call if the FDG contains loops.
sub upslope_sum {
    my($fdg, $a, $b) = @_;
    croak "usage: \$fdg->upslope_sum(\$op); where \$op is a raster whose values are to be summed" unless $a and $a->{GRID}; 
    $b = 1 unless defined $b;
    my $g = ral_fdg_upslope_sum($fdg->{GRID}, $a->{GRID}, $b);
    if (defined wantarray) {
	return Geo::Raster->new($g);
    } else {
	$fdg->_new_grid($g);
    }
}

## @method Geo::Raster kill_extra_outlets(Geo::Raster lakes, Geo::Raster uag)
# 
# @brief Checks and possibly correct the sanity of the flow paths in a
# terrain with lakes (FDG method).
#
# The FDG is modified so that each lake has only one outlet. The lakes
# raster is typically a reclassified land cover raster.
# @param[in] lakes an integer raster of the lakes in the terrain (each
# lake may have its own non-zero id)
# @param[in] uag (optional) Upslope area raster. Computed using the
# upslope_count method unless given.
# @return In void context changes this flow direction raster,
# otherwise returns a new FDG.
sub kill_extra_outlets {
    my ($fdg, $lakes, $uag) = @_;
    $fdg = new Geo::Raster $fdg if defined wantarray;
    $uag = $fdg->upslope_count unless $uag;
    ral_fdg_kill_extra_outlets($fdg->{GRID}, $lakes->{GRID}, $uag->{GRID});
    return $fdg if defined wantarray;
}

## @method Geo::Raster catchment(Geo::Raster catchment, @cell, $m)
#
# @brief Return the catchment area of the given cell (FDG method).
#
# @param[in,out] catchment (optional) The raster in which to return
# the catchment of the given cell.
# @param[in] cell The cell.
# @param[in] m (optional). Number used to mark the cells belonging to
# the catchment. Default is 1.
# @return Depending on the context returns the catchment raster or a
# list containing the catchment raster and the number of cells in the
# catchment.
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

## @method Geo::Raster prune(Geo::Raster fdg, Geo::Raster lakes, $min_length, @cell)
# 
# @brief Delete streams that are shorter than min_length in a streams raster.
#
# Example of removing streams shorter than min_lenght:
# @code
# $streams->prune($fdg, $lakes, $min_lenght, @cell);
# @endcode
# @param[in] fdg Flow direction raster.
# @param[in] lakes (optional) Lakes raster.
# @param[in] min_length (optional) Minimum length (in raster scale!)
# of streams to be not deleted. Default is 1.5*cell_size.
# @param[in] cell (optional) The root cell (a catchment outlet) from
# which the method begins to remove too short streams. If not given
# then all streams are pruned.
# @return In void context changes this streams raster, otherwise
# returns a new streams raster.
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
    $streams = Geo::Raster->new($streams) if defined wantarray;
    $i = -1 unless defined $i;
    if ($lakes) {
	ral_streams_prune($streams->{GRID}, $fdg->{GRID}, $lakes->{GRID}, $i, $j, $min_length);
    } else {
	ral_streams_prune_without_lakes($streams->{GRID}, $fdg->{GRID}, $i, $j, $min_length);
    }
    return $streams if defined wantarray;
}

## @method Geo::Raster number_streams(Geo::Raster fdg, Geo::Raster lakes, @cell, $id)
#
# @brief Number streams in a streams raster with unique id.
#
# @param[in] fdg Flow direction raster.
# @param[in] lakes (optional) Lakes raster.
# @param[in] cell (optional) The root cell (a catchment outlet) from
# which the method begins to treat the streams. If not given
# then all stream trees are treated.
# @param[in] id (optional) Number for the first found stream, the next
# streams will get higher unique numbers. Default is 1.
# @return In void context changes this streams raster, otherwise
# returns a new streams raster.
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
    $streams = Geo::Raster->new($streams) if defined wantarray;
    $i = -1 unless defined $i;
    ral_streams_number($streams->{GRID}, $fdg->{GRID}, $i, $j, $sid);
    if ($lakes) {
	$sid = $streams->max() + 1;
	ral_streams_break($streams->{GRID}, $fdg->{GRID}, $lakes->{GRID}, $sid);
    }
    return $streams if defined wantarray;
}

## @method Geo::Raster subcatchments(Geo::Raster fdg, Geo::Raster lakes, @cell, $head)
#
# @brief Divide catchments into subcatchments defined by a streams
# raster.
#
# Example of usage:
# @code
# $subcatchments = $streams->subcatchments($fdg, @cell);
# @endcode
# or 
# @code
# ($subcatchments, $topo) = $streams->subcatchments($fdg, $lakes, @cell);
# @endcode
#
# @param[in] fdg The FDG from which the streams raster has been computed.
# @param[in] lakes (optional) Lakes raster.
# @param[in] cell (optional) The outlet cell of the catchment.
# @param[in] head (optional) Boolean value denoting whether the
# algorithm should divide the catchment of a headstream to the
# catchment of the first cell of the headstream and the catchment
# draining to the rest of the headstream. Default is false.
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
	# head -> stream (if exist)<
	# sub -> lake or stream
	# lake -> stream
	# stream -> lake or stream

	my %ds;

	for my $key (keys %{$r}) {
	    ($i, $j) = split (/,/, $key);
	    my($i_down, $j_down) = split (/,/, $r->{$key});
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

## @method save_catchment_structure(hashref topology, Geo::Raster streams, Geo::Raster lakes, $datasource, $layer)
#
# @brief Save the subcatchment structure as a vector layer (a subcatchments raster method).
#
# @param[in] topology Reference to an hash having as keys = type id i j, and as 
# values = type id.
# @param[in] streams Streams raster.
# @param[in] lakes (optional) Lakes raster.
# @param[in] datasource OGR datasource string, e.g., a directory.
# @param[in] layer Name for the new layer.
sub save_catchment_structure {
    my ($self, $topology, $streams, $lakes, $datasource_string, $layer) = @_;

    my $cell_size = $self->cell_size();

    my ($minX, $minY, $maxX, $maxY) = $self->world();

    my $datasource = Geo::OGR::Open($datasource_string, 1) or 
	croak "can't open '$datasource' as an OGR datasource";

    my $osr;
    #$osr = new osr::SpatialReference;
    #$osr->SetWellKnownGeogCS('WGS84');

    my $catchment = $datasource->CreateLayer($layer, $osr, $Geo::OGR::wkbPolygon);
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

    $layer = $self*1;
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

## @method route(Geo::Raster dem, Geo::Raster fdg, Geo::Raster flow, Geo::Raster k, Geo::Raster d, $f, $r)
#
# @brief Route water downstream (a water state raster method).
#
# The water in each cell of the self raster is routed downstream. A
# recursive routing method is applied, which first routes water from
# upslope cells.
#
# Example of routing water out from a catchment:
# @code
# $water_grid->route($dem, $fdg, $flow, $k, $d, $f, $r);
# @endcode
#
# @param[in] dem The DEM.
# @param[in] fdg The flow directions raster.
# @param[out] flow The amount of water routed forward (leaving each
# cell).
# @param[in] k Values to be added to the slope.
# @param[in] d Values to be used for multiplying the effect of slopes (current?).
# @param[in] f (optional). If true then water is routed from each cell to all of 
# its neighbors having the same or lower elevation, else if false only to a 
# single cell pointed by FDG. Default value is 1 (true).
# @param[in] r (optional). Unit of z dived by the unit of x and y. By default is 1.
# @todo IN DEVELOPMENT DO NOT USE
sub route {
    my($water, $dem, $fdg, $flow, $k, $d, $f, $r) = @_;
    $f = 1 unless defined $f;
    $r = 1 unless defined $r;
    croak ("usage: $water->route($dem, $fdg, $flow, $k, $d, $f, $r)") unless $flow;
    return water_route($water->{GRID}, $dem->{GRID}, $fdg->{GRID}, $flow->{GRID}, $k->{GRID}, $d->{GRID}, $f, $r);
}

## @method void vectorize_streams(Geo::Raster fdg, @cell)
#
# @brief Create an OGR layer from a streams raster.
#
# @param fdg The FDG from which the streams raster has been computed.
# @param cell The outlet cell of the catchment.
# @todo IN DEVELOPMENT DO NOT USE
sub vectorize_streams {
    my ($self, $fdg, $i, $j, $datasource, $layer) = @_;
    ral_streams_vectorize($self->{GRID}, $fdg->{GRID}, $i, $j);
}

## @ignore
#
sub compare_dem_derived_ws_attribs {
    my ($self, $uag, $dem, $filename, $iname, $ielev, $idarea) = @_;
    #my ($self, $filename) = @_;
    (my $fileBaseName, my $dirName, my $fileExtension) = fileparse($filename,('\.shp'));
    #my $jep = $fileBaseName.$fileExtension;
    #print STDERR "$dirName and $jep\n";
    ral_compare_dem_derived_ws_attribs($self->{GRID}, $uag->{GRID}, $dem->{GRID}, $dirName, $fileBaseName, $iname, $ielev, $idarea);
}

1;
