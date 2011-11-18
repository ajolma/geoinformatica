#!/usr/bin/perl

use strict;
use Carp;
use Encode;
use DBI;
use CGI;
#use Geo::Proj4;
use Gtk2::Ex::Geo;
use Geo::Raster;
use Geo::Vector;
use JSON;

my $config;
{
    open(my $fh, '<', "/var/www/etc/wfs.conf") or die $!;
    my @json = <$fh>;
    close $fh;
    $config = decode_json "@json";
}
my $q = CGI->new;
my %names = ();

eval {
    page();
};
if ($@) {
    #print STDERR "WFS error: $@\n";
    print $q->header($config->{MIME});
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n");
    my($error) = ($@ =~ /(.*?)\.\#/);
    $error =~ s/ $//;
    $error = { code => $error } if $error eq 'LayerNotDefined';
    $error = 'Unspecified error: '.$@ unless $error;
    xml_element('ServiceExceptionReport',['ServiceException', $error]);
}

sub page {
    for ($q->param) {
	croak "Parameter ".uc($_)." given more than once.#" if exists $names{uc($_)};
	$names{uc($_)} = $_;
    }
    $q->{resource} = $config->{resource};
    my $request = $q->param($names{REQUEST});
    my $version = $q->param($names{WMTVER});
    $version = $q->param($names{VERSION}) if $q->param($names{VERSION});
    $version = '1.1.0' unless $version;
    #croak "Not a supported WFS version.#" unless $version eq $config->{version};
    my $service = $q->param($names{SERVICE});
    $service = 'WFS'unless $service;
    if ($request eq 'GetCapabilities' or $request eq 'capabilities') {
	GetCapabilities($version);
    } elsif ($request eq 'DescribeFeatureType') {
	DescribeFeatureType($version, $q->param($names{TYPENAME}));
    } elsif ($request eq 'GetFeature') {
	GetFeature($version, $q->param($names{TYPENAME}));
    } else {
	print 
	    $q->header(), 
	    $q->start_html, 
	    $q->a({-href=>$q->{resource}.'REQUEST=GetCapabilities'}, "GetCapabilities"), 
	    $q->end_html;
    }
}

sub GetFeature {
    my($version, $typename) = @_;
    my $datasource;
    for my $type (@{$config->{FeatureTypeList}}) {
	$datasource = $type->{datasource}, last if $type->{Name} eq $typename;
    }
    croak "No such feature type: $typename" unless $datasource;
    $datasource = Geo::OGR::Open($datasource);
    my $fn = '/var/www/tmp/'.$typename.'.gml';
    Geo::OGR::Driver('GML')->Copy($datasource, $fn); #'/dev/stdout');
    serve_document($fn, 'text/xml');
}

sub DescribeFeatureType {
    my($version, $typename) = @_;
    my $name;
    for my $type (@{$config->{FeatureTypeList}}) {
	$name = $type->{Name}, last if $type->{Name} eq $typename;
    }
    croak "No such feature type: $typename" unless $name;
    print($q->header( -type => $config->{MIME} ));
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n");
    xml_element('schema', 
		{ version => '0.1',
		  targetNamespace => "http://mapserver.gis.umn.edu/mapserver",
		  xmlns => "http://www.w3.org/2001/XMLSchema",
		  'xmlns:ogr' => "http://ogr.maptools.org/",
		  'xmlns:ogc' => "http://www.opengis.net/ogc",
		  'xmlns:xsd' => "http://www.w3.org/2001/XMLSchema",
		  'xmlns:gml' => "http://www.opengis.net/gml",
		  elementFormDefault => "qualified" }, 
		'>');
    xml_element('import', { namespace => "http://www.opengis.net/gml",
			    schemaLocation => "http://schemas.opengis.net/gml/2.1.2/feature.xsd" } );
    xml_element('element', { name => $name, 
			     type => 'ogr:'.$typename.'Type',
			     substitutionGroup => 'gml:_Feature' } );
    xml_element('complexType', 
		['complexContent', 
		 ['extension', { base => 'gml:AbstractFeatureType' }, 
		  ['sequence', 
		   ['element', { name => "ogrGeometry",
				 type => "gml:GeometryPropertyType",
				 minOccurs => "0",
				 maxOccurs => "1" } ]]]]);
    xml_element('/schema', '>');
}

sub GetCapabilities {
    my($version) = @_;
    print($q->header( -type => $config->{MIME} ));
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n");
    xml_element('wfs:WFS_Capabilities', 
		{ version => $version,
		  'xmlns:gml' => "http://www.opengis.net/gml",
		  'xmlns:wfs' => "http://www.opengis.net/wfs",
		  'xmlns:ows' => "http://www.opengis.net/ows",
		  'xmlns:xlink' => "http://www.w3.org/1999/xlink",
		  'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
		  'xmlns:ogc' => "http://www.opengis.net/ogc",
		  'xmlns' => "http://www.opengis.net/wfs",
		  'xsi:schemaLocation' => "http://www.opengis.net/wfs http://schemas.opengis.net/wfs/1.1.0/wfs.xsd" }, 
		'<>');
    ServiceIdentification($version);
    ServiceProvider($version);
    OperationsMetadata($version);
    FeatureTypeList($version);
    Filter_Capabilities($version);
    xml_element('/wfs:WFS_Capabilities', '<>');
}

sub ServiceIdentification {
    my($version) = @_;
    xml_element('ows:ServiceIdentification', '<>');
    xml_element('ows:Title', 'WFS Server');
    xml_element('ows:Abstract');
    xml_element('ows:ServiceType', {codeSpace=>"OGC"}, 'OGC WFS');
    xml_element('ows:ServiceTypeVersion', $version);
    xml_element('ows:Fees');
    xml_element('ows:AccessConstraints');
    xml_element('/ows:ServiceIdentification', '<>');
}

sub ServiceProvider {
    my($version) = @_;
    xml_element('ows:ServiceProvider', '<>');
    xml_element('ows:ProviderName');
    xml_element('ows:ProviderSite', {'xlink:type'=>"simple", 'xlink:href'=>""});
    xml_element('ows:ServiceContact');
    xml_element('/ows:ServiceProvider', '<>');
}

sub OperationsMetadata  {
    my($version) = @_;
    xml_element('ows:OperationsMetadata', '<>');
    Operation($version, 'GetCapabilities', 
	      [{service => ['WFS']}, {AcceptVersions => ['1.1.0','1.0.0']}, {AcceptFormats => ['text/xml']}]);
    Operation($version, 'DescribeFeatureType', 
	      [{outputFormat => ['XMLSCHEMA','text/xml; subtype=gml/2.1.2','text/xml; subtype=gml/3.1.1']}]);
    Operation($version, 'GetFeature',
	      [{resultType => ['results']}, {outputFormat => ['text/xml; subtype=gml/3.1.1']}]);
    xml_element('/ows:OperationsMetadata', '<>');
}

sub Operation {
    my($version, $name, $parameters) = @_;
    my @parameters;
    for my $p (@$parameters) {
	for my $n (keys %$p) {
	    my @values;
	    for my $v (@{$p->{$n}}) {
		push @values, ['ows:Value', $v];
	    }
	    push @parameters, ['ows:Parameter', {name=>$n}, \@values];
	}
    }
    xml_element('ows:Operation', 
		{name => $name}, 
		[['ows:DCP', 
		  ['ows:HTTP', [['ows:Get', {'xlink:type'=>'simple', 'xlink:href'=>$config->{resource}}],
				['ows:Post', {'xlink:type'=>'simple', 'xlink:href'=>$config->{resource}}]]
		  ]],@parameters]);
}

sub FeatureTypeList  {
    my($version) = @_;
    xml_element('FeatureTypeList', '<>');
    xml_element('Operations', ['Operation', 'Query']);
    for my $type (@{$config->{FeatureTypeList}}) {
	xml_element('FeatureType', [
			['Name', $type->{Name}],
			['Title', $type->{Title}],
			['DefaultSRS', $type->{DefaultSRS}],
			['OutputFormats', ['Format', 'text/xml; subtype=gml/3.1.1']],
			['ows:WGS84BoundingBox', {dimensions=>2}, 
			 [['ows:LowerCorner',$type->{LowerCorner}],
			  ['ows:UpperCorner',$type->{UpperCorner}]]]
		    ]);
    }
    xml_element('/FeatureTypeList', '<>');
}

sub Filter_Capabilities  {
    my($version) = @_;
    xml_element('ogc:Filter_Capabilities', '<>');
    my @operands = ();
    for my $o (qw/Point LineString Polygon Envelope/) {
	push @operands, ['ogc:GeometryOperand', 'gml:'.$o];
    }
    my @operators = ();
    for my $o (qw/Equals Disjoint Touches Within Overlaps Crosses Intersects Contains DWithin Beyond BBOX/) {
	push @operators, ['ogc:SpatialOperator', { name => $o }];
    }
    xml_element('ogc:Spatial_Capabilities', 
		[['ogc:GeometryOperands', \@operands],
		 ['ogc:SpatialOperators', \@operators]]);
    @operators = ();
    for my $o (qw/LessThan GreaterThan LessThanEqualTo GreaterThanEqualTo EqualTo NotEqualTo Like Between/) {
	push @operators, ['ogc:ComparisonOperator', $o];
    }
    xml_element('ogc:Scalar_Capabilities', 
		[['ogc:LogicalOperators'],
		 ['ogc:ComparisonOperators', \@operators]]);
    xml_element('ogc:Id_Capabilities', ['ogc:FID']);
    xml_element('/ogc:Filter_Capabilities', '<>');
}

sub serve_document {
    my($doc, $mime_type) = @_;
    my $length = (stat($doc))[10];
    print "Content-type: $mime_type\n";
    print "Content-length: $length\n\n";
    open(DOC, '<', $doc) or croak "Couldn't open $doc: $!";
    my $data;
    while( sysread(DOC, $data, 10240) ) {
	print $data;
    }
    close DOC;
}

sub xml_elements {
    for my $e (@_) {
	if (ref($e) eq 'ARRAY') {
	    xml_element(@$e);
	} else {
	    xml_element($e->{element}, $e->{attributes}, $e->{content});
	}
    }
}

sub xml_element {
    my $element = shift;
    my $attributes;
    my $content;
    for my $x (@_) {
	$attributes = $x, next if ref($x) eq 'HASH';
	$content = $x;
    }
    print("<$element");
    if ($attributes) {
	for my $a (keys %$attributes) {
	    print(" $a=\"$attributes->{$a}\"");
	}
    }
    unless ($content) {
	print("/>\n");
    } else {
	if (ref $content) {
	    print(">");
	    if (ref $content->[0]) {
		for my $e (@$content) {
		    xml_element(@$e);
		}
	    } else {
		xml_element(@$content);
	    }
	    print("</$element>\n");
	} elsif ($content =~ /\>$/) {
	    print(">\n");
	} elsif ($content) {
	    print(">$content</$element>\n");	
	}
    }
}
