package WxS;

use Carp;
require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = (all  => [ qw/Operation config error serve_document serve_vsi list2element xml_elements xml_element ogc_request ogc_filter transaction_sql/ ]);
our @EXPORT_OK = @{$EXPORT_TAGS{all}};

use Encode;
use JSON;
use XML::LibXML qw /:libxml/;

sub Operation {
    my($config, $name, $parameters) = @_;
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

sub config {
    my $conf = shift;
    unless ($conf) {
        if (open(my $fh, '<', '/var/www/etc/dispatch')) {
            while (<$fh>) {
                chomp;
                @l = split /\t/;
                $conf = $l[1] if $l[0] and $l[0] eq $0;
            }
        }
    }
    croak "no configuration file.#" unless $conf;
    open(my $fh, '<', $conf) or croak "can't open configuration file.#";
    binmode $fh, ":utf8";
    my @json = <$fh>;
    close $fh;
    $config = JSON->new->utf8->decode(encode('UTF-8', "@json"));
    $config->{CORS} = $ENV{'REMOTE_ADDR'} unless $config->{CORS};
    return $config;
}

sub error {
    my($cgi, $msg, %header_arg) = @_;
    select(STDOUT);
    print $cgi->header(%header_arg, -charset=>'utf-8'), '<?xml version="1.0" encoding="UTF-8"?>',"\n";
    my($error) = ($msg =~ /(.*?)\.\#/);
    if ($error) {
        $error =~ s/ $//;
        $error = { code => $error } if $error eq 'LayerNotDefined';
    } else {
        $error = 'Unspecified error: '.$msg;
    }
    xml_element('ServiceExceptionReport',['ServiceException', $error]);
    select(STDERR);
    print "$error\n";
}

sub serve_document {
    my($cgi, $doc, $type) = @_;
    my $length = (stat($doc))[10];
    croak "Can't stat file to serve" unless $length;    
    open(DOC, '<', $doc) or croak "Couldn't open $doc: $!";
    print $cgi->header(-type => $type, -Content_length => $length, -charset=>'utf-8');
    my $data;
    while( sysread(DOC, $data, 10240) ) {
        print $data;
    }
    close DOC;
}

sub serve_vsi {
    my($cgi, $doc, $type) = @_;
    my $fp = Geo::GDAL::VSIFOpenL($vsi, 'r');
    my $data;
    while (my $chunk = Geo::GDAL::VSIFReadL(1024,$fp)) {
        $data .= $chunk;
    }
    Geo::GDAL::VSIFCloseL($fp);
    $data = decode('utf8', $data);
    $length = length(Encode::encode_utf8($data));
    print $cgi->header(-type => $type, -Content_length => $length, -charset=>'utf-8');
    print $data;
    STDOUT->flush;
    Geo::GDAL::Unlink($arg{vsi});
}

sub list2element {
    my($tag, $list) = @_;
    my @element;
    my @t = split /\s*,\s*/, $list;
    for my $t (@t) {
        push @element, [$tag, $t];
    }
    return @element;
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
    unless (defined $content) {
        print("/>");
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
            print("</$element>");
        } elsif ($content eq '>' or $content eq '<' or $content eq '<>') {
            print(">");
        } else {
            print(">$content</$element>");
        }
    }
}

# return OGC request in a hash
# this function is written according to WFS 1.1.0
sub ogc_request {
    my($node) = @_;
    if ($node->nodeName eq 'wfs:GetFeature') {
        my $request = {};
        $request->{request} = 'GetFeature';
        for my $a (qw/service version resultType outputFormat maxFeatures/) {
            $request->{$a} = $node->{$a} if exists $node->{$a};
        }
        $request->{queries} = [];
        for ($node = $node->firstChild; $node; $node = $node->nextSibling) {
            push @{$request->{queries}}, ogc_request($node);
        }
        return $request;
    } elsif ($node->nodeName eq 'wfs:Transaction') {
        my $request = {};
        $request->{request} = 'Transaction';
        for my $a (qw/service version/) {
            $request->{$a} = $node->{$a} if exists $node->{$a};
        }
        $request->{inserts} = [];
        for ($node = $node->firstChild; $node; $node = $node->nextSibling) {
            if ($node->nodeName eq 'wfs:Insert') {
                for (my $n = $node->firstChild; $n; $n = $n->nextSibling) {
                    push @{$request->{inserts}}, $n;
                }
            }
        }
        return $request;
    } elsif ($node->nodeName eq 'wfs:Query') {
        my $query = {};
        my @filters = $node->getChildrenByTagName('ogc:Filter');
        $query->{filter} = ogc_filter($filters[0]) if @filters; # there is only one filter
        for my $a (qw/typeName srsName/) {
            $query->{$a} = $node->{$a} if exists $node->{$a};
        }
        if (exists $query->{srsName}) {
            ($query->{EPSG}) = $query->{srsName} =~ /EPSG:(\d+)/;
        }
        return $query;
    }
}

# convert OGC Filter XML to SQL
# this function is written according to V1.1
sub ogc_filter {
    my($node) = @_;
    if ($node->nodeName eq 'ogc:Literal') {
        return "'".$node->firstChild->data."'";
    } elsif ($node->nodeName eq 'ogc:PropertyName') {
        return '"'.$node->firstChild->data.'"';
    } elsif ($node->nodeName eq 'ogc:PropertyIsEqualTo') {
        $node = $node->firstChild;
        return '('.ogc_filter($node).' = '.ogc_filter($node->nextSibling).')';
    } elsif ($node->nodeName eq 'ogc:PropertyIsNotEqualTo') {
        $node = $node->firstChild;
        return '('.ogc_filter($node).' != '.ogc_filter($node->nextSibling).')';
    } elsif ($node->nodeName eq 'ogc:PropertyIsLessThan') {
        $node = $node->firstChild;
        return '('.ogc_filter($node).' < '.ogc_filter($node->nextSibling).')';
    } elsif ($node->nodeName eq 'ogc:PropertyIsGreaterThan') {
        $node = $node->firstChild;
        return '('.ogc_filter($node).' > '.ogc_filter($node->nextSibling).')';
    } elsif ($node->nodeName eq 'ogc:PropertyIsLessThanOrEqualTo') {
        $node = $node->firstChild;
        return '('.ogc_filter($node).' <= '.ogc_filter($node->nextSibling).')';
    } elsif ($node->nodeName eq 'ogc:PropertyIsGreaterThanOrEqualTo') {
        $node = $node->firstChild;
        return '('.ogc_filter($node).' >= '.ogc_filter($node->nextSibling).')';
    } elsif ($node->nodeName eq 'ogc:PropertyIsBetween') {
        $node = $node->firstChild;
        my $property = ogc_filter($node->firstChild);
        $node = $node->nextSibling;
        return '('.$property.' >= '.ogc_filter($node).' AND '.$property.'<='.ogc_filter($node->nextSibling).')';
    } elsif ($node->nodeName eq 'ogc:PropertyIsLike') {
        $node = $node->firstChild;
        return '('.ogc_filter($node).' ~ '.ogc_filter($node->nextSibling).')';
    } elsif ($node->nodeName eq 'ogc:PropertyIsNull') {
        return '('.ogc_filter($node->firstChild).' ISNULL)';
    } elsif ($node->nodeName eq 'ogc:And') {
        $node = $node->firstChild;
        my $p = '('.ogc_filter($node);
        while ($node = $node->nextSibling) {
            $p .= ' AND '.ogc_filter($node);
        }
        return $p.')';
    } elsif ($node->nodeName eq 'ogc:Or') {
        $node = $node->firstChild;
        my $p = '('.ogc_filter($node);
        while ($node = $node->nextSibling) {
            $p .= ' OR '.ogc_filter($node);
        }
        return $p.')';
    } elsif ($node->nodeName eq 'ogc:Not') {
        return '(NOT '.ogc_filter($node->firstChild).')';
    } elsif ($node->nodeName eq 'gml:Envelope') {
        my($srid) = $node->{srsName} =~ /EPSG:(\d+)/ if exists $node->{srsName};
        $node = $node->firstChild;
        my $lc = $node->firstChild->data; # gml:lowerCorner
        $lc =~ s/ /,/;
        $node = $node->nextSibling;
        my $uc = $node->firstChild->data; # gml:upperCorner
        $uc =~ s/ /,/;
        return "ST_MakeEnvelope($lc,$uc,$srid)" if $srid;
        return "ST_MakeEnvelope($lc,$uc)";
    } elsif ($node->nodeName eq 'gml:Box') {
        my $env = $node->firstChild->firstChild->data;
        $env =~ s/ /,/;
        return "ST_MakeEnvelope($end)";
    } elsif ($node->nodeName eq 'ogc:BBOX') {
        $node = $node->firstChild;
        $node = $node->nextSibling if $node->nodeName eq 'ogc:PropertyName';
        return '(GeometryColumn && '.ogc_filter($node).')'; # GeometryColumn to be replaced by something real later
    } elsif ($node->nodeName eq 'ogc:Filter') {
        return ogc_filter($node->firstChild);
    } 
}

# convert OGC Transaction XML to SQL
sub transaction_sql {
    my($request, $type_callback) = @_;
    my %dbisql;
    for my $node (@{$request->{inserts}}) {
        my $typeName = $node->nodeName;
        $typeName =~ s/^wfs://;
        $typeName =~ s/^feature://;
        my $type = $type_callback->($typeName);
        croak "No such feature type: $insert_type" unless $type;
        croak "The datasource is not PostGIS" unless $type->{Table};
        my @cols;
        my @vals;
        for ($field = $node->firstChild; $field; $field = $field->nextSibling) {
            my $fieldName = $field->nodeName;
            $fieldName =~ s/^\w+://; # remove namespace
            my $val;
            if ($fieldName eq 'geometryProperty' or $fieldName eq 'null') {
                $val = GML2WKT($field->firstChild);
                $fieldName = $type->{GeometryColumn};
            }  else {            
                next unless exists $type->{Schema}{$fieldName};
                $val = $field->firstChild->data;
            }
            push @cols, '"'.$fieldName.'"';
            push @vals, "'".$val."'";
        }
        my $dbi = $type->{dbi};
        $dbisql{$dbi} .= "INSERT INTO $type->{Table} (".join(',',@cols).") VALUES (".join(',',@vals).");\n";
    }
    for my $dbi (keys %dbisql) {
        $dbisql{$dbi} = "BEGIN;\n".$dbisql{$dbi}."END;\n";
    }
    return \%dbisql;
}

sub GML2WKT {
    my($geom) = @_;
    my $wkt;
    if ($geom->nodeName eq 'gml:Point') {
        my $pos = $geom->firstChild->firstChild->data;
        $wkt = "POINT ($pos)";
    } elsif ($geom->nodeName eq 'gml:LineString') {
        my @tmp = split / /, $geom->firstChild->firstChild->data;
        my @pos;
        for (my $i = 0; $i < @tmp; $i+=2) {
            push @pos, $tmp[$i].' '.$tmp[$i+1];
        }
        $wkt = "LINESTRING (".join(', ',@pos).")";
    } elsif ($geom->nodeName eq 'gml:Polygon') {
        my @tmp = split / /, $geom->firstChild->firstChild->firstChild->data;
        my @pos;
        for (my $i = 0; $i < @tmp; $i+=2) {
            push @pos, $tmp[$i].' '.$tmp[$i+1];
        }
        $wkt = "POLYGON ((".join(', ',@pos)."))";
    } 
    #print STDERR "$wkt\n";
    my($srid) = $geom->{srsName} =~ /EPSG:(\d+)/;
    return "ST_GeometryFromText('$wkt',$srid)";
}

1;
