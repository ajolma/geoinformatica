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
my %names = ();
my %params = ();
my $debug = 1;

for my $k (sort keys %ENV) {
    print STDERR "$k => $ENV{$k}\n";
}

eval {
    $config = WXS::config();
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

sub get_predicate {
    my($key, $hash) = @_;
    my $property = $hash->{'ogc:PropertyName'};
    my $literal = $hash->{'ogc:Literal'};
    $literal = '' if ref($literal);
    if ($key eq 'ogc:PropertyIsEqualTo') {
        return "$property = '$literal'";
    } elsif ($key eq 'ogc:PropertyIsNotEqualTo') {
        return "$property != '$literal'";
    } elsif ($key eq 'ogc:PropertyIsLessThan') {
        return "$property < '$literal'";
    } elsif ($key eq 'ogc:PropertyIsGreaterThan') {
        return "$property > '$literal'";
    } elsif ($key eq 'ogc:PropertyIsLessThanOrEqualTo') {
        return "$property <= '$literal'";
    } elsif ($key eq 'ogc:PropertyIsGreaterThanOrEqualTo') {
        return "$property >= '$literal'";
    } elsif ($key eq 'ogc:PropertyIsBetween') {
        my $lb = $hash->{'ogc:LowerBoundary'};
        my $ub = $hash->{'ogc:UpperBoundary'};
        return "$property >= '$lb' and $property <= '$ub'";
    } elsif ($key eq 'ogc:PropertyIsLike') {
        return "$property ~ '$literal'";
    } elsif ($key eq 'ogc:PropertyIsNull') {
        return "$property isnull";
    } elsif ($key eq 'ogc:BBOX') {
    } else {
        print STDERR "unknown element in predicate: $key\n";
    }
}

sub get_not_filter {
    my $e = shift; # hash of a constraint, return NOT(A)
    my @keys = keys %$e;
    print STDERR "more than one element inside NOT: @keys" if @keys != 1;
    my $key = $keys[0];
    my $f;
    if ($key eq 'ogc:Not') {
        $f = get_not_filter($e->{$key});
    } elsif ($key eq 'ogc:Or') {
        $f = get_or_filter($e->{$key});
    } elsif ($key eq 'ogc:And') {
        $f = get_and_filter($e->{$key});
    } else {
        $f = get_predicate($key, $e->{$key});
    }
    return "NOT($f)";
}

sub get_or_filter {
    my $e = shift; # hash of or'red constraints, return ((A) OR ...)
    my @or;
    for my $key (keys %$e) {
        if ($key eq 'ogc:Not') {
            my $f = get_not_filter($e->{$key});
            push @or, $f if $f;
        } elsif ($key eq 'ogc:Or') {
            my $f = get_or_filter($e->{$key});
            push @or, $f if $f;
        } elsif ($key eq 'ogc:And') {
            my $f = get_and_filter($e->{$key});
            push @or, $f if $f;
        } else {
            if (ref($e->{$key}) eq 'ARRAY') { # XML::Simple puts similar elements into a list
                for my $a (@{$e->{$key}}) {
                    push @or, get_predicate($key, $a);
                }
            } else {
                push @or, get_predicate($key, $e->{$key});
            }
        }
    }
    my $filter = '(('.join(') OR (', @or).'))';
    return $filter;
}

sub get_and_filter {
    my $e = shift; # hash of and'ed constraints, return ((A) and ...)
    my @and;
    for my $key (keys %$e) {
        print "and filter: $key\n";
        if ($key eq 'ogc:Not') {
            my $f = get_not_filter($e->{$key});
            push @and, $f if $f;
        } elsif ($key eq 'ogc:Or') {
            my $f = get_or_filter($e->{$key});
            push @and, $f if $f;
        } elsif ($key eq 'ogc:And') {
            my $f = get_and_filter($e->{$key});
            push @and, $f if $f;
        } else {
            if (ref($e->{$key}) eq 'ARRAY') { # XML::Simple puts similar elements into a list
                for my $a (@{$e->{$key}}) {
                    push @and, get_predicate($key, $a);
                }
            } else {
                push @and, get_predicate($key, $e->{$key});
            }
        }
    }
    my $filter = '(('.join(') AND (', @and).'))';
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
                $params{maxfeatures} = $h->{maxFeatures} || $h->{count};

		next unless $h->{'ogc:Filter'};
		$h = $h->{'ogc:Filter'};

                if ($h->{'ogc:Not'}) {
                    $h = $h->{'ogc:Not'};
                    $params{filter} = get_not_filter($h);
                } elsif ($h->{'ogc:Or'}) {
                    $h = $h->{'ogc:Or'};
                    $params{filter} = get_or_filter($h);
                } elsif ($h->{'ogc:And'}) {
		    $h = $h->{'ogc:And'};
                    if ($h->{'ogc:BBOX'}) {
			$params{bbox} = get_bbox($h->{'ogc:BBOX'});
		    }
                    $params{filter} = get_and_filter($h);
		} elsif ($h->{'ogc:BBOX'}) {
		    $params{bbox} = get_bbox($h->{'ogc:BBOX'});
		}

            } elsif ($k eq 'wfs:Transaction') {
		my $h = $post->{$k};
                $params{service} = $h->{'service'};
		$params{version} = $h->{'version'};
		$params{request} = 'Transaction';
                if ($h->{'wfs:Insert'}) {
                    $params{Insert} = $h->{'wfs:Insert'};
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
        $params{maxfeatures} = $q->param($names{MAXFEATURES}) || $q->param($names{COUNT});
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

    # adjustments to parameters

    $params{EPSG} = 3857 if $params{EPSG} and $params{EPSG} == 900913;

    $params{maxfeatures} = $config->{maxfeatures} unless defined $params{maxfeatures};
    ($params{maxfeatures}) = $params{maxfeatures} =~ /(\d+)/ if defined $params{maxfeatures};

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
    } elsif ($params{request} eq 'Transaction' and $params{Insert}) {
	Insert();
    } else {
	croak('Unrecognized request: '.$params{request});
    }
}

sub Insert {
    for my $insert_type (keys %{$params{Insert}}) {
        my $h = $params{Insert}{$insert_type};
        $insert_type =~ s/^wfs://;
        $insert_type =~ s/^feature://;
        my $type = feature($insert_type);
        croak "No such feature type: $insert_type" unless $type;
        croak "The datasource is not PostGIS" unless $type->{Table};
        my $datasource = Geo::OGR::Open($type->{Datasource});
        my @cols;
        my @vals;
        for my $f (keys %$h) {
            my $v = $h->{$f};
            $f =~ s/^wfs://;
            $f =~ s/^feature://;
            my $val;
            if ($f eq 'geometryProperty') {

                $val = WKT($v);
                $f = $type->{GeometryColumn};

            }  else {
            
                $f = '' unless exists $type->{Schema}{$f};

            }
            
            next unless $f;

            push @cols, "\"$f\"";
            push @vals, $val;

        }
	my $sql = "insert into $type->{Table} (".join(',',@cols).") values (".join(',',@vals).")";
        my($connect, $user, $pass) = split / /, $type->{dbi};
	my $dbh = DBI->connect($connect, $user, $pass) or croak('no db');
        $dbh->{pg_enable_utf8} = 1;
        $dbh->do($sql) or croak $dbh->errstr;;
    }
    print $q->header(-Access_Control_Allow_Origin=>$config->{CORS});
}

sub WKT {
    my($geom) = @_;
    my $wkt;
    my $e;
    if ($e = $geom->{'gml:Point'}) {
        my $pos = $e->{'gml:pos'};
        $wkt = "POINT ($pos)";
    } elsif ($e = $geom->{'gml:LineString'}) {
        my @tmp = split / /, $e->{'gml:posList'};
        my @pos;
        for (my $i = 0; $i < @tmp; $i+=2) {
            push @pos, $tmp[$i].' '.$tmp[$i+1];
        }
        $wkt = "LINESTRING (".join(', ',@pos).")";
    } elsif ($e = $geom->{'gml:Polygon'}) {
        my @tmp = split / /, $e->{'gml:exterior'}{'gml:LinearRing'}{'gml:posList'};
        my @pos;
        for (my $i = 0; $i < @tmp; $i+=2) {
            push @pos, $tmp[$i].' '.$tmp[$i+1];
        }
        $wkt = "POLYGON ((".join(', ',@pos)."))";
    } 
    print STDERR "$wkt\n";
    my $srid = $e->{'srsName'};
    ($srid) = $srid =~ /EPSG:(\d+)/;
    return "ST_GeometryFromText('$wkt',$srid)";
}

sub GetFeature {
    my $type = feature();
    croak "No such feature type: $params{typename}" unless $type;

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

    # note that OpenLayers seem not to like the default ones, at least with outputFormat: "GML2"
    # use "TARGET_NAMESPACE": "http://ogr.maptools.org/", "PREFIX": "ogr", in config or type section
    my $ns = $config->{TARGET_NAMESPACE} || $type->{TARGET_NAMESPACE} || '"http://www.opengis.net/wfs';
    my $prefix = $config->{PREFIX} || $type->{PREFIX} || 'wfs';

    # feed the copy directly to stdout
    print $q->header( -type => $config->{MIME}, 
                      -charset=>'utf-8',
                      -expires=>$config->{expires} || '+1s',
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
	last if defined $params{maxfeatures} and $i >= $params{maxfeatures};
    }
    print STDERR "$i features served, max is ",$params{maxfeatures}||'not set',"\n" if $debug;
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
    print $q->header( -Content_length => length(Encode::encode_utf8($var)), 
                      -type => $config->{MIME},
                      -charset => 'utf-8',
                      -expires=>$config->{expires} || '+1s',
                      -Access_Control_Allow_Origin => $config->{CORS} );
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
    print $q->header( -Content_length => length(Encode::encode_utf8($var)), 
                      -type => $config->{MIME},
                      -charset => 'utf-8',
                      -expires=>$config->{expires} || '+1s',
                      -Access_Control_Allow_Origin => $config->{CORS} ), $var;
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
    if ($config->{Transaction}) {
	my @t = split /\s*,\s*/, $config->{Transaction};
	for my $t (@t) {
	    push @operations, ['wfs:Operation', $t];
	}
    }
    xml_element('wfs:Operations', \@operations);
    for my $type (@{$config->{FeatureTypeList}}) {
	if ($type->{Layer}) {
	    xml_element('wfs:FeatureType', [
			    ['wfs:Name', $type->{Name}],
			    ['wfs:Title', $type->{Title}],
			    ['wfs:Abstract', $type->{Abstract}],
			    ['wfs:DefaultSRS', $type->{DefaultSRS}],
			    ['wfs:OutputFormats', ['wfs:Format', 'text/xml; subtype=gml/3.1.1']],
			    ['ows:WGS84BoundingBox', {dimensions=>2}, 
			     [['ows:LowerCorner',$type->{LowerCorner}],
			      ['ows:UpperCorner',$type->{UpperCorner}]]]
			]);
	} else {
	    # restrict now to postgis databases
	    my @layers = layers($type->{dbi}, $type->{prefix});
	    for my $l (@layers) {
		xml_element('wfs:FeatureType', [
                                ['wfs:Name', $l->{Name}],
                                ['wfs:Title', $l->{Title}],
                                ['wfs:Abstract', $l->{Abstract}],
                                ['wfs:DefaultSRS', $l->{DefaultSRS}],
                                ['wfs:OtherSRS', 'EPSG:3857'],
                                ['wfs:OutputFormats', ['wfs:Format', 'text/xml; subtype=gml/3.1.1']],
				['wfs:Operations', \@operations]
                            ]);
	    }
	}
    }
    xml_element('/wfs:FeatureTypeList', '>');
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
