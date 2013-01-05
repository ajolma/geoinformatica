#!/usr/bin/perl -w

use strict;
use IO::Handle;
use Carp;
use Encode;
use DBI;
use CGI;
use Geo::Proj4;
use Gtk2::Ex::Geo;
use Geo::Raster;
use Geo::Vector;
use JSON;
use lib '.';
require WXS;
WXS->import(qw/config header error serve_document xml_elements xml_element/);
require Scale;

binmode STDERR, ":utf8";
binmode STDOUT, ":utf8";
my $config;
my $q = CGI->new;
my %names = ();
my %params;
my $header = 0;
my $debug = 1;

eval {
    $config = config();
    page($q);
};
error(cgi => $q, header => $header, msg => $@, type => $config->{MIME}) if $@;

sub page {
    my($q) = @_;
    for ($q->param) {
	croak "Parameter ".uc($_)." given more than once.#" if exists $names{uc($_)};
	$names{uc($_)} = $_;
    }
    $q->{resource} = $config->{resource};
    my $request = $q->param($names{REQUEST}) || 'GetCapabilities';
    my $version = $q->param($names{WMTVER});
    $version = $q->param($names{VERSION}) if $q->param($names{VERSION});
    $version = '1.1.1' unless $version;
    croak "Not a supported WMS version.#" unless $version eq $config->{version};
    my $service = $q->param($names{SERVICE});
    $service = 'WMS'unless $service;

    $params{EPSG} = $1 if $q->param($names{SRS}) and $q->param($names{SRS}) =~ /EPSG:(\d+)/;
    $params{EPSG} = 3857 if $params{EPSG} and $params{EPSG} == 900913;
    $params{LAYERS} = [split(/,/, decode utf8=>$q->param($names{LAYERS}))] if $q->param($names{LAYERS});
    $params{BBOX} = [split(/,/, $q->param($names{BBOX}))] if $q->param($names{BBOX});
    ($params{WIDTH}) = $q->param($names{WIDTH}) =~ /(\d+)/ if $q->param($names{WIDTH});
    ($params{HEIGHT}) = $q->param($names{HEIGHT}) =~ /(\d+)/ if $q->param($names{HEIGHT});
    $params{WIDTH} = 512 unless $params{WIDTH};
    $params{HEIGHT} = 512 unless $params{HEIGHT};
    $params{WIDTH} = $config->{max_width} if $params{WIDTH} > $config->{max_width};
    $params{HEIGHT} = $config->{max_height} if $params{HEIGHT} > $config->{max_height};
    $params{pixel_size} = ($params{BBOX}[2] - $params{BBOX}[0])/$params{WIDTH} if $params{BBOX}; # assuming square pixels
    $params{FORMAT} = $q->param($names{FORMAT});
    $params{TRANSPARENT} = uc($q->param($names{TRANSPARENT})) eq 'TRUE' if $q->param($names{TRANSPARENT});
    $params{POLYGON} = $q->param($names{POLYGON});
    ($params{X}) = $q->param($names{X}) =~ /(\d+)/ if $q->param($names{X});
    ($params{Y}) = $q->param($names{Y}) =~ /(\d+)/ if $q->param($names{Y});
    my $bgcolor = $q->param($names{BGCOLOR}) || '0xffffff';
    $params{BGCOLOR} = [];
    @{$params{BGCOLOR}} = $bgcolor =~ /^0x(\w\w)(\w\w)(\w\w)/;
    $_ = hex($_) for (@{$params{BGCOLOR}});
    push @{$params{BGCOLOR}}, $params{TRANSPARENT} ? 0 : 255;
    $params{TIME} = $q->param($names{TIME});

    if ($debug) {
        for (sort keys %params) {
            next unless $params{$_};
            print STDERR "$_ => $params{$_}\n" unless ref $params{$_};
            print STDERR "$_ => @{$params{$_}}\n" if ref $params{$_} eq 'ARRAY';
        }
    }

    if ($request eq 'GetCapabilities' or $request eq 'capabilities') {
	GetCapabilities($version);
    } elsif ($request eq 'GetMap') {
	GetMap($version);
    } elsif ($request eq 'GetFeatureInfo') {
	GetFeatureInfo($version);
    } else {
	croak('Unrecognized request: '.$request);
    }
}

sub GetCapabilities {
    my($version) = @_;
    my($out, $var);
    open($out,'>', \$var);
    select $out;
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n",
	  '<!DOCTYPE WMT_MS_Capabilities SYSTEM ',
	  '"http://schemas.opengeospatial.net/wms/1.1.1/capabilities_1_1_1.dtd"',"\n",
	  " [\n",
	  " <!ELEMENT VendorSpecificCapabilities EMPTY>\n",
	  " ]>\n\n");
    xml_element('WMT_MS_Capabilities', { version=>$version }, '<');
    Service($version);
    Capability($version);
    xml_element('/WMT_MS_Capabilities', '>');
    select(STDOUT);
    close $out;
    $header = header(cgi => $q, length => length(Encode::encode_utf8($var)), type => $config->{MIME});
    print $var;
}

sub GetMap {
    my($version) = @_;

    my($minX, $minY, $maxX, $maxY) = @{$params{BBOX}};

    my @stack = ();
    for my $layer (@{$params{LAYERS}}) {
	my @layers = layer($layer);
	push @stack, @layers if @layers;
    }
    croak "LayerNotDefined .#" unless @stack;

    my $pixbuf = Gtk2::Ex::Geo::Canvas->new(
	[@stack], 
	$minX, 
	$minY+$params{HEIGHT}*$params{pixel_size},
	$params{pixel_size}, 0, 0, $params{WIDTH}, $params{HEIGHT}, @{$params{BGCOLOR}} );

    #print STDERR "no pixbuf from @stack\n", return unless $pixbuf;

    my $buffer = $pixbuf->save_to_buffer($params{FORMAT} eq 'image/png' ? 'png' : 'jpeg');
    print STDERR "length => ",length($buffer),", type => $params{FORMAT}\n" if $debug;
    $header = header(cgi => $q, length => length($buffer), type => $params{FORMAT});
    binmode STDOUT, ":raw";
    print $buffer;
    STDOUT->flush;
}

sub GetFeatureInfo {
    my($version) = @_;

    my($minX, $minY, $maxX, $maxY) = @{$params{BBOX}};
    my $x = $minX + $params{pixel_size} * $params{X};
    my $y = $maxY - $params{pixel_size} * $params{Y};

    my $wkt = $params{POLYGON} ? $params{POLYGON} : "POINT($x $y)";
    my $within = $params{POLYGON} ? 
	"within(the_geom, st_transform(st_geomfromewkt('SRID=3035;$wkt'),2393))" :
	"within(st_transform(st_geomfromewkt('SRID=3035;$wkt'),2393), the_geom)";
    my $sql = "select computed from \"1km\" where $within";

    my $dbh = DBI->connect('dbi:Pg:dbname=OILRISK', 'postgres', 'lahti') or croak $DBI::errstr;
    my $sth = $dbh->prepare($sql) or croak $dbh->errstr;
    $sth->execute() or croak $dbh->errstr;
    my @report;
    while ( my @row = $sth->fetchrow_array ) {
	push @report, $row[0];
    }

    print 
	$q->header(),
	'<meta content="text/html;charset=UTF-8" http-equiv="Content-Type">',
	$q->start_html,
	decode('utf8', "Infoa: valitussa kohdassa ($x,$y) val on:<br/>".join('<br/>',@report)), 
	$q->end_html;
}

sub layer {
    my($layer) = @_;
    my @layers = @{$config->{Layer}->{Layers}};

    # go through all layers in configuration and create the one that
    # was requested
    # returns an empty list in the case of an error

    for my $l (@layers) {
	next unless $layer eq $l->{Name};
	print STDERR "creating layer $l->{Name}\n" if $debug;
	my $scales = $l->{Scales};
	if ($scales) {
	    my $epsg = $l->{EPSG};
	    for my $s (@$scales) {
		if ($s->{Minimum_pixe_size}) {
		    if ($params{pixel_scale} > $s->{Minimum_pixe_size}) {
			$l = $s;
			last;
		    }
		} else {
		    $l = $s;
		    last;
		}
	    }
	    $l->{EPSG} = $epsg;
	}
	if ($l->{Filename}) {
            my $dataset = Geo::GDAL::Open($l->{Filename});
	    croak "$l->{Filename} is not recognized by GDAL" unless $dataset;
	    my $bands = $dataset->{RasterCount};
	    my @layers;
	    for my $band (1..$bands) {
                my $layer = Geo::Raster::Layer->new(filename => $l->{Filename}, band => $band);
		$layer->band()->SetNoDataValue($layer->{NoDataValue}) if exists $layer->{NoDataValue};
                print STDERR "created layer $layer\n" if $debug;
                push @layers, $layer;
            }
	    return @layers;
	}
	if ($l->{Datasource}) {
	    my %param = (datasource => $l->{Datasource});
	    if (exists $l->{SQL}) {

                my $geom = 'geom'; # need to get this from config...

		# a hack to allow a direct SQL injection
		my $SQL = decode utf8=>$q->param('SQL');
		if ($SQL) {
		    print STDERR "wms: $SQL\n" if $debug;
		    $l->{SQL} = $SQL;
		} else {
		    $l->{SQL} =~ s/\$time/$params{TIME}/;
		    $l->{SQL} =~ s/\$pixel_scale/$params{pixel_size}/g;
		}
		# the_geom should be replaced with a column name coming from the config
		if ($l->{EPSG} and $params{EPSG} != $l->{EPSG}) {
		    $l->{SQL} =~ s/$geom/st_transform($geom,$params{EPSG})/;
		}
                if (not $l->{SQL} =~ /where/) {
                    $l->{SQL} .= " where";
                } else {
                    $l->{SQL} .= " and";
                }
		$l->{SQL} .= " st_transform($geom,$params{EPSG}) && st_SetSRID(".
		    "'BOX3D($params{BBOX}[0] $params{BBOX}[1],$params{BBOX}[2] $params{BBOX}[3])'::box3d,$params{EPSG})";
		$param{SQL} = $l->{SQL};
		print STDERR "SQL: $param{SQL}\n" if $debug;
	    }
	    $param{single_color} = 
		[$l->{single_color}->{R},$l->{single_color}->{G},$l->{single_color}->{B},$l->{single_color}->{A}]
		if exists $l->{single_color};
	    $param{border_color} = 
		[$l->{border_color}->{R},$l->{border_color}->{G},$l->{border_color}->{B}]
		if exists $l->{border_color};
	    my $v = Geo::Vector::Layer->new(%param);
	    print STDERR "created layer $v ".$v->feature_count()."\n" if $debug;
	    for (sort keys %$v) {
		#print STDERR "$_ -> $v->{$_}\n";
	    }
	    for (qw/SYMBOL_SIZE LABEL_FIELD LABEL_PLACEMENT INCREMENTAL_LABELS/) {
		$v->{$_} = $l->{$_} if exists $l->{$_};
	    }
	    return $v;
	}
	if ($l->{Special}) {
	    return Scale->new(dx => $l->{dx}, dy => $l->{dy}) if $l->{Special} eq 'Scale';
	}
    }
    return ();
}

sub Service {
    my($version) = @_;
    xml_element('Service', '<>');
    xml_element('Name', 'OGC:WMS');
    xml_element('Title', $config->{Title});
    xml_element('Abstract', $config->{Abstract});
    xml_element('OnlineResource', { 'xmlns:xlink' => 'http://www.w3.org/1999/xlink', 
				    'xlink:type' => 'simple', 
				    'xlink:href' => $q->{resource}});
    xml_element('/Service', '<>');
}

sub Capability {
    my($version) = @_;
    xml_element('Capability', '<>');
    Request($version);
    Exception($version);
    xml_element('VendorSpecificCapabilities');
    Layers($version);
    xml_element('/Capability', '<>');
}

sub Request {
    my($version) = @_;
    xml_element('Request', '<>');
    my %request = ( GetCapabilities => 'application/vnd.ogc.wms_xml',
		    GetMap => ['image/png', 'image/jpeg'],
		    GetFeatureInfo => 'text/html' );
    for my $key ('GetCapabilities', 'GetMap', 'GetFeatureInfo') {
	my @format;
	if (ref $request{$key}) {
	    for my $f (@{$request{$key}}) {
		push @format, [ 'Format', $f ];
	    }
	} else {
	    @format = ([ 'Format', $request{$key} ]);
	}	
	xml_element( $key, [
			    @format,
			    [ 'DCPType', 
			      [ [ 'HTTP', 
				  [ [ 'Get', 
				      [ [ 'OnlineResource',
					  { 'xmlns:xlink' => 'http://www.w3.org/1999/xlink',
					    'xlink:type' => 'simple',
					    'xlink:href' => $q->{resource} } ]]]]]]]] );
    }
    xml_element('/Request', '<>');
}

sub Exception {
    my($version) = @_;
    xml_element('Exception', [ 'Format', 'application/vnd.ogc.se_xml' ] );
}

sub Layers {
    my($version) = @_;    
    
    # support top level BoundingBox element and EPSG
    
    my @BoundingBoxes;
    my $LatLonBoundingBox;
    if (exists $config->{BoundingBox}) {
        my $bs = $config->{BoundingBox};
        $bs = [$bs] if ref($bs) eq 'HASH';
        for my $b (@$bs) {
            push @BoundingBoxes, { SRS => "EPSG:$b->{EPSG}",
                                   minx => $b->{minX},
                                   miny => $b->{minY},
                                   maxx => $b->{maxX},
                                   maxy => $b->{maxY} };
        }
        $LatLonBoundingBox = LatLonBoundingBox(@BoundingBoxes);
    }
    my %epsg = map { $_ => 1 } split /,/, $config->{EPSG} if $config->{EPSG};
    
    # output Layer element(s) from the top level Layer in configuration
    
    my $layers = $config->{Layer};
    croak "Missing Layer in configuration" unless $layers;
    $layers = [$layers] if ref($layers) eq 'HASH';
    for my $layer (@$layers) {
        Layer($version,
              $layer,
              EPSG => \%epsg,
              LatLonBoundingBox => $LatLonBoundingBox,
              BoundingBoxes => \@BoundingBoxes
            );
    }
}

sub Layer {
    my($version, $layer, %inherit) = @_;

    # inherit BoundingBoxes
    my @bb = @{$inherit{BoundingBoxes}} if $inherit{BoundingBoxes};
    my $bs = $layer->{BoundingBox};
    if ($bs) {
        $bs = [$bs] if ref($bs) eq 'HASH';
        for my $b (@$bs) {
            push @bb, { SRS => "EPSG:$b->{EPSG}",
                        minx => $b->{minX},
                        miny => $b->{minY},
                        maxx => $b->{maxX},
                        maxy => $b->{maxY} };        
        }
    }
    my $ll = $inherit{LatLonBoundingBox} ? $inherit{LatLonBoundingBox} : LatLonBoundingBox(@bb) if @bb;
    
    # inherit EPSGs
    my %epsg;
    if ($inherit{EPSGs}) {
        for (keys %{$inherit{EPSGs}}) {
            $epsg{$_} = 1;
        }
    }
    if ($layer->{EPSG}) {
        for (split /,/, $layer->{EPSG}) {
            $epsg{$_} = 1;
        }
    }
    
    xml_element('Layer', '<');
    xml_elements( ['Name', $layer->{Name}], 
		  ['Title', $layer->{Title}],
                  ['Abstract', $layer->{Abstract}] );
    xml_element(LatLonBoundingBox => $ll) if $ll;
    for my $epsg  (keys %epsg) {
	xml_element('SRS', "EPSG:$epsg");
    }
    for my $bb (@bb) {
        xml_element('BoundingBox', $bb);
    }
    my $layers = $layer->{Layers};
    if ($layers) {
        $layers = [$layers] if ref($layers) eq 'HASH';
        for my $l (@$layers) {
            Layer($version, $l);
        }
    }
    xml_element('/Layer', '>');
}

sub LatLonBoundingBox {
    for (@_) {
        return {minx => $_->{minx}, miny=> $_->{miny}, maxx => $_->{maxx}, maxy => $_->{maxy}} if $_->{SRS} eq "EPSG:4326";
    }
    $b = shift;
    my $proj = Geo::Proj4->new(init => lc($b->{SRS}));
    my ($min_lat,$min_lon) = $proj->inverse($b->{minx}, $b->{miny});
    my ($max_lat,$max_lon) = $proj->inverse($b->{maxx}, $b->{maxy});
    return { minx => $min_lon, miny=> $min_lat, maxx => $max_lon, maxy => $max_lat };
}
