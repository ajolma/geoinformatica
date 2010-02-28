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

use vars qw( @ISA %RENDER_AS );

our $VERSION = '0.52';

require Exporter;

@ISA = qw( Exporter );

our %EXPORT_TAGS = ( 'all' => [qw( %RENDER_AS )] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

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
# @return a list of valid geometry types (as strings).
sub geometry_types {
    return @Geo::OGR::Geometry::GEOMETRY_TYPES;
}

## @cmethod @render_as_modes()
#
# @brief Returns a list of valid render as modes.
#
# @return a list of valid render as modes (as strings).
sub render_as_modes {
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
    my $self = {};
    open_data_source($self, $driver, $data_source, 0);
    return unless $self->{OGR}->{DataSource};
    my %layers;
    for my $i ( 0 .. $self->{OGR}->{DataSource}->GetLayerCount - 1 ) {
	my $l  = $self->{OGR}->{DataSource}->GetLayerByIndex($i);
	my $fd = $l->GetLayerDefn();
	my $t  = $fd->GetGeomType;
	next unless exists $Geo::OGR::Geometry::TYPE_INT2STRING{$t};
	$layers{ $l->GetName } = $Geo::OGR::Geometry::TYPE_INT2STRING{$t};
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
    my $self = {};
    open_data_source($self, $driver, $data_source, 1);
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
# A Geo::Vector object is either a wrapped Geo::OGR::Layer or a
# collection of Geo::OGR::Feature objects. Without any parameters an
# empty OGR memory layer without any attributes is created. A feature
# collection object does not have a unique schema.
#
# @param params Named parameters, all are optional: (see also the
# named parameters of the Geo::Vector::layer method)
# - \a driver => string Name of the OGR driver for creating or opening
# a data source. If not given, an attempt is made to open the data
# source using the data source parameter.
# - \a create_options => reference to a hash of data source creation
# options. May be empty. Forwarded to
# Geo::OGR::CreateDataSource. Required to create other than memory
# data sources.
# - \a data_source => string OGR data source to create or
# open. Opening a data source is first attempted unless create_options
# is given. If open fails, creation is attempted.
# - \a open => string The layer to open.
# - \a layer => string [deprecated] Same as \a open.
# - \a create => string The layer to create.
# - \a layer_options forwarded to Geo::OGR::DataSource::CreateLayer.
# - \a SQL => string SQL-string, forwarded to
# Geo::OGR::DataSource::ExecuteSQL. An alternative to \a open and \a
# create.
# - \a geometry_type => string The geometry type for the
# new layer. Default is 'Unknown'.
# - \a schema, as in method Geo::Vector::schema.
# - \a encoding => string, the encoding of the attribute values of the
# features.
# - \a srs => either a string which defines a spatial reference system
# (e.g. 'EPSG:XXXX') or a Geo::OSR::SpatialReference object. The srs
# for the new layer. Default is 'EPSG:4326'.
# - \a features => a reference to a list of features to be inserted
# into the collection. May be empty. If given, the resulting object is
# a feature collection object, and not an OGR layer.
# - \a geometries => a reference to a list of geometries to be
# inserted as new features into the collection. Creates features
# without attributes for the geometries. May be empty. If given, the
# resulting object is a feature collection object, and not an OGR
# layer. Do not mix with \a features.
# @return A new Geo::Vector object
sub new {
    my $package = shift;
    my $self = {};
    bless $self => (ref($package) or $package);

    my %params = @_ == 1 ? ( single => $_[0] ) : @_;

    # the single parameter can be a filename, geometry, feature, or a
    # list of geometries or features, which are copied into a new
    # memory layer

    if (ref($params{single})) {
    } else {
	$params{data_source} = $params{single} if $params{single};
    }

    # complain about unknown / deprecated parameters
    my %known = (
	driver => 1,
	create_options => 1,
	data_source => 1,
	open => 1,
	create => 1,
	layer_options => 1,
	SQL => 1,
	geometry_type => 1,
	schema => 1,
	encoding => 1,
	srs => 1,
	features => 1,
	geometries => 1,
	);

    for my $param (keys %params) {
	unless ($known{$param}) {
#	    warn("parameter $param is unknown or deprecated in Geo::Vector->new()") 
	}
    }

    # aliases
    $params{data_source} = $params{filename} if $params{filename};
    $params{data_source} = $params{datasource} if $params{datasource};
    $params{open} = $params{name} if $params{name};
    $params{open} = $params{layer_name} if $params{layer_name};
    $params{open} = $params{layer} if $params{layer};
    $params{SQL} = $params{sql} if $params{sql};
    $params{layer_options} = [] unless $params{layer_options};
    $params{geometry_type} = $params{schema}{GeometryType} if ref $params{schema};

    if ($params{features} or $params{geometries}) {
	$self->{features} = [];
	for my $g (@{$params{geometries}}) {
	    $self->geometry($g);
	}
	for my $f (@{$params{features}}) {
	    $self->feature($f);
	}
	return $self;
    }

    $params{update} = $params{create} ? 1 : 0;
    $self->{encoding} = $params{encoding};

    $self->open_data_source($params{driver}, $params{data_source}, $params{update}, $params{create_options});

    if ($params{create} or $self->{OGR}->{Driver}->{name} eq 'Memory') {

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
	$params{geometry_type} = 'Unknown' unless $params{geometry_type};
	$params{layer_options} = '' unless $params{layer_options};
	croak "$self->{OGR}->{Driver}->{name}: $params{data_source}: ".
	    "Data source does not have the capability to create layers"
	    unless $self->{OGR}->{DataSource}->TestCapability('CreateLayer');
	eval {
	    $self->{OGR}->{Layer} =
		$self->{OGR}->{DataSource}->CreateLayer( $params{create}, 
							 $srs, 
							 $params{geometry_type},
							 $params{layer_options});
	};
	croak "CreateLayer failed: $@" unless $self->{OGR}->{Layer};
	
    } elsif ( $params{SQL} ) {
	    
	$self->{SQL} = $params{SQL};
	eval {
	    $self->{OGR}->{Layer} =
		$self->{OGR}->{DataSource}->ExecuteSQL( $self->{SQL} );
	};
	croak "ExecuteSQL failed: $@" unless $self->{OGR}->{Layer};
	
    } elsif ($params{open}) {
	
	$self->{OGR}->{Layer} =
	    $self->{OGR}->{DataSource}->Layer( $params{open} );
	
    } else {
	
	# open the first layer
	$self->{OGR}->{Layer} = $self->{OGR}->{DataSource}->GetLayerByIndex();
	croak "Could not open the default layer: $@" unless $self->{OGR}->{Layer};
	
    }

    schema($self, $params{schema}) if $params{schema};
    $self->{OGR}->{Layer}->SyncToDisk unless $self->{OGR}->{Driver}->{name} eq 'Memory';
    return $self;
}

## @ignore
sub open_data_source {
    my($self, $driver, $data_source, $update, $create_options) = @_;
    if ($driver or !$data_source) {
	if (!$data_source) {
	    $data_source = '';
	    $self->{OGR}->{Driver} = Geo::OGR::GetDriver('Memory');
	    $create_options = {};
	} elsif (isa($driver, 'Geo::OGR::Driver')) {
	    $self->{OGR}->{Driver} = $driver;
	} else {
	    $self->{OGR}->{Driver} = Geo::OGR::GetDriver($driver);
	}
	croak "Can't find driver: $driver" unless $self->{OGR}->{Driver};
	
	unless ($create_options) {

	    eval {
		$self->{OGR}->{DataSource} = $self->{OGR}->{Driver}->Open($data_source, $update);
	    };
	    return if $self->{OGR}->{DataSource};

	}

	croak "$self->{OGR}->{Driver}->{name}: ".
	    "Driver does not have the capability to create data sources"
	    unless $self->{OGR}->{Driver}->TestCapability('CreateDataSource');

	eval {
	    $self->{OGR}->{DataSource} = 
		$self->{OGR}->{Driver}->CreateDataSource($data_source, $create_options);
	};
	$@ = "no reason given" unless $@;
	croak "Can't open nor create data source: $@" unless $self->{OGR}->{DataSource};

    } else {
	eval {
	    $self->{OGR}->{DataSource} = Geo::OGR::Open($data_source, $update);
	};
        $@ = "no reason given" unless $@;
	croak "Can't open data source: $@" unless $self->{OGR}->{DataSource};
	$self->{OGR}->{Driver} = $self->{OGR}->{DataSource}->GetDriver;
    }
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
    while (my $feature = $self->next_feature()) {
	print $fh "Feature $i:\n";
	my $s = $schema;
	$s = $self->schema($i-1) unless $s;
	$i++;
	for my $name ($s->field_names) {
	    next if $name =~ /^\./;
	    my $value = $feature->GetField($name);
	    print $fh "$name: $value\n";
	}
	my $geom = $feature->GetGeometryRef();
	dump_geom($geom, $fh, $params{suppress_points});
    }
}

## @method init_iterate(%options)
# @param options Named parameters, all are optional.
# - \a features => reference to a list of features, which to iterate
# through.
# - \a filter => a spatial filter
# - \a filter_rect => reference to an array defining a spatial
# rectangle filter (min_x, min_y, max_x, max_y)
#
# @todo filter for feature collections
# @brief Reset reading features from the object iteratively.
sub init_iterate {
    my $self = shift;
    my %options = @_ if @_;
    if ($options{features}) {
	$self->{_features} = $options{features};
	$self->{_cursor} = 0;
	$self->{_filter_rect} = $options{filter_rect};
    } elsif ($self->{features}) {
	$self->{_cursor} = 0;
	$self->{_filter_rect} = $options{filter_rect};
    } else {
	if ( exists $options{filter} ) {
	    $self->{OGR}->{Layer}->SetSpatialFilter( $options{filter} );
	}
	elsif ( exists $options{filter_rect} ) {
	    $self->{OGR}->{Layer}->SetSpatialFilterRect( @{ $options{filter_rect} } );
	}
	else {
	    $self->{OGR}->{Layer}->SetSpatialFilter(undef);
	}
	$self->{OGR}->{Layer}->ResetReading();
    }
}

## @method next_feature()
#
# @brief Return a feature iteratively or undef if no more features. 
sub next_feature {
    my $self = shift;
    my $features = $self->{_features} || $self->{features};
    if ($features) {
	my $f;
	while (1) {
	    last if $self->{_cursor} > $#$features;
	    $f = $features->[$self->{_cursor}++];
	    last unless $self->{_filter_rect};
	    my $r = $self->{_filter_rect};
	    my $e = $f->GetGeometryRef()->GetEnvelope(); # [$minx, $maxx, $miny, $maxy]
	    last if 
		$e->[0] <= $r->[2] and $e->[1] >= $r->[0] and
		$e->[2] <= $r->[3] and $e->[3] >= $r->[1];
	}
	return $f if $f;
	delete $self->{_cursor};
	delete $self->{_features};
	return;
    }
    my $f = $self->{OGR}->{Layer}->GetNextFeature();
    $self->{OGR}->{Layer}->SetSpatialFilter(undef) unless $f;
    return $f;
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
	    for my $name ($params{schema}->field_names) {
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
	    for my $name ($params{schema}->field_names) {
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
# if one is created, and for iterating through the features of other.
# @return (If used in non-void context) A new Geo::Vector object, which
# contain features from both this and from the other.
sub add {
    my $self = shift;
    my $other = shift;
    #print STDERR "add from $other->{NAME} to $self->{NAME}\n";
    my %params = @_ if @_;
    if (defined wantarray) {
	$params{schema} = $self->schema();
	$self = Geo::Vector->new(%params);
    }
    my $dst_layer = $self->{OGR}->{Layer} unless $self->{features};
    my $dst_defn;
    my %dst_schema;
    my $dst_geometry_type;
    if ($dst_layer) {
	$dst_defn = $dst_layer->GetLayerDefn();
	$dst_geometry_type = $dst_defn->GeometryType;
	$dst_geometry_type =~ s/25D$//;
	my $n = $dst_defn->GetFieldCount();
	for my $i ( 0 .. $n - 1 ) {
	    my $fd   = $dst_defn->GetFieldDefn($i);
	    $dst_schema{$fd->GetName} = $fd->GetType;
	}
    } else {
	$dst_geometry_type = 'Unknown';
    }
    $other->init_iterate(%params);
    while (my $feature = $other->next_feature()) {
	my $geom = $feature->GetGeometryRef();

	# check for match of geometry types
	next unless $dst_geometry_type eq 'Unknown' or 
	    $dst_geometry_type =~ /$geom->GeometryType/;

	my $src_defn = $feature->GetDefnRef;
	my $defn = $dst_defn ? $dst_defn : $src_defn;
	my $f = Geo::OGR::Feature->new($defn);
	my $n = $src_defn->GetFieldCount();
	for my $i ( 0 .. $n - 1 ) {
	    my $fd   = $src_defn->GetFieldDefn($i);
	    my $name = $fd->GetName;
	    my $type = $fd->GetType;
	    if ($dst_defn) {
		# copy only those attributes which match
		next unless exists($dst_schema{$name}) and $dst_schema{$name} eq $type;
	    }
	    $f->SetField($name, $feature->GetField($name));
	}
	if ($params{transformation}) {
	    my $points = $geom->Points;
	    transform_points($points, $params{transformation});
	    $geom->Points($points);
	}
	$f->SetGeometry($geom);
	if ($dst_layer) {
	    $dst_layer->CreateFeature($f);
	} else {
	    push @{$self->{features}}, $f;
	}
    }
    $dst_layer->SyncToDisk unless $self->driver eq 'Memory';
    return $self if defined wantarray;
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
    return $Geo::OGR::Geometry::TYPE_INT2STRING{$t};
}

## @method hashref schema(hashref schema)
#
# @brief Get or set the schema of the layer.
#
# Schema is a hash whose keyes are Name, GeometryType, FID, Z, and
# Fields. Fields is a reference to a list of field schemas. A field
# schema is a hash whose keys are Name, Type, Justify, Width, and
# Precision. This is similar to schemas in Geo::OGR.
#
# @param[in] schema (optional) a reference to a hash specifying the schema.
# @return the schema.

## @method hashref schema($feature, hashref schema)
#
# @brief Get or set the schema of a feature in a feature collection.
#
# @param[in] feature the index of the feature, whose schema to get or set.
# @param[in] schema (optional) a reference to a hash specifying the schema.
# @return the schema.
sub schema {
    my $self = shift;
    my %schema;
    my $feature;
    if (ref($_[$#_]) eq 'HASH') {
	my $s = pop;
	%schema = %{$s};
    } else {
	if (@_ == 1) {
	    $feature = pop;
	} else {
	    %schema = @_;
	}
    }
    my $s = Gtk2::Ex::Geo::Layer::schema();
    if ($self->{features}) {
	return unless defined $feature;
	$s = $self->{features}->[$feature]->Schema(%schema);
    } else {
	$s = $self->{OGR}->{Layer}->Schema(%schema);
    }
    return bless $s, 'Gtk2::Ex::Geo::Schema';
}

## @ignore
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
    
    my $schema = $self->schema()->field($field_name);
    croak "value_range: field with name '$field_name' does not exist"
	unless defined $schema;
    croak
	"value_range: can't use value from field '$field_name' since its' type is '$schema->{Type}'"
	unless $schema->{Type} eq 'Integer'
	or $schema->{Type}     eq 'Real';
    
    return ( 0, $self->{OGR}->{Layer}->GetFeatureCount - 1 )
	if $field_name eq 'FID';
    
    my @range;
    
    $self->init_iterate(%params);
    while (my $f = $self->next_feature()) {
	my $value = $f->GetField($field_name);
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
    my $i = 0;
    my $from = $params{from} || 1;
    my $limit = 0;
    $limit = $from + $params{limit} if exists $params{limit};
    my $is_all = 1;

    if ( exists $params{with_id} ) {

	for my $fid (sort { $a <=> $b } @{$params{with_id}}) {
	    my $x = $self->{OGR}->{Layer}->GetFeature($fid) if $self->{OGR}->{Layer};
	    next unless $x;
	    $i++;
	    next if $i < $from;
	    push @features, $x;
	    $is_all = 0, last if $limit and $i >= $limit-1;
	}

    } else {

	my %options = ( filter_rect => $params{filter_with_rect} ) if $params{filter_with_rect};

	if ( exists $params{that_contain} ) 
	{
	    my $geom = $params{that_contain};
	    my $e = $geom->GetEnvelope;
	    $options{filter_rect} = [$e->[0], $e->[2], $e->[1], $e->[3]];
	    $self->init_iterate(%options);
	    while ( my $f = $self->next_feature() ) {
		my $g = $f->GetGeometryRef;
		next unless _within($geom, $g);
		$i++;
		next if $i < $from;
		push @features, $f;
		$is_all = 0, last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{that_are_within} ) 
	{
	    my $geom = $params{that_are_within};
	    my $e = $geom->GetEnvelope;
	    $options{filter_rect} = [$e->[0], $e->[2], $e->[1], $e->[3]];
	    $self->init_iterate(%options);
	    while ( my $f = $self->next_feature() ) {
		my $g = $f->GetGeometryRef;
		next unless _within($g, $geom);
		$i++;
		next if $i < $from;
		push @features, $f;
		$is_all = 0, last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{that_intersect} ) 
	{
	    my $geom = $params{that_intersect};
	    my $e = $geom->GetEnvelope;
	    $options{filter_rect} = [$e->[0], $e->[2], $e->[1], $e->[3]];
	    $self->init_iterate(%options);
	    while ( my $f = $self->next_feature() ) {
		my $g = $f->GetGeometryRef;
		next unless _intersect($g, $geom);
		$i++;
		next if $i < $from;
		push @features, $f;
		$is_all = 0, last if $limit and $i >= $limit-1;
	    }
	}
	else {
	    $self->init_iterate(%options);
	    while ( my $f = $self->next_feature() ) {
		$i++;
		next if $i < $from;
		push @features, $f;
		$is_all = 0, last if $limit and $i >= $limit-1;
	    }
	}
    }
    return wantarray ? (\@features, $is_all) : \@features;
}

## @ignore
sub _within {
    my($a, $b) = @_;
    if (($a->GetGeometryType & ~0x80000000) == $Geo::OGR::wkbGeometryCollection) {
	my $w = 1;
	for my $i (0..$a->GetGeometryCount()-1) {
	    $w = $a->GetGeometryRef($i)->Within($b);
	    last unless $w;
	}
	return $w;
    } elsif (($b->GetGeometryType & ~0x80000000) == $Geo::OGR::wkbGeometryCollection) {
	my $w = 0;
	for my $i (0..$b->GetGeometryCount()-1) {
	    $w = $a->Within($b->GetGeometryRef($i));
	    last if $w;
	}
	return $w;
    } else {
	return $a->Within($b);
    }
}

## @ignore
sub _intersect {
    my($a, $b) = @_;
    if (($a->GetGeometryType & ~0x80000000) == $Geo::OGR::wkbGeometryCollection) {
	my $w = 1;
	for my $i (0..$a->GetGeometryCount()-1) {
	    $w = $a->GetGeometryRef($i)->Intersect($b);
	    last unless $w;
	}
	return $w;
    } elsif (($b->GetGeometryType & ~0x80000000) == $Geo::OGR::wkbGeometryCollection) {
	my $w = 0;
	for my $i (0..$b->GetGeometryCount()-1) {
	    $w = $a->Intersect($b->GetGeometryRef($i));
	    last if $w;
	}
	return $w;
    } else {
	return $a->Intersect($b);
    }
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
	elsif ( $self->{OGR}->{Layer} and $self->{OGR}->{Layer}->GetFeatureCount() > 0 ) {
	    eval { $extent = $self->{OGR}->{Layer}->GetExtent(); };
	    croak "GetExtent failed: $@" if $@;
	}
    }
    
    return unless $extent;
    $extent->[1] = $extent->[0] + 1 if $extent->[1] <= $extent->[0];
    $extent->[3] = $extent->[2] + 1 if $extent->[3] <= $extent->[2];
    return ( $extent->[0], $extent->[2], $extent->[1], $extent->[3] );
}

## @method Geo::Vector copy(%params)
#
# @brief Copy selected or all features from the layer into a new layer.
#
# @param[in] params is a list of named parameters:
# - \a layer_name name for the new layer (default is "copy")
# - \a driver driver (default is the driver of the layer)
# - \a data_source data source (default is the data source of the layer)
# - \a features features (a ref to an array) to copy, if not defined
# then all are copied.
# The params are forwarded to the constructor of the new layer.
# @return A Geo::Vector object.
# @bug If self is a polygon shapefile, the result seems to be linestrings, but
# the saved shapefile is ok.
sub copy {
    my($self, %params) = @_;

    $params{create} = 'copy' unless $params{create};
    $params{data_source} = $params{datasource} if $params{datasource}; 
    $params{data_source} = $self->{data_source} unless $params{data_source};
    $params{driver} = $self->driver unless $params{driver};
    $params{schema} = $self->schema;

    my $copy = Geo::Vector->new(%params);

    my $fd = Geo::OGR::FeatureDefn->create($params{schema});
    my $i = 0;
    $self->init_iterate(%params);
    while (my $f = $self->next_feature()) {
	
	my $geometry = $f->GetGeometryRef();

	# transformation if that is wished
	if ($params{transformation}) {
	    my $points = $geometry->Points;
	    transform_points($points, $params{transformation});
	    $geometry->Points($points);
	}
	
	# make copies of the features and add them to copy
	
	my $feature = Geo::OGR::Feature->new($fd);
	$feature->SetGeometry($geometry); # makes a copy
	
	for my $i (0..$fd->GetFieldCount-1) {
	    my $value = $f->GetField($i);
	    $feature->SetField($i, $value) if defined $value;
	}
	
	$copy->add_feature($feature);
	
    }
    
    $copy->{OGR}->{Layer}->SyncToDisk if $copy->{OGR};
    return $copy;
}

## @ignore
sub transform_points {
    my($points, $ct) = @_;
    unless (ref($points->[0])) { # single point [x,y,z]
	@$points = $ct->TransformPoint(@$points);
	return;
    }
    $ct->TransformPoints($points), return 
	unless ref($points->[0]->[0]); # list of points [[x,y,z],[x,y,z],...]

    # list of list of points [[[x,y,z],[x,y,z],...],...]
    for my $p (@$points) {
	transform_points($p, $ct);
    }
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
	my $schema = $self->schema()->field($params{value_field});
	croak "rasterize: field with name '$params{value_field}' does not exist"
	    unless defined $schema;
		croak
		    "rasterize: can't use value from field ".
		    "'$params{value_field}' since its' type is '$schema->{Type}'"
		    unless $schema->{Type} eq 'Integer'
		    or $schema->{Type}     eq 'Real';
	$params{datatype} = $schema->{Type};
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
    my $distance = Geo::Distance->new();
    $self->init_iterate;
    while ( my $feature = $self->next_feature ) {
	
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
