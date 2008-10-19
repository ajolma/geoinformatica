## @class Geo::Raster::Zonal
# @brief Adds zonal operations into Geo::Raster
package Geo::Raster;

use Statistics::Descriptive;

## @method hashref zones(Geo::Raster zones)
#
# @brief Return a hash defining the rasters values for each zone.
#
# @param[in] zones An integer raster, which defines the zones. All 
# different integers point to a different zone.
# @return A reference to a hash, which has the values of the zones
# raster as keys and respective values from this raster as values. The
# values are in anonymous arrays.
# @exception The zones raster is not of type integer.
sub zones {
    my($self, $zones) = @_;
    return ral_grid_zones($self->{GRID}, $zones->{GRID});
}

## @method $size(@cell)
#
# @brief Returns the number of cells in a zone.
#
# @param[in] cell Zone cell. Identifies the zone.
# @return The number of cells in the zone.

## @method hashref zonal_fct(Geo::Raster zones, $fct)
#
# @brief Calculates the mean of this rasters values for each zone.
# @param[in] zones An integer raster, which defines the zones. All 
# different integers point to a different zone.
# @param fct (string) a method supported by Statistics::Descrptive ('mean' by default)
# @return Returns a reference to an hash having as keys the zones and as 
# values the means of this rasters cells belonging to the zones.
# @exception The zones grid is not overlayable with the raster.
# @exception The zones grid is not of type integer.
sub zonal_fct {
    my($self, $zones, $fct) = @_;
    my $z = ral_grid_zones($self->{GRID}, $zones->{GRID});
    $fct = 'mean' unless $fct;
    my %m;
    for (keys %{$z}) {
    	# http://search.cpan.org/~colink/Statistics-Descriptive-2.6/Descriptive.pm
	my $stat = Statistics::Descriptive::Full->new();
	$stat->add_data(@{$z->{$_}});
	$m{$_} = eval "\$stat->$fct();";
    }
    return \%m;
}

## @method hashref zonal_count(Geo::Raster zones)
#
# @brief Calculates the amount of this rasters cells for each zone.
#
# Example of getting count of cells having values for each zone:
# @code
# $zonalcount = $grid->zonal_count($zones);
# @endcode
#
# @param[in] zones An integer raster, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the amount of this rasters cells having some value and belonging 
# to zone.
# @exception The zones grid is not overlayable with the raster.
# @exception The zones grid is not of type integer.
sub zonal_count {
    my($self, $zones) = @_;
    return ral_grid_zonal_count($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_sum(Geo::Raster zones)
#
# @brief Calculates the sum of this rasters cells for each zone.
#
# Example of getting sum of values for each zone:
# @code
# $zonalsum = $grid->zonal_sum($zones);
# @endcode
#
# @param[in] zones An integer raster, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the sum of this rasters cells belonging to the zone.
# @exception The zones grid is not overlayable with the raster.
# @exception The zones grid is not of type integer.
sub zonal_sum {
    my($self, $zones) = @_;
    return ral_grid_zonal_sum($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_min(Geo::Raster zones)
#
# @brief Calculates the minimum of this rasters cells for each zone.
#
# Example of getting smallest value for each zone:
# @code
# $zonalmin = $grid->zonal_min($zones);
# @endcode
#
# @param[in] zones An integer raster, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the minimum of this rasters cells belonging to the zone.
# @exception The zones grid is not overlayable with the raster.
# @exception The zones grid is not of type integer.
sub zonal_min {
    my($self, $zones) = @_;
    return ral_grid_zonal_min($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_max(Geo::Raster zones)
#
# @brief Calculates the maximum of this rasters cells for each zone.
#
# Example of getting highest value for each zone:
# @code
# $zonalmax = $grid->zonal_max($zones);
# @endcode
#
# @param[in] zones An integer raster, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the maximum of this rasters cells belonging to the zone.
# @exception The zones grid is not overlayable with the raster.
# @exception The zones grid is not of type integer.
sub zonal_max {
    my($self, $zones) = @_;
    return ral_grid_zonal_max($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_mean(Geo::Raster zones)
#
# @brief Calculates the mean of this rasters cells for each zone.
#
# Example of getting mean of all values for each zone:
# @code
# $zonalmean = $grid->zonal_mean($zones);
# @endcode
#
# @param[in] zones An integer raster, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the mean of this rasters cells belonging to the zone.
# @exception The zones grid is not overlayable with the raster.
# @exception The zones grid is not of type integer.
sub zonal_mean {
    my($self, $zones) = @_;
    return ral_grid_zonal_mean($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_variance(Geo::Raster zones)
#
# @brief Calculates the variance of this rasters cells for each zone.
#
# Example of getting variance of all values for each zone:
# @code
# $zonalvar = $grid->zonal_variance($zones);
# @endcode
#
# @param[in] zones An integer raster, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the variance of this rasters cells belonging to the zone.
# @exception The zones grid is not overlayable with the raster.
# @exception The zones grid is not of type integer.
sub zonal_variance {
    my($self, $zones) = @_;
    return ral_grid_zonal_variance($self->{GRID}, $zones->{GRID});
}

## @method Geo::Raster grow_zones(Geo::Raster grow, $connectivity)
#
# @brief Grows this zones grid recursively using the given growing grid and
# 4- or 8-connectivity.
#
# The calling grid has to be an integer grid, which defines the zones. All 
# different integers point to a different zone.
#
# Example of growing the zones defining raster:
# @code
# $zones->growzones($grow);
# @endcode
# Example of creating a new zones defining raster, which has a :
# @code
# $new_zones = $zones->growzones($grow);
# @endcode
#
# @param[in] grow A binary grid defining to where the zones raster
# can grow. Has to have the same size as this grid. 
# @param[in] connectivity (optional). Connectivity between cells as a number:4 
# or 8. If connectivity is not given then 8-connectivity is used.
# @return Returns a new zones grid, if a return value is wanted, else the 
# growing will be done to this zones grid.
# @exception The zones grid is not overlayable with the grid used for growing.
# @exception The zones grid or the grid used for growing is not of type integer.
sub grow_zones {
    my($zones, $grow, $connectivity) = @_;
    $connectivity = 8 unless defined($connectivity);
    $zones = new Geo::Raster $zones if defined wantarray;
    ral_grid_grow_zones($zones->{GRID}, $grow->{GRID}, $connectivity);
    return $zones if defined wantarray;
}

1;
