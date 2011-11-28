#!/usr/bin/perl -w

use utf8;
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
my $config = WXS::config("/var/www/etc/wfs.conf");
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
    $version = '1.1.0' unless $version;
    #croak "Not a supported WFS version.#" unless $version eq $config->{version};
    my $service = $q->param($names{SERVICE});
    $service = 'WFS'unless $service;
    if ($request eq 'GetCapabilities' or $request eq 'capabilities') {
	GetCapabilities($version);
    } elsif ($request eq 'DescribeFeatureType') {
	DescribeFeatureType($version, decode utf8=>$q->param($names{TYPENAME}));
    } elsif ($request eq 'GetFeature') {
	GetFeature($version, decode utf8=>$q->param($names{TYPENAME}));
    } else {
	croak('Unrecognized request: '.$request);
    }
}

sub GetFeature {
    my($version, $typename) = @_;
    my $type = feature($typename);
    croak "No such feature type: $typename" unless $type;

    my $bbox = $q->param($names{BBOX});
    
    my $vsi = '/vsimem/wfs.gml';
    my $fp = Geo::GDAL::VSIFOpenL($vsi, 'w');
    my $gml = Geo::OGR::Driver('GML')->Create($vsi);

    my $datasource = Geo::OGR::Open($type->{Datasource});
    my $layer;
    if ($type->{Layer}) {
	$layer = $datasource->Layer($type->{Layer});
    } elsif ($type->{Table}) {	    
	my @cols;
	for my $f (keys %{$type->{Schema}}) {
	    next if $f eq 'ID';
	    my $n = $f;
	    $n =~ s/ /_/g;
	    # need to use specified GeometryColumn and only it
	    next if $type->{Schema}{$f} eq 'geometry' and not ($f eq $type->{GeometryColumn});
	    push @cols, "\"$f\" as \"$n\"";
	}
	my $sql = "select ".join(',',@cols)." from \"$type->{Table}\"";
	$layer = $datasource->ExecuteSQL($sql);
    } else {
	croak "missing information in configuration file";
    }

    if ($bbox) {
	my @bbox = split /,/, $bbox;
	$layer->SetSpatialFilterRect(@bbox);
    }    

    $gml->CopyLayer($layer, $type->{Title});
    undef $gml;
    Geo::GDAL::VSIFCloseL($fp);

    serve_vsi(vsi => $vsi, cgi => $q, type => $config->{MIME}, utf8 => 1);
}

sub DescribeFeatureType {
    my($version, $typename) = @_;
    my $type = feature($typename);
    croak "No such feature type: $typename" unless $type;
    my($out, $var);
    open($out,'>', \$var);
    select $out;
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
		'<');
    xml_element('import', { namespace => "http://www.opengis.net/gml",
			    schemaLocation => "http://schemas.opengis.net/gml/2.1.2/feature.xsd" } );
    xml_element('element', { name => $type->{Name}, 
			     type => 'ogr:'.$typename.'Type',
			     substitutionGroup => 'gml:_Feature' } );

    my @elements;
    if ($type->{Schema}) {
	for my $col (keys %{$type->{Schema}}) {
	    if ($type->{Schema}{$col} eq 'geometry' and not($typename =~ /$col$/)) {
		next;
	    }
	    my $t = $type->{Schema}{$col};
	    $t = "gml:GeometryPropertyType" if $t eq 'geometry';
	    my $c = $col;
	    $c =~ s/ /_/g; # field name adjustments as GDAL does them
	    push @elements, ['element', { name => $c,
					  type => $t,
					  minOccurs => "0",
					  maxOccurs => "1" } ];
	}
    } else {
	@elements = (['element', { name => "ogrGeometry",
				   type => "gml:GeometryPropertyType",
				   minOccurs => "0",
				   maxOccurs => "1" } ]);
    }
    
    xml_element('complexType', {name => $typename.'Type'},
		['complexContent', 
		 ['extension', { base => 'gml:AbstractFeatureType' }, 
		  ['sequence', \@elements
		  ]]]);
    xml_element('/schema', '>');
    select(STDOUT);
    close $out;    
    $header = WXS::header(cgi => $q, length => length($var), type => $config->{MIME});
    print $var;
}

sub GetCapabilities {
    my($version) = @_;
    my($out, $var);
    open($out,'>', \$var);
    select $out;
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
		'<');
    ServiceIdentification($version);
    ServiceProvider($version);
    OperationsMetadata($version);
    FeatureTypeList($version);
    Filter_Capabilities($version);
    xml_element('/wfs:WFS_Capabilities', '>');
    select(STDOUT);
    close $out;    
    $header = WXS::header(cgi => $q, length => length($var), type => $config->{MIME});
    print $var;
}

sub ServiceIdentification {
    my($version) = @_;
    xml_element('ows:ServiceIdentification', '<');
    xml_element('ows:Title', 'WFS Server');
    xml_element('ows:Abstract');
    xml_element('ows:ServiceType', {codeSpace=>"OGC"}, 'OGC WFS');
    xml_element('ows:ServiceTypeVersion', $version);
    xml_element('ows:Fees');
    xml_element('ows:AccessConstraints');
    xml_element('/ows:ServiceIdentification', '>');
}

sub ServiceProvider {
    my($version) = @_;
    xml_element('ows:ServiceProvider', '<');
    xml_element('ows:ProviderName');
    xml_element('ows:ProviderSite', {'xlink:type'=>"simple", 'xlink:href'=>""});
    xml_element('ows:ServiceContact');
    xml_element('/ows:ServiceProvider', '>');
}

sub OperationsMetadata  {
    my($version) = @_;
    xml_element('ows:OperationsMetadata', '<');
    Operation($config, 'GetCapabilities', 
	      [{service => ['WFS']}, {AcceptVersions => ['1.1.0','1.0.0']}, {AcceptFormats => ['text/xml']}]);
    Operation($config, 'DescribeFeatureType', 
	      [{outputFormat => ['XMLSCHEMA','text/xml; subtype=gml/2.1.2','text/xml; subtype=gml/3.1.1']}]);
    Operation($config, 'GetFeature',
	      [{resultType => ['results']}, {outputFormat => ['text/xml; subtype=gml/3.1.1']}]);
    xml_element('/ows:OperationsMetadata', '>');
}

sub FeatureTypeList  {
    my($version) = @_;
    xml_element('FeatureTypeList', '<');
    xml_element('Operations', ['Operation', 'Query']);
    for my $type (@{$config->{FeatureTypeList}}) {
	if ($type->{Layer}) {
	    xml_element('FeatureType', [
			    ['Name', $type->{Name}],
			    ['Title', $type->{Title}],
			    ['DefaultSRS', $type->{DefaultSRS}],
			    ['OutputFormats', ['Format', 'text/xml; subtype=gml/3.1.1']],
			    ['ows:WGS84BoundingBox', {dimensions=>2}, 
			     [['ows:LowerCorner',$type->{LowerCorner}],
			      ['ows:UpperCorner',$type->{UpperCorner}]]]
			]);
	} else {
	    # restrict now to postgis databases
	    my @layers = layers($type->{dbi}, $type->{prefix});
	    for my $l (@layers) {
		xml_element('FeatureType', [
				['Name', $l->{Name}],
				['Title', $l->{Title}],
				['DefaultSRS', $l->{DefaultSRS}],
				['OutputFormats', ['Format', 'text/xml; subtype=gml/3.1.1']]
			    ]);
	    }
	}
    }
    xml_element('/FeatureTypeList', '>');
}

sub feature {
    my($typename) = @_;
    my $type;
    for my $t (@{$config->{FeatureTypeList}}) {
	if ($t->{Layer}) {
	    $type = $t, last if $t->{Name} eq $typename;
	} else {
	    next unless $typename =~ /^$t->{prefix}/;
	    # restrict now to postgis databases
	    my @layers = layers($t->{dbi}, $t->{prefix});
	    for my $l (@layers) {
		if ($l->{Name} eq $typename) {
		    $type = $t;
		    for (keys %$l) {
			$type->{$_} = $l->{$_};
		    }
		}
	    }
	    last if $type;
	}
    }
    return $type;
}

sub layers {
    my($dbi, $prefix) = @_;
    my($connect, $user, $pass) = split / /, $dbi;
    my $dbh = DBI->connect($connect, $user, $pass) or croak('no db');
    $dbh->{pg_enable_utf8} = 1;
    my $sth = $dbh->table_info( '', 'public', undef, 'TABLE' );
    my @tables;
    while (my $data = $sth->fetchrow_hashref) {
	my $n = $data->{TABLE_NAME};
	$n =~ s/"//g;
	push @tables, $n;
    }
    my @layers;
    for my $table (@tables) {
	my $sth = $dbh->column_info( '', 'public', $table, '' );
	my %schema;
	my @l;
	while (my $data = $sth->fetchrow_hashref) {
	    my $n = $data->{COLUMN_NAME};
	    $n =~ s/"//g;
	    $schema{$n} = $data->{TYPE_NAME};
	    push @l, $n if $data->{TYPE_NAME} eq 'geometry';	    
	}
	for my $geom (@l) {
	    my $sql = "select auth_name,auth_srid ".
		"from \"$table\" join spatial_ref_sys on srid=srid(\"$geom\") limit 1";
	    my $sth = $dbh->prepare($sql) or croak($dbh->errstr);
	    my $rv = $sth->execute or croak($dbh->errstr);
	    my($name,$srid)  = $sth->fetchrow_array;
	    push @layers, { Title => "$prefix.$table.$geom", 
			    Name => "$prefix.$table.$geom", 
			    DefaultSRS => "$name:$srid",
			    Table => $table,
			    GeometryColumn => $geom,
			    Schema => \%schema };
	}
    }
    return @layers;
}

sub Filter_Capabilities  {
    my($version) = @_;
    xml_element('ogc:Filter_Capabilities', '<');
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
    xml_element('/ogc:Filter_Capabilities', '>');
}
