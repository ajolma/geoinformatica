package Geo::Vector;

## @class Geo::Vector
# @brief A geospatial layer that consists of Geo::OGR::Features.
#
# This module should be discussed in https://list.hut.fi/mailman/listinfo/geo-perl
#
# The homepage of this module is 
# https://github.com/ajolma/geoinformatica
#
# @author Ari Jolma
# @author Copyright (c) 2005- by Ari Jolma
# @author This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.5 or,
# at your option, any later version of Perl 5 you may have available.

=pod

=head1 NAME

Geo::Vector - Perl extension for geospatial vectors

The <a href="http://geoinformatics.aalto.fi/doc/Geoinformatica/html/">documentation
of Geo::Vector</a> is in doxygen format.

=cut

use 5.008;
use strict;
use warnings;
use Carp;
use POSIX;
POSIX::setlocale( &POSIX::LC_NUMERIC, "C" ); # http://www.remotesensing.org/gdal/faq.html nr. 11
use XSLoader;
use Scalar::Util 'blessed';
use Geo::GDAL;
use Geo::OGC::Geometry;
use Geo::Vector::Feature;
use Geo::Vector::Layer;
use JSON;
use Gtk2;
use WWW::Curl::Easy;

use vars qw( @ISA %RENDER_AS );

our $VERSION = '0.53';

require Exporter;

@ISA = qw( Exporter );

our %EXPORT_TAGS = ( 'all' => [qw( %RENDER_AS )] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our $AUTOLOAD;

# from ral_visual.h:
%RENDER_AS = ( Native => 0, Points => 1, Lines => 2, Polygons => 4 );

## @ignore
# tell dynaloader to load this module so that xs functions are available to all:
sub dl_load_flags {0x01}

XSLoader::load( 'Geo::Vector', $VERSION );

my %dispatch = (
    Capabilities => \&Geo::OGR::Layer::Capabilities,
    TestCapability =>  \&Geo::OGR::Layer::TestCapability,
    Schema =>  \&Geo::OGR::Layer::Schema,
    Row =>  \&Geo::OGR::Layer::Row,
    Tuple =>  \&Geo::OGR::Layer::Tuple,
    SpatialFilter =>  \&Geo::OGR::Layer::SpatialFilter,
    SpatialFilter =>  \&Geo::OGR::Layer::SpatialFilter,
    SetSpatialFilter =>  \&Geo::OGR::Layer::SetSpatialFilter,
    SetSpatialFilterRect =>  \&Geo::OGR::Layer::SetSpatialFilterRect,
    GetSpatialFilter =>  \&Geo::OGR::Layer::GetSpatialFilter,
    SetAttributeFilter =>  \&Geo::OGR::Layer::SetAttributeFilter,
    ResetReading =>  \&Geo::OGR::Layer::ResetReading,
    GetNextFeature =>  \&Geo::OGR::Layer::GetNextFeature,
    SetNextByIndex =>  \&Geo::OGR::Layer::SetNextByIndex,
    GetFeaturesRead =>  \&Geo::OGR::Layer::GetFeaturesRead,
    GetName =>  \&Geo::OGR::Layer::GetName,
    GetFeature =>  \&Geo::OGR::Layer::GetFeature,
    SetFeature =>  \&Geo::OGR::Layer::SetFeature,
    CreateFeature =>  \&Geo::OGR::Layer::CreateFeature,
    InsertFeature =>  \&Geo::OGR::Layer::InsertFeature,
    DeleteFeature =>  \&Geo::OGR::Layer::DeleteFeature,
    SyncToDisk =>  \&Geo::OGR::Layer::SyncToDisk,
    GetLayerDefn =>  \&Geo::OGR::Layer::GetLayerDefn,
    GetFeatureCount =>  \&Geo::OGR::Layer::GetFeatureCount,
    GetExtent =>  \&Geo::OGR::Layer::GetExtent,
    CreateField =>  \&Geo::OGR::Layer::CreateField,
    StartTransaction =>  \&Geo::OGR::Layer::StartTransaction,
    CommitTransaction =>  \&Geo::OGR::Layer::CommitTransaction,
    RollbackTransaction =>  \&Geo::OGR::Layer::RollbackTransaction,
    GetSpatialRef =>  \&Geo::OGR::Layer::GetSpatialRef,
    AlterFieldDefn =>  \&Geo::OGR::Layer::AlterFieldDefn,
    DeleteField =>  \&Geo::OGR::Layer::DeleteField,
    GetFIDColumn =>  \&Geo::OGR::Layer::GetFIDColumn,
    GetGeometryColumn =>  \&Geo::OGR::Layer::GetGeometryColumn,
    GeometryType =>  \&Geo::OGR::Layer::GeometryType,
    SetIgnoredFields =>  \&Geo::OGR::Layer::SetIgnoredFields,
    ForFeatures => \&Geo::OGR::Layer::ForFeatures,
    ForGeometries => \&Geo::OGR::Layer::ForGeometries,
    Intersection => \&Geo::OGR::Layer::Intersection,
    Union => \&Geo::OGR::Layer::Union,
    SymDifference => \&Geo::OGR::Layer::SymDifference,
    Identity => \&Geo::OGR::Layer::Identity,
    Update => \&Geo::OGR::Layer::Update,
    Clip => \&Geo::OGR::Layer::Clip,
    Erase => \&Geo::OGR::Layer::Erase,
    );

## @ignore
# call Geo::OGR::Layer method as a fallback
sub AUTOLOAD {
    my $self = shift;
    (my $sub = $AUTOLOAD) =~ s/.*:://;
    if (exists $dispatch{$sub} and $self->{OGR}->{Layer}) {
	unshift @_, $self->{OGR}->{Layer};
	goto $dispatch{$sub};
    } else {
	croak "Undefined subroutine $sub";
    }
}

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

##@ignore
sub WFS_layers {
    my($url) = @_; # 'WFS:' + CURL style

    $url =~ s/^WFS://;
    $url .= '?service=WFS&version=1.1.0&request=GetCapabilities';
    my $curl = WWW::Curl::Easy->new;
    $curl->setopt(CURLOPT_HEADER,1);
    $curl->setopt(CURLOPT_URL, $url);
    my $xml;
    $curl->setopt(CURLOPT_WRITEDATA, \$xml);
    my $retcode = $curl->perform;
    
    my $msg;
    if ($retcode == 0) {
	my %defs = ( 
	    200 => 'OK',
	    301 => 'Moved Permanently',
	    400 => 'Bad Request',
	    401 => 'Unauthorized',
	    402 => 'Payment Required',
	    403 => 'Forbidden',
	    404 => 'Not Found',
	    500 => 'Internal Server Error',
	    501 => 'Not Implemented',
	    503 => 'Service Unavailable',
	    505 => 'HTTP Version Not Supported'
	    );
	$msg = $defs{$curl->getinfo($curl->CURLINFO_HTTP_CODE)};
    } else {
	$msg = "Error in transfer: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n";
    }
    croak $msg unless $msg eq 'OK';
    
    my @xml = split /\n/, $xml;
    while (not $xml[0] =~ /^<\w+:WFS_Capabilities/) {
	shift @xml;
    }
    my $capabilities = XML::LibXML->load_xml(string => "<xml>@xml</xml>");
    my $xpc = XML::LibXML::XPathContext->new($capabilities);
    $xpc->registerNs('x', 'http://www.opengis.net/wfs');

    my @layers;
    for my $layer ($xpc->findnodes('//x:FeatureType')) {
	my $xc = XML::LibXML::XPathContext->new($layer);
	$xc->registerNs('x', 'http://www.opengis.net/wfs');
	my $name = $xc->findnodes('./x:Name')->to_literal;
	my $title = $xc->findnodes('./x:Title')->to_literal;
	my $abstract = $xc->findnodes('./x:Abstract')->to_literal;
	my $default_srs = $xc->findnodes('./x:DefaultSRS')->to_literal;
	my $other_srs = $xc->findnodes('./x:SRS')->to_literal;
	push @layers, {
	    Title => $title,
	    Name => $name,
	    Abstract => $abstract,
	    DefaultSRS => $default_srs,
	    OtherSRS => $other_srs
	};
    }
    @layers = sort {$a->{Title} cmp $b->{Title}} @layers;
    return \@layers;
}

## @cmethod ref @layers($driver, $data_source)
#
# @brief Lists the layers that are available in a data source.
# @return A reference to a list of references of layer data in tuples
sub layers {
    my($driver, $data_source) = @_;
    #$driver = '' unless $driver;
    #$data_source = '' unless $data_source;
    return WFS_layers($data_source) if $driver and $driver eq 'WFS';
    my $self = {};
    open_data_source($self, driver => $driver, data_source => $data_source, update => 0);
    return unless $self->{OGR}->{DataSource};
    my @layers;
    for my $i ( 0 .. $self->{OGR}->{DataSource}->GetLayerCount - 1 ) {
	my $l  = $self->{OGR}->{DataSource}->GetLayerByIndex($i);
	my $fd = $l->GetLayerDefn();
	my $t  = $fd->GetGeomType;
	next unless exists $Geo::OGR::Geometry::TYPE_INT2STRING{$t};
	push @layers, { 
	    'Name' => $l->GetName,
	    'Geometry type' => $Geo::OGR::Geometry::TYPE_INT2STRING{$t} 
	};
    }
    @layers = sort {$a->{Name} cmp $b->{Name}} @layers;
    return \@layers;
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
    open_data_source($self, driver => $driver, data_source=>$data_source, update => 1);
    for my $i ( 0 .. $self->{OGR}->{DataSource}->GetLayerCount - 1 ) {
	my $l = $self->{OGR}->{DataSource}->GetLayerByIndex($i);
	$self->{OGR}->{DataSource}->DeleteLayer($i), last
	    if $l->GetName() eq $layer;
    }
}

##@ignore
sub describe_WFS_layer {
    my($url, $layer) = @_; # 'WFS:' + CURL style

    $url =~ s/^WFS://;
    $url .= '?service=WFS&version=1.1.0&request=DescribeFeatureType&typename='.$layer;
    my $curl = WWW::Curl::Easy->new;
    $curl->setopt(CURLOPT_HEADER,1);
    $curl->setopt(CURLOPT_URL, $url);
    my $xml;
    $curl->setopt(CURLOPT_WRITEDATA, \$xml);
    my $msg;
    my $retcode = $curl->perform;   
    if ($retcode == 0) {
	my %defs = ( 
	    200 => 'OK',
	    301 => 'Moved Permanently',
	    400 => 'Bad Request',
	    401 => 'Unauthorized',
	    402 => 'Payment Required',
	    403 => 'Forbidden',
	    404 => 'Not Found',
	    500 => 'Internal Server Error',
	    501 => 'Not Implemented',
	    503 => 'Service Unavailable',
	    505 => 'HTTP Version Not Supported'
	    );
	$msg = $defs{$curl->getinfo($curl->CURLINFO_HTTP_CODE)};
    } else {
	$msg = "Error in transfer: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n";
    }
    croak $msg unless $msg eq 'OK';

    my @xml = split /\n/, $xml;
    while (not $xml[0] =~ /^<schema/) {
	shift @xml;
    }
    my $schema = XML::LibXML->load_xml(string => "<xml>@xml</xml>");
    my $xpc = XML::LibXML::XPathContext->new($schema);
    $xpc->registerNs('x', 'http://www.w3.org/2001/XMLSchema');

    my @schema;
    for my $element ($xpc->findnodes('//x:element')) {
	my $x = $element->findvalue('@substitutionGroup');
	next if $x;
	my $name = $element->findvalue('@name');
	my $type = $element->findvalue('@type');
	push @schema, [ 0 => $name, 1 => $type ];
    }
    @schema = sort {$a->[1] cmp $b->[1]} @schema;

    return ([], \@schema);
}

## @cmethod @describe_layer($driver, $data_source, $layer)
#
# @brief Describes a layer in a data source.
# @return Meta data and schema of the layer
sub describe_layer {
    my %attr = @_;
    
    return describe_WFS_layer($attr{data_source}, $attr{layer}) 
	if $attr{driver} and $attr{driver} eq 'WFS';

    my $vector;
    my @metadata; # key, value pairs
    my @schema; # field, type pairs

    eval {
	$vector = Geo::Vector->new( %attr );
    };
    croak($@) if $@;

    push @metadata, [ 0 => 'Feature count', 1 => $vector->feature_count() ];
    eval {
	my @b = $vector->world;
	@b = ('undef','undef','undef','undef') unless @b;
	push @metadata, [ 0 => 'Bounding box', 
			  1 => "minX = $b[0]\nminY = $b[1]\nmaxX = $b[2]\nmaxY = $b[3]" ];
    };
    my $srs = $vector->srs(format=>'Wkt');
    if ($srs) { # pretty print $srs
	my @a = split(/(\w+\[)/, $srs);
	my @b;
	for (my $i = 1; $i < @a; $i+=2) {
	    push @b, $a[$i].$a[$i+1];
	}
	$srs = '';
	my $in = 0;
	for (@b) {
	    $srs .= "   " for (1..$in);
	    $srs .= "$_\n";
	    $in++ while ($_ =~ m/\[/g);
	    $in-- while ($_ =~ m/\]/g);
	}
	$srs =~ s/\n$//;
    } else {
	$srs = 'undefined';
    }
    push @metadata, [ 0 => 'SRS', 1 => $srs ];

    my $schema = $vector->schema();
    for my $field (@{$schema->{Fields}}) {
	push @schema, [ 0 => $field->{Name}, 1 => $field->{Type} ];
    }
    @schema = sort {$a->[1] cmp $b->[1]} @schema;

    return (\@metadata, \@schema);
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
# - \a update => boolean Set true if open in update mode.
# - \a layer => string [deprecated] Same as \a open.
# - \a create => string The layer to create.
# - \a layer_options forwarded to Geo::OGR::DataSource::CreateLayer.
# - \a SQL => string SQL-string, forwarded to
# Geo::OGR::DataSource::ExecuteSQL. An alternative to \a open and \a
# create.
# - \a geometry_type => string The geometry type for the
# new layer. Default is 'Unknown'.
# - \a schema, as in method Geo::Vector::schema.
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

    if (blessed($params{single})) {
	# create from an object
	if ($params{single}->isa('Geo::OGR::Layer')) {
	    $self->{OGR}->{Layer} = $params{single};
	    $self->{update} = undef;
	}
    } elsif (ref($params{single})) {
	# create from a list of things, assuming a list of geometry or feature objects
    } elsif ($params{single}) {
	# create from a scalar, assuming an OGR datasource string
	$params{data_source} = $params{single};
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
	$self->{update} = 1;
	$self->{features} = {};
	if ($params{geometries}) {
	    for my $g (@{$params{geometries}}) {
		$self->geometry($g);
	    }
	} elsif (-r $params{features}) {
	    open my $fh, "<$params{features}";
	    my @a = <$fh>;
	    close $fh;
	    my $coder = JSON->new->ascii->pretty->allow_nonref;
	    my $object = $coder->decode("@a");
	    if ($object->{type} eq 'FeatureCollection') {
		for my $o (@{$object->{features}}) {
		    $self->feature(Geo::Vector::Feature->new(GeoJSON => $o));
		}
	    } else {
		$self->feature(Geo::Vector::Feature->new(GeoJSON => $object));
	    }
	} else {	
	    for my $f (@{$params{features}}) {
		$self->feature($f);
	    }
	}
	return $self;
    }

    $params{update} = 0 unless defined $params{update};
    $params{update} = 1 if $params{create};
    $self->{update} = $params{update} unless exists $self->{update};
    $params{create_options} = [] if (!$params{create_options} and $params{create});

    $self->open_data_source(%params) unless $self->{OGR};

    if ($params{create} or ($self->{OGR}->{Driver} and $self->{OGR}->{Driver}->{name} eq 'Memory')) {

	my $srs;
	if (blessed($params{srs}) and $params{srs}->isa('Geo::OSR::SpatialReference')) {
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
	croak "Driver '$self->{OGR}->{Driver}->{name}' and data source '$params{data_source}' does support creating layers"
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
	croak "Could not open layer '$params{open}': $@" unless $self->{OGR}->{Layer};
	
    } elsif (!$self->{OGR}->{Layer}) {
	
	# open the first layer
	$self->{OGR}->{Layer} = $self->{OGR}->{DataSource}->GetLayerByIndex();
	croak "Could not open the default layer: $@" unless $self->{OGR}->{Layer};
	
    }

    schema($self, $params{schema}) if $params{schema};
    #$self->{OGR}->{Layer}->SyncToDisk unless $self->{OGR}->{Driver}->{name} eq 'Memory';
    return $self;
}

## @ignore
sub save {
    my($self, $filename) = @_;
    my $object = { type => 'FeatureCollection', features => [] };
    for my $f (values %{$self->{features}}) {
	push @{$object->{features}}, $f->GeoJSON;
    }
    my $coder = JSON->new->ascii->pretty->allow_nonref;
    my $data = $coder->encode($object);
    open my $fh, ">$filename";
    print $fh $data;
    close $fh;
}

## @ignore
sub open_data_source {
    my $self = shift;
    my %params = @_;
    my($driver, $data_source, $update, $create_options) = 
	($params{driver}, $params{data_source}, $params{update}, $params{create_options});
    #print STDERR "$driver, $data_source, $update, $create_options\n";
    if ($driver) {
        if (blessed($driver) and $driver->isa('Geo::OGR::Driver')) {
            $self->{OGR}->{Driver} = $driver;
        } else {
            $self->{OGR}->{Driver} = Geo::OGR::GetDriver($driver);
        }
        if ($self->{OGR}->{Driver}->{name} eq 'Memory') {
            $self->{OGR}->{DataSource} = $self->{OGR}->{Driver}->CreateDataSource('', {});
        } elsif ($create_options) {
	    croak "Driver '$self->{OGR}->{Driver}->{name}' does not have the capability to create data sources."
		unless $self->{OGR}->{Driver}->TestCapability('CreateDataSource');
	    eval {
		$self->{OGR}->{DataSource} = $self->{OGR}->{Driver}->CreateDataSource($data_source, $create_options);
	    };
	    $@ = "no reason given" unless $@;
	    $@ =~ s/\n$//;
	    croak "Can't open nor create data source '$data_source' with driver '$self->{OGR}->{Driver}->{name}': $@." unless $self->{OGR}->{DataSource};
	} else {
	    eval {
		$self->{OGR}->{DataSource} = $self->{OGR}->{Driver}->Open($data_source, $update);
	    };
	    $@ = "no reason given" unless $@;
	    $@ =~ s/\n$//;
	    croak "Can't open data source '$data_source' with driver '$self->{OGR}->{Driver}->{name}': $@." unless $self->{OGR}->{DataSource};
	}
    } elsif ($data_source) {
	eval {
	    $self->{OGR}->{DataSource} = Geo::OGR::Open($data_source, $update);
	};
        $@ = "no reason given" unless $@;
	$@ =~ s/\n$//;
	croak "Can't open data source '$data_source': $@." unless $self->{OGR}->{DataSource};
	$self->{OGR}->{Driver} = $self->{OGR}->{DataSource}->GetDriver;
    } else {
	$self->{OGR}->{Driver} = Geo::OGR::GetDriver('Memory');
	$self->{OGR}->{DataSource} = $self->{OGR}->{Driver}->CreateDataSource('', {});
    }
}

## @ignore
sub DESTROY {
    my $self = shift;
    return unless $self;
    $self->{OGR}->{Layer}->SyncToDisk if ($self->{update} and $self->{OGR}->{Layer});
    if ( $self->{SQL} and $self->{OGR}->{DataSource} ) {
	$self->{OGR}->{DataSource}->ReleaseResultSet( $self->{OGR}->{Layer} );
    }
    delete $self->{features};
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

## @method datasource()
#
# @brief The datasource of the object.
# @return The name of the OGR datasource as a string. Returns 'Memory' if the
# object is not an OGR layer.
sub data_source {
    my $self = shift;
    return $self->{OGR}->{DataSource}->GetName if $self->{OGR}->{DataSource};
    return 'Memory';
}

## @method dump(%parameters)
#
# @brief Print the contents of the layer (consider setting binmode to utf8).
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
	    my $v = $feature->GetField($name);
	    print $fh "$name: $v\n";
	}
	my $geom = $feature->GetGeometryRef();
	dump_geom($geom, $fh, $params{suppress_points});
    }
}

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

## @method init_iterate(%options)
# @brief Reset reading features from the object iteratively.
#
# For OGR layers uses GDAL filtering. Only filter_rect is implemented
# for feature collection and filtering is only preliminary, based on
# envelopes.
#
# @param options Named parameters, all are optional.
# - \a selected_features => reference to a list of features, which to
# iterate through.
# - \a filter => a spatial filter (geometry)
# - \a filter_rect => reference to an array defining a spatial
# rectangle filter (min_x, min_y, max_x, max_y)
sub init_iterate {
    my $self = shift;
    return unless $self->isa('Geo::Vector');
    my %options = @_ if @_;
    if ($options{filter_rect}) {
	$self->{_filter} = Geo::OGR::Geometry->create(
	    GeometryType => 'Polygon',
	    Points => 
	    [[[$options{filter_rect}->[0], $options{filter_rect}->[1]],
	      [$options{filter_rect}->[0], $options{filter_rect}->[3]],
	      [$options{filter_rect}->[2], $options{filter_rect}->[3]],
	      [$options{filter_rect}->[2], $options{filter_rect}->[1]],
	      [$options{filter_rect}->[0], $options{filter_rect}->[1]]]]);
    } elsif ($options{filter}) {
	$self->{_filter} = $options{filter};
    }
    if ($options{selected_features}) {
	$self->{_features} = $options{selected_features};
	$self->{_cursor} = 0;
    } elsif ($self->{features}) {
    } else {
	if ( exists $self->{_filter} ) {
	    $self->{OGR}->{Layer}->SetSpatialFilter( $self->{_filter} );
	} else {
	    $self->{OGR}->{Layer}->SetSpatialFilter(undef);
	}
	$self->{OGR}->{Layer}->ResetReading();
    }
}

## @method next_feature()
#
# @brief Return a feature iteratively or undef if no more features. 
#
sub next_feature {
    my $self = shift;
    return $self unless $self->isa('Geo::Vector');
    if ($self->{features}) {
	my $f;
	while (1) {
	    (undef, $f) = each %{$self->{features}};
	    last unless $f;
	    last unless $self->{_filter};
	    last if $self->{_filter}->Intersect($f->Geometry);
	}
	return $f if $f;
	delete $self->{_filter};
	return;
    } elsif ($self->{_features}) {
	my $f;
	while (1) {
	    $f = undef;
	    last if $self->{_cursor} > $#{$self->{_features}};
	    $f = $self->{_features}->[$self->{_cursor}++];
	    last unless $self->{_filter};
	    last if $self->{_filter}->Intersect($f->Geometry);
	}
	return $f if $f;
	delete $self->{_cursor};
	delete $self->{_features};
	delete $self->{_filter};
	return;
    } else {
	my $f;
	while (1) {
	    $f = $self->{OGR}->{Layer}->GetNextFeature();
	    last unless $f;
	    last unless $self->{_filter};
	    # can't trust that all OGR drivers are good filterers
	    last if $self->{_filter}->Intersect($f->Geometry);
	}
	return $f if $f;
	delete $self->{_filter};
	$self->{OGR}->{Layer}->SetSpatialFilter(undef);
    }
}
*get_next = *next_feature;

## @method $add($other, %params)
#
# @brief Add a feature or features from another layer to this layer.
# @param other A feature or a feature layer object
# @param params Named parameters, used for creating the new object,
# if one is created, and for iterating through the features of other.
# @return (If used in non-void context) A new Geo::Vector object, which
# contain features from both this and from the other.
sub add {
    my $self = shift;
    my $other = shift;
    my %params = @_ if @_;
    if (defined wantarray) {
	$params{schema} = $self->schema();
	$self = Geo::Vector->new(%params);
    }
    my %dst_schema;
    my $dst_geometry_type;
    if ($self->{features}) {
	$dst_geometry_type = 'Unknown';
    } else {
	my $dst_defn = $self->{OGR}->{Layer}->GetLayerDefn();
	$dst_geometry_type = $dst_defn->GeometryType;
	$dst_geometry_type =~ s/25D$//;
	my $n = $dst_defn->GetFieldCount();
	for my $i ( 0 .. $n - 1 ) {
	    my $fd   = $dst_defn->GetFieldDefn($i);
	    $dst_schema{$fd->GetName} = $fd->GetType;
	}
    }
    init_iterate($other, %params);
    while (my $feature = next_feature($other)) {
	my $geom = $feature->Geometry();

	# check for match of geometry types
	next unless $dst_geometry_type eq 'Unknown' or 
	    $dst_geometry_type =~ /$geom->GeometryType/;

	my $f = $self->feature();
	for my $field ( @{$feature->Schema->{Fields}} ) {
	    my $name = $field->{Name};
	    unless ($self->{features}) {
		# copy only those attributes which match
		next unless exists($dst_schema{$name}) and $dst_schema{$name} eq $field->{Type};
	    }
	    $f->SetField($name, $feature->GetField($name));
	}
	if ($params{transformation}) {
	    my $points = $geom->Points;
	    transform_points($points, $params{transformation});
	    $geom->Points($points);
	}
	$f->Geometry($geom);
	$self->feature($f);
    }
    return $self if defined wantarray;
}

## @method Geo::Vector copy(%params)
#
# @brief Copy selected or all features from the layer into a new layer.
#
# @param[in] params is a list of named parameters. They are forwarded
# to constructor (new) and init_iterate. If no value is given the
# defaults are taken from this layer.
# @return A Geo::Vector object.
sub copy {
    my($self, %params) = @_;
    $params{data_source} = $self->{data_source} unless $params{data_source};
    $params{driver} = $self->driver unless $params{driver};
    $params{schema} = $self->schema unless $params{schema};
    my $copy = Geo::Vector->new(%params);
    my $fd = Geo::OGR::FeatureDefn->new();
    $fd->GeometryType($params{schema}{GeometryType}) if $params{schema}{GeometryType};
    if ($params{schema}{Fields}) {
	for my $f (@{$params{schema}{Fields}}) {
	    if (ref($f) eq 'HASH') {
		$f = Geo::OGR::FieldDefn->create(%$f);
	    }
	    $fd->AddFieldDefn($f);
	}
    }
    my $i = 0;
    $self->init_iterate(%params);
    while (my $f = $self->next_feature()) {
	
	my $geometry = $f->GetGeometry();
	
	# transformation if that is wished
	if ($params{transformation}) {
	    eval {
		$geometry->Transform($params{transformation});
	    };
	    next if $@;
	}
	
	# make copies of the features and add them to copy
	
	my $feature = Geo::OGR::Feature->new($fd);
	$feature->SetGeometry($geometry); # makes a copy
	
	for my $i (0..$fd->GetFieldCount-1) {
	    my $v = $f->GetField($i);
	    $feature->SetField($i, $v) if defined $v;
	}

	$copy->feature($feature);
	
    }
    $copy->{OGR}->{Layer}->SyncToDisk if $copy->{OGR};
    return $copy;
}

## @ignore
sub transform_points {
    my($points, $ct) = @_;
    unless (ref($points->[0])) { # single point [x,y,z]
	@$points = $ct->TransformPoint($#$points < 2 ? @$points[0..1] : @$points[0..2]);
    } else {
	$ct->TransformPoints($points), return 
	    unless ref($points->[0]->[0]); # list of points [[x,y,z],[x,y,z],...]

	# list of list of points [[[x,y,z],[x,y,z],...],...]
	for my $p (@$points) {
	    transform_points($p, $ct);
	}
    }
}

## @method $feature_count()
#
# @brief Count the number of features in the layer.
# @todo Add $force parameter.
# @return The number of features in the layer. The valued may be approximate.
sub feature_count {
    my($self) = @_;
    if ( $self->{features} ) {
	my $count = keys %{ $self->{features} };
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

## @method $geometry_type()
#
# @brief Return the geometry type of the layer.
#
# @return The geometry type as a string.
sub geometry_type {
    my($self) = @_;
    return 'Unknown' if $self->{features};
    return $self->{OGR}->{Layer}->GeometryType; # GetLayerDefn()->GeometryType;
}

## @method hashref schema(hashref schema)
#
# @brief Get or set the schema of the layer.
#
# Schema is a hash whose keyes are GeometryType, FID, and
# Fields. Fields is a reference to a list of field schemas. A field
# schema is a hash whose keys are Name, Type, Justify, Width, and
# Precision. This is similar to schemas in Geo::OGR.
#
# @param[in] schema (optional) a reference to a hash specifying the schema.
# @return the schema.
sub schema {
    my $self = shift;
    my $o;
    if ($self->{features}) {
    } else {
	$o = $self->{OGR}->{Layer};
    }
    if (@_ > 0) {
	my %schema = @_ == 1 ? %{$_[0]} : @_;
	$o->Schema(%schema);
    }
    if ($o) {
	my $s = $o->Schema();
	return bless $s, 'Gtk2::Ex::Geo::Schema';
    } else {
	return Gtk2::Ex::Geo::Schema->new;
    }
}

## @ignore
sub feature_attribute {
    my($self, $f, $a) = @_;
    if ($a =~ /^\./) { # pseudo fields
	if ($a eq '.FID') {
	    return $f->GetFID;
	} elsif ($a eq '.Z') {
	    my $g = $f->Geometry;
	    return $g->GeometryType =~ /^Point/ ? $g->GetZ : undef;
	} elsif ($a eq '.GeometryType') {
	    my $g = $f->Geometry;
	    return $g->GeometryType if $g;
	}
    } else {
	my $v = $f->GetField($a);
	return $v;
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
    
    if ($field_name eq '.Z') {
	my($zmin, $zmax);
	$self->init_iterate(%params);
	while (my $f = $self->next_feature()) {
	    ($zmin, $zmax) = z_range($f->Geometry()->Points, $zmin, $zmax);
	}
	return ($zmin, $zmax);
    }

    if ($self->{features}) {
	my $n = keys %{$self->{features}};
	return (0, $n) if $field_name eq '.FID';
    } else {
	my $schema = $self->schema()->field($field_name);
	confess "Field with name '$field_name' does not exist."
	    unless defined $schema;
	confess
	    "Can't use value from field '$field_name' since it is of type '$schema->{Type}'."
	    unless $schema->{Type} eq 'Integer'
	    or $schema->{Type}     eq 'Real';
	
	return ( 0, $self->{OGR}->{Layer}->GetFeatureCount - 1 )
	    if $field_name eq '.FID';
    }
    
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

## @ignore
sub z_range {
    my($points, $zmin, $zmax) = @_;
    unless (ref($points->[0])) { # single point [x,y,z]
	if (@$points > 2) {
	    $zmin = $points->[2] if (!defined($zmin) or $points->[2] < $zmin);
	    $zmax = $points->[2] if (!defined($zmax) or $points->[2] > $zmax);
	}
	return ($zmin, $zmax);
    }
    for my $p (@$points) {
	($zmin, $zmax) = z_range($p, $zmin, $zmax);
    }
    return ($zmin, $zmax);
}

## @method hashref feature($fid, $feature)
#
# @brief Get, add, update, or create a new feature.
#
# Example of retrieving:
# @code
# $feature = $layer->feature($fid);
# @endcode
#
# Example of updating:
# @code
# $layer->feature($fid, $feature);
# @endcode
#
# Example of adding:
# @code $layer->feature($feature);
# @endcode
#
# Example of creating a new feature (note: the feature is not added to the layer):
# @code $feature = $layer->feature();
# @endcode
#
# @param[in] fid The ID of the feature
# @param[in] feature A feature object to add or to update.
# @return a feature object
sub feature {
    my($self, $fid, $feature) = @_;
    if ($feature) {
	
	# update at fid
	if ( $self->{features} ) {
	    $feature = $self->make_feature($feature) unless blessed($feature) and $feature->isa('Geo::Vector::Feature');
	    $self->{features}{$fid} = $feature;
	    $feature->{FID} = $fid;
	} else {
	    $feature = $self->make_feature($feature) unless blessed($feature) and $feature->isa('Geo::OGR::Feature');
	    $feature->SetFID($fid);
	    $self->{OGR}->{Layer}->SetFeature($feature);
	}
	# selected_features is a layer method, this is a bug perhaps
	#my $features = $self->selected_features();
	#if (@$features) {
	#    my @fids;
	#    for (@$features) {push @fids, $_->GetFID}
	#    $self->select( with_id => \@fids );
	#}
    } elsif (ref $fid) {

	# add
	$feature = $fid;
	if ($self->{features}) {
	    $feature = $self->make_feature($feature) unless blessed($feature) and $feature->isa('Geo::Vector::Feature');
	    $fid = 0;
	    while (exists $self->{features}{$fid}) {$fid++}
	    $self->{features}{$fid} = $feature;
	    $feature->{FID} = $fid;
	} else {
	    $feature = $self->make_feature($feature) unless blessed($feature) and $feature->isa('Geo::OGR::Feature');
	    $self->{OGR}->{Layer}->CreateFeature($feature);
	}
    } elsif (defined $fid) {

	# retrieve
	if ( $self->{features} ) {
	    return $self->{features}{$fid} if exists $self->{features}{$fid};
	    return;
	} else {
	    return $self->{OGR}->{Layer}->GetFeature($fid);
	}
    } else {

	# create new
	if ( $self->{features} ) {
	    return Geo::Vector::Feature->new();	    
	} else {
	    return Geo::OGR::Feature->new($self->{OGR}->{Layer}->GetLayerDefn());
	}
    }
}

sub add_feature {
    my $self = shift;
    my %params = @_ == 1 ? %{$_[0]} : @_;
    feature($self, \%params);
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
	my $feature = $self->feature($fid);
	$feature->Geometry($geometry) if $feature;
    }
    elsif (ref $fid) {
	# add
	$geometry = $fid;
	my $feature = $self->make_feature(Geometry => $geometry);
	if ($self->{features}) {
	    $fid = 0;
	    while (exists $self->{features}{$fid}) {$fid++}
	    $self->{features}{$fid} = $feature;
	    $feature->{FID} = $fid;
	} else {
	    $self->{OGR}->{Layer}->CreateFeature($feature);
	    $self->{OGR}->{Layer}->SyncToDisk;
	}
    }
    else {
	# retrieve
	my $f;
	if ( $self->{features} ) {
	    $f = $self->{features}{$fid} if exists $self->{features}{$fid};
	} else {
	    $f = $self->{OGR}->{Layer}->GetFeature($fid);
	}
	return $f->Geometry->Clone if $f;
    }
}

sub geometries {
    my $self = shift;
    my @g = ();
    if ( $self->{features} ) {
	for my $fid (@_) {
	    my $f = $self->{features}{$fid} if exists $self->{features}{$fid};
	    push @g, $f->Geometry->Clone if $f;
	}
    } else {
	for my $fid (@_) {
	    my $f = $self->{OGR}->{Layer}->GetFeature($fid);
	    push @g, $f->Geometry->Clone if $f;
	}
    }
    return @g;
}

sub make_geometry {
    my($input) = @_;
    my $geometry;
    if (blessed($input)) {
	if ($input->isa('Geo::OGR::Geometry')) {
	    return $input->Clone;
	} else {
	    $geometry = Geo::OGR::CreateGeometryFromWkt( $input->AsText );
	}
    } else {
	$geometry = Geo::OGR::CreateGeometryFromWkt( $input );
    }
    return $geometry;
}

## @method Geo::OGR::Feature make_feature(%params)
#
# @brief Creates a feature object for this layer from argument data.
#
# @param[in] feature a hash whose keys are field names (Geometry is
# recognized as a field) and values are field values, or, for the
# geometry, a geometry object or well-known text.
# @return A feature object.
sub make_feature {
    my $self = shift;
    my %params;
    if (@_ == 1) {
	my $feature = shift;
	if ($self->{features}) {
	    return $feature if blessed($feature) and $feature->isa('Geo::Vector::Feature');
	} else {
	    return $feature if blessed($feature) and $feature->isa('Geo::OGR::Feature');
	}
	%params = %$feature;
    } else {
	%params = @_;
    }
    my $feature;
    $params{Geometry} = $params{geometry} if exists $params{geometry};
    my $geometry = make_geometry($params{Geometry});
    delete $params{Geometry};
    delete $params{geometry};
    if ($self->{features}) {
	$feature = Geo::Vector::Feature->new();
	for (keys %params) {
	    next if /^FID$/;
	    $feature->Field($_, $params{$_});
	}
    } else {
	my $defn = $self->{OGR}->{Layer}->GetLayerDefn();
	$defn->DISOWN; # feature owns
	$feature = Geo::OGR::Feature->new($defn);
	my $n = $defn->GetFieldCount();
	for my $i ( 0 .. $n - 1 ) {
	    my $fd   = $defn->GetFieldDefn($i);
	    my $name = $fd->GetName;
	    $feature->SetField( $name, $params{$name} );
	}
    }
    $feature->Geometry($geometry);
    return $feature;
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
# - \a filter
# - \a filter_rect
# - \a with_id => Reference to an array of feature indexes (fids).
# - \a from => If defined, the number of features that are skipped + 1.
# - \a limit => If defined, maximum number of features returned.
# @return A reference to an array of features.
sub features {
    my($self, %params) = @_;
    my @features;
    my $i = 0;
    my $from = $params{from} || 1;
    my $limit = 0;
    $limit = $from + $params{limit} if exists $params{limit};
    my $is_all = 1;

    if ( exists $params{with_id} ) {

	for my $fid (@{$params{with_id}}) {
	    my $x;
	    if ($self->{features}) {
		$x = $self->{features}{$fid} if exists $self->{features}{$fid};
	    } else {
		$x = $self->{OGR}->{Layer}->GetFeature($fid);
	    }
	    next unless $x;
	    $i++;
	    next if $i < $from;
	    push @features, $x;
	    $is_all = 0, last if $limit and $i >= $limit-1;
	}

    } else {

	if ( exists $params{that_contain} ) 
	{
	    $self->init_iterate( filter => $params{that_contain} );
	    while ( my $f = $self->next_feature() ) {
		$i++;
		next if $i < $from;
		next unless $f->GetGeometry->Contains($params{that_contain});
		push @features, $f;
		$is_all = 0, last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{that_are_within} ) 
	{
	    $self->init_iterate( filter => $params{that_are_within} );
	    while ( my $f = $self->next_feature() ) {
		$i++;
		next if $i < $from;
		next unless $f->GetGeometry->Within($params{that_are_within});
		push @features, $f;
		$is_all = 0, last if $limit and $i >= $limit-1;
	    }
	}
	elsif ( exists $params{that_intersect} ) 
	{
	    $self->init_iterate( filter => $params{that_intersect} );
	    while ( my $f = $self->next_feature() ) {
		$i++;
		next if $i < $from;
		next unless $f->GetGeometry->Intersect($params{that_intersect});
		push @features, $f;
		$is_all = 0, last if $limit and $i >= $limit-1;
	    }
	}
	else {
	    my %options = %params;
	    $options{filter_rect} = $params{filter_with_rect} if $params{filter_with_rect};
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

## @method @world($FID)
#
# @brief Get the bounding box (xmin, ymin, xmax, ymax) of the layer or some of
# its features.
#
# @param[in] FID ID or IDs of the features to take into account.
# @return Returns the bounding box (minX, minY, maxX, maxY) as an array.
sub world {
    my $self = shift;
    my %fids;
    if (@_ == 1) {
	my $ref = shift;
	if (ref $ref eq 'ARRAY') {
	    %fids = map {$_ => 1} @$ref;
	} else {
	    %fids = %$ref;
	}
    } elsif (@_ > 1) {
	%fids = map {$_ => 1} @_;
    }
    my $extent;
    if (%fids) {
	for my $fid (keys %fids) {
	    my $e = $self->feature($fid)->Geometry->GetEnvelope();
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
    } elsif ($self->{features}) {
	for my $feature(values %{$self->{features}}) {
	    my $e = $feature->Geometry->GetEnvelope();
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
    } elsif ($self->{OGR}->{Layer}->GetFeatureCount() > 0) {
	eval { $extent = $self->{OGR}->{Layer}->GetExtent(); };
	croak "GetExtent failed: $@" if $@;
    }
    
    return unless $extent;
    $extent->[1] = $extent->[0] + 1 if $extent->[1] <= $extent->[0];
    $extent->[3] = $extent->[2] + 1 if $extent->[3] <= $extent->[2];
    return ( $extent->[0], $extent->[2], $extent->[1], $extent->[3] );
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
# - \a nodata_value (optional). What value to use for nodata. Default
# is -9999 and to initialize the raster to nodata. Set to undef to not
# to use nodata values at all (and initialize to zero).
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
    
    croak "Geo::Vector->rasterize: only OGR layers can be currently rasterized" 
	unless $self->{OGR}->{Layer};
    my $handle = OGRLayerH( $self->{OGR}->{Layer} );
    
    ( $params{M}, $params{N} ) = $params{like}->size(of_GDAL=>1) if $params{like};
    $params{world} = [ $params{like}->world() ] if $params{like};
    
    croak "Geo::Vector->rasterize needs the raster size: M, N"
	unless $params{M} and $params{N};
    
    $params{world} = [ $self->world() ] unless $params{world};
    
    my $field = -1;
    if ( defined $params{value_field} and $params{value_field} ne '' ) {
	my $schema = $self->schema()->field($params{value_field});
	confess "Field with name '$params{value_field}' does not exist."
	    unless defined $schema;
		confess
		    "Can't use value from field ".
		    "'$params{value_field}' since it is of type '$schema->{Type}'."
		    unless $schema->{Type} eq 'Integer'
		    or $schema->{Type}     eq 'Real';
	$params{datatype} = $schema->{Type};
	$field = $schema->{Index};
    }
    
    my $gd = Geo::Raster->new(
			      datatype => $params{datatype},
			      M        => $params{M},
			      N        => $params{N},
			      world    => $params{world}
			      );
    if (defined($params{nodata_value})) {
	$gd->nodata_value( $params{nodata_value} );
	$gd->set('nodata');
    }
    
    xs_rasterize( $handle, $gd->{GRID},
		  $RENDER_AS{ $params{render_as} },
		  $params{feature}, $field );
    
    return $gd;
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

This module should be discussed in https://list.hut.fi/mailman/listinfo/geo-perl

The homepage of this module is https://github.com/ajolma/geoinformatica

=head1 AUTHOR

Ari Jolma, E<lt>ari.jolma at aalto.fiE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2006 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
