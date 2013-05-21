#!/usr/bin/perl -w

use utf8;
use strict;
use IO::Handle;
use Carp;
use Encode;
use DBI;
use CGI;
use XML::Simple;
use Data::Dumper;

use Geo::GDAL;
use JSON;
use lib '.';
require WXS;
WXS->import(':all');

binmode STDERR, ":utf8";
binmode STDOUT, ":utf8";
my $config;
my $q = CGI->new;
my $header = 0;
my %names = ();
my %params = ();
my $debug = 1;

eval {
    $config = WXS::config();
    page();
};
error(cgi => $q, header => $header, msg => $@, type => $config->{MIME}) if $@;

sub remove_ns {
    my $hashref = shift;
    for my $k (keys %$hashref) {
	delete $hashref->{$k} if $k =~ /^xmlns/;
	remove_ns($hashref->{$k}) if ref($hashref->{$k}) eq 'HASH';
    }
}

sub get_bbox {
    my $e = shift;
    my $bbox;
    if ($e->{'gml:Envelope'}) { # WFS 1.1 GML 3
	$e = $e->{'gml:Envelope'};
	$bbox = $e->{'gml:lowerCorner'}.' '.$e->{'gml:upperCorner'};
	$bbox =~ s/ /,/g;
    } else { # GML 2
	$bbox = $e->{'gml:Box'}{'gml:coordinates'}{content};
	$bbox =~ s/ /,/;
    }
    return $bbox;
}

sub get_filter {
    my $e = shift; # list of or'red constraints
    my $filter;
    if ($e->{'ogc:PropertyIsEqualTo'}) {
	$e = $e->{'ogc:PropertyIsEqualTo'};
	$filter = $e->{'ogc:PropertyName'}."='".$e->{'ogc:Literal'}."'";
    }
    return $filter;
}

sub page {
    print STDERR "\n" if $debug;
    for ($q->param) {
	croak "Parameter ".uc($_)." given more than once.#" if exists $names{uc($_)};
	$names{uc($_)} = $_;
        print STDERR "$_ => ".$q->param($_)."\n" if $debug > 1;
    }

    $params{bbox} = '';
    $params{filter} = '';
    $params{EPSG} = '';

    my $post = $names{POSTDATA};
    $post = $names{'XFORMS:MODEL'} unless $post;

    if ($post) {
	my $post = XMLin('<xml>'.$q->param($post).'</xml>');
	remove_ns($post);

	print STDERR Dumper($post) if $debug > 2;

	for my $k (keys %$post) {
	    if ($k eq 'wfs:GetFeature') {
		my $h = $post->{$k};
		$params{service} = $h->{'service'};
		$params{version} = $h->{'version'};
		$params{request} = 'GetFeature';

		next unless $h->{'wfs:Query'};
		$h = $h->{'wfs:Query'};
		$params{typename} = $h->{typeName};
		$params{typename} =~ s/^feature://;
                $params{EPSG} = $1 if $h->{srsName} and $h->{srsName} =~ /EPSG:(\d+)/;

		next unless $h->{'ogc:Filter'};
		$h = $h->{'ogc:Filter'};

                if ($h->{'ogc:And'}) {
		    $h = $h->{'ogc:And'};
		    if ($h->{'ogc:Or'}) {
			$params{filter} = get_filter($h->{'ogc:Or'});
		    }
                    if ($h->{'ogc:PropertyIsEqualTo'}) {
			$params{filter} = get_filter($h);
		    }
		    if ($h->{'ogc:BBOX'}) {
			$params{bbox} = get_bbox($h->{'ogc:BBOX'});
		    }
		} elsif ($h->{'ogc:BBOX'}) {
		    $params{bbox} = get_bbox($h->{'ogc:BBOX'});
		}

	    } elsif ($k eq 'x') {
	    }
	}

    } else {

	$q->{resource} = $config->{resource};
	$params{request} = $q->param($names{REQUEST}) || 'capabilities';
	$params{version} = $q->param($names{WMTVER});
	$params{version} = $q->param($names{VERSION}) if $q->param($names{VERSION});
	$params{version} = '1.1.0' unless $params{version};
	#croak "Not a supported WFS version.#" unless $params{version} eq $config->{version};
	$params{service} = $q->param($names{SERVICE});
	$params{service} = 'WFS'unless $params{service};
	$params{bbox} = $q->param($names{BBOX}) if $q->param($names{BBOX});
        $params{EPSG} = $1 if $q->param($names{SRSNAME}) and $q->param($names{SRSNAME}) =~ /EPSG:(\d+)/;
	$params{typename} = decode utf8=>$q->param($names{TYPENAME});
        $params{filter} = decode utf8=>$q->param($names{FILTER});
        if ($params{filter} and $params{filter} =~ /^</) {
            my $e = XMLin('<xml>'.$params{filter}.'</xml>');
            $e = $e->{Filter} if $e->{Filter};
            if ($e->{PropertyIsEqualTo}) {
                $e = $e->{PropertyIsEqualTo};
                $params{filter} = $e->{PropertyName}."='".$e->{Literal}."'";
            } else {
		for my $key (keys %$e) {
		    next if $key =~ /^xmlns/;
		    print STDERR "warning: discarding $key filter\n";
		}
		$params{filter} = '';
	    }
        } else {
            $params{filter} = '';
        }

    }

    $params{EPSG} = 3857 if $params{EPSG} and $params{EPSG} == 900913;

    if ($debug) {
        for (sort keys %params) {
            next unless $params{$_};
            print STDERR "$_ => $params{$_}\n" unless ref $params{$_};
            print STDERR "$_ => @{$params{$_}}\n" if ref $params{$_} eq 'ARRAY';
        }
    }

    if ($params{request} eq 'GetCapabilities' or $params{request} eq 'capabilities') {
	GetCapabilities();
    } elsif ($params{request} eq 'DescribeFeatureType') {
	DescribeFeatureType();
    } elsif ($params{request} eq 'GetFeature') {
	GetFeature();
    } else {
	croak('Unrecognized request: '.$params{request});
    }
}

sub GetFeature {
    my $type = feature();
    croak "No such feature type: $params{typename}" unless $type;

    my $maxfeatures = $q->param($names{MAXFEATURES});
    ($maxfeatures) = $maxfeatures =~ /(\d+)/ if defined $maxfeatures;
    
    # feed the copy directly to stdout
    print($q->header(-type => $config->{MIME}, -charset=>'utf-8'));
    STDOUT->flush;
    my $vsi = '/vsistdout/';

    # should use options to set prefix and namespace
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
            $n =~ s/ä/a/g;
	    $n =~ s/ö/o/g;

	    # need to use the specified GeometryColumn and only it
	    next if $type->{Schema}{$f} eq 'geometry' and not ($f eq $type->{GeometryColumn});
            if ($params{EPSG} and $f eq $type->{GeometryColumn}) {
                push @cols, "st_transform(\"$f\",$params{EPSG}) as \"$n\"";
            } else {
                push @cols, "\"$f\" as \"$n\"";
            }
	}
	my $sql;
        $sql = "select ".join(',',@cols)." from \"$type->{Table}\" where ST_IsValid($type->{GeometryColumn})";
        $sql .= " and $params{filter}" if $params{filter};
	$layer = $datasource->ExecuteSQL($sql);
    } else {
	croak "missing information in configuration file";
    }

    if ($params{bbox}) {
	my @bbox = split /,/, $params{bbox};
	$layer->SetSpatialFilterRect(@bbox);
    }    

    #$gml->CopyLayer($layer, $type->{Name});

    my $l2 = $gml->CreateLayer($type->{Name});
    my $d = $layer->GetLayerDefn;
    for (0..$d->GetFieldCount-1) {
	my $f = $d->GetFieldDefn($_);
	$l2->CreateField($f);
    }
    my $i = 0;
    $layer->ResetReading;
    while (my $f = $layer->GetNextFeature) {
	$l2->CreateFeature($f);
	$i++;
	last if defined $maxfeatures and $i >= $maxfeatures;
    }
    print STDERR "$i features\n" if $debug;

}

sub DescribeFeatureType {
    my @typenames = split(/\s*,\s*/, $params{typename});
    for my $name (@typenames) {
	my $type = feature($name);
	croak "No such feature type: $name (extracted from $params{typename})" unless $type;
    }

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

    for my $name (@typenames) {
	my $type = feature($name);
	my @elements;
	if ($type->{Schema}) {
	    for my $col (keys %{$type->{Schema}}) {
		if ($type->{Schema}{$col} eq 'geometry' and not($params{typename} =~ /$col$/)) {
		    next;
		}
		my $t = $type->{Schema}{$col};
		$t = "gml:GeometryPropertyType" if $t eq 'geometry';
		my $c = $col;
		$c =~ s/ /_/g; # field name adjustments as GDAL does them
		$c =~ s/ä/a/g; # extra name adjustments, needed by QGIS
                $c =~ s/ö/o/g;
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
	xml_element('complexType', {name => $params{typename}.'Type'},
		    ['complexContent', 
		     ['extension', { base => 'gml:AbstractFeatureType' }, 
		      ['sequence', \@elements
		       ]]]);
	xml_element('element', { name => $type->{Name}, 
				 type => 'ogr:'.$params{typename}.'Type',
				 substitutionGroup => 'gml:_Feature' } );
    }

    xml_element('/schema', '>');
    select(STDOUT);
    close $out;    
    $header = WXS::header(cgi => $q, length => length(Encode::encode_utf8($var)), type => $config->{MIME});
    print $var;
}

sub GetCapabilities {
    my($out, $var);
    open($out,'>', \$var);
    select $out;
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n");
    xml_element('wfs:WFS_Capabilities', 
		{ version => $params{version},
		  'xmlns:gml' => "http://www.opengis.net/gml",
		  'xmlns:wfs' => "http://www.opengis.net/wfs",
		  'xmlns:ows' => "http://www.opengis.net/ows",
		  'xmlns:xlink' => "http://www.w3.org/1999/xlink",
		  'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
		  'xmlns:ogc' => "http://www.opengis.net/ogc",
		  'xmlns' => "http://www.opengis.net/wfs",
		  'xsi:schemaLocation' => "http://www.opengis.net/wfs http://schemas.opengis.net/wfs/1.1.0/wfs.xsd" }, 
		'<');
    ServiceIdentification();
    ServiceProvider();
    OperationsMetadata();
    FeatureTypeList();
    Filter_Capabilities();
    xml_element('/wfs:WFS_Capabilities', '>');
    select(STDOUT);
    close $out;
    $header = WXS::header(cgi => $q, length => length(Encode::encode_utf8($var)), type => $config->{MIME});
    print $var;
}

sub ServiceIdentification {
    xml_element('ows:ServiceIdentification', '<');
    xml_element('ows:Title', 'WFS Server');
    xml_element('ows:Abstract');
    xml_element('ows:ServiceType', {codeSpace=>"OGC"}, 'OGC WFS');
    xml_element('ows:ServiceTypeVersion', $params{version});
    xml_element('ows:Fees');
    xml_element('ows:AccessConstraints');
    xml_element('/ows:ServiceIdentification', '>');
}

sub ServiceProvider {
    xml_element('ows:ServiceProvider', '<');
    xml_element('ows:ProviderName');
    xml_element('ows:ProviderSite', {'xlink:type'=>"simple", 'xlink:href'=>""});
    xml_element('ows:ServiceContact');
    xml_element('/ows:ServiceProvider', '>');
}

sub OperationsMetadata  {
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
    xml_element('FeatureTypeList', '<');
    xml_element('Operations', ['Operation', 'Query']);
    for my $type (@{$config->{FeatureTypeList}}) {
	if ($type->{Layer}) {
	    xml_element('FeatureType', [
					['Name', $type->{Name}],
					['Title', $type->{Title}],
					['Abstract', $type->{Abstract}],
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
                                ['Abstract', $l->{Abstract}],
                                ['DefaultSRS', $l->{DefaultSRS}],
                                ['SRS', 'EPSG:3587'],
                                ['OutputFormats', ['Format', 'text/xml; subtype=gml/3.1.1']]
                            ]);
	    }
	}
    }
    xml_element('/FeatureTypeList', '>');
}

sub feature {
    my $name = @_ ? shift : $params{typename};
    my $type;
    for my $t (@{$config->{FeatureTypeList}}) {
	if ($t->{Layer}) {
	    $type = $t, last if $t->{Name} eq $name;
	} else {
	    next unless $name =~ /^$t->{prefix}/;
	    # restrict now to postgis databases
	    my @layers = layers($t->{dbi}, $t->{prefix});
	    for my $l (@layers) {
		if ($l->{Name} eq $name) {
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
    my $sth = $dbh->table_info( '', 'public', undef, "'TABLE','VIEW'" );
    my @tables;
    while (my $data = $sth->fetchrow_hashref) {
	#my $n = decode("utf8", $data->{TABLE_NAME});
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
	    #my $n = decode("utf8", $data->{COLUMN_NAME});
	    my $n = $data->{COLUMN_NAME};
	    $n =~ s/"//g;
	    $schema{$n} = $data->{TYPE_NAME};
	    push @l, $n if $data->{TYPE_NAME} eq 'geometry';	    
	}
	for my $geom (@l) {
	    my $sql = "select auth_name,auth_srid ".
		"from \"$table\" join spatial_ref_sys on srid=st_srid(\"$geom\") limit 1";
	    my $sth = $dbh->prepare($sql) or croak($dbh->errstr);
	    my $rv = $sth->execute or croak($dbh->errstr);
	    my($name,$srid)  = $sth->fetchrow_array;
	    $name = 'unknown' unless defined $name;
	    $srid = -1 unless defined $srid;

	    # check that the table contains at least one spatial feature
	    $sql = "select \"$geom\" from \"$table\" where not \"$geom\" isnull limit 1";
	    $sth = $dbh->prepare($sql) or croak($dbh->errstr);
	    $rv = $sth->execute or croak($dbh->errstr);
	    my($g)  = $sth->fetchrow_array;
	    next unless $g;

	    push @layers, { Title => "$table($geom)",
			    Name => "$prefix.$table.$geom",
			    Abstract => "Layer from $table in $prefix using column $geom",
			    DefaultSRS => "$name:$srid",
			    Table => $table,
			    GeometryColumn => $geom,
			    Schema => \%schema };
	}
    }
    return @layers;
}

sub Filter_Capabilities  {
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
