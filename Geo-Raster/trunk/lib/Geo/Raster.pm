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
use Statistics::Descriptive; # Used in zonal functions

# subsystems:
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
# tell dynaloader to load this module so that xs functions are available to all:
sub dl_load_flags {0x01}

XSLoader::load( 'Geo::Raster', $VERSION );

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.
# not having "" linked makes print "$raster" to print "1"

use overload (
	      'fallback' => undef,
	      '""'       => 'as_string',
	      'bool'     => 'bool',
#	      '='        => 'clone',
	      '='        => 'shallow_copy',
	      'neg'      => 'neg',
	      '+'        => 'plus',
	      '-'        => 'minus',	      
	      '*'        => 'times',
	      '/'        => 'over',
	      '%'        => 'modulo',
	      '**'       => 'power',
	      '+='       => 'add',
	      '-='       => 'subtract',
	      '*='       => 'multiply_by',
	      '/='       => 'divide_by',
	      '%='       => 'modulus_with',
	      '**='      => 'to_power_of',
	      '<'        => 'lt',
	      '>'        => 'gt',
	      '<='       => 'le',
	      '>='       => 'ge',
	      '=='       => 'eq',
	      '!='       => 'ne',
	      '<=>'      => 'cmp',
	      'atan2'    => 'atan2',
	      'cos'      => 'cos',
	      'sin'      => 'sin',
	      'exp'      => 'exp',
	      'abs'      => 'abs',
	      'log'      => 'log',
	      'sqrt'     => 'sqrt',
	      );

## @method protected @_new_grid(ref ral_grid grid)
#
# @brief Adds to the object the given grid.
# @param[in] grid Reference to a raster grid to add to the object.
# @return Array of the objects attributes defined by the grid.
# @note If the method had an grid already, that is destroyed..
sub _new_grid {
    my $self = shift;
    my $grid = shift;
    return unless $grid;
    ral_grid_destroy($self->{GRID}) if $self->{GRID};
    $self->{GRID} = $grid;
    attributes($self);
}

## @method protected $_interpret_datatype($number)
#
# @brief Returns the parammeters datatype.
# @param[in] number Number which datatype is wanted to know.
# @return Datatype of the number.
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
# @brief The constructor can be used to load a previously saved raster grid.
#
# Example of loading a previously saved raster
# @code
# $grid = new Geo::Raster("data/dem");
# @endcode
# @param[in] file_name Name of file, from where the new Geo::Raster is loaded. 
# @return New instance of Geo::Raster.

## @cmethod Geo::Raster new(ral_gridPtr param)
#
# @brief The constructor can be used to load a previously saved raster grid, 
# create a new or to act as an copy constructor.
#
# @param[in] param A reference to a ral_grid, returned for example by a libral 
# function (through the XS interface).
# @return New instance of Geo::Raster.

## @cmethod Geo::Raster new(Geo::Raster param)
#
# @brief The constructor can be used to act as an copy constructor.
#
# Example of acting as an copy constructor:
# @code
# $copy_grid = new Geo::Raster($other_grid);
# @endcode
#
# @param[in] param A reference to an another Geo::Raster object, which is copied.
# @return New instance of Geo::Raster.

## @cmethod Geo::Raster new($datatype, $M, $N)
#
# @brief The constructor can be used to create a new grid.
#
# Example of creating a new raster grid with real type:
# @code
# $real_grid = new Geo::Raster(2, 100, 100);
# @endcode
# Example of creating a new raster grid with integer type:
# @code
# $int_grid = new Geo::Raster(100, 100);
# @endcode
#
# @param[in] datatype (optional) Creates a new grid with the given datatype. 
# By default the datatype will be integer (1).
# @param[in] M Vertical cell amount of the grid.
# @param[in] N Horizontal cell amount of the grid.
# @return New instance of Geo::Raster.

## @cmethod Geo::Raster new(%params)
#
# @brief The constructor can be used to load a previously saved raster grid, 
# create a new or to act as an copy constructor.
#
# Example of starting with a new fresh raster grid:
# @code
# $grid = new Geo::Raster(datatype=>datatype_string, M=>100, N=>100);
# @endcode
#
# Example of opening a previously saved grid:
# @code
# $grid = new Geo::Raster(filename=>"data/dem", load=>1);
# @endcode
#
# Example of acting as an copy constructor:
# @code
# $copy_grid = new Geo::Raster(copy=>$other_grid);
# @endcode
#
# Example of creating a grid with same size:
# @code
# $new_grid = new Geo::Raster(like=>$old_grid);
# @endcode
#
# @param[in] params is a hash of named parameters:
# - <I>datatype</I> Can be real (float, 2), which denotes a real grid or
# integer. Default is integer (1).
# - <I>copy</I> A Geo::Raster object. If given, the constructor acts as an copy 
# constructor.
# - <I>use</I> Reference to a ral_grid. Parameter is used only if <I>copy</I> 
# is not defined.
# - <I>like</I> A Geo::Raster object. Used only if <I>copy</I> and <I>use</I> 
# are undefined.
# - <I>filename</I> Files location as string. A raster grid saved previously in 
# the given filename is loaded.
# If filename is given then also two additional named parameter can be given 
# with which Geo::Raster::gdal_open() is called:
#  - <I>band</I> (optional). Default is 1.
#  - <I>load</I> (optional). Default is false, calls cache without parameters if 
# true.
# .
# Used only if previous parameters, not including <I>datatype</I>, are undefined.
# - <I>M</I> Height of of the grid area (max(i)+1). Used if previous parameters, 
# not including <I>datatype</I>, are undefined and <I>N</I> is given.
# - <I>N</I> Width of of the grid area (max(j)+1). Used if previous parameters, 
# not including <I>datatype</I>, are undefined and <I>M</I> is given.
# - <I>world</I> Named parameters suitable to define the real world boundaries. 
# Used only if <I>M</I> and <I>N</I> are also given. Possible parameters 
# include:
#   -# cell_size.
#   -# minx.
#   -# miny.
#   -# maxx.
#   -# maxy.
# .
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
    
    my %p = @_;
    for (keys %p) {
	$params{$_} = $p{$_} unless exists $params{$_};
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

sub gdal_mem_band {
    my $self = shift;
    my @size = $self->size;
    my $datapointer = ral_pointer_to_data($self->{GRID});
    my $datatype = ral_data_element_type($self->{GRID});
    my $size = ral_sizeof_data_element($self->{GRID});
    my %gdal_type = (
	'short' => 'Int',
	'float' => 'Float',
	);
    my $ds = Geo::GDAL::Open(
	"MEM:::DATAPOINTER=$datapointer,".
	"PIXELS=$size[1],LINES=$size[0],DATATYPE=$gdal_type{$datatype}$size");
    my $world = ral_grid_get_world($self->{GRID});
    my $cell_size = ral_grid_get_cell_size($self->{GRID});
    $ds->SetGeoTransform([$world->[0], $cell_size, 0, $world->[3], 0, -$cell_size]);
    return $ds->Band(1);
}

sub as_string {
    my $self = shift;
    return $self;
}

sub shallow_copy {
    my $self = shift;
    return $self;
}

## @method $has_field($field_name)
#
# @brief The subroutine tells if the asked field name exists in the raster grid. 
# @param[in] field_name Name of the field whose existence is checked.
# @return True if the raster grid has a field having the same name as the given 
# parameter, else returns false.
sub has_field {
    my($self, $field_name) = @_;
    return 1 if $field_name eq 'Cell value';
    return 0 unless $self->{TABLE_NAMES} and @{$self->{TABLE_NAMES}};
    for my $name (@{$self->{TABLE_NAMES}}) {	
		return 1 if $name eq $field_name;
    }
    return 0;
}

## @method @table(listref table)
#
# @brief Get or set the attribute table.
#
# An attribute table is a table, whose keys are cell values, thus defined only 
# for integer rasters.
#
# @param[in] table (optional). The parameter is a reference to the attribute 
# table. 
# @return If no parameter is given, the subroutine returns the current attribute 
# table.

## @method @table($table)
#
# @brief Get or set the attribute table.
#
# An attribute table is a table, whose keys are cell values, thus defined only 
# for integer rasters.
#
# @param[in] table (optional). File path, from where the attribute table can be 
# read. 
# @return If no parameter is given, the subroutine returns the current attribute 
# table.
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

## @method void copy_world_to(Geo::Raster to)
#
# @brief The method copies the objects raster grid bounding box to the given 
# raster grid.
# @param[out] to A raster grid to which the world is copied to.
sub copy_world_to {
    my($self, $to) = @_;
    return ral_grid_copy_bounds($self->{GRID}, $to->{GRID});
}

## @method boolean cell_in(@cell)
#
# @brief Tells if the raster grid has a cell with given grid coordinates.
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
# @param[in] cell The raster grid cell (i, j).
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
# @param[in] ga The boundary coordinates of an raster grid as an array (i_min, 
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
# @param[in] wa The boundary coordinates of an raster grid as an array (x_min, 
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

## @method void mask(Geo::Raster mask)
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

## @method void set($i, $j, $value)
#
# @brief Sets a value to a single grid cell or to all cells.
#
# If grid coordinates i and j are given then the method sets given value 
# to all cells in the raster set.
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
# @param[in] i (optional) the cells i-coordinate. 
# @param[in] j (optional) the cells j-coordinate.
# @param[in] value (optional) The value to set, which can be a number, 
# "nodata" or a reference to Geo::Raster. If not given then the cell gets a
# <I>nodata</I> value.
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

## @method $get($i, $j)
# 
# @brief Retrieve the value of a cell.
#
# If the cell has a nodata or out-of-world value undef is returned.
# @param[in] i The i-coordinate of the cell.
# @param[in] j The j-coordinate of the cell.
# @return Value of the cell.

## @method @get($i, $j, $distance)
# 
# @brief Retrieve the value of a cell or the values of its neighborhood 
# (a rectangle) cells.
#
# If the cell has a nodata or it is out-of-world value undef is returned.
# @param[in] i The i-coordinate of the (center) cell.
# @param[in] j The j-coordinate of the (center) cell.
# @param[in] distance (optional) Integer value that specifies how large 
# neighborhood is returned.
# @return Values of the cell or its neighborhood cells. The maximum total amount 
# of returned values in the array is (2*distance+1)^2.
# @note If the distance is zero (0) then only one cells value is returned.
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

## @method $cell($i, $j, $value)
#
# @brief Set or get the value of a cell.
# @param[in] i The i-coordinate of the cell.
# @param[in] j The j-coordinate of the cell.
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

## @method protected $_type_name()
#
# @brief Returns the datatype of the object.
# @return Name of type. Type can be 'Integer', 'Real' or undef.
sub _type_name {
    my $self = shift;
    return undef unless $self->{DATATYPE}; # may happen if not cached
    return 'Integer' if $self->{DATATYPE} == $INTEGER_GRID;
    return 'Real' if $self->{DATATYPE} == $REAL_GRID;
    return undef;
}

## @method list value_range(%named_parameters)
#
# @brief Returns the minimum and maximum values of the raster grid.
# @param[in] named_parameters A hash of named parameters:
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
# @brief Returns the datatype of the raster grid as a string.
# @return Name of type if the object has a raster grid. Type can be 'Integer'
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

## @method @size($row, $column)
#
# @brief Returns the size (height, width) of the grid. If row and
# column of a cell are given returns the size of the zone of which the
# cell is a part of.
# @param[in] row (optional) 
# @param[in] column (optional)
# @return The size (height, width) of the grid.
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
# @brief Returns the cells size.
# @param[in] params A hash of named parameters:
# - <I>of_GDAL</I>=>boolean (optional) whether the cell size should be
# queried from GDAL (the actual data source) instead from libral (the
# memory raster).
# @return Size of cell (lenght of one side) if possible, else undef.
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

## @fn $bool()
#
# @brief Method returns a true value accepted by all methods of the object.
# @return True.
sub bool {
    my $self = shift;
    return 1;
}

## @method Geo::Raster clone()
#
# @brief Creates a clone from the Geo::Raster object, which is returned.
# @return A clone of this object.
sub clone {
    my $self = shift;
    Geo::Raster::new($self);
}

## @method Geo::Raster neg()
#
# @brief Creates a new copy of the Geo::Raster object with opposite values 
# compared to the current grids values.
#
# For example a cell with value 1 becomes a cell with value -1, and a cell
# with value -2.5 becomes a cell with value 2.5. Values can be of type 'Real' or
# 'Integer'.
# @return An Geo::Raster object with reverse values compared to the current 
# values.
sub neg {
    my $self = shift;
    my $copy = Geo::Raster::new($self);
    ral_grid_mult_integer($copy->{GRID}, -1);
    return $copy;
}

## @method protected $_typeconversion(Geo::Raster other)
#
# @brief Compares two datatypes and returns 'integer' if both have an integer as 
# datatype. Else returns a 'real'.
#
# @param[in] other A reference to an another Geo::Raster object.
# @return Returns integer if both have an integer as datatype, else a real type.
# @exception Parameter is not reference to a Geo::Raster object.

## @method protected $_typeconversion($datatype)
#
# @brief Compares two datatypes and returns 'integer' if both have an integer as 
# datatype. Else returns a 'real'.
#
# @param[in] datatype A datatype to compare with the objects datatype.
# @return Returns integer if both have an integer as datatype, else a real type.
# @exception Parameter is not a numeric datatype.
# @note Datatypes are only allowed to be real or integer.
sub _typeconversion {
    my($self,$other) = @_;
    if (ref($other)) {
	if (isa($other, 'Geo::Raster')) {
	    return $REAL_GRID if 
		$other->{DATATYPE} == $REAL_GRID or 
		$self->{DATATYPE} == $REAL_GRID;
	    return $INTEGER_GRID;
	} else {
	    croak "$other is not a grid\n";
	}
    } else {
	# perlfaq4: is scalar an integer ?
	return $self->{DATATYPE} if $other =~ /^-?\d+$/;
	
	# perlfaq4: is scalar a C float ?
	if ($other =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) {
	    return $REAL_GRID if $self->{DATATYPE} == $INTEGER_GRID;
	    return $self->{DATATYPE};
	}
	croak "$other is not numeric\n";
    }
}


## @method Geo::Raster plus($value)
#
# @brief Adds to returned raster grids cells this grids values plus the 
# given number.
#
# If this raster grid and the number differ in datatypes (other is integer and 
# the other real) then the returned raster grid will have as datatype real.
# 
# Example of summing
# @code
# $new_grid = $grid + $value;
# @endcode
# is the same as
# @code
# $new_grid = $grid->plus($value); 
# @endcode
#
# @param[in] value A number to add to this objects cell values.
# @return A copy of this raster grid with the additions from the other grid.
# @note In the case that this raster and the value differ in datatype, the 
# datatype conversion of the returned grid into real type makes it possible not 
# to use rounding.

## @method Geo::Raster plus(Geo::Raster second)
#
# @brief Adds to returned raster grids cells this grids values plus the 
# given grids values.
#
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# - If raster grids differ in datatypes (other is integer and the other real) 
# then the returned raster grid will have as datatype real.
# 
# Example of summing
# @code
# $new_grid = $grid + $second_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->plus($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
# @return A copy of this raster grid with the additions from the other grid.
# @note In the case of the two rasters differ in datatype, the datatype 
# conversion of the returned grid into real type makes it possible not to use 
# rounding (Also note that without the conversion the libral functions will 
# round that grids values that has real datatype).
sub plus {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    my $copy = Geo::Raster::new($self, datatype=>$datatype, copy=>$self);
    if (ref($second)) {
	ral_grid_add_grid($copy->{GRID}, $second->{GRID});
    } else {
	my $dt = ral_grid_get_datatype($copy->{GRID});
	if ($dt == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_add_integer($copy->{GRID}, $second);
	} else {
	    ral_grid_add_real($copy->{GRID}, $second);
	}
    }
    return $copy;
}

## @method Geo::Raster minus($value, $reversed)
#
# @brief Subtracts the given number from this grids values (or 
# vice versa if reversed is true) and gives those values to the returned grid.
#
# If this raster grid and the number differ in datatypes (other is integer and 
# the other real) then the returned raster grid will have as datatype real.
#
# Example of subtraction
# @code
# $new_grid = $grid - $value;
# @endcode
# is the same as
# @code
# $new_grid = $grid->minus($value);
# @endcode
#
# @param[in] value A number to subtract from this objects cell values.
# @param[in] reversed (optional) A boolean which tells in which order the 
# subtraction is done. If true, then the this objects grid cell values are 
# subtracted from the given value, else the the value is subtracted from this 
# grids values.
# @return A copy of this Geo::Raster with the subtractions made.
# @note In the case that this raster and the value differ in datatype, the 
# datatype conversion of the returned grid into real type makes it possible not 
# to use rounding.

## @method Geo::Raster minus(Geo::Raster second, $reversed)
#
# @brief Subtracts the given grids values from this grids values (or 
# vice versa if reversed is true) and gives those values to the returned grid.
#
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# - If raster grids differ in datatypes (other is integer and the other real) 
# then the returned raster grid will have as datatype real.
#
# Example of subtraction
# @code
# $new_grid = $grid - $second_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->minus($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
# @param[in] reversed (optional) A boolean which tells in which order the 
# subtraction is done. If true, then the this objects grid cell values are 
# subtracted from the second grids cells values, else the second grids values 
# are subtracted from this grids values.
# @return A copy of this Geo::Raster with the subtractions made.
# @note In the case of the two rasters differ in datatype, the datatype 
# conversion of the returned grid into real type makes it possible not to use 
# rounding.
sub minus {
    my($self, $second, $reversed) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    
    my $copy = Geo::Raster::new($self, datatype=>$datatype, copy=>$self);
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_grid_sub_grid($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    ral_grid_mult_integer($copy->{GRID}, -1);
	} else {
	    $second *= -1;
	}
	
	if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    # Second parameter is an integer.
	    ral_grid_add_integer($copy->{GRID}, $second);
	} else {
	    # Second parameter is a real.
	    ral_grid_add_real($copy->{GRID}, $second);
	}
    }
    return $copy;
}

## @method Geo::Raster times($value)
#
# @brief Multiplies the raster grids values with the given number 
# and returns a new grid with the resulting values.
#
# If this raster grid and the number differ in datatypes (other is integer and 
# the other real) then the returned raster grid will have as datatype real.
#
# Example of multiplication
# @code
# $new_grid = $grid * $value;
# @endcode
# is the same as
# @code
# $new_grid = $grid->times($value);
# @endcode
#
# @param[in] value A number with which to multiply this objects cell values.
# @return A copy of this Geo::Raster with the multiplication made.
# @note In the case that this raster and the given value differ in datatype, the 
# datatype conversion of the returned grid into real type makes it possible not 
# to use rounding.

## @method Geo::Raster times(Geo::Raster second)
#
# @brief Multiplies the raster grids values with the given grids
# values and returns a new grid with the resulting values.
#
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# - If raster grids differ in datatypes (other is integer and the other real) 
# then the returned raster grid will have as datatype real.
#
# Example of multiplication
# @code
# $new_grid = $grid * $second_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->times($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
# @return A copy of this Geo::Raster with the multiplication made.
# @note In the case of the two rasters differ in datatype, the datatype 
# conversion of the returned grid into real type makes it possible not to use 
# rounding.
sub times {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    my $copy = Geo::Raster::new($self, datatype=>$datatype, copy=>$self);
    if (ref($second)) {
	ral_grid_mult_grid($copy->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_mult_integer($copy->{GRID},$second);
	} else {
	    ral_grid_mult_real($copy->{GRID},$second);
	}
    }
    return $copy;
}

## @method Geo::Raster over($value, $reversed)
#
# @brief Divides the grids values with the number (or vice versa if reversed is 
# true) and returns the resulting values as a new raster grid.
#
# Example of division
# @code
# $new_grid = $grid / $value;
# @endcode
# is the same as
# @code
# $new_grid = $grid->over($value); 
# @endcode
#
# @param[in] value A number to use for dividing.
# @param[in] reversed (optional) A boolean which tells which one (the raster set 
# or the number) is the denominator. 
# If true then the this grids values are used as denominators, if
# false then the given number is used as denominator (the same thing as if 
# parameter would not be given at all).
# @return A copy of this Geo::Raster with the division made.
# @note The returned raster grid will always have as datatype real.

## @method Geo::Raster over(Geo::Raster second, $reversed)
#
# @brief Divides the grids values with the other grids values(or 
# vice versa if reversed is true) and returns the resulting values as a new 
# raster grid.
#
# The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
#
# Example of division
# @code
# $new_grid = $grid / $second_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->over($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
# @param[in] reversed (optional) A boolean which tells which raster set is the 
# denominator. If true then the this grids values are used as denominators, if
# false then given grid values are denominators (the same thing as if parameter
# would not be given at all).
# @return A copy of this Geo::Raster with the division made.
# @note The returned raster grid will always have as datatype real.
sub over {
    my($self, $second, $reversed) = @_;
    my $copy = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_grid_div_grid($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_integer_div_grid($second, $copy->{GRID});
	    } else {
		ral_real_div_grid($second, $copy->{GRID});
	    }
	} else {
	    if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_div_integer($copy->{GRID}, $second);
	    } else {
		ral_grid_div_real($copy->{GRID}, $second);
	    }
	}
    }
    return $copy;
}



sub over2 {
    my($self, $second, $reversed) = @_;
    my $copy;
    if($reversed) {
        $copy = new Geo::Raster datatype=>$REAL_GRID, copy=>$second;
    } else {
        $copy = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    }
    
    if (ref($second)) {
	# ($copy, $second) = ($second, $copy) if $reversed;
	if($reversed) {
	    ral_grid_div_grid($copy->{GRID}, $self->{GRID});
	} els {
	     ral_grid_div_grid($copy->{GRID}, $second->{GRID});
	}
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_integer_div_grid($second, $copy->{GRID});
	    } else {
		ral_real_div_grid($second, $copy->{GRID});
	    }
	} else {
	    if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_div_integer($copy->{GRID}, $second);
	    } else {
		ral_grid_div_real($copy->{GRID}, $second);
	    }
	}
    }
    return $copy;
}

## @method Geo::Raster modulo($value, $reversed)
#
# @brief Calculates the modulus gotten by dividing the grids values with 
# the given number (or vice versa if reversed is true) and 
# returns a new grid with result values.
#
# Example of modulus
# @code
# $new_grid = $grid % $value;
# @endcode
# is the same as
# @code
# $new_grid = $grid->modulo($value); 
# @endcode
#
# @param[in] value A integer number used for dividing.
# @param[in] reversed (optional) A boolean which tells which one (the raster set 
# or the number) is the denominator. 
# If true then the this grids values are used as denominators, if
# false then the given number is used as denominator (the same thing as if 
# parameter would not be given at all).
# @return A copy of this Geo::Raster with the division remainders.
# @note This raster grid has to have integer as datatype and
# the returned raster grid will always have integer as datatype.

## @method Geo::Raster modulo(Geo::Raster second, $reversed)
#
# @brief Calculates the modulus gotten by dividing the grids values with 
# the given grids values (or vice versa if reversed is true) and 
# returns a new grid with result values.
#
# The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
#
# Example of modulus
# @code
# $new_grid = $grid % $second_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->modulo($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster having integer as datatype.
# @param[in] reversed (optional) A boolean which tells which raster set is the 
# divisor and dividend. If true then the this grids values are used as 
# denominators, if false then given grid values or the number are denominators 
# (the same thing as if parameter would not be given at all).
# @return A copy of this Geo::Raster with the division remainders.
# @note This raster grid has to have integer as datatype and
# the returned raster grid will always have integer as datatype.
sub modulo {
    my($self, $second, $reversed) = @_;
    my $copy = new Geo::Raster($self);
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_grid_modulus_grid($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    ral_integer_modulus_grid($second, $copy->{GRID});
	} else {
	    ral_grid_modulus_integer($copy->{GRID}, $second);
	}
    }
    return $copy;
}

## @method Geo::Raster power($value, $reversed)
#
# @brief Calculates the exponential values gotten by using the grids values 
# as bases the given number as exponents (or vice versa if 
# reversed is true) and returns a new grid with the calculated values.
#
# If this raster grid and the number differ in datatypes (other is integer and 
# the other real) then the returned raster grid will have as datatype real.
#
# Example of rising to the power defined by the parameter
# @code
# $new_grid = $grid ** $exponent;
# @endcode
# is the same as
# @code
# $new_grid = $grid->power($exponent); 
# @endcode
#
# @param[in] value A number used as exponent (or base, if reversed is true).
# @param[in] reversed (optional) A boolean which tells which one (the raster set 
# or the number) is the exponent, and which as base. 
# If true then the this grids values are used as exponents, if false then the 
# given number is used as exponent (the same thing as if parameter would not be 
# given at all).
# @return A copy of this Geo::Raster with the exponentation done.

## @method Geo::Raster power(Geo::Raster second, $reversed)
#
# @brief Calculates the exponential values gotten by using the grids values 
# as bases the given grids values as exponents (or vice versa if 
# reversed is true) and returns a new grid with the calculated values.
#
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# - If the raster grids differ in datatypes (other is integer and the other real) 
# then the returned raster grid will have as datatype real.
#
# Example of rising to the powers defined the given grid
# @code
# $new_grid = $grid ** $exponent_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->power($exponent_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
# @param[in] reversed (optional) A boolean which tells which raster set is the 
# base and which the exponent. If true then the this grids values are used as 
# exponents, if false then given grid values or the number are exponents 
# (the same thing as if parameter would not be given at all).
# @return A copy of this Geo::Raster with the exponentation done.
sub power {
    my($self, $second, $reversed) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    my $copy = Geo::Raster::new($self, datatype=>$datatype, copy=>$self);
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_grid_power_grid($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    ral_realpower_grid($second, $copy->{GRID});
	} else {
	    ral_grid_power_real($copy->{GRID}, $second);
	}
    }
    return $copy;
}

## @method add($value)
#
# @brief Adds the given number to the cell values.
#
# - The method is almost the same as Geo::Raster::plus(), except that in this 
# method the addition is done directly to this grid, not a new one.
# - If this raster grid and the number differ in datatypes (other is integer and 
# the other real) then this raster grid will have as datatype real after the 
# operation.
#
# Example of addition
# @code
# $grid += $value;
# @endcode
# is the same as
# @code
# $grid->add($value); 
# @endcode
#
# @param[in] value The number to add.

## @method Geo::Raster add(Geo::Raster second)
#
# @brief Adds to the cells the respective cell values of the given raster 
#
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# - If raster grids differ in datatypes (other is integer and the other real) 
# then the this raster grid will have as datatype real.
# - The method is almost the same as Geo::Raster::plus(), except that in this 
# method the addition is done directly to this grid, not a new one.
# 
# Example of addition
# @code
# $grid += $second_grid;
# @endcode
# is the same as
# @code
# $grid->add($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster or a number.
sub add {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $datatype)) 
    	if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_grid_add_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_add_integer($self->{GRID}, $second);
	} else {
	    ral_grid_add_real($self->{GRID}, $second);
	}
    }
    return $self;
}

## @method Geo::Raster subtract($value)
#
# @brief Subtracts the given number from the cell values.
#
# - The method is almost the same as Geo::Raster::minus(), except that in this 
# method the subtraction is done directly to this grid, not a new one. And there
# is also no reversed possibility.
# - If this raster grid and the number differ in datatypes (other is integer and 
# the other real) then this raster grid will have as datatype real after the 
# operation.
#
# Example of subtraction
# @code
# $grid -= $value;
# @endcode
# is the same as
# @code
# $grid->subtract($value); 
# @endcode
#
# @param[in] value A number that is subtracted from all cells of this grid.

## @method Geo::Raster subtract(Geo::Raster second)
#
# @brief Subtracts from the cell value the respective cell values of the given raster.
#
# - The method is almost the same as Geo::Raster::minus(), except that in this 
# method the subtraction is done directly to this grid, not a new one. And there
# is also no reversed possibility.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# - If raster grids differ in datatypes (other is integer and the other real) 
# then this raster grid will have as datatype real after the method.
#
# Example of subtraction
# @code
# $grid -= $second_grid;
# @endcode
# is the same as
# @code
# $grid->subtract($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
sub subtract {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_grid_sub_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_add_integer($self->{GRID}, -$second);
	} else {
	    ral_grid_add_real($self->{GRID}, -$second);
	}
    }
    return $self;
}

## @method Geo::Raster multiply_by($value)
#
# @brief Multiplies the cell values with the given number.
#
# - The method is almost the same as Geo::Raster::times(), except that in this 
# method the multiplication is done directly to this grid, not a new one!
# - If this raster grid and the number differ in datatypes (other is integer and 
# the other real) then this raster grid will have as datatype real after the 
# operation.
#
# Example of multiplication
# @code
# $grid *= $multiplier;
# @endcode
# is the same as
# @code
# $grid->multiply_by($multiplier); 
# @endcode
#
# @param[in] value Number used as multiplier.

## @method Geo::Raster multiply_by(Geo::Raster second)
#
# @brief Multiplies the cell values with the respective cell values of the given raster.
#
# - The method is almost the same as Geo::Raster::times(), except that in this 
# method the multiplication is done directly to this grid, not a new one!
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# - If raster grids differ in datatypes (other is integer and the other real) 
# then this raster grids datatype will be real after the calculation.
#
# Example of multiplication
# @code
# $grid *= $multiplier_grid;
# @endcode
# is the same as
# @code
# $grid->multiply_by($multiplier_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
sub multiply_by {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_grid_mult_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_mult_integer($self->{GRID}, $second);
	} else {
	    ral_grid_mult_real($self->{GRID}, $second);
	}
    }
    return $self;
}

## @method Geo::Raster divide_by($value)
#
# @brief Divides the cell values with the given number.
#
# - The method is almost the same as Geo::Raster::over(), except that in this 
# method the division is done directly to this grid, not a new one. And there
# is also no reversed possibility.
#
# Example of division
# @code
# $grid /= $denominator;
# @endcode
# is the same as
# @code
# $grid->divide_by($denominator); 
# @endcode
#
# @param[in] value Number used as denominator.
# @note The returned raster grid will always have as datatype real.

## @method Geo::Raster divide_by(Geo::Raster second)
#
# @brief Divides the cell values with the respective cell values of the other raster.
#
# - The method is almost the same as Geo::Raster::over(), except that in this 
# method the division is done directly to this grid, not a new one. And there
# is also no reversed possibility.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
#
# Example of division
# @code
# $grid /= $denominator_grid;
# @endcode
# is the same as
# @code
# $grid->divide_by($denominator_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster, which cells values are 
# used as denominators.
# @note The returned raster grid will always have as datatype real.
sub divide_by {
    my($self, $second) = @_;
    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    if (ref($second)) {
	ral_grid_div_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_div_integer($self->{GRID}, $second);
	} else {
	    ral_grid_div_real($self->{GRID}, $second);
	}
    }
    return $self;
}

## @method Geo::Raster modulus_with($value)
#
# @brief Calculates the modulus gotten by dividing the cell values with 
# the given integer value.
#
# The method is almost the same as Geo::Raster::modulo(), except that in this 
# method the modulus is done directly to this grid, not a new one. And there
# is also no reversed possibility.
#
# Example of calculating the modulus
# @code
# $grid %= $denominator;
# @endcode
# is the same as
# @code
# $grid->modulus_with($denominator); 
# @endcode
#
# @param[in] value Number to use as denominator.
# @note The operation does not affect the datatype.

## @method Geo::Raster modulus_with(Geo::Raster second)
#
# @brief Calculates the modulus gotten by dividing the cell values with 
# the respective cell values of the given integer raster.
#
# - The method is almost the same as Geo::Raster::modulo(), except that in this 
# method the modulus is done directly to this grid, not a new one. And there
# is also no reversed possibility.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
#
# Example of calculating the modulus
# @code
# $grid %= $denominator_grid;
# @endcode
# is the same as
# @code
# $grid->modulus_with($denominator_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster, which values are used
# as denominators.
# @note The operation does not affect the datatype.
sub modulus_with {
    my($self, $second) = @_;
    if (ref($second)) {
	ral_grid_modulus_grid($self->{GRID}, $second->{GRID});
    } else {
	ral_grid_modulus_integer($self->{GRID}, $second);
    }
    return $self;
}

## @method Geo::Raster to_power_of($power)
#
# @brief Raises the cell values to the given power.
# 
# - The method is almost the same as Geo::Raster::power(), except that in this 
# method the power is calculated directly to this grid, not a new one. And there
# is also no reversed possibility.
# - If this raster grid and the parameter differ in datatypes (other is integer 
# and the other real) then this raster grid will have as datatype real after the 
# operation.
#
# Example of calculating the power
# @code
# $grid **= $exponent;
# @endcode
# is the same as
# @code
# $grid->to_power_of($exponent); 
# @endcode
#
# @param[in] power Number used as exponent.

## @method Geo::Raster to_power_of(Geo::Raster second)
#
# @brief Raises the cell values to the power of the respective cell values of the given raster.
#
# - The method is almost the same as Geo::Raster::power(), except that in this 
# method the power is calculated directly to this grid, not a new one. And there
# is also no reversed possibility.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# - If the raster grids differ in datatypes (other is integer and the other real) 
# then this raster grids datatype will have after the operation as datatype real.
#
# Example of calculating the power
# @code
# $grid **= $exponent_grid;
# @endcode
# is the same as
# @code
# $grid->to_power_of($exponent_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster defining the exponents 
# for each cell.
sub to_power_of {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_grid_power_grid($self->{GRID}, $second->{GRID});
    } else {
	ral_grid_power_real($self->{GRID}, $second);
    }
    return $self;
}

## @method Geo::Raster atan2(Geo::Raster second)
#
# @brief Calculates the arctangent between each cells value of the grid and 
# given grids values.
#
# - With the arctangent we get the direction between the two cell values in
# 2-dimemsional Euclidean space.
# - The operation is performed in-place in void context
# - The second raster grids real world boundaries must be the same as this
# raster grids. The cell sizes and amounts in both directions must also be equal.
#
# @param[in] second Reference to an another Geo::Raster.
# @return A new Geo::Raster having the calculated directions.
# @note The resulting raster grid will always have as datatype real.
sub atan2 {
    my($self, $second) = @_;
    if (ref($self) and ref($second)) {
	if (defined wantarray) {
	    $self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
	} elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
	}
	ral_grid_atan2($self->{GRID}, $second->{GRID});
	return $self;
    } else {
	croak "don't mix scalars and grids in atan2, please";
    }
}

## @method Geo::Raster cos()
#
# @brief Calculates the cosine of the grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated cosine values.
# @note The resulting raster grid will always have as datatype real.
sub cos {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_cos($self->{GRID});
    return $self;
}

## @method Geo::Raster sin()
#
# @brief Calculates the sine of the grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the sine values.
# @note The resulting raster grid will always have as datatype real.
sub sin {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_sin($self->{GRID});
    return $self;
}

## @method Geo::Raster exp()
#
# @brief Calculates the exponential function with Euler's number as base of the 
# grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculation results.
# @note The resulting raster grid will always have as datatype real.
sub exp {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_exp($self->{GRID});
    return $self;
}

## @method Geo::Raster abs()
#
# @brief Calculates the absolute value of the grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having non-negative values.
sub abs {
    my $self = shift;
    if (defined wantarray) {
	my $copy = new Geo::Raster($self);
	ral_grid_abs($copy->{GRID});
	return $copy;
    } else {
	ral_grid_abs($self->{GRID});
    }
}

## @method Geo::Raster log()
#
# @brief Calculates the logarithm of the grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the logarithmic values.
# @note The resulting raster grid will always have as datatype real.
sub log {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_log($self->{GRID});
    return $self;
}

## @method Geo::Raster sqrt()
#
# @brief Calculates the square root of the grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
# @note The resulting raster grid will always have as datatype real.
sub sqrt {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_sqrt($self->{GRID});
    return $self;
}

## @method Geo::Raster round()
#
# @brief Rounds grids each value to the nearest integer value.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
# - If the raster grid has already a as datatype integer, the operation does 
# nothing.
#
# @return A new Geo::Raster having the integer values.
# @note The resulting raster grid will always have as datatype integer.
sub round {
    my $self = shift;
    if (ref($self)) {
	my $grid = ral_grid_round($self->{GRID});
	return unless $grid;
	if (defined wantarray) {
	    my $new = new Geo::Raster $grid;
	    return $new;
	} else {
	    $self->_new_grid($grid);
	}
    } else {
	return $self < 0 ? POSIX::floor($self - 0.5) : POSIX::floor($self + 0.5);
    }
}

{
    no warnings 'redefine';

## @method Geo::Raster acos()
#
# @brief Calculates the arccosine of the grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
# @note The resulting raster grid will always have as datatype real.
sub acos {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_acos($self->{GRID});
    return $self;
}

## @method Geo::Raster atan()
#
# @brief Calculates the arctangent of the grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
# @note The resulting raster grid will always have as datatype real.
sub atan {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_atan($self->{GRID});
    return $self;
}

## @method Geo::Raster ceil()
#
# @brief Calculates the ceiling of the grids each value.
#
# Ceiling is the smallest integer value not less than the grids original value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
sub ceil {
    my $self = shift;
    if (ref($self)) {
	$self = new Geo::Raster($self) if defined wantarray;
	ral_grid_ceil($self->{GRID});
	return $self;
    } else {
	return POSIX::ceil($self);
    }
}

## @method Geo::Raster cosh()
#
# @brief Calculates the hyperbolic cosine of the grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated cosine values.
# @note The resulting raster grid will always have as datatype real
sub cosh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_cosh($self->{GRID});
    return $self;
}

## @method Geo::Raster floor()
#
# @brief Calculates the ceiling of the grids each value.
#
# Floor is the largest integer value not higher than the grids original value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values
sub floor {
    my $self = shift;
    if (ref($self)) {
	$self = new Geo::Raster($self) if defined wantarray;
	ral_grid_floor($self->{GRID});
	return $self;
    } else {
	return POSIX::floor($self);
    }
}

## @method Geo::Raster log10()
#
# @brief Calculates the base-10 logarithm of the grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the logarithmic values.
# @note The resulting raster grid will always have as datatype real.
sub log10 {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_log10($self->{GRID});
    return $self;
}

## @method Geo::Raster sinh()
#
# @brief Calculates the hyperbolic sine of the grids each value.
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated hyperbolic sine values.
# @note The resulting raster grid will always have as datatype real
sub sinh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_sinh($self->{GRID});
    return $self;
}

## @method Geo::Raster tan()
#
# @brief Calculates the tangent of the grids each value.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
# @note The resulting raster grid will always have as datatype real.
sub tan {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_tan($self->{GRID});
    return $self;
}

## @method Geo::Raster tanh()
#
# @brief Calculates the hyperbolic tangent of the grids each value.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
# @note The resulting raster grid will always have as datatype real.
sub tanh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_tanh($self->{GRID});
    return $self;
}
}

## @method Geo::Raster lt($number, $reversed)
#
# @brief The method tells if the raster grids cells have smaller values than the 
# given given number. Comparison result is returned if needed.
#
# There are four cases of the use of comparison operations between this grid and a number:
# <center><table border="1">
# <tr><th>Case</th><th>Example</th>     <th>a unchanged</th>  <th>self</th> <th>number</th> <th>reversed</th><th>wantarray defined</th></tr>
# <tr><td>1.</td><td>b = a->lt(n);</td>   <td>yes</td>        <td>a</td>    <td>n</td>       <td>no</td>         <td>yes</td></tr>
# <tr><td>2.</td><td>a->lt(n);</td>       <td>no</td>         <td>a</td>    <td>n</td>       <td>no</td>         <td>no</td></tr>
# <tr><td>3.</td><td>b = a < n;</td>      <td>yes</td>        <td>a</td>    <td>n</td>       <td>no</td>         <td>yes</td></tr>
# <tr><td>4.</td><td>b = n < a;</td>      <td>yes</td>        <td>a</td>    <td>n</td>       <td>yes</td>        <td>yes</td></tr>
# </table></center>
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed (look at case 2), else a new grid with the comparison results 
# is returned.
# 
# @param[in] number Number used for comparison.
# @param[in] reversed (optional) Tells the comparison order. If true then the 
# method checks if the given parameters value(s) are less than the raster grids 
# cells values. If false, then the method acts as no reverse parameter would 
# have given.
# @return Geo::Raster, which has zeros (0) in those cells that are greater or 
# equal and therefor don't fulfil the comparison condition. If the raster grids 
# value is less than the comparison value, then the cell gets a value true (1).
# @note If this grids some cells do not have any value, those cells 
# resulting value will also be undef.

## @method Geo::Raster lt(Geo::Raster second)
#
# @brief The method tells if the raster grids cells have smaller values than the 
# given raster grids cells. Comparison result is returned if needed.
#
# There are three cases of the use of comparison operations between two grids:
# <table border="1">
# <tr><th>Case</th><th>Example</th>     <th>a unchanged</th>  <th>self</th> <th>second</th> <th>wantarray defined</th></tr>
# <tr><td>1.</td><td>c = a->lt(b);</td>   <td>yes</td>        <td>a</td>    <td>b</td>       <td>yes</td></tr>
# <tr><td>2.</td><td>a->lt(b);</td>       <td>no</td>         <td>a</td>    <td>b</td>       <td>no</td></tr>
# <tr><td>3.</td><td>c = a < b;</td>      <td>yes</td>        <td>a</td>    <td>b</td>       <td>yes</td></tr>
# </table>
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed (look at case 2), else a new grid with the comparison results 
# is returned.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster.
# @return Geo::Raster, which has zeros (0) in those cells that are greater or 
# equal and therefor don't fulfil the comparison condition. If the raster grids 
# value is less than the comparison value, then the cell gets a value true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
sub lt {
    my($self, $second, $reversed) = @_;    
    $self = Geo::Raster::new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_lt_grid($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_gt_integer($self->{GRID}, $second);
	    } else {
		ral_grid_gt_real($self->{GRID}, $second);
	    }
	} else {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_lt_integer($self->{GRID}, $second);
	    } else {
		ral_grid_lt_real($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster gt($number, $reversed)
#
# @brief The method tells if the raster grids cells have greater values than the 
# given number. Comparison result is returned if  needed.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# 
# @param[in] number Number used for comparison.
# @param[in] reversed (optional) Tells the comparison order. If true then the 
# method checks if the given parameters value(s) are greater than the raster 
# grids cells values. If false, then the method acts as no reverse parameter 
# would have been given.
# @return Geo::Raster, which has zeros (0) in those cells that are less or 
# equal and therefor don't fulfil the comparison condition. If the raster grids 
# value is greater than the comparison value, then the cell gets a value true 
# (1).
# @note If this grids some cells do not have any value, those cells 
# resulting value will also be undef.

## @method Geo::Raster gt(Geo::Raster second)
#
# @brief The method tells if the raster grids cells have greater values than the 
# given raster grids cells. Comparison result is returned if needed.
#
# There are three cases of the use of comparison operations between two grids:
# <table border="1">
# <tr><th>Case</th><th>Example</th>     <th>a unchanged</th>  <th>self</th> <th>second</th> <th>wantarray defined</th></tr>
# <tr><td>1.</td><td>c = a->gt(b);</td>   <td>yes</td>        <td>a</td>    <td>b</td>       <td>yes</td></tr>
# <tr><td>2.</td><td>a->gt(b);</td>       <td>no</td>         <td>a</td>    <td>b</td>       <td>no</td></tr>
# <tr><td>3.</td><td>c = a > b;</td>      <td>yes</td>        <td>a</td>    <td>b</td>       <td>yes</td></tr>
# </table>
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed (look at case 2), else a new grid with the comparison results 
# is returned.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster.
# @return Geo::Raster, which has zeros (0) in those cells that are less or 
# equal and therefor don't fulfil the comparison condition. If the raster grids 
# value is greater than the comparison value, then the cell gets a value true 
# (1).
sub gt {
    my($self, $second, $reversed) = @_;
    $self = Geo::Raster::new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_gt_grid($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_lt_integer($self->{GRID}, $second);
	    } else {
		ral_grid_lt_real($self->{GRID}, $second);
	    }
	} else {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_gt_integer($self->{GRID}, $second);
	    } else {
		ral_grid_gt_real($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster le($number, $reversed)
#
# @brief The method tells if the raster grids cells have smaller or equal values 
# compared to the given number. Comparison result is returned if needed.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# 
# @param[in] number Number used for comparison.
# @param[in] reversed (optional) Tells the comparison order. If true then the 
# method checks if the given parameters value(s) are less or equal than the 
# raster grids cells values. If false, then the method acts as no reverse 
# parameter would have given.
# @return Geo::Raster, which has zeros (0) in those cells that are greater 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.

## @method Geo::Raster le(Geo::Raster second)
#
# @brief The method tells if the raster grids cells have smaller or equal values 
# compared to the given raster grids cells. Comparison result is returned if 
# needed.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster.
# @return Geo::Raster, which has zeros (0) in those cells that are greater 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
sub le {
    my($self, $second, $reversed) = @_;
    $self = Geo::Raster::new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_le_grid($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_ge_integer($self->{GRID}, $second);
	    } else {
		ral_grid_ge_real($self->{GRID}, $second);
	    }
	} else {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_le_integer($self->{GRID}, $second);
	    } else {
		ral_grid_le_real($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster ge($number, $reversed)
#
# @brief The method tells if the raster grids cells have greater or equal values 
# compared to the given number. Comparison result is returned if needed.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# 
# @param[in] number Number used for comparison.
# @param[in] reversed (optional) Tells the comparison order. If true then the 
# method checks if the given parameters value(s) are greater or equal than the 
# raster grids cells values. If false, then the method acts as no reverse 
# parameter would have given.
# @return Geo::Raster, which has zeros (0) in those cells that are less 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.

## @method Geo::Raster ge(Geo::Raster second)
#
# @brief The method tells if the raster grids cells have greater or equal values 
# compared to the given raster grids cells. Comparison result is returned if 
# needed.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster.
# @return Geo::Raster, which has zeros (0) in those cells that are less 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
sub ge {
    my($self, $second, $reversed) = @_;
    $self = Geo::Raster::new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_ge_grid($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_le_integer($self->{GRID}, $second);
	    } else {
		ral_grid_le_real($self->{GRID}, $second);
	    }
	} else {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_ge_integer($self->{GRID}, $second);
	    } else {
		ral_grid_ge_real($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster eq($number)
#
# @brief The method tells if the raster grids cells have equal values 
# compared to the given number. Comparison result is returned if needed.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# 
# @param[in] number Number used for comparison.
# @return Geo::Raster, which has zeros (0) in those cells that are not equal 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.

## @method Geo::Raster ge(Geo::Raster second)
#
# @brief The method tells if the raster grids cells have equal values 
# compared to the given raster grids cells. Comparison result is returned if 
# needed.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster.
# @return Geo::Raster, which has zeros (0) in those cells that are not equal 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
sub eq {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster::new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_eq_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_eq_integer($self->{GRID}, $second);
	} else {
	    ral_grid_eq_real($self->{GRID}, $second);
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster ne($second)
#
# @brief The method tells if the raster grids cells have not equal values 
# compared to the given raster grids cells or given number. Comparison result is 
# returned if needed.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster or a number.
# @return Geo::Raster, which has zeros (0) in those cells that are equal 
# and therefor don't fulfil the comparison condition. An equally valued cell 
# gets a value true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
sub ne {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster::new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_ne_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_ne_integer($self->{GRID}, $second);
	} else {
	    ral_grid_ne_real($self->{GRID}, $second);
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster cmp($second, $reversed)
#
# @brief The method tells if the raster grids cells have not equal values 
# compared to the given raster grids cells or given number. Comparison result is 
# returned if needed.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# - The comparison rasters can differ in datatype.
# - If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
#
# @param[in] second Reference to an another Geo::Raster or a number.
# @param[in] reversed Tells the comparison order. If true then the method does  
# the comparison in reversed order. The returned method then returns as values 
# -1 in those cells that are greater in this raster, 1 in those that are less 
# and 0 in those cells that have equal values (equal case is same and not equal 
# cases just have a reversed sign compared to direct comparison results).
# @return Geo::Raster, which has as values 1 in those cells that are greater in
# this raster, -1 in those that are less and 0 in those cells that have equal 
# values.
sub cmp {
    my($self, $second, $reversed) = @_;
    $self = Geo::Raster::new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_cmp_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_cmp_integer($self->{GRID}, $second);
	} else {
	    ral_grid_cmp_real($self->{GRID}, $second);
	}
	if ($reversed) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_mult_integer($self->{GRID}, -1);
	    } else {
		ral_grid_mult_real($self->{GRID}, -1);
	    }
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster not()
#
# @brief The operator returns the logical negation of each raster cell value.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The raster grids datatype must be integer.
# - The resulting value is 1 if the original raster cell has a value 0, else the
# resulting value is 0.
#
# @return Geo::Raster with results from using the not operator.
# @exception The raster grids datatype is not integer.
sub not {
    my $self = shift;
    $self = Geo::Raster::new($self) if defined wantarray;
    ral_grid_not($self->{GRID});
    return $self if defined wantarray;
}

## @method Geo::Raster and(Geo::Raster second)
#
# @brief The operator returns the logical conjuction of this raster grid and
# given grids cells values.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The raster grids must have the same amount of cells in both directions.
# - The raster grids datatypes must be integer.
# - The resulting cell value will be 1 if both raster grids have in the same 
# cell nonzero values, else the resulting value is 0.
# - If the other or both raster grid cells have an <I>no data</I> value, then 
# also the resulting cell will have that value.
# .
# The (truth) table here shows all possible value combinations (not incl. no 
# data):
#<table>
#<tr><th>Resulting value</th><th>Own value</th><th>Parameter value</th></tr>
#<tr><td>1</td><td>not 0</td><td>not 0</td></tr>
#<tr><td>0</td><td>0</td><td>0</td></tr>
#<tr><td>0</td><td>0</td><td>not 0</td></tr>
#<tr><td>0</td><td>not 0</td><td>0</td></tr>
#</table>
#
# @param[in] second A Geo::Raster, which cell values are used to calculate the 
# logical conjunction.
# @return Geo::Raster with results from using the AND operator.
# @exception The raster grids datatype is not integer.
sub and {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster::new($self) if defined wantarray;
    ral_grid_and_grid($self->{GRID}, $second->{GRID});
    return $self if defined wantarray;
}

## @method Geo::Raster or(Geo::Raster second)
#
# @brief The operator returns the logical disjuction of this raster grid and
# given grids cells values.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The raster grids must have the same amount of cells in both directions.
# - The raster grids datatypes must be integer.
# - The resulting cell value will be 1 if both raster grids don't have in the 
# same cell 0, else the resulting value is 1.
# - If the other or both raster grid cells have an <I>no data</I> value, then 
# also the resulting cell will have that value.
# .
# The (truth) table here shows all possible value combinations (not incl. no 
# data):
#<table>
#<tr><th>Resulting value</th><th>Own value</th><th>Parameter value</th></tr>
#<tr><td>1</td><td>not 0</td><td>not 0</td></tr>
#<tr><td>0</td><td>0</td><td>0</td></tr>
#<tr><td>1</td><td>0</td><td>not 0</td></tr>
#<tr><td>1</td><td>not 0</td><td>0</td></tr>
#</table>
#
# @param[in] second A Geo::Raster, which cell values are used to calculate the 
# logical disjunction.
# @return Geo::Raster with results from using the OR operator.
# @exception The raster grids datatype is not integer.
sub or {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster::new($self) if defined wantarray;
    ral_grid_or_grid($self->{GRID}, $second->{GRID});
    return $self if defined wantarray;
}

## @method Geo::Raster nor($second)
#
# @brief The operator returns the inverse of disjunction of this raster 
# grid and given grids cells values.
#
# - The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The raster grids must have the same amount of cells in both directions.
# - The raster grids datatypes must be integer.
# - The resulting cell value will be 1 if both raster grids have in the same 
# cell 0, else the resulting value is 1.
# - If the other or both raster grid cells have an <I>no data</I> value, then 
# also the resulting cell will have that value.
# .
# The (truth) table here shows all possible value combinations (not incl. no 
# data):
#<table>
#<tr><th>Resulting value</th><th>Own value</th><th>Parameter value</th></tr>
#<tr><td>0</td><td>not 0</td><td>not 0</td></tr>
#<tr><td>1</td><td>0</td><td>0</td></tr>
#<tr><td>0</td><td>0</td><td>not 0</td></tr>
#<tr><td>0</td><td>not 0</td><td>0</td></tr>
#</table>
#
# @param[in] second A Geo::Raster, which cell values are used to calculate the 
# logical inverse of disjunction.
# @return Geo::Raster with results from using the NOR operator.
# @exception The raster grids datatype is not integer.
sub nor {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster::new($self) if defined wantarray;
    ral_grid_or_grid($self->{GRID}, $second->{GRID});
    $self->not();
    return $self if defined wantarray;
}

## @method Geo::Raster min($param)
# 
# @brief Set each cell to the minimum of cell's own value or parameter (which 
# ever is smaller).
# 
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the minimum values is returned.
#
# @param[in] param Number to compare with the raster cell values.
# @return A raster grid with values equal to those of this grids or parameters, 
# which ever are smaller.

## @method Geo::Raster min(Geo::Raster second)
# 
# @brief Set each cell to the minimum of cells own value or parameter grids 
# cells value (which ever is smaller).
#
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the minimum values is returned.
#
# @param[in] second A reference to an another raster, whose cells define the 
# comparison value for each of this raster grids cells.
# @return A raster grid with values equal to those of this grids or parameter 
# grids, which ever are smaller.

## @method $min()
# 
# @brief Returns the smallest value in the raster grid.
# @return The minimum of the raster grid.
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
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the maximum values is returned.
#
# @param[in] param Number to compare with the raster cell values.
# @return A raster grid with values equal to those of this grids or parameters, 
# which ever are higher.

## @method Geo::Raster max(Geo::Raster second)
# 
# @brief Set each cell to the maximum of cell's own value or parameter grids 
# cells value (which ever is greater).
# 
# The operation is performed to this raster grid, if no resulting new raster 
# grid is needed, else a new grid with the maximum values is returned.
#
# @param[in] second A reference to an another raster, whose cells define the 
# comparison value for each of this raster grids cells.
# @return A raster grid with values equal to those of this grids or parameters, 
# which ever are higher.

## @method $max()
# 
# @brief Returns the highest value in the raster grid.
# @return The maximum of the raster grid.
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

sub random {
    my $self = shift;
    $self = Geo::Raster::new($self) if defined wantarray;
    ral_grid_random($self->{GRID});
    return $self if defined wantarray;
}

## @method Geo::Raster cross(Geo::Raster b)
# 
# @brief Cross product of raster grids.
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
# - The operation results are given to this raster grid, if no resulting new 
# raster grid is needed, else a new grid with the cross product values is 
# returned.
# - The raster grids datatypes must be integer.
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be equal.
# - If the other or both raster grid cells have an <I>no data</I> value, then 
# also the resulting cell will have that value.
#
# @param[in] b A reference to an another Geo::Raster object.
# @return A new raster grid with the calculated cross product values.
sub cross {
    my($a, $b) = @_;
    my $c = ral_grid_cross($a->{GRID}, $b->{GRID}); 
    return new Geo::Raster ($c) if defined wantarray;
    $a->_new_grid($c) if $c;
}

## @method Geo::Raster if(Geo::Raster b, $c)
# 
# @brief If...then statement construct for grids.
#
# Example of usage:
# @code
# $a->if($b, $c);
# @endcode
# where $a and $b are references to grids and $c can be a reference to a grid or 
# a scalar. The effect of this subroutine is:
#
# 	for all i, j if (b[i, j]) then a[i, j]=c[i, j]
#
# If a return value is requested:
# @code
# $d = $a->if($b, $c);
# @endcode
# then d[i, j] is a[i, j] if b[i, j] == 0, else d[i, j] = c  
# (or in case $c is a reference to a grid: d[i, j] = c[i, j] ).
#
# - If $c is a reference to a zonal mapping hash, i.e., it has value pairs
# k=>v, where k is an integer, which represents a zone in b, then a is
# set to v on that zone. A zone mapping hash can, for example, be
# obtained using the zonal functions (see for example 
# Geo::Raster::zonal_count(), ...).
# - The second raster grids real world boundaries must be the same as this 
# raster grids. The cell sizes and amounts in both directions must also be 
# equal.
# - The operation results are given to this raster grid, if no resulting new 
# raster grid is needed.
#
# @param[in] b Reference to an another raster grid.
# @param[in] c Reference to an another raster grid or zonal mapping hash or a 
# number.
# @return A raster grid with the results gotten according to the statement.

## @method Geo::Raster if(Geo::Raster b, $c, $d)
# 
# @brief If...then...else statement construct for grids.
#
# Example of usage:
# @code
# 	$a->if($b, $c, $d);
# @endcode
# where $a and $b are references to grids. $c and $d can be a references to 
# grids or scalars. The effect of this subroutine is:
#
# 	for all i, j if (b[i, j]) then a[i, j]=c[i, j] else a[i, j]=d[i, j]
#
# If a return value is requested:
# @code
#	$e = $a->if($b, $c, $d);
# @endcode
# then e[i, j] is d[i, j] if b[i, j] == 0, else e[i, j] = c  
# (or in case $c is a grid e[i, j] = c[i, j] ).
#
# - If $c is a reference to a zonal mapping hash, i.e., it has value pairs
# k=>v, where k is an integer, which represents a zone in b, then a is
# set to v on that zone. A zone mapping hash can, for example, be
# obtained using the zonal functions (see for example 
# Geo::Raster::zonal_count(), ...).
# - The second and third raster grids real world boundaries must be the same as 
# this raster grids. The cell sizes and amounts in both directions must also be 
# equal.
# - The operation results are given to this raster grid, if no resulting new 
# raster grid is needed.
#
# @param[in] b Reference to an another raster grid.
# @param[in] c Reference to an another raster grid or zonal mapping hash or a 
# number.
# @param[in] d Reference to an another raster grid or zonal mapping hash or a 
# number.
# @return A raster grid with the results gotten according to the statement.
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

## @method Geo::Raster binary()
#
# @brief Convert an integer image into a binary image.
# @return A binary image (grid with only ones and zeros).
# @note Writing $g->ne(0) has the same effect as $g->binary().
sub binary {
    my $self = shift;
    return gdbinary($self->{GRID});
}

## @method Geo::Raster bufferzone($z, $w)
#
# @brief Creates buffer zones around cells having given value
#
# Creates (or converts a grid to) a binary grid, where all cells
# within distance w of a cell (measured as pixels from cell center to cell center)
# having the value z will have value 1, all other cells will
# have values 0. 
# @param[in] z Denotes cell	values for which the bufferzone is computed.
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

## @method $count()
#
# @brief Counts the cells with values (as opposed to nodata).
# @return Returns the count of cells without <I>no data</I> values.
sub count {
    my $self = shift;
    return ral_grid_count($self->{GRID});
}

## @method $sum()
#
# @brief Calculates the sum of all cells with values having the same type as the
# grid (integer/float).
# @return Returns the sum of all cells having values with the same datatype as 
# the grid (integer/float).
sub sum {
    my($self) = @_;
    return ral_grid_sum($self->{GRID});
}

## @method $mean()
#
# @brief Calculates the mean over all cell values.
# @return Returns the mean (double accuracy).
sub mean {
    my $self = shift;
    return ral_grid_mean($self->{GRID});
}

## @method $variance()
#
# @brief Calculates the variance of all cells with values having the same type as the
# grid (integer/float).
# @return Returns the variance of all cells having values with the same datatype as 
# the grid (integer/float).
sub variance {
    my $self = shift;
    return ral_grid_variance($self->{GRID});
}

## @method Geo::Raster distances()
#
# @brief Computes and stores into nodata cells the distance
# (in world units) to the nearest data cell.
# @return If a return value is wanted, then the method returns a new grid with 
# values only in this raster grids <I>no data</I> cells having the distance
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
# values only in this raster grids <I>no data</I> cells, having the direction
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
# @brief Clips a part of the raster grid according the given rectangle.
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
# @brief Clips a part of the raster grid according the given raster grids real 
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

=pod

=head2 Joining two grids: (NOTE: this is from before gdal/cache)

    $g3 = $g1->join($g2);

The joining is based on the world coordinates of the grids.  clip and
join without assignment clip or join the original grid, so

    $a->clip($i1, $j1, $i2, $j2);
    $a->join($b);

have the effect "clip a to i1, j1, i2, j2" and "join b to a".

=cut

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
# @param[in] second A raster grid to join to this raster grid. 
# @return If a return value is wanted, then the method returns a new grid.
# @exception The raster grids have a different cell size.
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
# @brief Assigns the values from an another raster grid to this. 
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
# @brief Creates a list of the raster grids values.
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

## @method Geo::Raster focal_sum(listref mask)
#
# @brief Compute the focal sum for the whole raster.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal sum is computed.
# @return The focal sums for the entire raster grid. If no return value is 
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
	    attributes($self);
	}
    }
}

## @method Geo::Raster focal_mean(listref mask)
#
# @brief Compute the focal mean for the whole raster.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal mean is computed.
# @return The focal means for the entire raster grid. If no return value is 
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
	    attributes($self);
	}
    }
}

## @method Geo::Raster focal_variance(listref mask)
#
# @brief Compute the focal variance for the whole raster.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal variance is computed.
# @return The focal variances for the entire raster grid. If no return value is 
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
	    attributes($self);
	}
    }
}

## @method Geo::Raster focal_count(listref mask)
#
# @brief Compute the focal count for the whole raster.
# @param[in] mask The mask is [[], [], ..., []], i.e., a 2D table that 
# determines the focal area. The table is read from left to right, top to down,
# and its center element is the cell for which the focal count is computed.
# @return The focal counts for the entire raster grid. If no return value is 
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
	    attributes($self);
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
# @return The focal counts of the value for the entire raster grid. If no return 
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
	    attributes($self);
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
	attributes($self);
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
	attributes($self);
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

## @method ref %zones(Geo::Raster zones)
#
# @brief Return a hash defining the raster grids values for each zone.
#
# @param[in] zones An integer raster grid, which defines the zones. All 
# different integers point to a different zone.
# @return A reference to a hash having all values of the zones grid (the zones) 
# as keys (as has the return value of Geo::Raster::contents() for the raster 
# grid). As values of the hash are references to arrays having this raster grids 
# values, which belong to the zone defined by the key.
# @exception The zones grid is not overlayable with the raster grid.
# @exception The zones grid is not of type integer.
sub zones {
    my($self, $zones) = @_;
    return ral_grid_zones($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_fct(Geo::Raster zones, $fct)
#
# @brief Calculates the mean of this raster grids values for each zone.
# @param[in] zones An integer raster grid, which defines the zones. All 
# different integers point to a different zone.
# @param fct (string) a method supported by Statistics::Descrptive ('mean' by default)
# @return Returns a reference to an hash having as keys the zones and as 
# values the means of this raster grids cells belonging to the zones.
# @exception The zones grid is not overlayable with the raster grid.
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
# @brief Calculates the amount of this raster grids cells for each zone.
#
# Example of getting count of cells having values for each zone:
# @code
# $zonalcount = $grid->zonal_count($zones);
# @endcode
#
# @param[in] zones An integer raster grid, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the amount of this raster grids cells having some value and belonging 
# to zone.
# @exception The zones grid is not overlayable with the raster grid.
# @exception The zones grid is not of type integer.
sub zonal_count {
    my($self, $zones) = @_;
    return ral_grid_zonal_count($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_sum(Geo::Raster zones)
#
# @brief Calculates the sum of this raster grids cells for each zone.
#
# Example of getting sum of values for each zone:
# @code
# $zonalsum = $grid->zonal_sum($zones);
# @endcode
#
# @param[in] zones An integer raster grid, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the sum of this raster grids cells belonging to the zone.
# @exception The zones grid is not overlayable with the raster grid.
# @exception The zones grid is not of type integer.
sub zonal_sum {
    my($self, $zones) = @_;
    return ral_grid_zonal_sum($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_min(Geo::Raster zones)
#
# @brief Calculates the minimum of this raster grids cells for each zone.
#
# Example of getting smallest value for each zone:
# @code
# $zonalmin = $grid->zonal_min($zones);
# @endcode
#
# @param[in] zones An integer raster grid, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the minimum of this raster grids cells belonging to the zone.
# @exception The zones grid is not overlayable with the raster grid.
# @exception The zones grid is not of type integer.
sub zonal_min {
    my($self, $zones) = @_;
    return ral_grid_zonal_min($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_max(Geo::Raster zones)
#
# @brief Calculates the maximum of this raster grids cells for each zone.
#
# Example of getting highest value for each zone:
# @code
# $zonalmax = $grid->zonal_max($zones);
# @endcode
#
# @param[in] zones An integer raster grid, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the maximum of this raster grids cells belonging to the zone.
# @exception The zones grid is not overlayable with the raster grid.
# @exception The zones grid is not of type integer.
sub zonal_max {
    my($self, $zones) = @_;
    return ral_grid_zonal_max($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_mean(Geo::Raster zones)
#
# @brief Calculates the mean of this raster grids cells for each zone.
#
# Example of getting mean of all values for each zone:
# @code
# $zonalmean = $grid->zonal_mean($zones);
# @endcode
#
# @param[in] zones An integer raster grid, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the mean of this raster grids cells belonging to the zone.
# @exception The zones grid is not overlayable with the raster grid.
# @exception The zones grid is not of type integer.
sub zonal_mean {
    my($self, $zones) = @_;
    return ral_grid_zonal_mean($self->{GRID}, $zones->{GRID});
}

## @method hashref zonal_variance(Geo::Raster zones)
#
# @brief Calculates the variance of this raster grids cells for each zone.
#
# Example of getting variance of all values for each zone:
# @code
# $zonalvar = $grid->zonal_variance($zones);
# @endcode
#
# @param[in] zones An integer raster grid, which defines the zones. All 
# different integers point to a different zone.
# @return Returns a reference to an hash having as keys the zones and as 
# values the variance of this raster grids cells belonging to the zone.
# @exception The zones grid is not overlayable with the raster grid.
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
# @return Returns a new raster grid, if a return value is wanted, else the 
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
# @return eturns a new raster grid, if a return value is wanted, else the 
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
# @return Returns a new raster grid, if a return value is wanted, else the 
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
# @return Returns a new raster grid, if a return value is wanted, else the 
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

## @fn log_base($base, $value)
#
# @brief Calculates the logarithm with a desired base, for example 2 or 10.
# @param base Desired logarithm base, for example 2 or 10.
# @param value Value for which the logarithm is calculated.
# @return The result of the logarithm function.
sub log_base {
    my ($base, $value) = @_;
    return CORE::log($value)/CORE::log($base);
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

