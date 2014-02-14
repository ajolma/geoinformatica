#!/usr/bin/perl -w

use utf8;
use strict;
use IO::Handle;
use Carp;
use Encode;
use DBI;
use CGI;
use XML::LibXML;
use Data::Dumper;

use Geo::GDAL;
use JSON;
use lib '/var/www/lib';
require WxS;
WxS->import(':all');

binmode STDERR, ":utf8";
binmode STDOUT, ":utf8";
my $config;
my $q = CGI->new;
my %names = ();
my $request;
my $debug = 0;

eval {
    $config = WxS::config();
    if ($ENV{REQUEST_METHOD} eq 'OPTIONS') {
        print $q->header(
            -type=>"text/plain", 
            -Access_Control_Allow_Origin=>$config->{CORS},
            -Access_Control_Allow_Methods=>"GET,POST",
            -Access_Control_Allow_Headers=>"origin,x-requested-with,content-type",
            -Access_Control_Max_Age=>60*60*24
            );
    } else {
        page();
    }
};
error($q, $@, $config ? (-type => $config->{MIME}, -Access_Control_Allow_Origin=>$config->{CORS}) : ()) if $@;

sub page {
    print STDERR "\n" if $debug;
    for ($q->param) {
	croak "Parameter ".uc($_)." given more than once.#" if exists $names{uc($_)};
	$names{uc($_)} = $_;
        print STDERR "$_ => ".$q->param($_)."\n" if $debug > 1;
    }

    my $post = $names{POSTDATA};
    $post = $names{'XFORMS:MODEL'} unless $post;

    if ($post) {
        my $parser = XML::LibXML->new(no_blanks => 1);
        my $dom = $parser->load_xml(string => $q->param($post));
        my $node = $dom->documentElement();
        $request = ogc_request($node);
    } else {
        $q->{resource} = $config->{resource};
	$request->{request} = $q->param($names{REQUEST}) || 'GetCapabilities';
	$request->{service} = $q->param($names{SERVICE});
	$request->{service} = 'WFS' unless $request->{service};
	$request->{version} = $q->param($names{WMTVER});
	$request->{version} = $q->param($names{VERSION}) if $q->param($names{VERSION});
	$request->{version} = '1.1.0' unless $request->{version};
	#croak "Not a supported WFS version.#" unless $request->{version} eq $config->{version};
	$request->{BBox} = $q->param($names{BBOX}) if $q->param($names{BBOX});
        $request->{EPSG} = $1 if $q->param($names{SRSNAME}) and $q->param($names{SRSNAME}) =~ /EPSG:(\d+)/;
	$request->{typeName} = decode utf8=>$q->param($names{TYPENAME});
        $request->{maxFeatures} = $q->param($names{MAXFEATURES}) || $q->param($names{COUNT});
        $request->{filter} = decode utf8=>$q->param($names{FILTER});
        if ($request->{filter} and $request->{filter} =~ /^</) {
            my $s2 = '<ogc:Filter xmlns:ogc="http://www.opengis.net/ogc">';
            $request->{filter} =~ s/<ogc:Filter>/$s2/;
            my $parser = XML::LibXML->new(no_blanks => 1);
            my $dom = $parser->load_xml(string => $request->{filter});
            my $node = $dom->documentElement();
            $request->{filter} = ogc_filter($node);
        } else {
            $request->{filter} = '';
        }
    }

    # adjustments to parameters

    $request->{EPSG} = 3857 if $request->{EPSG} and $request->{EPSG} == 900913;

    print STDERR Dumper($request) if $debug > 2;

    if ($request->{request} eq 'GetCapabilities' or $request->{request} eq 'capabilities') {
	GetCapabilities();
    } elsif ($request->{request} eq 'DescribeFeatureType') {
	DescribeFeatureType();
    } elsif ($request->{request} eq 'GetFeature') {
        $request->{maxFeatures} = $config->{maxfeatures} unless defined $request->{maxFeatures};
        ($request->{maxFeatures}) = $request->{maxFeatures} =~ /(\d+)/ if defined $request->{maxFeatures};
	GetFeature();
    } elsif ($request->{request} eq 'Transaction') {
        Transaction();
    } else {
	croak('Unrecognized request: '.$request->{request});
    }
}

sub Transaction {
    my $dbisql = transaction_sql($request, \&feature);
    for my $dbi (keys %$dbisql) {
        my($connect, $user, $pass) = split / /, $dbi;
        my $dbh = DBI->connect($connect, $user, $pass) or croak('no db');
        $dbh->{pg_enable_utf8} = 1;
        $dbh->do($dbisql->{$dbi}) or croak $dbh->errstr;
    }
    print $q->header(-Access_Control_Allow_Origin=>$config->{CORS});
    # should return a TransactionResponse
}

sub GetFeature {
    my $query = $request->{queries} ? $request->{queries}[0] : $request; # actually we should loop through all queries
    my $typeName = $query->{typeName};
    $typeName =~ s/\w+://; # remove namespace
    my $type = feature($typeName);
    croak "No such feature type: $request->{typeName}" unless $type;
    croak "Datasource not defined" unless $type->{Datasource};

    my $datasource = Geo::OGR::Open($type->{Datasource});
    my $layer;
    if ($type->{Layer}) {
	$layer = $datasource->Layer($type->{Layer});
        if ($request->{BBox}) {
            my @bbox = split /,/, $request->{BBox};
            $layer->SetSpatialFilterRect(@bbox);
        }
    } elsif ($type->{Table}) {

        # pseudo_credentials: these fields are required to be in the filter and they are not included as attributes
        my($pseudo_credentials,@pseudo_credentials) = pseudo_credentials($type);
        if (@pseudo_credentials) {
            # test for pseudo credentials in filter
            my $pat1 = "\\(\\(\"$pseudo_credentials[0]\" = '.+?'\\) AND \\(\"$pseudo_credentials[1]\" = '.+?'\\)\\)";
            my $pat2 = "\\(\\(\"$pseudo_credentials[1]\" = '.+?'\\) AND \\(\"$pseudo_credentials[0]\" = '.+?'\\)\\)";
            croak "Not authorized: provide ".join(' and ', @pseudo_credentials)." in filter (is now '$query->{filter}')" unless 
                $query->{filter} and ($query->{filter} =~ /$pat1/ or $query->{filter} =~ /$pat2/);
        }
        
	my @cols;
	for my $f (keys %{$type->{Schema}}) {
	    next if $f eq 'ID';
            next if $pseudo_credentials->{$f};
	    my $n = $f;
	    $n =~ s/ /_/g;
            $n =~ s/ä/a/g;
	    $n =~ s/ö/o/g;

	    # need to use the specified GeometryColumn and only it
	    next if $type->{Schema}{$f} eq 'geometry' and not ($f eq $type->{GeometryColumn});

            if ($query->{EPSG} and $f eq $type->{GeometryColumn}) {
                push @cols, "st_transform(\"$f\",$query->{EPSG}) as \"$n\"";
            } else {
                push @cols, "\"$f\" as \"$n\"";
            }
	}
	my $sql;
        $sql = "select ".join(',',@cols)." from \"$type->{Table}\" where ST_IsValid($type->{GeometryColumn})";

        # test for $type->{$type->{Title}}{require_filter} vs $query->{filter}
        my $geom = $type->{GeometryColumn};
        $geom = "st_transform(\"$geom\",$query->{EPSG})" if $query->{EPSG};
        $query->{filter} =~ s/GeometryColumn/$geom/g if $query->{filter};
        $sql .= " and $query->{filter}" if $query->{filter};

        print STDERR "$sql\n";
	$layer = $datasource->ExecuteSQL($sql);
    } else {
	croak "missing information in configuration file";
    }    

    # note that OpenLayers seem not to like the default ones, at least with outputFormat: "GML2"
    # use "TARGET_NAMESPACE": "http://ogr.maptools.org/", "PREFIX": "ogr", in config or type section
    my $ns = $config->{TARGET_NAMESPACE} || $type->{TARGET_NAMESPACE} || '"http://www.opengis.net/wfs';
    my $prefix = $config->{PREFIX} || $type->{PREFIX} || 'wfs';

    # feed the copy directly to stdout
    print $q->header( -type => $config->{MIME}, 
                      -charset=>'utf-8',
                      -expires=>'+1s',
                      -Access_Control_Allow_Origin=>$config->{CORS} );
    
    STDOUT->flush;
    my $vsi = '/vsistdout/';
    my $gml = Geo::OGR::Driver('GML')->Create($vsi, { TARGET_NAMESPACE => $ns, PREFIX => $prefix });

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
	last if defined $request->{maxFeatures} and $i >= $request->{maxFeatures};
    }
    print STDERR "$i features served, max is ",$request->{maxFeatures}||'not set',"\n" if $debug;
}

sub DescribeFeatureType {
    my @typenames = split(/\s*,\s*/, $request->{typeName});
    for my $name (@typenames) {
	my $type = feature($name);
	croak "No such feature type: $name (extracted from $request->{typeName})" unless $type;
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
        my($pseudo_credentials) = pseudo_credentials($type);
	my @elements;
	if ($type->{Schema}) {
            for my $col (keys %{$type->{Schema}}) {
                next if $pseudo_credentials->{$col};
		next if $type->{Schema}{$col} eq 'geometry' and not($request->{typeName} =~ /$col$/);
		my $t = $type->{Schema}{$col};
		$t = "gml:GeometryPropertyType" if $t eq 'geometry';
		my $c = $col;
		$c =~ s/ /_/g; # field name adjustments as GDAL does them
		$c =~ s/ä/a/g; # extra name adjustments, needed by QGIS
                $c =~ s/ö/o/g;
		# GDAL will use geometryProperty for geometry elements when producing GML:
		$c = 'geometryProperty' if $t eq 'gml:GeometryPropertyType';
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
	xml_element('complexType', {name => $request->{typeName}.'Type'},
		    ['complexContent', 
		     ['extension', { base => 'gml:AbstractFeatureType' }, 
		      ['sequence', \@elements
		       ]]]);
	xml_element('element', { name => $type->{Name}, 
				 type => 'ogr:'.$request->{typeName}.'Type',
				 substitutionGroup => 'gml:_Feature' } );
    }

    xml_element('/schema', '>');
    select(STDOUT);
    close $out;
    print $q->header( -Content_length => length(Encode::encode_utf8($var)), 
                      -type => $config->{MIME},
                      -charset => 'utf-8',
                      -expires=>'+1s',
                      -Access_Control_Allow_Origin => $config->{CORS} );
    print $var;
}

sub GetCapabilities {
    my($out, $var);
    open($out,'>', \$var);
    select $out;
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n");
    xml_element('wfs:WFS_Capabilities', 
		{ version => $request->{version},
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
    print $q->header( -Content_length => length(Encode::encode_utf8($var)), 
                      -type => $config->{MIME},
                      -charset => 'utf-8',
                      -expires=>'+1s',
                      -Access_Control_Allow_Origin => $config->{CORS} ), $var;
}

sub ServiceIdentification {
    xml_element('ows:ServiceIdentification', '<');
    xml_element('ows:Title', 'WFS Server');
    xml_element('ows:Abstract');
    xml_element('ows:ServiceType', {codeSpace=>"OGC"}, 'OGC WFS');
    xml_element('ows:ServiceTypeVersion', $request->{version});
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
    Operation($config, 'Transaction',
	      [{inputFormat => ['text/xml; subtype=gml/3.1.1']}, 
	       {idgen => ['GenerateNew','UseExisting','ReplaceDuplicate']},
	       {releaseAction => ['ALL','SOME']}
	      ]);
    xml_element('/ows:OperationsMetadata', '>');
}

sub FeatureTypeList  {
    xml_element('wfs:FeatureTypeList', '<');
    my @operations = (['wfs:Operation', 'Query']);
    push @operations, list2element('wfs:Operation', $config->{Transaction}) if $config->{Transaction};
    xml_element('wfs:Operations', \@operations);
    for my $type (@{$config->{FeatureTypeList}}) {
	if ($type->{Layer}) {
            my @FeatureType = (
                ['wfs:Name', $type->{Name}],
                ['wfs:Title', $type->{Title}],
                ['wfs:Abstract', $type->{Abstract}],
                ['wfs:DefaultSRS', $type->{DefaultSRS}],
                ['wfs:OutputFormats', ['wfs:Format', 'text/xml; subtype=gml/3.1.1']]);
            push @FeatureType, ['ows:WGS84BoundingBox', {dimensions=>2}, 
                                [['ows:LowerCorner',$type->{LowerCorner}],
                                 ['ows:UpperCorner',$type->{UpperCorner}]]]
                                     if exists $type->{LowerCorner};
            push @FeatureType, ['wfs:Operations', [list2element('wfs:Operation', $type->{Transaction})]] if exists $type->{Transaction};
	    xml_element('wfs:FeatureType', \@FeatureType);
	} elsif ($type->{prefix}) {
	    # restrict now to postgis databases
	    my @layers = layers($type->{dbi}, $type->{prefix});
	    for my $l (@layers) {
                next if $type->{allow} and !$type->{allow}{$l->{Title}};
                my @FeatureType = (
                    ['wfs:Name', $l->{Name}],
                    ['wfs:Title', $l->{Title}],
                    ['wfs:Abstract', $l->{Abstract}],
                    ['wfs:DefaultSRS', $l->{DefaultSRS}],
                    ['wfs:OtherSRS', 'EPSG:3857'],
                    ['wfs:OutputFormats', ['wfs:Format', 'text/xml; subtype=gml/3.1.1']]);
                my $sub = $type->{$l->{Title}};
                push @FeatureType, ['wfs:Operations', [list2element('wfs:Operation', $sub->{Transaction})]] if exists $sub->{Transaction};
		xml_element('wfs:FeatureType', \@FeatureType);
	    }
	} else {
            croak "No Layer nor prefix in FeatureType definition.";
        }
    }
    xml_element('/wfs:FeatureTypeList', '>');
}

sub pseudo_credentials {
    my $type = shift;
    my $c = $type->{pseudo_credentials} if $type->{pseudo_credentials};
    unless ($c) {
        my $title = $type->{Title};
        $c = $type->{$title}->{pseudo_credentials} if $type->{$title};
    }
    return ({}) unless $c;
    my($c1,$c2) = $c =~ /(\w+),(\w+)/;
    return ({$c1 => 1,$c2 => 1},$c1,$c2);
}

sub feature {
    my $name = shift;
    for my $t (@{$config->{FeatureTypeList}}) {
	if ($t->{Layer}) {
	    return $t if $t->{Name} eq $name;
	} else {
	    next unless $name =~ /^$t->{prefix}\./;
	    # restrict now to postgis databases
	    my @layers = layers($t->{dbi}, $t->{prefix});
	    for my $l (@layers) {
		if ($l->{Name} eq $name) {
		    my $type = $t;
		    for (keys %$l) {
			$type->{$_} = $l->{$_};
		    }
                    return $type;
		}
	    }
	}
    }
    croak "Requested FeatureType '$name' not served.";
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
	    #next unless $g;

            #print STDERR "found layer $prefix.$table.$geom\n";

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
