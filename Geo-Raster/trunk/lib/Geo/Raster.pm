package Geo::Raster;

## @class Geo::Raster
# @brief A class for geospatial rasters.
#
# Import tags:
# - \a types Imports scalars $INTEGER_GRID and $REAL_GRID
# - \a logics Imports (overrides) \c not, \c and, and \c or
#
# This module should be discussed in geo-perl@list.hut.fi.
#
# The homepage of this module is 
# http://geoinformatics.tkk.fi/twiki/bin/view/Main/GeoinformaticaSoftware.
#
# @author Ari Jolma
# @author Copyright (c) 1999- by Ari Jolma
# @author This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.5 or,
# at your option, any later version of Perl 5 you may have available.

=pod

=head1 NAME

Geo::Raster - Perl extension for geospatial rasters

The <a href="http://map.hut.fi/doc/Geoinformatica/html/">
documentation of Geo::Raster</a> is written in doxygen format.

=cut

use strict;
use warnings;
use POSIX;
POSIX::setlocale( &POSIX::LC_NUMERIC, "C" ); # http://www.gdal.org/faq.html nr. 12
use Carp;
use FileHandle;
use Config; # For byteorder
use UNIVERSAL qw(isa);
use XSLoader;
use File::Basename;
use Geo::GDAL;
use Gtk2;

# subsystems:
use Geo::Raster::Operations;
use Geo::Raster::Focal;
use Geo::Raster::Zonal;
use Geo::Raster::Global;
use Geo::Raster::IO;
use Geo::Raster::Image;
use Geo::Raster::Algorithms;
use Geo::Raster::TerrainAnalysis;
use Geo::Raster::Geostatistics;
use Geo::Raster::Layer;

use vars qw($BYTE_ORDER $INTEGER_GRID $REAL_GRID);

our $VERSION = '0.62';

# TODO: make these constants derived from libral:
$INTEGER_GRID = 1;
$REAL_GRID = 2;

require Exporter;

our @ISA = qw( Exporter );

our %EXPORT_TAGS = (types  => [ qw ( $INTEGER_GRID $REAL_GRID ) ],
		    logics => [ qw ( &not &and &or ) ] );

our @EXPORT_OK = qw ( $INTEGER_GRID $REAL_GRID
		      &not &and &or );

## @ignore
sub dl_load_flags {0x01}

XSLoader::load( 'Geo::Raster', $VERSION );

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.
# not having "" linked makes print "$raster" to print "1"

## @ignore
sub _new_grid {
    my $self = shift;
    my $grid = shift;
    return unless $grid;
    ral_grid_destroy($self->{GRID}) if $self->{GRID};
    $self->{GRID} = $grid;
    attributes($self);
}

## @ignore
sub _interpret_datatype {
    return $INTEGER_GRID if $_[0] =~  m/^i/i;
    return $REAL_GRID if $_[0] =~ m/^real/i;
    return $REAL_GRID if $_[0] =~ m/^float/i;
    return $INTEGER_GRID if $_[0] == $INTEGER_GRID;
    return $REAL_GRID if $_[0] == $REAL_GRID;
    return $INTEGER_GRID;
}

## @cmethod Geo::Raster new($file_name)
#
# @brief Create a new raster from a file.
#
# Example of loading a previously saved raster
# @code
# $raster = new Geo::Raster->new("data/dem");
# @endcode
# @param[in] file_name Name of file, from where the raster is loaded. 
# @return New raster.

## @cmethod Geo::Raster new(Geo::Raster param)
#
# @brief Create a new raster as a copy of an existing raster.
#
# Example of acting as an copy constructor:
# @code
# $copy = new Geo::Raster($raster);
# @endcode
#
# @param[in] param A reference to an another Geo::Raster object, which is copied.
# @return a new raster

## @cmethod Geo::Raster new($datatype, $rows, $columns)
#
# @brief Create a new raster.
#
# Example of creating a new raster with real type:
# @code
# $raster = new Geo::Raster('real', 100, 100);
# @endcode
# Example of creating a new raster with integer type:
# @code
# $raster = new Geo::Raster(100, 100);
# @endcode
#
# @param[in] datatype (optional) The datatype for the new raster,
# either "integer" or "real".  Default is integer.
# @param[in] rows Height of the new raster.
# @param[in] columns Width of the new raster.
# @return a new raster

## @cmethod Geo::Raster new(%params)
#
# @brief The constructor can be used to load a previously saved raster, 
# create a new or to act as an copy constructor.
#
# Example of starting with a new fresh raster:
# @code
# $raster = new Geo::Raster(datatype=>datatype_string, rows=>100, columns=>100);
# @endcode
#
# Example of opening a previously saved grid:
# @code
# $raster = new Geo::Raster(filename=>"data/dem", load=>1);
# @endcode
#
# Example of using the copy constructor:
# @code
# $copy = new Geo::Raster(copy=>$raster);
# @endcode
#
# Example of creating a raster with same size:
# @code
# $new = new Geo::Raster(like=>$old);
# @endcode
#
# @param[in] params Named parameters:
# - <I>datatype</I> The data type for the new raster. Either "real" or
# - "integer". Default is integer.
# - <I>copy</I> A raster to be copied into the new raster.
# - <I>like</I> A raster to be used as a model for the new raster.
# - <I>filename</I> A raster file. GDAL is used for opening the file.
# - <I>band</I> integer (optional) Which band to read from the file. Default is 1.
# - <I>load</I> boolean (optional) Whether to convert the GDAL raster
# into a libral raster. Default is false.
# - <I>rows</I> Height of the new raster.
# - <I>columns</I> Width of the new raster.
# - <I>world</I> Named parameters suitable to define the real world boundaries. 
# Used only if <I>M</I> and <I>N</I> are also given. Possible parameters 
# include:
#   - cell_size
#   - minx
#   - miny
#   - maxx
#   - maxy
# @return New instance of Geo::Raster.
sub new {
    my $package = shift;
    my %params;

    if (@_ == 0 and isa($package, 'Geo::Raster')) { # Geo::Raster::new($geo_raster_object)

	$params{copy} = $package;

    } elsif (@_ == 1 and ref($_[0]) eq 'ral_gridPtr') {
	
	$params{use} = shift;
	
    } elsif (@_ == 1 and isa($_[0], 'Geo::Raster')) {
	
	$params{copy} = shift;
	
    } elsif (@_ == 1) {
	
	$params{filename} = shift;
	
    } elsif (@_ == 2 and ($_[0] =~ /\d+/) and ($_[1] =~ /\d+/)) {
	
	$params{M} = shift;
	$params{N} = shift;
	$params{datatype} = $INTEGER_GRID;
	
    } elsif (@_ == 3) {
	
	$params{datatype} = shift;
	$params{M} = shift;
	$params{N} = shift;

    }

    if (@_) {
	my %p = @_;
	for (keys %p) {
	    $params{$_} = $p{$_} unless exists $params{$_};
	}
	$params{M} = $params{rows} if exists $params{rows};
	$params{N} = $params{columns} if exists $params{columns};
    }

    my $self = {};
    bless $self => (ref($package) or $package);

    $self->{TABLE} = [];
    
    $params{datatype} = $params{datatype} ? _interpret_datatype($params{datatype}) : 0;
    
    if ($params{copy} and isa($params{copy}, 'Geo::Raster')) {
	croak "Can't copy an empty raster." unless $params{copy}->{GRID};
	$self->{GRID} = ral_grid_create_copy($params{copy}->{GRID}, $params{datatype})
    } elsif ($params{use} and ref($params{use}) eq 'ral_gridPtr') {
	$self->{GRID} = $params{use};
    } elsif ($params{like}) {
	$self->{GRID} = ral_grid_create_like($params{like}->{GRID}, $params{datatype});
    } elsif ($params{filename}) {
	gdal_open($self, %params);
	$self->{FILENAME} = $params{filename};
    } elsif ($params{M} and $params{N}) {
	$params{datatype} = $INTEGER_GRID unless $params{datatype};
	$self->{GRID} = ral_grid_create($params{datatype}, $params{M}, $params{N});
	if ($params{world}) {
	    ref $params{world} eq 'HASH' ? 
		$self->world( %{$params{world}} ) :
		$self->world( minx=>$params{world}->[0], 
			      miny=>$params{world}->[1],
			      maxx=>$params{world}->[2] );
	}
    }
    $self->attributes() if $self->{GRID};
    return $self;
}

## @ignore
sub shallow_copy {
    my $self = shift;
    return $self;
}

## @ignore
sub DESTROY {
    my $self = shift;
    return unless $self;
    ral_grid_destroy($self->{GRID}) if $self->{GRID};
    delete($self->{GRID});
}

## @ignore
sub _with_decimal_point {
    my $tmp = shift;
    $tmp =~ s/,/./;
    return $tmp;
}

## @method @world(%params)
# 
# @brief Get or set the world (bounding box and cell size) of the raster dataset.
# @param[in] params is a hash of named parameters:
# - <I>min_x</I> The smallest x value of the datasets bounding box.
# - <I>min_y</I> The smallest y value of the datasets bounding box.
# - <I>max_x</I> The highest x value of the datasets bounding box.
# - <I>max_y</I> The highest y value of the datasets bounding box.
# - <I>cell_size</I> Lenght of cells one edge.
# @return List of raster datasets attributes (datatype, M, N, cell size, 
# bounding box (world), symbol for no data).
# @note At least three parameters must be set to define the world.
sub world {
    my $self = shift;
    if (@_) {

	my($cell_size,$minx,$miny,$maxx,$maxy);
	my %o = @_;
	for (keys %o) {
	    my $k = $_;
	    s/_//g;
	    $cell_size = $o{$k} if /cellsize/i;
	    $minx = $o{$k} if /minx/i;
	    $miny = $o{$k} if /miny/i;
	    $maxx = $o{$k} if /maxx/i;
	    $maxy = $o{$k} if /maxy/i;
	}
	
	if ($cell_size and defined($minx) and defined($miny)) {
	    ral_grid_set_bounds_csnn($self->{GRID}, $cell_size, $minx, $miny);
	} elsif ($cell_size and defined($minx) and defined($maxy)) {
	    ral_grid_set_bounds_csnx($self->{GRID}, $cell_size, $minx, $maxy);
	} elsif ($cell_size and defined($maxx) and defined($miny)) {
	    ral_grid_set_bounds_csxn($self->{GRID}, $cell_size, $maxx, $miny);
	} elsif ($cell_size and defined($maxx) and defined($maxy)) {
	    ral_grid_set_bounds_csxx($self->{GRID}, $cell_size, $maxx, $maxy);
	} elsif (defined($minx) and defined($maxx) and defined($miny)) {
	    ral_grid_set_bounds_nxn($self->{GRID}, $minx, $maxx, $miny);
	} elsif (defined($minx) and defined($maxx) and defined($maxy)) {
	    ral_grid_set_bounds_nxx($self->{GRID}, $minx, $maxx, $maxy);
	} elsif (defined($minx) and defined($miny) and defined($maxy)) {
	    ral_grid_set_bounds_nnx($self->{GRID}, $minx, $miny, $maxy);
	} elsif (defined($maxx) and defined($miny) and defined($maxy)) {
	    ral_grid_set_bounds_xnx($self->{GRID}, $maxx, $miny, $maxy);
	} elsif ($self->{GDAL} and defined($o{of_GDAL})) {
	    my $w = $self->{GDAL}->{world};
	    return @$w;
	} elsif (!$self->{GRID}) {
	    return ();
	} else {
	    my $w = ral_grid_get_world($self->{GRID});
	    return @$w;
	}
    } elsif (!$self->{GRID}) {
	    return ();
    } else {
	my $w = ral_grid_get_world($self->{GRID});
	return @$w;
    }
    $self->attributes;
}

## @method copy_world_to(Geo::Raster to)
#
# @brief The method copies the objects raster bounding box to the given 
# raster.
# @param[out] to A raster to which the world is copied to.
sub copy_world_to {
    my($self, $to) = @_;
    ral_grid_copy_bounds($self->{GRID}, $to->{GRID});
}

## @method boolean cell_in(@cell)
#
# @brief Tells if the raster has a cell with given coordinates.
# @param[in] cell The i- and j-coordinates to test against the raster set.
# @return True if the raster has a cell with given coordinates, else false.
sub cell_in {
    my($self, @cell) = @_;
    return ($cell[0] >= 0 and $cell[0] < $self->{M} and 
	    $cell[1] >= 0 and $cell[1] < $self->{N})
}

## @method boolean point_in(@point)
#
# @brief Tells if the given point (x, y) is inside the world boundaries.
# @param[in] point The points x- and y-coordinates.
# @return True if the point is within the world boundaries, else false.
sub point_in {
    my($self, @point) = @_;
    return ($point[0] >= $self->{WORLD}->[0] and 
	    $point[0] <= $self->{WORLD}->[2] and 
	    $point[1] >= $self->{WORLD}->[1] and 
	    $point[1] <= $self->{WORLD}->[3])
}

## @method @g2w(@cell)
#
# @brief The method converts the given grid cell to the cells 
# center points world coordinates (x, y). 
# @param[in] cell The raster cell (i, j).
# @return The center point of the cell in world coordinates (x,y).
sub g2w {
    my($self, @cell) = @_;
    if ($self->{GDAL}) {
	my $gdal = $self->{GDAL};
	my $x = $gdal->{world}->[0] + ($cell[1]+0.5)*$gdal->{cell_size};
	my $y = $gdal->{world}->[3] - ($cell[0]+0.5)*$gdal->{cell_size};
	return ($x,$y);
    }
    my $point = ral_grid_cell2point( $self->{GRID}, @cell);
    return @$point;
}

## @method @w2g(@point)
#
# @brief The method converts the world coordinates (x, y) into
# grid coordinates (i, j).
# @param[in] point The x- and y-coordinates of a point in world coordinate system.
# @return The cell (i, j), which contains the point.
sub w2g {
    my($self, @point) = @_;
    if ($self->{GDAL}) {
	my $gdal = $self->{GDAL};
	$point[0] -= $gdal->{world}->[0];
	$point[0] /= $gdal->{cell_size};
	$point[1] = $gdal->{world}->[3] - $point[1];
	$point[1] /= $gdal->{cell_size};
	return (POSIX::floor($point[1]),POSIX::floor($point[0]));
    }
    my $cell = ral_grid_point2cell($self->{GRID}, @point);
    return @$cell;
}

## @method @ga2wa(@ga)
#
# @brief The subroutine converts the boundary of an grid area into a rectangle 
# defined by world coordinates.
# @param[in] ga The boundary coordinates of an raster as an array (i_min, 
# i_max, j_min, j_max).
# @return The rectangles upper left and lower right corners (center points of 
# the corner grid cells) in world coordinates (x, y).
sub ga2wa {
    my($self, @ga) = @_;
    if ($self->{GDAL}) {
	my @min = $self->g2w($ga[0],$ga[3]);
	my @max = $self->g2w($ga[2],$ga[1]);
	return (@min,@max);
    }
    my $min = ral_grid_cell2point($self->{GRID}, $ga[0], $ga[3]);
    my $max = ral_grid_cell2point($self->{GRID}, $ga[2], $ga[1]);
    return (@$min,@$max);
}

## @method @wa2ga(@wa)
#
# @brief The subroutine converts the boundary of an area defined by world 
# coordinates into the areas rectangle in grid coordinates (i, j).
# @param[in] wa The boundary coordinates of an raster as an array (x_min, 
# x_max, y_min, y_max).
# @return A rectangles upper left and lower right corners cells. Cells are given 
# in grid coordinates (i, j).
sub wa2ga {
    my($self, @wa) = @_;
    if ($self->{GDAL}) {
	my @ul = $self->w2g($wa[0],$wa[3]);
	my @lr = $self->w2g($wa[2],$wa[1]);
	return (@ul,@lr);
    }
    my $ul = ral_grid_point2cell($self->{GRID}, $wa[0], $wa[3]);
    my $lr = ral_grid_point2cell($self->{GRID}, $wa[2], $wa[1]);
    return (@$ul,@$lr);
}

## @method mask(Geo::Raster mask)
#
# @brief Set or remove the mask.
# @param[in] mask (optional). If mask is undef, the method removes the current 
# mask.
sub mask {
    my($self, $mask) = @_;
    isa($mask, 'Geo::Raster') ? 
	ral_grid_set_mask($self->{GRID}, $mask->{GRID}) : 
	ral_grid_clear_mask($self->{GRID});
}

## @method void set(@cell, $value)
#
# @brief Sets a value to a single grid cell or to all cells.
#
# If cell coordinates row and column are not given then the method
# sets the given value to all cells in the raster.
#
# Example of setting to single cell a new value:
# @code
# $grid->set($i, $j, $value);
# @endcode
# Example of setting all cell values to 2:
# @code
# $grid->set(2);
# @endcode
# Example of setting to single cell a <I>nodata</I> value:
# @code
# $grid->set($i, $j);
# @endcode
# Example of setting to all cells a <I>nodata</I> value:
# @code
# $grid->set();
# @endcode
#
# @param[in] cell (optional) the cell coordinates
# @param[in] value (optional) The value to set, which can be a number, 
# "nodata" or a reference to Geo::Raster. Default is "nodata".
sub set {
    my($self, $i, $j, $value) = @_;
    croak "set: GRID is undefined" unless $self->{GRID};
    if (defined($j)) {
	if (!defined($value) or $value eq 'nodata') {
	    return ral_grid_set_nodata($self->{GRID}, $i, $j);
	}
	if (ref $value) {
	    ral_grid_set_focal($self->{GRID}, $i, $j, $value);
	} else {
	    return ral_grid_set($self->{GRID}, $i, $j, $value);
	}
    } else {
	if (ref($i)) {
	    if (isa($i, 'Geo::Raster') and $i->{GRID}) {
		return ral_grid_copy($self->{GRID}, $i->{GRID});
	    } else {
		croak "can't copy a ",ref($i)," onto a grid\n";
	    }
	}
	if (!defined($i) or $i eq 'nodata') {
	    return ral_grid_set_all_nodata($self->{GRID});
	}
	ral_grid_set_all($self->{GRID}, $i);
    }
}

## @method $get(@cell)
# 
# @brief Retrieve the value of a cell.
#
# If the cell has a nodata or out-of-world value undef is returned.
# @param[in] cell The cell coordinates
# @return Value of the cell.
sub get {
    my($self, $i, $j, $distance) = @_;
    return unless $self->{GRID};
    if ($self->{GDAL}) {
	my @point = $self->g2w($i, $j);
	my $cell = ral_grid_point2cell($self->{GRID}, @point);
	($i, $j) = @$cell;
    }
    unless (defined $distance) {
	return ral_grid_get($self->{GRID}, $i, $j);
    } else {
	return ral_grid_get_focal($self->{GRID}, $i, $j, $distance);
    }
}

## @method $cell(@cell, $value)
#
# @brief Set or get the value of a cell.
# @param[in] cell The cell coordinates
# @param[in] value (optional) The value to set. If no value if given then the 
# method returns the cells current value.
# @return The cells current value. Only returned if no value is given to the 
# method.
sub cell {
    my($self, $i, $j, $value) = @_;
    if ($self->{GDAL}) {
	my @point = $self->g2w($i, $j);
	if ($self->{GRID}) {
	    my $cell = ral_grid_point2cell($self->{GRID}, @point);
	    ($i, $j) = @$cell;
	}
    }
    if (defined $value) {
	croak "cell: GRID is undefined" unless $self->{GRID};
	if (!defined($value) or $value eq 'nodata') {
	    ral_grid_set_nodata($self->{GRID}, $i, $j);
	}
	ral_grid_set($self->{GRID}, $i, $j, $value);
    } else {
	return unless $self->{GRID};
	ral_grid_get($self->{GRID}, $i, $j);
    }
}

## @method $point($x, $y, $value)
#
# @brief Set or get the value of a cell, which contains the point.
# @param[in] x The x-coordinate inside the world.
# @param[in] y The y-coordinate inside the world.
# @param[in] value (optional) The value to set. If no value if given then the method 
# returns the cells current value.
# @return The cells current value in which the point is located. Only returned 
# if no value is given to the method.
sub point {
    my($self, $x, $y, $value) = @_;
   
    if (defined $value) {

	croak "point: GRID is undefined" unless $self->{GRID};

	my $cell = ral_grid_point2cell($self->{GRID}, $x, $y);

	if (!defined($value) or $value eq 'nodata') {
	    ral_grid_set_nodata($self->{GRID}, $cell->[0], $cell->[1]);
	}
	ral_grid_set($self->{GRID}, $cell->[0], $cell->[1], $value);

    } else {

	return unless $self->{GRID};

	my $cell = ral_grid_point2cell($self->{GRID}, $x, $y);
	ral_grid_get($self->{GRID}, $cell->[0], $cell->[1]);

    }
}

## @method Geo::Raster data()
# 
# @brief Turn the raster into a raster, which has 0 where there were
# nodata values exist and 1 where there was data.
#
# If an object is returned, then the methos does not change the current raster.
# @return Geo::Raster, which has zeros (0) in those cells as value that did not 
# have data and ones (1) in those cells that had data. 
# @note If the the grid already has only zeros and ones, and the <I>nodata</I> 
# value is defined as zeros then the method does nothing to the grid.
sub data {
    my $self = shift;
    $self = Geo::Raster::new($self) if defined wantarray;
    my $g = ral_grid_data($self->{GRID});
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray and $g;
}

## @method $schema(hashref schema)
#
# @brief Returns the objects schema (table names and numbers).
# @param[in] schema If the schema is given, then the method does nothing!
# @return The current schema of the object.
# @todo Support to give to the object a new schema.
# @todo link with RATs in GDAL
sub schema {
    my($self, $schema) = @_;
    if ($schema) {
    	
    } else {
	$schema = { 'Cell value' => { Number => -1, TypeName => $self->_type_name() } };
	if ($self->{TABLE_NAMES}) {
	    for my $i (0..$#{$self->{TABLE_NAMES}}) {
		$schema->{$self->{TABLE_NAMES}->[$i]}{Number} = $i;
		$schema->{$self->{TABLE_NAMES}->[$i]}{TypeName} = $self->{TABLE_TYPES}->[$i];
	    }
	}
	return $schema;
    }
}

## @method $has_field($field_name)
#
# @brief Indicates whether the raster attribute table (RAT) contain the given field.
# @param[in] field_name Name of the field whose existence is checked.
# @return True if the raster has a field having the same name as the given 
# parameter, else returns false.
# @todo link with RATs in GDAL
sub has_field {
    my($self, $field_name) = @_;
    return 1 if $field_name eq 'Cell value';
    return 0 unless $self->{TABLE_NAMES} and @{$self->{TABLE_NAMES}};
    for my $name (@{$self->{TABLE_NAMES}}) {	
		return 1 if $name eq $field_name;
    }
    return 0;
}

## @method @table($table)
#
# @brief Get or set the raster attribute table.
#
# An attribute table is a table, whose keys are cell values, thus defined only 
# for integer rasters.
#
# @param[in] table (optional). Either a reference to an array or a file name.
# @return If no parameter is given, the subroutine returns the current attribute 
# table.
# @todo link with RATs in GDAL
sub table {
    my($self, $table) = @_;
    if (ref $table) {
	$self->{TABLE_NAMES} = 0;
	$self->{TABLE_TYPES} = 0;
	$self->{TABLE} = [];
	for my $record (@$table) {
	    $self->{TABLE_NAMES} = [@$record],next unless $self->{TABLE_NAMES};
	    $self->{TABLE_TYPES} = [@$record],next unless $self->{TABLE_TYPES};
	    push @{$self->{TABLE}}, [@$record];
	}
    } elsif (defined $table) {
	my $fh = new FileHandle;
	croak "can't read from $table: $!\n" unless $fh->open("< $table");
	$self->{TABLE_NAMES} = 0;
	$self->{TABLE_TYPES} = 0;
	$self->{TABLE} = [];
	while (<$fh>) {
	    next if /^#/;
	    my @record = split /\t/;
	    $self->{TABLE_NAMES} = [@record],next unless $self->{TABLE_NAMES};
	    $self->{TABLE_TYPES} = [@record],next unless $self->{TABLE_TYPES};
	    push @{$self->{TABLE}},\@record;
	}
	$fh->close;
    } else {
	return $self->{TABLE};
    }
}

## @ignore
sub _type_name {
    my $self = shift;
    return undef unless $self->{DATATYPE}; # may happen if not cached
    return 'Integer' if $self->{DATATYPE} == $INTEGER_GRID;
    return 'Real' if $self->{DATATYPE} == $REAL_GRID;
    return undef;
}

## @method list value_range(%params)
#
# @brief Returns the minimum and maximum values of the raster.
# @param[in] params Named parameters:
# - <I>field_name</I> The attribute whose min and max values are looked up.
# - <I>of_GDAL</I> Boolean telling if the value range should be from GDAL.
# - <I>filter</I> No effect currently!
# - <I>filter_rect</I> No effect currently!
# @return array (min,max)
sub value_range {
    my $self = shift;
    my $field_name;
    my %param;
    if (@_ == 1) {
	$field_name = shift;
    } else {
	%param = @_;
	$field_name = $param{field_name};
    }
    if (defined $field_name and $field_name ne 'Cell value') {
	my $schema = $self->schema()->{$field_name};
	croak "value_range: field with name '$field_name' does not exist" unless defined $schema;
	croak "value_range: can't use value from field '$field_name' since its' type is '$schema->{TypeName}'"
	    unless $schema->{TypeName} eq 'Integer' or $schema->{TypeName} eq 'Real';
	my $field = $schema->{Number};
	my @range;
	for my $r (@{$self->{TABLE}}) {
	    my $value = $r->[$field];
	    $range[0] = defined $range[0] ? ($range[0] < $value ? $range[0] : $value) : $value;
	    $range[1] = defined $range[1] ? ($range[1] > $value ? $range[1] : $value) : $value;
	}
	return @range;
    } elsif ($param{of_GDAL} and $self->{GDAL}) {
	my $gdal = $self->{GDAL};
	my $band = $gdal->{dataset}->GetRasterBand($gdal->{band});
	return($band->GetMinimum, $band->GetMaximum);
    }
    return () unless $self->{GRID};
    my $range = ral_grid_get_value_range($self->{GRID});
    return @$range;
}

## @method @attributes()
#
# @brief If the object has a grid defined, then the method sets the objects
# properties according to the grid.
# @deprecated.
sub attributes {
    my $self = shift;
    return unless $self->{GRID};
    my $datatype = $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID});
    my $M = $self->{M} = ral_grid_get_height($self->{GRID});
    my $N = $self->{N} = ral_grid_get_width($self->{GRID});
    my $cell_size = $self->{CELL_SIZE} = ral_grid_get_cell_size($self->{GRID});
    my $world = $self->{WORLD} = ral_grid_get_world($self->{GRID});
    my $nodata = $self->{NODATA} = ral_grid_get_nodata_value($self->{GRID});
    return($datatype, $M, $N, $cell_size, @$world, $nodata);
}

## @method $datatype()
#
# @brief Returns the datatype of the raster as a string.
# @return Name of type if the object has a raster. Type can be 'Integer'
# or 'Real'.
sub datatype {
    my $self = shift;
    return unless $self->{GRID};
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID});
    return 'Integer' if $self->{DATATYPE} == $INTEGER_GRID;
    return 'Real' if $self->{DATATYPE} == $REAL_GRID;
}

## @ignore
sub data_type {
    my $self = shift;
    return $self->datatype;
}

## @method @size(%params)
#
# @brief Returns the size (height, width) of the raster.
#
# @param params Named parameters:
# - <i>of_GDAL</i>=>boolean Force the method to return the size of the
# underlying GDAL raster, if there is one.
#
# @return The size (height, width) of the raster or an empty list if
# no part of the GDAL raster has yet been cached.
sub size {
    my $self = shift;
    my($i, $j) = @_;
    if (defined($i) and defined($j) and ($i =~ /^\d+$/) and ($j =~ /^\d+$/)) {
	return ral_grid_zonesize($self->{GRID}, $i, $j);
    } else {
	my %o = @_;
	if ($self->{GDAL} and $o{of_GDAL}) {
	    return ($self->{GDAL}->{dataset}->{RasterYSize}, 
		    $self->{GDAL}->{dataset}->{RasterXSize});
	} elsif (!$self->{GRID}) {
	    return ();
	} else {
	    return ($self->{M}, $self->{N});
	}
    }
}

## @method $cell_size(%params)
# 
# @brief Returns the cell size.
# @param[in] params Named parameters:
# - <I>of_GDAL</I>=>boolean (optional) Force the method to return the
# cell size of the underlying GDAL raster if there is one.
# @return Cell size, i.e., the length of the cell edge in raster scale.
sub cell_size {
    my($self, %o) = @_;
    if ($self->{GDAL} and $o{of_GDAL}) {
	return $self->{GDAL}->{cell_size};
    } elsif (!$self->{GRID}) {
	return undef;
    } else {
	$self->{CELL_SIZE} = ral_grid_get_cell_size($self->{GRID});
	return $self->{CELL_SIZE};
    }
}

## @method $nodata_value($value)
#
# @brief Set a nodata value for the grid. If 
# @param[in] value (optional) Value that represents <I>no data</I> in the grid.
# @return The value set for no data.
# @note It might be wise to use zero (0) for representing no data. 
# @note Do not use a real number for <I>no data</I> for a grid of type integer.
sub nodata_value {
    my $self = shift;
    my $nodata_value = shift;
    if (defined $nodata_value) {
	if ($nodata_value eq '') {
	    ral_grid_remove_nodata_value($self->{GRID});
	} else {
	    ral_grid_set_nodata_value($self->{GRID}, $nodata_value);
	}
    } else {
	if ($self->{GDAL}) {
	    my $gdal = $self->{GDAL};
	    my $band = $gdal->{dataset}->GetRasterBand($gdal->{band});
	    $nodata_value = $band->GetNoDataValue;
	} else {
	    $nodata_value = $self->{NODATA} = ral_grid_get_nodata_value($self->{GRID});
	}
    }
    return $nodata_value;
}

## @method Geo::Raster min($param)
# 
# @brief Set each cell to the minimum of cell's own value or parameter (which 
# ever is smaller).
# 
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the minimum values is returned.
#
# @param[in] param Number to compare with the raster cell values.
# @return A raster with values equal to those of this grids or parameters, 
# which ever are smaller.

## @method Geo::Raster min(Geo::Raster second)
# 
# @brief Set each cell to the minimum of cells own value or parameter grids 
# cells value (which ever is smaller).
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the minimum values is returned.
#
# @param[in] second A reference to an another raster, whose cells define the 
# comparison value for each of this rasters cells.
# @return A raster with values equal to those of this grids or parameter 
# grids, which ever are smaller.
sub min {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster::new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_min_grid($self->{GRID}, $second->{GRID});
    } else {
	if (defined($second)) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_min_integer($self->{GRID}, $second);
	    } else {
		ral_grid_min_real($self->{GRID}, $second);
	    }
	} else {
	    my $range = ral_grid_get_value_range($self->{GRID});
	    return $range->[0];
	}
    }
    return $self if defined wantarray;
}

## @method Geo::Raster max($param)
# 
# @brief Set each cell to the maximum of cell's own value or parameter (which 
# ever is greater).
# 
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the maximum values is returned.
#
# @param[in] param Number to compare with the raster cell values.
# @return A raster with values equal to those of this grids or parameters, 
# which ever are higher.

## @method Geo::Raster max(Geo::Raster second)
# 
# @brief Set each cell to the maximum of cell's own value or parameter grids 
# cells value (which ever is greater).
# 
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the maximum values is returned.
#
# @param[in] second A reference to an another raster, whose cells define the 
# comparison value for each of this rasters cells.
# @return A raster with values equal to those of this grids or parameters, 
# which ever are higher.
sub max {
    my $self = shift;
    my $second = shift;   
    $self = Geo::Raster::new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_max_grid($self->{GRID}, $second->{GRID});
    } else {
	if (defined($second)) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_max_integer($self->{GRID}, $second);
	    } else {
		ral_grid_max_real($self->{GRID}, $second);
	    }
	} else {
	    my $range = ral_grid_get_value_range($self->{GRID});
	    return $range->[1];
	}
    }
    return $self if defined wantarray;
}

## @method Geo::Raster random()
# @brief Return a random part of values of the values of this raster.
# @return raster with a random portion of the values of this
# raster. In void context changes the values of this raster.
sub random {
    my $self = shift;
    $self = Geo::Raster::new($self) if defined wantarray;
    ral_grid_random($self->{GRID});
    return $self if defined wantarray;
}

## @method Geo::Raster cross(Geo::Raster b)
# 
# @brief Cross product of rasters.
#
# Example of usage: Creates a new Geo::Raster with cross product values 
# (c = a x b).
# @code
# $c = $a->cross($b);
# @endcode
# Example of usage: Changes values to cross product values (a = a x b).
# @code
# $a->cross($b);
# @endcode
#
# If a has values a1, ..., ana (ai < aj, na distinct values) and b has values 
# b1, ..., bnb (bi < bj, nb distinct values) then c will have nc = na * nb
# distinct values 1, ..., nc. The c will have value 1 where a = a1 and b
# = b1, 2 where a = a1 and b = b2, etc.
# - The operation results are given to this raster, if no resulting new 
# raster is needed, else a new grid with the cross product values is 
# returned.
# - The rasters datatypes must be integer.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# - If the other or both raster cells have an <I>no data</I> value, then 
# also the resulting cell will have that value.
#
# @param[in] b A reference to an another Geo::Raster object.
# @return A new raster with the calculated cross product values.
sub cross {
    my($a, $b) = @_;
    my $c = ral_grid_cross($a->{GRID}, $b->{GRID}); 
    return new Geo::Raster ($c) if defined wantarray;
    $a->_new_grid($c) if $c;
}

## @method Geo::Raster if(Geo::Raster b, Geo::Raster c)
# 
# @brief If...then statement construct for rasters.
#
# Example of usage:
# @code
# $a->if($b, $c);
# @endcode
# where $a and $b are rasters and $c can be a raster or a scalar. The
# effect of this subroutine is:
# @code
# for all cells k: if (b[k]) then a[k]=c[k]
# @endcode
#
# If a return value is requested:
# @code
# $d = $a->if($b, $c);
# @endcode
# @code
# for all cells k: if (b[k]) then d[k]=c[k] else d[k]=a[k]
# @endcode
#
# - If $c is a reference to a hash of key=>value pairs, where key is
# an integer and value is a number, then
# @code
# for all cells k and keys key: if (b[k]==key) then a[k]=c[key]
# @endcode
#
# @param[in] b Raster, whose values are used as boolean values.
# @param[in] c Value raster, reference to a hash, or value.
# @return a raster whose values are the results of the if
# statement. In void context changes the values of this raster.

## @method Geo::Raster if(Geo::Raster b, Geo::Raster c, Geo::Raster d)
# 
# @brief If...then...else statement construct for rasters.
#
# Example of usage:
# @code
# $a->if($b, $c, $d);
# @endcode
# where $a and $b are rasters and $c and $d can be a rasters or
# values. The effect of this subroutine is:
#
# @code
# for all cells k: if (b[k]) then a[k]=c[k] else a[k]=d[k]
# @endcode
#
# If a return value is requested:
# @code
# $e = $a->if($b, $c, $d);
# @endcode
# @code
# for all cells k: if (b[k]) then e[k]=c[k] else e[k]=d[k]
# @endcode
#
# - If $c and $d are references to hashes of key=>value pairs, where
# key is an integer and value is a number, then
# @code
# for all cells k and keys key: if (b[k]==key) then a[k]=c[key] else a[k]=d[key]
# @endcode
#
# @param[in] b Raster, whose values are used as boolean values.
# @param[in] c Value raster, reference to a hash, or value.
# @param[in] d Value raster, reference to a hash, or value.
# @return a raster whose values are the results of the if
# statement. In void context changes the values of this raster.
sub if {
    my $a = shift;
    my $b = shift;    
    my $c = shift;
    my $d = shift;
    $a = new Geo::Raster ($a) if defined wantarray;
    croak "usage $a->if($b, $c)" unless defined $c;
    if (ref($c)) {
	if (isa($c, 'Geo::Raster')) {
	    ral_grid_if_then_grid($b->{GRID}, $a->{GRID}, $c->{GRID});
	} elsif (ref($c) eq 'HASH') {
	    my(@k,@v);
	    foreach (keys %{$c}) {
		push @k, int($_);
		push @v, $c->{$_};
	    }
	    ral_grid_zonal_if_then_real($b->{GRID}, $a->{GRID}, \@k, \@v, $#k+1);
	} else {
	    croak("usage: $a->if($b, $c)");
	}
    } else {
	unless (defined $d) {
	    if (ral_grid_get_datatype($a->{GRID}) == $INTEGER_GRID and $c =~ /^-?\d+$/) {
		ral_grid_if_then_integer($b->{GRID}, $a->{GRID}, $c);
	    } else {
		ral_grid_if_then_real($b->{GRID}, $a->{GRID}, $c);
	    }
	} else {
	    if (ral_grid_get_datatype($a->{GRID}) == $INTEGER_GRID and $c =~ /^-?\d+$/) {
		ral_grid_if_then_else_integer($b->{GRID}, $a->{GRID}, $c, $d);
	    } else {
		ral_grid_if_then_else_real($b->{GRID}, $a->{GRID}, $c, $d);
	    }
	}
    }
    return $a if defined wantarray;
}

## @method Geo::Raster bufferzone($z, $w)
#
# @brief Creates buffer zones around cells having the given value
#
# Creates (or converts a grid to) a binary grid, where all cells
# within distance w of a cell (measured as pixels from cell center to cell center)
# having the value z will have value 1, all other cells will
# have values 0. 
# @param[in] z Denotes cell values for which the bufferzone is computed.
# @param[in] w Width of the bufferzone.
# @note Defined only for integer grids.
sub bufferzone {
    my($self, $z, $w) = @_;
    croak "method usage: bufferzone($z, $w)" unless defined($w);
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_grid_bufferzone($self->{GRID}, $z, $w));
	return $g;
    } else {
	$self->_new_grid(ral_grid_bufferzone($self->{GRID}, $z, $w));
    }
}

## @method Geo::Raster distances()
#
# @brief Computes and stores into nodata cells the distance
# (in world units) to the nearest data cell.
# @return If a return value is wanted, then the method returns a new grid with 
# values only in this rasters <I>no data</I> cells having the distance
# to the nearest data cell. 
sub distances {
    my($self) = @_;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_grid_distances($self->{GRID}));
	return $g;
    } else {
	$self->_new_grid(ral_grid_distances($self->{GRID}));
    }
}

## @method Geo::Raster directions()
# 
# @brief Computes and stores into nodata cells the direction to the nearest 
# data cell into nodata cells.
# 
# Directions are given in radians and direction zero is to the direction of 
# x-axis, Pi/2 is to the direction of y-axis.
# @return If a return value is wanted, then the method returns a new grid, with 
# values only in this rasters <I>no data</I> cells, having the direction
# to the nearest data cell. 
sub directions {
    my($self) = @_;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_grid_directions($self->{GRID}));
	return $g;
    } else {
	$self->_new_grid(ral_grid_directions($self->{GRID}));
    }
}

## @method Geo::Raster clip($i1, $j1, $i2, $j2)
# 
# @brief Clips a part of the raster according the given rectangle.
#
# Example of clipping a grid:
# @code
# $g2 = $g1->clip($i1, $j1, $i2, $j2);
# @endcode
# 
# @param[in] i1 Upper left corners i-coordinate of the rectangle to clip.
# @param[in] j1 Upper left corners j-coordinate of the rectangle to clip.
# @param[in] i2 Bottom right corners i-coordinate of the rectangle to clip.
# @param[in] j2 Bottom right corners j-coordinate of the rectangle to clip.
# @return If a return value is wanted, then the method returns a new grid with
# size defined by the parameters.

## @method Geo::Raster clip(Geo::Raster area_to_clip)
# 
# @brief Clips a part of the raster according the given rasters real 
# world boundaries.
#
# Example of clipping a grid:
# @code
# $g2 = $g1->clip($g3);
# @endcode
# The example clips from $g1 a piece which is overlayable with $g3. 
# If there is no lvalue, $g1 is clipped.
# 
# @param[in] area_to_clip A Geo::Raster, which defines the area to clip.
# @return If a return value is wanted, then the method returns a new grid with
# size defined by the parameter.
sub clip {
    my $self = shift;
    if (@_ == 4) {
	my($i1, $j1, $i2, $j2) = @_;
	if (defined wantarray) {
	    my $g = new Geo::Raster(ral_grid_clip($self->{GRID}, $i1, $j1, $i2, $j2));
	    return $g;
	} else {
	    $self->_new_grid(ral_grid_clip($self->{GRID}, $i1, $j1, $i2, $j2));
	}
    } else {
	my $gd = shift;
	return unless isa($gd, 'Geo::Raster');
	my @a = $gd->attributes;
	my($i1,$j1) = $self->w2g($a[4],$a[7]);
	my($i2,$j2) = ($i1+$a[1]-1,$j1+$a[2]-1);
	if (defined wantarray) {
	    my $g = new Geo::Raster(ral_grid_clip($self->{GRID}, $i1, $j1, $i2, $j2));
	    return $g;
	} else {
	    $self->_new_grid(ral_grid_clip($self->{GRID}, $i1, $j1, $i2, $j2));
	}
    }
}

## @method Geo::Raster join(Geo::Raster second)
# 
# @brief The method joins the two given rasters.
#
# - The upper and left world boundaries must must have equal values.
# - If the others or boths grid types are real, then the joined raster will have 
# real as type.
#
# Example of joining
# @code
# $g3 = $g1->join($g2);
# @endcode
#
# The joining is based on the world coordinates of the grids. clip and
# join without assignment clip or join the original grid, so
# @code
# $a->clip($i1, $j1, $i2, $j2);
#
# $a->join($b);
# @endcode
#
# @param[in] second A raster to join to this raster. 
# @return If a return value is wanted, then the method returns a new grid.
# @exception The rasters have a different cell size.
sub join {
    my $self = shift;
    my $second = shift;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_grid_join($self->{GRID}, $second->{GRID}));
	return $g;
    } else {
	$self->_new_grid(ral_grid_join($self->{GRID}, $second->{GRID}));
    }
}

## @method void assign(Geo::Raster src)
#
# @brief Assigns the values from an another raster to this. 
#
# The values are looked up simply based on the center point of cell.
# 
# Example of assigning
# @code
# $dest->assign($src);
# @endcode
#
# @param[in] src Source grid from where the values looked up.
sub assign {
    my($dest, $src) = @_;
    ral_grid_pick($dest->{GRID}, $src->{GRID});
}

## @method void clip_to(Geo::Raster like)
#
# @brief Creates a grid like the given and assigns to that grid this grids values.
#
# Makes a new grid g3, which is like g2 and assigns values from g1 to it. If
# called without return value, discards GDAL dataset if there is one.
# Also if g2 has GDAL, calls sg1->cache($g2) first.
# Example of clipping to a new grid
# @code
# $g3 = $g1->clip_to($g2);
# @endcode
# @param[in] like Source grid, where the values
sub clip_to {
    my($self, $like) = @_;
    if ($self->{GDAL}) {
	$self->cache($like);
    }
    if (defined wantarray) {
	my $g = new Geo::Raster(like=>$like, datatype=>ral_grid_get_datatype($self->{GRID}));
	$g->assign($self);
	return $g;
    } else {
	my $g = ral_grid_create_like($like->{GRID}, ral_grid_get_datatype($self->{GRID}));
	ral_grid_pick($g, $self->{GRID});
	$self->_new_grid($g);
	delete $self->{GDAL} if $self->{GDAL};
    }
}

## @method listref array()
#
# @brief Creates a list of the rasters values.
#
# Example of making an array of data in a grid
# @code
# $aref = $gd->array;
# @endcode
# where $aref is a reference to a list of references to arrays of cells and values:
#
# [[i0, j0, val0], [i1, j1, val1], [i2, j2, val2], ...].
#
# @return Returns a reference to a list, where first is given a grids 
# coordinates and then the value of that grid.
sub array {
    my($self) = @_;
    my $a = ral_grid2list($self->{GRID});
    return $a;
}

## @method listref histogram(listref bins)
#
# @brief Calculates the histogram values for the given bins.
#
# Example of calculating a histogram:
# @code
# $histogram = $gd->histogram(\@bins);
# @endcode
#
# @param[in] bins Reference to an array having the border values for the bins.
# @return Reference to an array having amount of cells falling to each bin.

## @method listref histogram($bins)
#
# @brief 
#
# Example of calculating a histogram, where all values plotted in to 10 equal 
# sized intervals:
# @code
# $histogram = $gd->histogram(10);
# @endcode
#
# @param[in] bins (optional) Amount of bins (disjoint categories). If not given 20 
# is used as bins amount. There is no "best" number of bins, and different bin 
# sizes can reveal different features of the data.
# @return Reference to an array having amount of cells falling to each bin.
sub histogram {
    my $self = shift;
    my $bins = shift;
    $bins = 20 unless $bins;
    my $a;
    if (ref($bins)) {
	$a = ral_grid_histogram($self->{GRID}, $bins, $#$bins+1);
	return @$a;
    } else {
	my $bins = int($bins);
	my ($minval,$maxval) = $self->value_range();
	my @bins;
	my $i;
	my $d = ($maxval-$minval)/$bins;
	$bins[0] = $minval + $d;
	for $i (1..$bins-2) {
	    $bins[$i] = $bins[$i-1]+$d;
	}
	$bins[$bins-1] = $maxval;
	my $counts = ral_grid_histogram($self->{GRID}, \@bins, $bins+1);
	# now, $$counts[$n] should be zero, right? 
	# (there are no values > maxval)
	unshift @bins, $minval;
	my $a = {};
	for $i (0..$bins-1) {
	    $a->{($bins[$i]+$bins[$i+1])/2} = $counts->[$i];
	}
	return $a;
    }
}

## @method hashref contents()
#
# @brief Returns a hash having all the amounts of each grid value.
#
# Example of calculating the the amounts of grid values
# @code
# $contents = $gd->contents();
# @endcode
# @return Returns a reference to a hash which has, values as keys and counts as 
# values.
sub contents {
    my $self = shift;
    if ($self->{DATATYPE} == $INTEGER_GRID) {
	return ral_grid_contents($self->{GRID});
    } else {
	my $c = $self->array();
	my %d;
	for my $c (@$c) {
	    $d{$c->[2]}++;
	}
	return \%d;
    }
}

## @method Geo::Raster function($fct)
#
# @brief Calculates the grid values according to the given function.
#
# Example of filling a grid using an arbitrary function of x and y
# @code
# $grid->function("<function of x and y>");
# @endcode
# fills the grid by calculating the z value for each grid cell separately using 
# the world coordinates. An example of a function string is '2*$x+3*$y', 
# which creates a plane.
#
# @param[in] fct A string having a function.
# @return Returns a new raster, if a return value is wanted, else the 
# values gotten by the function will be added to this grid.
# @note This method should be used only with care, because the command given as 
# parameter will be run even if it is harmful!
sub function {
    my($self, $fct) = @_;
    my(undef, $M, $N, $cell_size, $minX, $minY, $maxX, $maxY) = $self->attributes();
    my $y = $minY+$cell_size/2;
    for my $i (0..$M-1) {
	my $x = $minX+$cell_size/2;
	$y += $cell_size;
	for my $j (0..$N-1) {
	    $x += $cell_size;
	    my $z = eval $fct;
	    $self->set($i, $j, $z);
	}
    }
}

## @method Geo::Raster map(hashref map)
#
# @brief The method maps (reclassifies) the values in the raster or returns
# a reclassified raster. 
#
# Example of mapping values
# @code
# $img2 = $img1->map(\%map);
# @endcode
# or
# @code
# $img->map(\%map);
# @endcode
# or, for example, using an anonymous hash created on the fly
# @code
# $img->map({1=>5,2=>3});
# @endcode
# Maps cell values (keys in map) in img1 to respective values in map in
# img2 or within img.  Works only for integer grids.
#
# Hint: Take the contents of a grid, manipulate it and then feed it to
# the map.
#
# @param[in] map This is a reference to a hash of pairs of mappings.
# The key may be '*' (denoting a default value) or an integer. The
# value is a new value for the value the key specifies. If the value
# is a real number (i.e., contains '.') the result is a real valued
# raster.
# @return eturns a new raster, if a return value is wanted, else the 
# reclassifications are done to this grid.
# @note Use this method this way only for integer valued rasters.

## @method Geo::Raster map(listref map)
#
# @brief The method maps (reclassifies) the values in the raster or returns
# a reclassified raster.
#
# @param[in] map This is a reference to a list of of pairs of mappings. 
# The key may be '*' (denoting a default value), integer, or a reference to a 
# list denoting a value range: [min_value, max_value]. 
# The value is a new value for the
# value or value range the key specifies. If the value is a real
# number (i.e., contains '.') the result is a real valued raster.
# @return Returns a new raster, if a return value is wanted, else the 
# reclassifications are done to this grid.
# @note This method can be used for real valued rasters if value
# ranges are used.

## @method Geo::Raster map(@map)
#
# @brief The method maps (reclassifies) the values in the raster or returns
# a reclassified raster. 
#
# @param[in] map This is a list of pairs of mappings. 
# The key may be '*' (denoting a default value), integer, or a reference to a 
# list denoting a value range: [min_value, max_value]. The value is a new value 
# for the value or value range the key specifies. If the value is a real
# number (i.e., contains '.') the result is a real valued raster.
# @return Returns a new raster, if a return value is wanted, else the 
# reclassifications are done to this grid.
# @note This method can be used for real valued rasters if value
# ranges are used.
sub map {
    my $self = shift;
    my @map;
    if (@_ == 1) {
	if (ref($_[0]) eq 'HASH') {
	    for (keys %{$_[0]}) {
		push @map, $_;
		push @map, $_[0]->{$_};
	    }
	} elsif (ref($_[0]) eq 'ARRAY') {
	    @map = @{$_[0]};
	} else {
	    croak "usage map(list) or map({list}), list is a list of pairs of mappings";
	}
    } else {
	@map = @_;
    }
    my $ext = 0;
    my $to_real = 0;
    my $i;
    for ($i = 0; $i < $#map; $i += 2) {
	if (ref($map[$i]) eq 'ARRAY' or $map[$i] eq '*') {
	    $ext = 1;
	}
	if ($map[$i+1] =~ /\./ or $map[$i+1] =~ /\,/) {
	    $ext = 1;
	    $to_real = 1;
	}
    }  
    if ($self->{DATATYPE} == $INTEGER_GRID and $to_real) {
	my $grid = ral_grid_create_copy($self->{GRID}, $REAL_GRID);
	if (defined wantarray) {
	    $self = new Geo::Raster $grid;
	} else {
	    $self->_new_grid($grid);
	}
    } else {
	if (defined wantarray) {
	    $self = new Geo::Raster $self;
	}
    }
    if ($ext) {
	my %map;
	my $default;
	my(@source_min, @source_max, @destiny);
	for ($i = 0; $i < $#map; $i += 2) {
	    if ($map[$i] eq '*') {
		$default = $map[$i+1];
	    } elsif (ref($map[$i]) eq 'ARRAY') {
		$map{$map[$i]->[0]}{max} = $map[$i]->[1];
		$map{$map[$i]->[0]}{to} = $map[$i+1];
	    } else {
		$map{$map[$i]}{max} = $map[$i]+1;
		$map{$map[$i]}{to} = $map[$i+1];
	    }
	}
	for my $min (sort {$a<=>$b} keys %map) {
	    push @source_min, $min;
	    push @source_max, $map{$min}{max};
	    push @destiny, $map{$min}{to};
	}
	my $n = @destiny;
	if ($self->{DATATYPE} == $INTEGER_GRID) {
	    ral_grid_map_integer_grid($self->{GRID}, \@source_min, \@source_max, \@destiny, $n, $default);
	} else {
	    ral_grid_map_real_grid($self->{GRID}, \@source_min, \@source_max, \@destiny, $n, $default);
	}
    } else {
	my %map = @map;
	my(@source, @destiny);
	for (sort {$a<=>$b} keys %map) {
	    push @source, $_;
	    push @destiny, $map{$_};
	}
	my $n = @source;
	ral_grid_map($self->{GRID}, \@source, \@destiny, $n);
    }
    return $self if defined wantarray;
}

## @method hashref neighbors()
#
# @brief Creates a hash having all values as keys and their neighbor values stored.
#
# @return A reference to a hash having all cell values as keys. 
# As values of the hash are references to arrays having the 8-connected neighbor 
# values of the value being as key.
# @note Works only for integer grid.
sub neighbors {
    my $self = shift;
    $a = ral_grid_neighbors($self->{GRID});
    return $a;
}

## @ignore
# maps from ESRI style FDG to libral style FDG
sub many2ds {
    my($fdg) = @_;
    my %map;
    for my $i (1..255) {
	my $c = 0;
	for my $j (0..7) {
	    $c++ if $i & 1 << $j;
	}
	$map{$i} = $c;
    }
    $fdg->map(\%map);
}

## @method @movecell($i, $j, $dir)
#
# @brief Returns the coordinates of the new position if possible to move there.
# @param[in] i The i-coordinate of a cell from where to move.
# @param[in] j The i-coordinate of a cell from where to move.
# @param[in] dir (optional) Direction into where to move. If the direction is 
# not given, then the direction is gotten from the cells value. Directions are 
# numbered (where X indicates the cells position):<BR>
# 8 1 2<BR>
# 7 X 3<BR>
# 6 5 4
# @return The coordinates of the new position as an array [i, j] or undef if the 
# cell moves outside of the grid.
sub movecell {
    my($fdg, $i, $j, $dir) = @_;
    $dir = $fdg->get($i, $j) unless $dir;
  SWITCH: {
      if ($dir == 1) { $i--; last SWITCH; }
      if ($dir == 2) { $i--; $j++; last SWITCH; }
      if ($dir == 3) { $j++; last SWITCH; }
      if ($dir == 4) { $i++; $j++; last SWITCH; }
      if ($dir == 5) { $i++; last SWITCH; }
      if ($dir == 6) { $i++; $j--; last SWITCH; }
      if ($dir == 7) { $j--; last SWITCH; }
      if ($dir == 8) { $i--; $j--; last SWITCH; }
      croak "movecell: $dir: bad direction";
  }
    if ($fdg) {
	return if ($i < 0 or $j < 0 or $i >= $fdg->{M} or $j >= $fdg->{N});
    }
    return ($i, $j);
}

## @fn $dirsum($dir, $add)
#
# @brief Adds to the given direction number the other given number and returns 
# the new direction. 
# @param[in] dir Number indicating a direction. Directions are numbered 
# (where X indicates a cells position):
#
# 8 1 2<BR>
# 7 X 3<BR>
# 6 5 4
#
# @param[in] add Number to add to the direction as an integer in the interval [1, 8]. 
# @return The new direction (an integer in the interval [1, 8]).
sub dirsum {
    my($dir, $add) = @_;
    $dir += $add;
    $dir -= 8 if $dir > 8;
    return $dir;
}

call_g_type_init();
Geo::GDAL::AllRegister;
Geo::GDAL::UseExceptions();

1;
__END__


=head1 SEE ALSO

Geo::GDAL

This module should be discussed in geo-perl@list.hut.fi.

The homepage of this module is
http://geoinformatics.tkk.fi/twiki/bin/view/Main/GeoinformaticaSoftware.

=head1 AUTHOR

Ari Jolma, ari.jolma _at_ tkk.fi

=head1 COPYRIGHT AND LICENSE

Copyright (C) 1999- by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut

