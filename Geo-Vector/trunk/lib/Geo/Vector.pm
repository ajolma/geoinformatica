package Geo::Vector;

## @class Geo::Vector
# @brief A geospatial layer that consists of Geo::OGR::Features.
#
# This module should be discussed in geo-perl@list.hut.fi.
#
# The homepage of this module is 
# http://geoinformatics.tkk.fi/twiki/bin/view/Main/GeoinformaticaSoftware.
#
# @author Ari Jolma
# @author Copyright (c) 2005- by Ari Jolma
# @author This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.5 or,
# at your option, any later version of Perl 5 you may have available.

=pod

=head1 NAME

Geo::Vector - Perl extension for geospatial vectors

The <a href="http://map.hut.fi/doc/Geoinformatica/html/">documentation
of Geo::Vector</a> is in doxygen format.

=cut

use 5.008;
use strict;
use warnings;
use Carp;
use POSIX;
POSIX::setlocale( &POSIX::LC_NUMERIC, "C" ); # http://www.remotesensing.org/gdal/faq.html nr. 11
use UNIVERSAL qw(isa);
use XSLoader;
use File::Basename;
use Geo::GDAL;
use Geo::OGC::Geometry;
use Gtk2;

use Geo::Vector::Layer;

use vars qw( @ISA %GEOMETRY_TYPE %GEOMETRY_TYPE_INV %RENDER_AS );

our $VERSION = '0.52';

require Exporter;

@ISA = qw( Exporter );

our %EXPORT_TAGS = ( 'all' => [qw( %GEOMETRY_TYPE %RENDER_AS &drivers )] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

for my $key ( 'Unknown', 'Point', 'LineString', 'Polygon',
	      'MultiPoint', 'MultiLineString', 'MultiPolygon',
	      'GeometryCollection', 'None', 'LinearRing',
	      'Point25D', 'LineString25D', 'Polygon25D',
	      'MultiPoint25D', 'MultiLineString25D', 'MultiPolygon25D',
	      'GeometryCollection25D' ) 
{
    my $val = eval "\$Geo::OGR::wkb$key";
    $GEOMETRY_TYPE{$key} = $val;
    $GEOMETRY_TYPE_INV{ $val } = $key;
}

# from ral_visual.h:
%RENDER_AS = ( Native => 0, Points => 1, Lines => 2, Polygons => 4 );

## @ignore
# tell dynaloader to load this module so that xs functions are available to all:
sub dl_load_flags {0x01}

XSLoader::load( 'Geo::Vector', $VERSION );

## @cmethod @geometry_types()
#
# @brief Returns a list of valid geometry types.
#
# %GEOMETRY_TYPE is a hash of standard type names: 'Point', 'LineString', ...
# @return a list of valid geometry types (as strings).
sub geometry_types {
    my ($class) = @_;
    return keys %GEOMETRY_TYPE;
}

## @cmethod @render_as_modes()
#
# @brief Returns a list of valid render as modes.
#
# %RENDER_AS is a hash of render types: 'Native', 'Points', ...
# @return a list of valid render as modes (as strings).
sub render_as_modes {
    my ($class) = @_;
    return keys %RENDER_AS;
}

## @cmethod ref %layers($driver, $data_source)
#
# @brief Lists the layers that are available in a data source.
# @return A hashref to a (layer_name => geometry_type) hash.
sub layers {
    my($driver, $data_source) = @_;
    $driver = '' unless $driver;
    $data_source = '' unless $data_source;
    my $self = { update => 0 };
    set_driver($self, $driver, $data_source);
    return unless $self->{OGR}->{DataSource};
    my %layers;
    for my $i ( 0 .. $self->{OGR}->{DataSource}->GetLayerCount - 1 ) {
	my $l  = $self->{OGR}->{DataSource}->GetLayerByIndex($i);
	my $fd = $l->GetLayerDefn();
	my $t  = $fd->GetGeomType;
	next unless $GEOMETRY_TYPE_INV{$t};
	$layers{ $l->GetName } = $GEOMETRY_TYPE_INV{$t};
    }
    return \%layers;
}

## @cmethod void delete_layer($driver, $data_source, $layer)
#
# @brief Attempts to delete a layer from a datasource.
# @param[in] driver
# @param[in] data_source
# @param[in] layer Name of the layer that should be deleted.
sub delete_layer {
    my($driver, $data_source, $layer) = @_;
    my $self = { update => 1 };
    set_driver($self, $driver, $data_source);
    for my $i ( 0 .. $self->{OGR}->{DataSource}->GetLayerCount - 1 ) {
	my $l = $self->{OGR}->{DataSource}->GetLayerByIndex($i);
	$self->{OGR}->{DataSource}->DeleteLayer($i), last
	    if $l->GetName() eq $layer;
    }
}

## @cmethod Geo::Vector new($data_source)
#
# @brief Create a new Geo::Vector object for the first layer in a
# given OGR data souce.
#
# An example of creating a Geo::Vector object for a ESRI shapefile:
# @code
# $v = Geo::Vector->new("borders.shp");
# @endcode
#
# @param data_source An OGR data source string
# @return A new Geo::Vector object

## @cmethod Geo::Vector new(%params)
#
# @brief Create a new Geo::Vector object.
#
# A Geo::Vector object is either a Geo::OGR::Layer or an array of
# Geo::OGR::Feature objects. To create a new Geo::Vector of the first
# type, you need to specify either a data source or a name or a schema
# for the layer. The layer type object requires an OGR driver and data
# source. The default driver is Memory. If no name or SQL is
# specified, the first layer in the data source is opened. The feature
# table type object does not have a unique schema. By default (no name
# or schema for the layer is specified) this method creates an array
# of Geo::OGR::Feature objects type of object.
#
# @param params Named parameters, all are optional: (see also the
# named parameters of the Geo::Vector::layer method)
# - \a driver => string, used only if data source is not given,
# default is 'Memory' for layer type objects.
# - \a driver_options forwarded to Geo::OGR::CreateDataSource.
# - \a data_source => string, OGR data source string, required for
# other layer type objects than in-memory vectors.
# - \a update => true/false, data source option, default is false for
# other than in-memory vectors. Required and must be true to create a
# new layer.
# - \a schema, as in method Geo::Vector::schema. Note that the
# geometry type is also specified within the schema using the pseudo
# attribute ".GeometryType".
# - \a encoding => string, the encoding of the attribute values of the
# features.
# - \a layer => string, a name of or for the layer. Required for new
# layers except for in-memory ones. To explicitly require a new layer,
# use \a create.
# - \a create => string, a name for a new layer. Implies update => 1.
# - \a layer_options forwarded to Geo::OGR::DataSource::CreateLayer.
# - \a SQL => string SQL-string, forwarded to
# Geo::OGR::DataSource::ExecuteSQL, an alternative to \a layer. If \a
# SQL is given, \a layer is not consulted.
# - \a srs => either a string which defines a spatial reference system
# (e.g. 'EPSG:XXXX') or a Geo::OSR::SpatialReference object. Default
# is 'EPSG:4326'.
# - \a geometries => a reference to a list of geometries to be
# inserted into the layer. Assumes a feature table type of an
# object. Creates features without attributes for the geometries.
# - \a features => a reference to a list of features to be inserted
# into the layer. Assumes a feature table type of an object.
# @return A new Geo::Vector object
sub new {
    my $package = shift;
    my %params = @_ == 1 ? ( filename => $_[0] ) : @_;

    # the single parameter can be a filename, geometry, feature, or a
    # list of geometries or features, which are copied into a new
    # memory layer

    if (isa($params{filename}, 'Geo::OGR::Layer')) {
	$params{layer} = $params{filename};
	delete $params{filename};
    }

    $params{geometry_type} = $params{schema}{'.GeometryType'}{TypeName} if ref $params{schema};

    my %defaults = ( driver => '',
		     driver_options => [],
		     filename => '',
		     data_source => '',
		     update => 0,
		     srs => 'EPSG:4326',
		     geometry_type => 'Unknown',
		     SQL => '',
		     layer => '',
		     encoding => '',
		     features => [],
		     geometries => [],
		     );
	  
    for my $key (keys %defaults) {
	next if defined $params{$key};
	$params{$key} = $defaults{$key};
    }
    # aliases
    $params{data_source} = $params{filename} if $params{filename};
    $params{data_source} = $params{datasource} if $params{datasource};
    $params{SQL} = $params{sql} if $params{sql};
    $params{layer} = $params{name} if $params{name};
    $params{layer} = $params{layer_name} if $params{layer_name};
    $params{layer_options} = [] unless $params{layer_options};
    $params{update} = 1 if $params{create};
    delete $params{schema} if $params{schema} and $params{schema} eq 'free';
    
    #for (keys %params) {
	#print STDERR "create with $_ => $params{$_}\n";
    #}
    #print STDERR "end create\n";

    my $self = { encoding => $params{encoding},
		 update => $params{update},
    };
    bless $self => (ref($package) or $package);
    
    if ($params{data_source}) {
	set_driver($self, $params{driver}, $params{data_source}, $params{driver_options});
    }
    elsif ($params{layer} or $params{schema}) {
	$self->{update} = 1;
	set_driver($self, 'Memory', '');
	$params{layer} = 'x' unless $params{layer};
    }
    else {
	$self->{features} = [];
	for my $g (@{$params{geometries}}) {
	    $self->geometry($g);
	}
	for my $f (@{$params{features}}) {
	    $self->feature($f);
	}
	return $self;
    }

    if (!$params{create} and $self->{OGR}->{DataSource}->GetLayerCount > 0) {
	
	if ( $params{SQL} ) {
	    
	    $self->{SQL} = $params{SQL};
	    eval {
		$self->{OGR}->{Layer} =
		    $self->{OGR}->{DataSource}->ExecuteSQL( $self->{SQL} );
	    };
	    croak "ExecuteSQL failed: $@" unless $self->{OGR}->{Layer};

	} elsif ($params{layer}) {

	    $self->{OGR}->{Layer} =
		$self->{OGR}->{DataSource}->GetLayerByName( $params{layer} );
	    
	} else {
	
	    # open the first layer
	    $self->{OGR}->{Layer} = $self->{OGR}->{DataSource}->GetLayerByIndex();
	    croak "Could not open the default layer: $@" unless $self->{OGR}->{Layer};
	    
	}

    }

    # Create a new
    unless ($self->{OGR}->{Layer}) {

	$params{layer} = $params{create} if $params{create};

	croak "No name specified for the new layer." unless $params{layer};
	    
	my $srs;
	if (ref($params{srs}) and isa($params{srs}, 'Geo::OSR::SpatialReference')) {
	    $srs = $params{srs};
	} else {
	    $srs = new Geo::OSR::SpatialReference;
	    $params{srs} = 'EPSG:4326' unless $params{srs};
	    if ( $params{srs} =~ /^EPSG:(\d+)/ ) {
		eval { $srs->ImportFromEPSG($1); };
		croak "ImportFromEPSG failed: $@" if $@;
	    } else {
		croak "SRS $params{srs} not yet supported";
	    }
	}
	eval {
	    $self->{OGR}->{Layer} =
		$self->{OGR}->{DataSource}->CreateLayer( $params{layer}, 
							 $srs, 
							 $params{geometry_type},
							 $params{layer_options});
	};
	croak "CreateLayer failed (did you specify update=>1?): $@"
	    unless $self->{OGR}->{Layer};
	
    }

    schema($self, $params{schema}) if $params{schema};

    return $self;
}

## @ignore
sub set_driver {
    my($self, $driver, $data_source, $options) = @_;
    $options = [] unless $options;
    if ($driver) {
	if (isa($driver, 'Geo::OGR::Driver')) {
	    $self->{OGR}->{Driver} = $driver;
	} else {
	    $self->{OGR}->{Driver} = Geo::OGR::GetDriver($driver);
	}
	croak "Can't find driver: $driver" unless $self->{OGR}->{Driver};
	eval {
	    $self->{OGR}->{DataSource} = $self->{OGR}->{Driver}->CreateDataSource($data_source, $options);
	};
        $@ = "no reason given" unless $@;
	croak "Can't create data source: $@" unless $self->{OGR}->{DataSource};
    } else {
	eval {
	    $self->{OGR}->{DataSource} = Geo::OGR::Open($data_source, $self->{update});
	};
        $@ = "no reason given" unless $@;
	croak "Can't open data source: $@" unless $self->{OGR}->{DataSource};
	$self->{OGR}->{Driver} = $self->{OGR}->{DataSource}->GetDriver;
    }
    $self->{data_source} = $data_source;
}

## @ignore
sub DESTROY {
    my $self = shift;
    return unless $self;
    if ( $self->{SQL} and $self->{OGR}->{DataSource} ) {
	$self->{OGR}->{DataSource}->ReleaseResultSet( $self->{OGR}->{Layer} );
    }
    if ( $self->{features} ) {
	for ( @{ $self->{features} } ) {
	    undef $_;
	}
    }
}

## @method driver()
#
# @brief The driver of the object.
# @return The name of the OGR driver as a string. Returns 'Memory' if the
# object is not an OGR layer.
sub driver {
    my $self = shift;
    return $self->{OGR}->{Driver}->GetName if $self->{OGR} and $self->{OGR}->{Driver};
    return 'Memory';
}

## @method dump(%parameters)
#
# @brief Print the contents of the layer.
sub dump {
    my $self = shift;
    my %params = ( filehandle => \*STDOUT );
    if (@_) {
	if (@_ == 1) {
	    $params{filehandle} = shift;
	} else {
	    %params = @_ if @_;
	}
    }
    my $fh = $params{filehandle};
    my $schema = $self->schema();
    my $i = 1;
    $self->init_iterate;
    while (my $feature = $self->get_next()) {
	print $fh "Feature $i:\n";
	my $s = $schema;
	$s = $self->schema($i-1) unless $s;
	$i++;
	for my $name (sort { $s->{$a}{Number} <=> $s->{$b}{Number} } keys %$s) {
	    next if $name =~ /^\./;
	    my $value = $feature->GetField($name);
	    print $fh "$name: $value\n";
	}
	my $geom = $feature->GetGeometryRef();
	dump_geom($geom, $fh, $params{suppress_points});
    }
}

## @method init_iterate()
#
# @brief Reset reading features from the object iteratively.
sub init_iterate {
    my $self = shift;
    if ($self->{features}) {
	$self->{_cursor} = 0;
    } 
    else {
	$self->{OGR}->{Layer}->ResetReading();
    }
}

## @method next_feature()
#
# @brief Read a feature from the object iteratively.
sub next_feature {
    my $self = shift;
    if ($self->{features}) {
	return if $self->{_cursor} > $#{$self->{features}};
	return $self->{features}->[$self->{_cursor}++];
    }
    return $self->{OGR}->{Layer}->GetNextFeature()
}
*get_next = *next_feature;

## @ignore
sub dump_geom {
    my($geom, $fh, $supp) = @_;
    my $type = $geom->GeometryType;
    my $dim = $geom->CoordinateDimension;
    my $count = $geom->GetPointCount;
    print $fh "Geometry type: $type, Dimension: $dim, Point count: $count\n";
    if ($geom->GetGeometryCount) {
	for (0..$geom->GetGeometryCount-1) {
	    dump_geom($geom->GetGeometryRef($_), $fh, $supp);
	}
    } else {
	return if $supp;
	for my $i (1..$count) {
	    my @point = $geom->GetPoint($i-1);
	    print $fh "Point $i: @point\n";
	}
    }
}

## @method $copy(%params)
#
# @brief Copy this layer into a new layer.
# @param[in] params Named parameters (see the named
# parameters of Geo::Vector::new).
# @return The new Geo::Vector object.
sub copy {
    my $self = shift;
    my %params = @_ if @_;
    $params{schema} = $self->schema();
    my $new = Geo::Vector->new(%params);
    my $out = $new->{OGR}->{Layer};
    my $defn = $out->GetLayerDefn() if $out;
    $self->init_iterate;
    while (my $feature = $self->next_feature()) {
	my $geom = $feature->GetGeometryRef();
	$defn = $feature->GetDefnRef unless $out;
	my $f = Geo::OGR::Feature->new($defn);
	for my $name (keys %{$params{schema}}) {
	    next if $name =~ /^\./;
	    $f->SetField($name, $feature->GetField($name));
	}
	$f->SetGeometry($geom);
	if ($out) {
	    $out->CreateFeature($f);
	} else {
	    push @{$new->{features}}, $f;
	}
    }
    $out->SyncToDisk unless $new->driver eq 'Memory';
    return $new;
}

## @method $buffer(%params)
#
# @brief Create a new Geo::Vector object, whose features are buffer
# areas to the original.
# @param[in] params Named parameters: (see also the named
# parameters of Geo::Vector::new).
# - \a distance => float (default is 1.0). The width of the buffer.
# - \a quad_segs => int (default is 30). The number of segments used to approximate a 90
# degree (quadrant) of curvature.
# - \a copy_attributes => true/false (default is false). 
# - \a driver default is 'Memory'.
# - \a layer default is 'buffer'.
# @return The new Geo::Vector object.
sub buffer {
    my $self = shift;
    my %params;
    if (@_) {
	if (@_ == 1) {
	    $params{distance} = shift;
	} else {
	    %params = @_ if @_;
	}
    }
    my $w = $params{distance};
    $w = 1 unless defined $w;
    my $q = $params{quad_segs};
    $q = 30 unless defined $q;
    $params{schema} = $self->schema() if $params{copy_attributes};
    my $new = Geo::Vector->new(%params);
    my $out = $new->{OGR}->{Layer};
    my $defn = $out->GetLayerDefn() if $out;
    $self->init_iterate;
    while (my $feature = $self->next_feature()) {
	my $geom = $feature->GetGeometryRef();
	my $buf = $geom->Buffer($w, $q);
	$defn = $feature->GetDefnRef unless $out;
	my $f = Geo::OGR::Feature->new($defn);
	if ($params{schema}) {
	    for my $name (keys %{$params{schema}}) {
		next if $name =~ /^\./;
		$f->SetField($name, $feature->GetField($name));
	    }
	}
	$f->SetGeometry($buf);
	if ($out) {
	    $out->CreateFeature($f);
	} else {
	    push @{$new->{features}}, $f;
	}
    }
    $out->SyncToDisk unless $new->driver eq 'Memory';
    return $new;
}

## @method $within($other, %params)
#
# @brief Return the features from this layer that are within the
# features of other.
# @todo Add some optimizations.
# @return A new Geo::Vector object
sub within {
    my $self = shift;
    my $other = shift;
    my %params = @_ if @_;
    $params{schema} = $self->schema();
    my $new = Geo::Vector->new(%params);
    my $out = $new->{OGR}->{Layer};
    my @c;
    $other->init_iterate;
    while (my $feature = $other->next_feature()) {
	my $geom = $feature->GetGeometry();
	push @c, $geom;
    }
    my $defn = $out->GetLayerDefn() if $out;
    $self->init_iterate;
    while (my $feature = $self->next_feature()) {
	my $geom = $feature->GetGeometryRef();
	my $within = 0;
	for (@c) {
	    if ($geom->Within($_)) {
		$within = 1;
		last;
	    }
	}
	next unless $within;
	$defn = $feature->GetDefnRef unless $out;
	my $f = Geo::OGR::Feature->new($defn);
	if ($params{schema}) {
	    for my $name (keys %{$params{schema}}) {
		next if $name =~ /^\./;
		$f->SetField($name, $feature->GetField($name));
	    }
	}
	$f->SetGeometry($geom);
	if ($out) {
	    $out->CreateFeature($f);
	} else {
	    push @{$new->{features}}, $f;
	}
    }
    $out->SyncToDisk unless $new->driver eq 'Memory';
    return $new;
}

## @method $add($other, %params)
#
# @brief Add features from the other layer to this layer.
# @param other A Geo::Vector object
# @param params Named parameters, used for creating the new object,
# if one is created.
# @return (If used in non-void context) A new Geo::Vector object, which
# contain features from both this and from the other.
sub add {
    my $self = shift;
    my $other = shift;
    my %params = @_ if @_;
    my($new, $out);
    if (defined wantarray) {
	$params{schema} = $self->schema();
	$new = Geo::Vector->new(%params);
	$out = $new->{OGR}->{Layer};
    } else {
	$params{driver} = $self->driver;
	$new = $self;
	$out = $self->{OGR}->{Layer};
    }
    my $defn = $out->GetLayerDefn() if $out;
    $other->init_iterate;
    while (my $feature = $other->next_feature()) {
	my $geom = $feature->GetGeometryRef();
	$defn = $feature->GetDefnRef unless $out;
	my $f = Geo::OGR::Feature->new($defn);
	if ($params{schema}) {
	    for my $name (keys %{$params{schema}}) {
		next if $name =~ /^\./;
		$f->SetField($name, $feature->GetField($name));
	    }
	}
	$f->SetGeometry($geom);
	if ($out) {
	    $out->CreateFeature($f);
	} else {
	    push @{$new->{features}}, $f;
	}
    }
    $out->SyncToDisk unless $new->driver eq 'Memory';
    return $new if defined wantarray;
}

## @method $feature_count()
#
# @brief Count the number of features in the layer.
# @todo Add $force parameter.
# @return The number of features in the layer. The valued may be approximate.
sub feature_count {
    my ($self) = @_;
    if ( $self->{features} ) {
	my $count = @{ $self->{features} };
	return $count;
    }
    return unless $self->{OGR}->{Layer};
    my $count;
    eval { $count = $self->{OGR}->{Layer}->GetFeatureCount(); };
    croak "GetFeatureCount failed: $@" if $@;
    return $count;
}
## @method Geo::OSR::SpatialReference srs(%params)
#
# @brief Get or set (set is not yet implemented) the spatial reference system of
# the layer.
#
# SRS (Spatial reference system) is a geographic coordinate system code number
# in the EPSG database (European Petroleum Survey Group, http://www.epsg.org/).
# Default value is 4326, which is for WGS84.
# @param[in] params (optional) Named parameters:
# - format => string. Name of the wanted return format, like 'Wkt'. Wkt is for 
# Well-known text and is defined by the The OpenGIS Consortium specification for 
# the exchange (and easy persistance) of geometry data in ASCII format.
# @return Returns the current spatial reference system of the layer
# as a Geo::OSR::SpatialReference or wkt string.
sub srs {
    my ( $self, %params ) = @_;
    return unless $self->{OGR}->{Layer};
    my $srs;
    eval { $srs = $self->{OGR}->{Layer}->GetSpatialRef(); };
    croak "GetSpatialRef failed: $@" if $@;
    return unless $srs;
    if ( $params{format} ) {
	return $srs->ExportToWkt if $params{format} eq 'Wkt';
    }
    return $srs;
}

## @method $field_count(%params)
#
# @brief For a layer object returns the number of fields in the layer schema.
# For a feature set object requires a named parameter that specifies the feature.
#
# Each feature in a feature set object may have its own schema.
# @return For a layer object returns the number of fields in the layer schema.
# For a feature set object requires a named parameter that specifies the feature.
sub field_count {
    my ( $self, %params ) = @_;
    if ( $self->{features} ) {
	my $f = $self->{features}->[ $params{feature} ];
	return $f ? $f->GetFieldCount() : undef;
    }
    return unless $self->{OGR}->{Layer};
    my $n;
    eval { $n = $self->{OGR}->{Layer}->GetLayerDefn()->GetFieldCount(); };
    croak "GetLayerDefn or GetFieldCount failed: $@" if $@;
    return $n;
}

## @method $geometry_type(%params)
#
# @brief For a layer object returns the geometry type of the layer.
# For a feature set object requires a named parameter that specifies the feature.
#
# @param[in] params Named parameters:
# - flatten => true/false. Default is false.
# - feature => integer. Index of the feature whose geometry type is queried.
# @return For a layer object returns the geometry type of the layer.
# For a feature set object returns specified features geometry type.
sub geometry_type {
    my ( $self, %params ) = @_;
    my $t;
    if ( $self->{features} ) {
	return $Geo::OGR::wkbUnknown unless defined $params{feature};
	my $f = $self->{features}->[ $params{feature} ];
	if ($f) {
	    $t = $f->GetGeometryRef->GetGeometryType;
	}
    }
    elsif ( $self->{OGR}->{Layer} ) {
	$t = $self->{OGR}->{Layer}->GetLayerDefn()->GetGeomType;
    }
    return unless $t;
    $t = $t & ~0x80000000 if $params{flatten};
    return $GEOMETRY_TYPE_INV{$t};
}

## @method hashref schema(hashref schema)
#
# @brief Get or set the schema of the object.
#
# For a layer object there is only one schema. For a feature table
# object the schema is a feature specific (see the calling syntax
# below). The schema is a hash (actually a reference to an anonymous
# hash). The keys are attribute names except for pseudo
# attributes. The names of the pseudo attributes start with a dot
# ".". Currently there are the following pseudo attributes:
# ".GeometryType", ".FID", and ".Z". Z attribute is defined only for
# point features. FID pseudo attribute is the feature id as used by
# OGR.
#
# The value of the attribute entry in the schema is an anonymous hash
# with keys such as Number, TypeName, Justify, Width, and Precision,
# i.e. Geo::OGR::FieldDefn attributes etc. For the pseudo attribute
# GeometryType the value is simply the name of the geometry type.
#
# @param[in] schema (optional) a reference to a hash specifying the schema.
# @return the schema.

## @method hashref schema($feature, hashref schema)
#
# @brief Get or set the schema of a feature in a feature table object.
#
# @param[in] feature the index of the feature, whose schema to get or set.
# @param[in] schema (optional) a reference to a hash specifying the schema.
# @return the schema.
sub schema {
    my($self, $schema, $feature) = @_;
    if (ref($feature)) {
	my $s = $schema;
	$schema = $feature;
	$feature = $s;
    } 
    elsif (defined $schema and not ref($schema)) {
	$feature = $schema;
	$schema = undef;
    }
    my $defn = $self->{features} ?
	(defined $feature ? $self->{features}->[$feature]->GetDefnRef() : undef) : 
	$self->{OGR}->{Layer}->GetLayerDefn();
    if ($schema) {
	croak "refusing to set the schema of all features in a feature table at once" unless $defn;
	my %exists;
	my $n = $defn->GetFieldCount();
	for my $i ( 0 .. $n - 1 ) {
	    my $fd   = $defn->GetFieldDefn($i);
	    my $name = $fd->GetName;
	    $exists{$name} = 1;
	}
	for my $name ( keys %$schema ) {
	    next if $name =~ /^\./;
	    $schema->{$name}{Number} = $n++
		unless defined $schema->{$name}{Number};
	}
	my $recreate = 0;
	for my $name ( sort { $schema->{$a}{Number} <=> $schema->{$b}{Number} } keys %$schema ) {
	    next if $name =~ /^\./;
	    my $d    = $schema->{$name};
	    my $type = $d->{Type};
	    $type = eval "\$Geo::OGR::OFT$d->{TypeName}" unless $type;
	    my $fd = new Geo::OGR::FieldDefn( $name, $type );
	    $fd->ACQUIRE;
	    $fd->SetJustify( $d->{Justify} ) if defined $d->{Justify};
	    $fd->SetWidth( $d->{Width} )     if defined $d->{Width};
	    
	    if ( exists $d->{Width} ) {
		$fd->SetWidth( $d->{Width} );
	    }
	    else {
		$fd->SetWidth(10) if $type == $Geo::OGR::OFTInteger;
	    }
	    $fd->SetPrecision( $d->{Precision} ) if defined $d->{Precision};
	    unless ( $exists{$name} ) {
		$self->{OGR}->{Layer}->CreateField($fd) if $self->{OGR}->{Layer};
		$recreate = 1;
	    }
	}
	if ( $self->{features} and $recreate ) {
	    my $sg = $defn->GetGeometryRef();
	    my $dg = Geo::OGR::Geometry->new( $sg->GetGeometryType );
	    $dg->ACQUIRE;
	    copy_geometry_data( $sg, $dg );
	    my $d = Geo::OGR::FeatureDefn->new();
	    for my $name ( sort { $schema->{$a}{Number} <=> $schema->{$b}{Number} } keys %$schema ) {
		next if $name =~ /^\./;
		my $fd = Geo::OGR::FieldDefn->new( $name, $schema->{$name}{Type} );
		$fd->ACQUIRE;
		$fd->SetJustify( $schema->{$name}{Justify} )
		    if exists $schema->{$name}{Justify};
		if ( exists $schema->{$name}{Width} ) {
		    $fd->SetWidth( $schema->{$name}{Width} );
		}
		else {
		    $fd->SetWidth(10)
			if $schema->{$name}{Type} == $Geo::OGR::OFTInteger;
		}
		$fd->SetPrecision( $schema->{$name}{Precision} )
		    if exists $schema->{$name}{Precision};
		$d->AddFieldDefn($fd);
	    }
	    $d->DISOWN;    # this is given to feature
	    my $f = Geo::OGR::Feature->new($d);
	    $f->SetGeometry($dg);
	    for my $name ( keys %$schema ) {
		next if $name =~ /^\./;
		$f->SetField( $name, $defn->GetField($name) ) if $exists{$name};
	    }
	    $self->{features}->[$feature] = $f;
	}
    } else {
	return unless $defn;
	$schema = {};
	eval {
	    my $n = $defn->GetFieldCount();
	    for my $i ( 0 .. $n - 1 ) {
		my $fd   = $defn->GetFieldDefn($i);
		my $name = $fd->GetName;
		$schema->{$name}{Number}   = $i;
		$schema->{$name}{Type}     = $fd->GetType;
		$schema->{$name}{TypeName} =
		    $fd->GetFieldTypeName( $fd->GetType );
		$schema->{$name}{Justify}   = $fd->GetJustify;
		$schema->{$name}{Width}     = $fd->GetWidth;
		$schema->{$name}{Precision} = $fd->GetPrecision;
	    }
	};
	croak "GetFieldCount failed: $@" if $@;
	$schema->{'.FID'} = { Number   => -1,
			      Type     => $Geo::OGR::OFTInteger,
			      TypeName => 'Integer' };
	if ($defn->GeometryType eq 'Point25D') {
	    $schema->{'.Z'} = { Number   => -2,
				Type     => $Geo::OGR::OFTReal,
				TypeName => 'Real' };
	}
	$schema->{'.GeometryType'} = {
	    Number => -3,
	    TypeName => $defn->GeometryType };
	
        # sort order for visual interfaces, first FID and other pseudo attributes, the fields in order
	for my $key (keys %$schema) {
	    my $a = $schema->{$key}{Number};
	    $a = -100-$a if $a < 0;
	    $schema->{$key}{VisualOrder} = $a;
	}

	return $schema;
    }
}

sub feature_attribute {
    my($f, $a) = @_;
    if ($a =~ /^\./) { # pseudo fields
        my $g = $f->Geometry;
	if ($a eq '.FID') {
	    return $f->GetFID;
	} elsif ($a eq '.Z') {
	    return $g->GetZ if $g;
	} elsif ($a eq '.GeometryType') {
	    return $g->GeometryType if $g;
	}
    } else {
	return $f->GetField($a);
    }
}

## @method @value_range(%params)
#
# @brief Returns a list of the value range of the field.
# @param[in] params Named parameters:
# - field_name => string. The attribute whose min and max values are looked up.
# - filter => reference to a Geo::OGR::Geometry (optional). Used by 
# Geo::OGR::SetSpatialFilter() if the layer is an OGR layer.
# - filter_rect => reference to an array defining the rect (min_x, min_y, max_x, 
# max_y) (optional). Used by the Geo::OGR::SetSpatialFilterRect() if the layer 
# is an OGR layer.
# @return An array that has as it's first value the ranges minimum and as second
# the maximum -- array(min, max).

## @method @value_range($field_name)
#
# @brief Returns a list of the value range of the field.
# @param[in] field_name The name of the field, whose min and max values are 
# looked up.
# @return An array that has as it's first value the ranges minimum and as second
# the maximum -- array(min, max).
sub value_range {
    my $self = shift;
    my $field_name;
    my %params;
    if ( @_ == 1 ) {
	$field_name = shift;
    }
    else {
	%params      = @_;
	$field_name = $params{field_name};
    }
    
    if ( $self->{features} ) {
	my @range;
	for my $feature ( @{ $self->{features} } ) {
	    my $d = $feature->GetDefnRef;
	    my $n = $d->GetFieldCount;
	    my $value;
	    for my $i ( 0 .. $n - 1 ) {
		my $fd   = $d->GetFieldDefn($i);
		my $name = $fd->GetName;
		next unless $name eq $field_name;
		my $type = $fd->GetType;
		next
		    unless $type == $Geo::OGR::OFTInteger
		    or $type == $Geo::OGR::OFTReal;
		$value = $feature->GetField($i);
	    }
	    next unless defined $value;
	    $range[0] =
		defined $range[0]
		? ( $range[0] < $value ? $range[0] : $value )
		: $value;
	    $range[1] =
		defined $range[1]
		? ( $range[1] > $value ? $range[1] : $value )
		: $value;
	}
	return @range;
    }
    
    my $schema = $self->schema()->{$field_name};
    croak "value_range: field with name '$field_name' does not exist"
	unless defined $schema;
    croak
	"value_range: can't use value from field '$field_name' since its' type is '$schema->{TypeName}'"
	unless $schema->{TypeName} eq 'Integer'
	or $schema->{TypeName}     eq 'Real';
    
    return ( 0, $self->{OGR}->{Layer}->GetFeatureCount - 1 )
	if $field_name eq '.FID';
    
    my $field = $schema->{Number};
    
# this would be probably faster as a database operation if data is in a database
    if ( exists $params{filter} ) {
	$self->{OGR}->{Layer}->SetSpatialFilter( $params{filter} );
    }
    elsif ( exists $params{filter_rect} ) {
	$self->{OGR}->{Layer}->SetSpatialFilterRect( @{ $params{filter_rect} } );
    }
    else {
	$self->{OGR}->{Layer}->SetSpatialFilter(undef);
    }
    $self->{OGR}->{Layer}->ResetReading();
    my @range;
    while (1) {
	my $f = $self->{OGR}->{Layer}->GetNextFeature();
	last unless $f;
	my $value = $f->GetField($field);
	$range[0] =
	    defined $range[0]
	    ? ( $range[0] < $value ? $range[0] : $value )
	    : $value;
	$range[1] =
	    defined $range[1]
		  ? ( $range[1] > $value ? $range[1] : $value )
		  : $value;
    }
    return @range;
}

## @method void copy_geometry_data(Geo::OGR::Geometry source, Geo::OGR::Geometry destination)
#
# @brief The method copies the data of the other Geo::OGR::Geometry to the other.
# @param[in] source A reference to an Geo::OGR::Geometry object, whose data is
# copied.
# @param[out] destination A reference to an Geo::OGR::Geometry object to which the
# other parameters data is copied to.
sub copy_geometry_data {
    my ( $src, $dst ) = @_;
    
    if ( $src->GetGeometryCount ) {
	
	for ( 0 .. $src->GetGeometryCount - 1 ) {
	    my $s = $src->GetGeometryRef($_);
	    my $t = $s->GetGeometryType;
	    my $n = $s->GetGeometryName;
	    $t = $Geo::OGR::wkbLinearRing if $n eq 'LINEARRING';
	    my $r = new Geo::OGR::Geometry($t);
	    $r->ACQUIRE;
	    copy_geom_data( $s, $r );
	    $dst->AddGeometry($r);
	}
	
    } else {
	
	for ( 0 .. $src->GetPointCount - 1 ) {
	    my $x = $src->GetX($_);
	    my $y = $src->GetY($_);
	    my $z = $src->GetZ($_);
	    $dst->AddPoint( $x, $y, $z );
	}
	
    }
}

## @method hashref has_field($field_name)
#
# @deprecated use schema
# @brief Tells if the layer has a field with a given name.
# @param[in] field_name Name of the field, which existence is asked.
# @return Returns the schema of the field.
sub has_field {
    my ( $self, $field_name ) = @_;
    return $self->schema->{$field_name};
}

## @method hashref feature($fid, $feature)
#
# @brief Get, add or update a feature.
#
# Example of retrieving:
# @code
# $feature = $vector->feature($i);
# @endcode
#
# Example of updating:
# @code
# $vector->feature($i, $feature);
# @endcode
#
# Example of adding:
# @code $vector->feature($feature);
# @endcode
#
# @param[in] fid The FID of the feature (or the feature, if adding)
# @param[in] feature Feature to add (then no other parameters) or feature to update.
# @return Feature as a hashref, whose keys are field names and
# geometry and values are field values and a Geo::OGC::Geometry
# object.
# @exception The fid is higher than the feature count.
sub feature {
    my ( $self, $fid, $feature ) = @_;
    if ($feature) {
	
	# update at fid
	if ( $self->{features} ) {
	    $feature = $self->make_feature($feature);
	    $self->{features}->[$fid] = $feature;
	}
	elsif ( $self->{OGR}->{Layer} ) {
	    croak "can't set a feature in a layer (at least yet)";
	}
	else {
	    croak "no layer";
	}
    }
    elsif ( ref($fid) ) {
	$self->add_feature($fid);
    }
    else {	
	# retrieve
	my $f;
	if ( $self->{features} ) {
	    $f = $self->{features}->[$fid];
	    croak "feature: index out of bounds: $fid" unless $f;
	}
	elsif ( $self->{OGR}->{Layer} ) {
	    $f = $self->{OGR}->{Layer}->GetFeature($fid);
	}
	else {
	    croak "no layer";
	}
	my $defn = $f->GetDefnRef;
	$feature = {};
	my $n = $defn->GetFieldCount();
	for my $i ( 0 .. $n - 1 ) {
	    my $fd   = $defn->GetFieldDefn($i);
	    my $name = $fd->GetName;
	    $feature->{$name} = $f->GetField($i);
	}
	$feature->{geometry} = Geo::OGC::Geometry->new
	    (Text => $f->GetGeometryRef->ExportToWkt);
	return $feature;
    }
}

## @method Geo::OGR::Geometry geometry($fid, $geometry)
# @brief Get, set or add a geometry.
# @param $fid (optional) The feature id, whose geometry to set or get.
# @param $geometry (optional) The geometry, which to set or add.
# @return A geometry object.
sub geometry {
    my($self, $fid, $geometry) = @_;
    if ($geometry) {
	# update at fid
	if ( $self->{features} ) {
	    $self->{features}->[$fid]->SetGeometry($geometry);
	}
	elsif ( $self->{OGR}->{Layer} ) {
	    my $feature = $self->feature($fid);
	    $feature->SetGeometry($geometry);
	}
	else {
	    croak "no layer";
	}
    }
    elsif (ref $fid) {
	$self->add_feature(geometry => $fid);
    }
    else {
	# retrieve
	my $f;
	if ( $self->{features} ) {
	    $f = $self->{features}->[$fid];
	    croak "feature: index out of bounds: $fid" unless $f;
	}
	elsif ( $self->{OGR}->{Layer} ) {
	    $f = $self->{OGR}->{Layer}->GetFeature($fid);
	}
	else {
	    croak "no layer";
	}
	return $f->GetGeometryRef->Clone;
    }
}

## @method Geo::OGR::Feature make_feature(%feature)
#
# @brief Creates a Geo::OGR::Feature object from attribute data and a
# Geo::OGC::Geometry object.
# @param[in] feature a hash whose keys are field names or 'geometry'
# and values are field values, or, for geometry, well-known text or an
# object which responds to AsText method by returning well-known text.
# @return Geo::OGR::Feature object.
# @note If the parameter is already a reference to an Geo::OGR::Feature nothing
# is done to the feature.
sub make_feature {
    my $self = shift;
    my %feature;
    if ( @_ == 1 ) {
	my $feature = shift;
	return $feature if isa($feature, 'Geo::OGR::Feature');
	%feature = %$feature;
    }
    else {
	%feature = @_;
    }
    croak "Geo::Vector::make_feature: No geometry specified" unless $feature{geometry};
    my $defn;
    if ( $self->{features} ) {
	$defn = Geo::OGR::FeatureDefn->new();
	for my $name ( sort keys %feature ) {
	    next if $name eq 'geometry';
	    my $value = $feature{$name};    # fieldname found.
	    my $type;
	    if ( $value =~ /^[+-]*\d+$/ ) {
		$type = $Geo::OGR::OFTInteger;
	    }
	    elsif ( $value =~ /^[+-]*\d*\.*\d*$/ and $value =~ /\d/ ) {
		$type = $Geo::OGR::OFTReal;
	    }
	    else {
		$type = $Geo::OGR::OFTString;
	    }
	    my $fd = Geo::OGR::FieldDefn->new( $name, $type );
	    $fd->ACQUIRE;
	    $fd->SetWidth(10) if $type == $Geo::OGR::OFTInteger;
	    $defn->AddFieldDefn($fd);
	}
    }
    else {
	$defn = $self->{OGR}->{Layer}->GetLayerDefn();
    }
    
    $defn->DISOWN; # feature owns
    my $feature = Geo::OGR::Feature->new($defn);
    
    my $n = $defn->GetFieldCount();
    for my $i ( 0 .. $n - 1 ) {
	my $fd   = $defn->GetFieldDefn($i);
	my $name = $fd->GetName;
	$feature->SetField( $name, $feature{$name} );
    }
    my $geom;
    if (isa($feature{geometry}, 'Geo::OGR::Geometry')) {
	$geom = Geo::OGR::CreateGeometryFromWkt( $feature{geometry}->ExportToWkt );
    } elsif (isa($feature{geometry}, 'Geo::OGC::Geometry')) {
	$geom = Geo::OGR::CreateGeometryFromWkt( $feature{geometry}->AsText );
    } else {
	$geom = Geo::OGR::CreateGeometryFromWkt( $feature{geometry} );
    }
    $feature->SetGeometry( $geom );
    
    return $feature;
}

## @method void add_feature(%feature)
#
# @brief Adds a feature to the layer.
# @param[in] feature a hash whose keys are field names and 'geometry'
# and values are field values and a Geo::OGC::Geometry object.

## @method void add_feature(Geo::OGR::Feature feature)
#
# @brief Adds a feature to the layer.
# @param feature A Geo::OGR::Feature object.
sub add_feature {
    my $self = shift;
    my $feature = $self->make_feature(@_);
    if ($self->{features}) {
	push @{$self->{features}}, $feature;
    } else {
	$self->{OGR}->{Layer}->CreateFeature($feature);
	$self->{OGR}->{Layer}->SyncToDisk;
    }
}

## @method listref features(%params)
#
# @brief Returns features satisfying the given requirement.
# @param[in] params is a list named parameters
# - \a that_contain => an Geo::OGR::Geometry. The returned
# features are such that the geometry is within them. If the geometry
# is a multigeometry, then the features that have at least one of the
# geometries within.
# - \a that_are_within => an Geo::OGR::Geometry. The returned
# features are those that are within the geometry. If the geometry is
# a multigeometry, then the features are within at least one of the
# geometries.
# - \a that_intersect => Geo::OGR::Geometry object. The returned
# features are those that intersect with the geometry. If the geometry
# is a multigeometry, then the features intersect with at least one of
# the geometries.
# - \a with_id => Reference to an array of feature indexes (fids).
# - \a from => If defined, the number of features that are skipped + 1.
# - \a limit => If defined, maximum number of features returned.
# @return A reference to an array of features.
sub features {
    my ( $self, %params ) = @_;
    my @features;
    my $from = $params{from} || 1;
    my $limit = 0;
    $limit = $from + $params{limit} if exists $params{limit};
    my $geom;
    my $is_collection;
    my $n;
    my $e;
    my $is_all = 0;
    for (keys %params) {
	if (/^that/) {
	    $geom  = $params{$_};
	    $is_collection = ($geom->GetGeometryType & ~0x80000000) == $Geo::OGR::wkbGeometryCollection;
	    $n     = $geom->GetGeometryCount();
	    $e     = $geom->GetEnvelope;
	}
    }
    my $i = 0;
    if ($self->{OGR}->{Layer}) 
    {
	my $layer = $self->{OGR}->{Layer};
	if ($e) {
	    $layer->SetSpatialFilterRect( $e->[0], $e->[2], $e->[1], $e->[3] );
	    $layer->ResetReading();
	}
	if ( exists $params{that_contain} ) 
	{
	    while (1) {
		my $f = $layer->GetNextFeature();
		$is_all = 1, last unless $f;
		my $g = $f->GetGeometryRef;
		if ($is_collection) {
		    my $w = 0;
		    for my $j (0..$n-1) {
			$w = $geom->GetGeometryRef($j)->Within($g);
			last if $w;
		    }
		    next unless $w;
		} else {
		    next unless $geom->Within($g);
		}
		$i++;
		next if $i < $from;
		push @features, $f;
		last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{that_are_within} ) 
	{
	    while (1) {
		my $f = $layer->GetNextFeature();
		$is_all = 1, last unless $f;
		my $g = $f->GetGeometryRef;
		if ($is_collection) {
		    my $w = 0;
		    for my $j (0..$n-1) {
			$w = $g->Within($geom->GetGeometryRef($j));
			last if $w;
		    }
		    next unless $w;
		} else {
		    next unless $g->Within($geom);
		}
		$i++;
		next if $i < $from;
		push @features, $f;
		last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{that_intersect} ) 
	{
	    while (1) {
		my $f = $layer->GetNextFeature();
		$is_all = 1, last unless $f;
		my $g = $f->GetGeometryRef;
		if ($is_collection) {
		    my $w = 0;
		    for my $j (0..$n-1) {
			$w = $g->Intersect($geom->GetGeometryRef($j));
			last if $w;
		    }
		    next unless $w;
		} else {
		    next unless $g->Intersect($geom);
		}
		$i++;
		next if $i < $from;
		push @features, $f;
		last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{filter_with_rect} ) 
	{
	    my $rect  = $params{filter_with_rect};
	    $layer->SetSpatialFilterRect( @$rect );
	    $layer->ResetReading();
	    while (1) {
		my $f = $layer->GetNextFeature();
		$is_all = 1, last unless $f;
		$i++;
		next if $i < $from;
		push @features, $f;
		last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{with_id} ) {
	    my $fids = $params{with_id};
	    for my $f (@$fids) {
		my $x = $layer->GetFeature($f);
		push @features, $x if $x;
	    }
	    $is_all = 1;
	}
	else {
	    $layer->SetSpatialFilter(undef);
	    $layer->ResetReading();
	    while (1) {
		my $f = $layer->GetNextFeature();
		$is_all = 1, last unless $f;
		$i++;
		next if $i < $from;
		push @features, $f;
		last if $limit and $i >= $limit-1;
	    }
	}
	unless ($is_all) {
	    my $f = $layer->GetNextFeature();
	    $is_all = 1 unless $f;
	}
	$layer->SetSpatialFilter(undef) if $e; # remove the filter
    } 
    elsif ( $self->{features} )
    {
	if ( exists $params{that_contain} ) 
	{
	    for my $f (@{$self->{features}}) {
		my $g = $f->GetGeometryRef;
		if ($is_collection) {
		    my $w = 0;
		    for my $j (0..$n-1) {
			$w = $geom->GetGeometryRef($j)->Within($g);
			last if $w;
		    }
		    next unless $w;
		} else {
		    next unless $geom->Within($g);
		}
		$i++;
		next if $i < $from;
		push @features, $f;
		last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{that_are_within} ) 
	{
	    for my $f (@{$self->{features}}) {
		my $g = $f->GetGeometryRef;
		if ($is_collection) {
		    my $w = 0;
		    for my $j (0..$n-1) {
			$w = $g->Within($geom->GetGeometryRef($j));
			last if $w;
		    }
		    next unless $w;
		} else {
		    next unless $g->Within($geom);
		}
		$i++;
		next if $i < $from;
		push @features, $f;
		last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{that_intersect} ) 
	{
	    for my $f (@{$self->{features}}) {
		my $g = $f->GetGeometryRef;
		if ($is_collection) {
		    my $w = 0;
		    for my $j (0..$n-1) {
			$w = $g->Intersect($geom->GetGeometryRef($j));
			last if $w;
		    }
		    next unless $w;
		} else {
		    next unless $g->Intersect($geom);
		}
		$i++;
		next if $i < $from;
		push @features, $f;
		last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{filter_with_rect} ) 
	{
	    my $rect  = $params{filter_with_rect};
	    for my $f (@{$self->{features}}) {
		$i++;
		next if $i < $from;
		push @features, $f;
		last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{with_id} ) {
	    my $fids = $params{with_id};
	    for my $f (@$fids) {
		my $x = $self->{features}->[$f];
		push @features, $x if $x;
	    }
	}
	else {
	    for my $f (@{$self->{features}}) {
		$i++;
		next if $i < $from;
		push @features, $f;
		last if $limit and $i >= $limit-1;
	    }
	}
	$is_all = @features == @{$self->{features}};
    }
    return wantarray ? (\@features, $is_all) : \@features;
}

## @method @world(hash params)
#
# @brief Get the bounding box (xmin, ymin, xmax, ymax) of the layer or one of
# its features.
#
# The method uses Geo::OGR::Geometry::GetEnvelope() or
# Geo::OGR::Layer::GetExtent().
#
# Example of getting a bounding box:
# @code
# @bb = $vector->world(feature=><feature_index>);
# @endcode
#
# @param[in] params is a list of named parameters:
# - feature => feature_index (optional).
# @return Returns the bounding box (minX, minY, maxX, maxY) as an array.
# If a single feature is defined with it's index as parameter, then the method
# returns that feature's bounding box, else the whole layer's bounding box.
sub world {
    my $self = shift;
    my %params;
    %params = @_ unless @_ % 2;
    my $extent;
    if ( defined $params{feature} ) {
	my $f;
	if ( $self->{features} ) {
	    $f = $self->{features}->[ $params{feature} ];
	} elsif ( $self->{OGR}->{Layer} ) {
	    $f = $self->{OGR}->{Layer}->GetFeature( $params{feature} );
	} else {
	    croak "no layer";
	}
	croak "feature with fid=$params{feature} does not exist" unless $f;
	eval { $extent = $f->GetGeometryRef()->GetEnvelope(); };
	croak "GetEnvelope failed: $@" if $@;
    }
    else {
	if ( $self->{features} ) {
	    for my $f ( @{ $self->{features} } ) {
		my $e = $f->GetGeometryRef()->GetEnvelope();
		unless ($extent) {
		    @$extent = @$e;
		}
		else {
		    $extent->[0] = MIN( $extent->[0], $e->[0] );
		    $extent->[2] = MIN( $extent->[2], $e->[2] );
		    $extent->[1] = MAX( $extent->[1], $e->[1] );
		    $extent->[3] = MAX( $extent->[3], $e->[3] );
		}
	    }
	}
	elsif ( $self->{OGR}->{Layer} ) {
	    eval { $extent = $self->{OGR}->{Layer}->GetExtent(); };
	    croak "GetExtent failed: $@" if $@;
	}
	else {
	    croak "no layer";
	}
    }
    
    # return a sensible world in any case
    unless ($extent) {
	$extent = [ 0, 1, 0, 1 ];
    }
    else {
	$extent->[1] = $extent->[0] + 1 if $extent->[1] <= $extent->[0];
	$extent->[3] = $extent->[2] + 1 if $extent->[3] <= $extent->[2];
    }
    return ( $extent->[0], $extent->[2], $extent->[1], $extent->[3] );
}

## @method Geo::Vector clip(%params)
#
# @brief Clip selected features from the layer into a new layer.
#
# @param[in] params is a list of named parameters:
# - \a layer_name name for the new layer (default is "clip")
# - \a driver driver (default is the driver of the layer)
# - \a data_source data source (default is the data source of the layer)
# - \a selected_features selected features (a ref to an array)
# The params are forwarded to the constructor of the new layer.
# @return A Geo::Vector object.
# @bug If self is a polygon shapefile, the result seems to be linestrings, but
# the saved shapefile is ok.
sub clip {
    my($self, %params) = @_;

    $params{create} = 'clip' unless $params{create};
    $params{data_source} = $params{datasource} if $params{datasource}; 
    $params{data_source} = $self->{data_source} unless $params{data_source};
    $params{driver} = $self->driver unless $params{driver};

    my $clip = new Geo::Vector(%params);

    my $schema = $self->{OGR}->{Layer}->GetLayerDefn();

    for my $i (0..$schema->GetFieldCount-1) {
	my $fd = $schema->GetFieldDefn($i);
	$clip->{OGR}->{Layer}->CreateField($fd);
    }

    for my $f (@{$params{selected_features}}) {
	
	next unless $f; # should not happen
	
	my $geometry = $f->GetGeometryRef();
	
	# make copies of the features and add them to clip
	
	my $feature = new Geo::OGR::Feature($schema);
	$feature->SetGeometry($geometry); # makes a copy
	
	for my $i (0..$schema->GetFieldCount-1) {
	    my $value = $f->GetField($i);
	    $feature->SetField($i, $value) if defined $value;
	}
	
	$clip->{OGR}->{Layer}->CreateFeature($feature);
	
    }
    
    $clip->{OGR}->{Layer}->SyncToDisk;
    $params{layer} = $params{create};
    delete $params{create};
    return Geo::Vector->new(%params);
}

## @method void add_layer(Geo::Vector another)
#
# @brief Adds an another layer to this layer.
# @param[in] another An another Geo::Vector layer.
# @note The layers must have the same geometry_type.
sub add_layer {
    my ( $self, $another ) = @_;
    
    croak "the layer is not writable" unless $self->{update};

    my $type =
	$GEOMETRY_TYPE_INV{ $self->{OGR}->{Layer}->GetLayerDefn->GetGeomType };
    my $another_type =
	$GEOMETRY_TYPE_INV{ $another->{OGR}->{Layer}->GetLayerDefn->GetGeomType };
    
    croak "can't add a $another_type layer to a $type layer"
	unless $type eq $another_type;
    
    my $defn = $self->{OGR}->{Layer}->GetLayerDefn();
    
    my $schema         = $self->schema;
    my $another_schema = $another->schema;
    
    $another->{OGR}->{Layer}->ResetReading();
    
    while (1) {
	my $f = $another->{OGR}->{Layer}->GetNextFeature();
	last unless $f;
	
	my $geometry = $f->GetGeometryRef();
	
	# make copies of the features and add them to self
	
	my $feature = new Geo::OGR::Feature($defn);
	$feature->SetGeometry($geometry);    # makes a copy
	
	for my $name ( keys %$schema ) {
	    next if $name =~ /^\./;
	    next unless $another_schema->{$name};
	    $feature->SetField($name, $f->GetField($name));
	}
	$self->{OGR}->{Layer}->CreateFeature($feature);
    }
    $self->{OGR}->{Layer}->SyncToDisk;
}

## @method Geo::Raster rasterize(%params)
#
# @brief Creates a new Geo::Raster from this Geo::Vector object.
#
# The new Geo::Raster has the size and extent of the Geo::Raster $this and draws
# the layer on it. The raster is boolean integer raster unless value_field is
# given. If value_field is floating point value, the returned raster is a
# floating point raster. render_as hash is optional, but if given should be one of
# 'Native', 'Points', 'Lines', or 'Polygons'. $fid (optional) is the number of
# the feature to render.
#
# @param[in] params is a list of named parameters: 
# - \a like (optional). A Geo::Raster object, from which the resulting
# Geo::Raster object's size and extent are copied.
# - \a M (optional). Height of the resulting Geo::Raster object. Has to be
# given if hash like is not given. If like is given, then M will not be used.
# - \a N (optional). Width of the resulting Geo::Raster object. Has to be
# given if hash like is not given. If like is given, then N will not be used.
# - \a world (optional). The world (bounding box) of the resulting raster
# layer. Useless to give if parameter like is given, because then it's world
# will be used.
# - \a render_as (optional). Rendering mode, which should be 'Native',
# 'Points', 'Lines' or 'Polygons'.
# - \a feature (optional). Number of the feature to render.
# - \a value_field (optional). Value fields name.
# @return A new Geo::Raster, which has the size and extent of the given as
# @todo make this work for schema free layers
# parameters and values
sub rasterize {
    my $self = shift;
    my %params;
    
    %params = @_ if @_;
    
    my %defaults = (
		    render_as => $self->{RENDER_AS} ? $self->{RENDER_AS} : 'Native',
		    feature => -1,
		    nodata_value => -9999,
		    datatype     => 'Integer'
		    );

    for ( keys %defaults ) {
	$params{$_} = $defaults{$_} unless exists $params{$_};
    }
    
    croak "Not a valid rendering mode: $params{render_as}" unless defined $RENDER_AS{$params{render_as}};
    
    croak "Geo::Vector->rasterize: empty layer" unless $self->{OGR}->{Layer};
    my $handle = OGRLayerH( $self->{OGR}->{Layer} );
    
    ( $params{M}, $params{N} ) = $params{like}->size(of_GDAL=>1) if $params{like};
    $params{world} = [ $params{like}->world() ] if $params{like};
    
    croak "Geo::Vector->rasterize needs the raster size: M, N"
	unless $params{M} and $params{N};
    
    $params{world} = [ $self->world() ] unless $params{world};
    
    my $field = -1;
    if ( defined $params{value_field} and $params{value_field} ne '' ) {
	my $schema = $self->schema()->{ $params{value_field} };
	croak "rasterize: field with name '$params{value_field}' does not exist"
	    unless defined $schema;
		croak
		    "rasterize: can't use value from field ".
		    "'$params{value_field}' since its' type is '$schema->{TypeName}'"
		    unless $schema->{TypeName} eq 'Integer'
		    or $schema->{TypeName}     eq 'Real';
	$field = $schema->{Number};
	$params{datatype} = $schema->{TypeName};
    }
    
    my $gd = Geo::Raster->new(
			      datatype => $params{datatype},
			      M        => $params{M},
			      N        => $params{N},
			      world    => $params{world}
			      );
    $gd->nodata_value( $params{nodata_value} );
    $gd->set('nodata');
    
    xs_rasterize( $handle, $gd->{GRID},
		  $RENDER_AS{ $params{render_as} },
		  $params{feature}, $field );
    
    return $gd;
}

## @ignore
# Creates an undirected weighted graph from the OGR-layer.
# The edge weights are calculated according to the distances between the 
# points inside each layer's feature. Requires Geo::Distance.
sub graph {
    my ($self) = @_;
    my %node;
    my %edge;
    my $layer = $self->{OGR}->{Layer};
    $layer->ResetReading();
    my $distance = Geo::Distance->new();
    while ( my $feature = $layer->GetNextFeature() ) {
	
	my $geom = $feature->GetGeometryRef();
	my $n    = $geom->GetPointCount - 1;
	
	my $length = 0;
	
	# length of linestring computation, this is lat lon
	my $lon1 = $geom->GetX(0);
	my $lat1 = $geom->GetY(0);
	for my $i ( 1 .. $n ) {
	    my $lon2 = $geom->GetX($i);
	    my $lat2 = $geom->GetY($i);
	    $length +=
		$distance->distance( 'meter', $lon1, $lat1, $lon2, $lat2 );
	    $lon1 = $lon2;
	    $lat1 = $lat2;
	}
	
	# the cost model
	my $cost = $length;
	
	if (    $geom->GetGeometryCount == 0
		and $geom->GetGeometryName =~ /^linestring/i ) {
	    
	    my $fid = $feature->GetFID();
	    
	    # the accuracy
	    my $first = sprintf( "%.5f %.5f", $geom->GetX(0), $geom->GetY(0) );
	    my $last = sprintf( "%.5f %.5f", $geom->GetX($n), $geom->GetY($n) );
	    
	    $node{$first}++;
	    $node{$last}++;
	    
	    # edges
	    my $liikennevi = $feature->GetField('LIIKENNEVI');
	    if ( $liikennevi == 2 ) {
		$edge{$first}{$last} = $cost;
		$edge{$last}{$first} = $cost;
	    }
	    elsif ( $liikennevi == 3 ) {
		$edge{$last}{$first} = $cost;
	    }
	    elsif ( $liikennevi == 4 ) {
		$edge{$first}{$last} = $cost;
	    }
	}
    }
    
    my $g = Graph->new;
    for my $u ( keys %node ) {
	$g->add_vertex($u);
	for my $v ( keys %{ $edge{$u} } ) {
	    $g->add_weighted_edge( $u, $v, $edge{$u}{$v} );
	}
    }
    $self->{graph} = $g;
}

## @method void overlay_graph(Gtk2::Gdk::Pixmap pixmap)
#
# @brief Creates from the objects graph an overlay graph (incl. vertices and 
# edges) as a pixmap.
# @param[in,out] pixmap Gtk2::Gdk::Pixmap
sub overlay_graph {
    my ( $self, $pixmap ) = @_;
    my @V  = $self->{graph}->vertices;
    my $gc = new Gtk2::Gdk::GC $pixmap;
    $gc->set_rgb_fg_color( Gtk2::Gdk::Color->new( 65535, 65535, 0 ) );
    for my $v (@V) {
	my @p = split /\s+/, $v;
	@p = $self->{overlay}->point2pixmap_pixel(@p);
	$pixmap->draw_rectangle( $gc, 0, $p[0] - 2, $p[1] - 2, 5, 5 );
    }
    my @E = $self->{graph}->edges;
    for my $e (@E) {
	my @u = split /\s+/, $e->[0];
	my @v = split /\s+/, $e->[1];
	@u = $self->{overlay}->point2pixmap_pixel(@u);
	@v = $self->{overlay}->point2pixmap_pixel(@v);
	$pixmap->draw_line( $gc, @u, @v );
	next;
	
	# arrows.. not very helpful
	my $deltaX = $v[0] - $u[0];
	my $deltaY = $v[1] - $u[1];
	my $theta  =
	    $deltaX == 0 ? 3.14159 / 2.0 : POSIX::atan( $deltaY / $deltaX );
	my $theta2 = $theta;
	$theta2 += 3.14159 if $deltaX < 0;
	my $lengthdeltaX = -cos($theta2) * 8;
	my $lengthdeltaY = -sin($theta2) * 8;
	my $widthdeltaX  = sin($theta2) * 5;
	my $widthdeltaY  = cos($theta2) * 5;
	$pixmap->draw_line(
			   $gc, @v,
			   int( $v[0] + $lengthdeltaX + $widthdeltaX ),
			   int( $v[1] + $lengthdeltaY - $widthdeltaY )
			   );
	$pixmap->draw_line(
			   $gc, @v,
			   int( $v[0] + $lengthdeltaX - $widthdeltaX ),
			   int( $v[1] + $lengthdeltaY + $widthdeltaY )
			   );
    }
}

sub MIN {
    $_[0] > $_[1] ? $_[1] : $_[0];
}

sub MAX {
    $_[0] > $_[1] ? $_[0] : $_[1];
}

1;
__END__

=pod

=head1 SEE ALSO

Geo::GDAL

This module should be discussed in geo-perl@list.hut.fi.

The homepage of this module is http://libral.sf.net.

=head1 AUTHOR

Ari Jolma, E<lt>ari.jolma at tkk.fiE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2006 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
