#!/usr/bin/perl -w

use strict;
use IO::Handle;
use Carp;
use Encode;
use DBI;
use CGI;
use Geo::GDAL;
#use Geo::Proj4;
#use Gtk2::Ex::Geo;
#use Geo::Raster;
#use Geo::Vector;
use JSON;
use lib '.';
require WXS;
WXS->import(':all');

binmode STDERR, ":utf8";
binmode STDOUT, ":utf8";
my $config = config("/var/www/etc/wps.conf");
my $q = CGI->new;
my $header = 0;
my %names = ();

eval {
    page();
};
error(cgi => $q, header => $header, msg => $@, type => $config->{MIME}) if $@;

sub page {
    for ($q->param) {
	croak "Parameter ".uc($_)." given more than once.#" if exists $names{uc($_)};
	$names{uc($_)} = $_;
    }
    $q->{resource} = $config->{resource};
    my $request = $q->param($names{REQUEST}) || 'capabilities';
    my $version = $q->param($names{WMTVER});
    $version = $q->param($names{VERSION}) if $q->param($names{VERSION});
    $version = '1.0.0' unless $version;
    #croak "Not a supported WPS version.#" unless $version eq $config->{version};
    my $service = $q->param($names{SERVICE});
    $service = 'WPS' unless $service;
    if ($request eq 'GetCapabilities' or $request eq 'capabilities') {
	GetCapabilities($version);
    } elsif ($request eq 'DescribeProcess') {
	DescribeProcess($version);
    } elsif ($request eq 'Execute') {
	Execute($version);
    } else {
	croak('Unrecognized request: '.$request);
    }
}

sub Execute {
    my($version) = @_;
    my($out, $var);
    open($out,'>', \$var);
    select $out;
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n");
    xml_element('not_implemented');
    select(STDOUT);
    close $out;
    $header = header(cgi => $q, length => length($var), type => $config->{MIME});
    print $var;
}

sub DescribeProcess {
    my($version) = @_;
    my($out, $var);
    open($out,'>', \$var);
    select $out;
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n");
    xml_element('wps:ProcessDescriptions', {
	'xmlns:wps' => "http://www.opengis.net/wps/1.0.0",
	'xmlns:ows' => "http://www.opengis.net/ows/1.1",
	'xmlns:xlink' => "http://www.w3.org/1999/xlink",
	'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
	'xsi:schemaLocation' => "http://www.opengis.net/wps/1.0.0 ../wpsDescribeProcess_response.xsd",
	'service' => "WPS",
	'version' => "1.0.0",
	'xml:lang' => "en-CA" }, '<');
    xml_element('ProcessDescription', { 
	'wps:processVersion' => "2",
	'storeSupported' => "true",
	'statusSupported' => "false" }, '<');
    xml_element('ows:Identifier', 'Buffer');
    xml_element('ows:Title', 'Create a buffer around a polygon.');
    xml_element('ows:Abstract', 'Create a buffer around a single polygon. '.
		'Accepts the polygon as GML and provides GML output for the buffered feature.');
    xml_element('ows:Metadata', { 'xlink:title' => "spatial" });
    xml_element('ows:Metadata', { 'xlink:title' => "geometry" });
    xml_element('ows:Metadata', { 'xlink:title' => "buffer" });
    xml_element('ows:Metadata', { 'xlink:title' => "GML" });
    xml_element('wps:Profile', 'urn:ogc:wps:1.0.0:buffer');
    xml_element('wps:WSDL', { 'xlink:href' => "http://foo.bar/foo" });
    xml_element('DataInputs', '<');

    xml_element('Input', { minOccurs => "1", maxOccurs => "1" }, '<');
    xml_element('ows:Identifier', 'InputPolygon');
    xml_element('ows:Title', 'Polygon to be buffered');
    xml_element('ows:Abstract', 'URI to a set of GML that describes the polygon.');
    xml_element('ComplexData', { maximumMegabytes => "5" }, '<');
    xml_element('Default', ['Format', [['MimeType','text/xml'],
				       ['Encoding','base64'],
				       ['Schema','http://foo.bar/gml/3.1.0/polygon.xsd']]]);
    xml_element('Supported', ['Format', [['MimeType','text/xml'],
					 ['Encoding','base64'],
					 ['Schema','http://foo.bar/gml/3.1.0/polygon.xsd']]]);
    xml_element('/ComplexData', '>');
    xml_element('/Input', '>');

    xml_element('Input', { minOccurs => "0", maxOccurs => "1" }, '<');
    xml_element('ows:Identifier', 'BufferDistance');
    xml_element('ows:Title', 'Buffer Distance');
    xml_element('ows:Abstract', 'Distance to be used to calculate buffer.');
    xml_element('LiteralData', '<');
    xml_element('ows:DataType', { 'ows:reference' => "http://www.w3.org/TR/xmlschema-2/#float" }, 'float');
    xml_element('UOMs', [['Default', ['ows:UOM','meters']],
			 ['Supported', [['ows:UOM','meters'],['ows:UOM','feet']]]]);
    xml_element('ows:AnyValue');
    xml_element('DefaultValue', 100);
    xml_element('/LiteralData', '>');
    xml_element('/Input', '>');

    xml_element('/DataInputs', '>');

    xml_element('ProcessOutputs', '<');

    xml_element('Output', '<');
    xml_element('ows:Identifier', 'BufferedPolygon');
    xml_element('ows:Title', 'Buffered Polygon');
    xml_element('ows:Abstract', 'GML stream describing the buffered polygon feature.');
    xml_element('ComplexOutput', '<');
    xml_element('Default', ['Format', [['MimeType','text/xml'],
				       ['Encoding','base64'],
				       ['Schema','http://foo.bar/gml/3.1.0/polygon.xsd']]]);
    xml_element('Supported', ['Format', [['MimeType','text/xml'],
					 ['Encoding','UTF-8'],
					 ['Schema','http://foo.bar/gml/3.1.0/polygon.xsd']]]);
    xml_element('/ComplexOutput', '>');
    xml_element('/Output', '>');

    xml_element('/ProcessOutputs', '>');
    xml_element('/ProcessDescription', '>');
    xml_element('/wps:ProcessDescriptions', '>');

    select(STDOUT);
    close $out;    
    $header = header(cgi => $q, length => length($var), type => $config->{MIME});
    print $var;
}

sub GetCapabilities {
    my($version) = @_;
    my($out, $var);
    open($out,'>', \$var);
    select $out;
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n");
    xml_element('wps:Capabilities',
		{ service => "WPS",
		  version => $version,
		  'xml:lang' => $config->{lang},
		  'xmlns:xlink' => "http://www.w3.org/1999/xlink",
		  'xmlns:wps' => "http://www.opengis.net/wps/1.0.0",
		  'xmlns:ows' => "http://www.opengis.net/ows/1.1",
		  'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
		  'xsi:schemaLocation' => "http://www.opengis.net/wps/1.0.0 ../wpsGetCapabilities_response.xsd",
		  updateSequence => 1 }, 
		'<');
    ServiceIdentification($version);
    ServiceProvider($version);
    OperationsMetadata($version);
    ProcessOfferings($version);
    Languages($version);
    xml_element('wps:WSDL', { 'xlink:href' => $q->{resource}.'WSDL' });
    xml_element('/wps:Capabilities', '>');
    select(STDOUT);
    close $out;    
    $header = header(cgi => $q, length => length($var), type => $config->{MIME});
    print $var;
}

sub ServiceIdentification {
    my($version) = @_;
    xml_element('ows:ServiceIdentification', '<');
    xml_element('ows:Title', 'WPS Server');
    xml_element('ows:Abstract');
    xml_element('ows:ServiceType', {codeSpace=>"OGC"}, 'OGC WPS');
    xml_element('ows:ServiceTypeVersion', $version);
    xml_element('ows:Fees', 'NONE');
    xml_element('ows:AccessConstraints', 'NONE');
    xml_element('/ows:ServiceIdentification', '>');
}

sub ServiceProvider {
    my($version) = @_;
    xml_element('ows:ServiceProvider', '<');
    xml_element('ows:ProviderName', 'Aalto Environmental Informatics');
    xml_element('ows:ProviderSite', {'xlink:type'=>"simple", 'xlink:href'=>""});
    xml_element('ows:ServiceContact');
    xml_element('/ows:ServiceProvider', '>');
}

sub OperationsMetadata  {
    my($version) = @_;
    xml_element('ows:OperationsMetadata', '<');
    Operation($config, 'GetCapabilities');
    Operation($config, 'DescribeProcess');
    Operation($config, 'Execute');
    xml_element('/ows:OperationsMetadata', '>');
}

sub ProcessOfferings  {
    my($version) = @_;
    xml_element('wps:ProcessOfferings', '<');
    xml_element('wps:Process', {'wps:processVersion' => 1}, '<');
    xml_element('ows:Identifier', 'buffer');
    xml_element('ows:Title', 'buffer');
    xml_element('ows:Abstract', 'buffer');
    xml_element('ows:Metadata', {'xlink:title' => 'buffer'});
    xml_element('ows:Metadata', {'xlink:title' => 'polygon'});
    xml_element('/wps:Process', '>');
    xml_element('/wps:ProcessOfferings', '>');
}

sub Languages  {
    my($version) = @_;
    xml_element('wps:Languages', '<');
    xml_element('wps:Default', [['ows:Language', 'en-US']]);
    xml_element('wps:Supported', [['ows:Language', 'en-UK'],['ows:Language', 'fi-FI']]);
    xml_element('/wps:Languages', '>');
}

