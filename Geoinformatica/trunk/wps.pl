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
WXS->import(qw/config header error serve_document xml_elements xml_element/);

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
    xml_element('not_implemented');
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
    xml_element('ows:ServiceIdentification', '<>');
    xml_element('ows:Title', 'WPS Server');
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
    xml_element('ows:OperationsMetadata', '<');
    xml_element('/ows:OperationsMetadata', '>');
}

sub ProcessOfferings  {
    my($version) = @_;
    xml_element('wps:ProcessOfferings', '<');
    xml_element('/wps:ProcessOfferings', '>');
}

sub Languages  {
    my($version) = @_;
    xml_element('wps:Languages', '<');
    xml_element('/wps:Languages', '>');
}

