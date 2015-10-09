#!/usr/bin/perl -w

use utf8;
use strict;
use IO::Handle;
use Carp;
use Encode;
use CGI;
use lib '/var/www/lib';
require WxS;
WxS->import(':all');

binmode STDERR, ":utf8";
binmode STDOUT, ":utf8";

my $debug = 0;
my $config;
my %names = ();
my $q = CGI->new;
my $my_url = $q->url(-path_info=>1);

# http://www.microimages.com/documentation/TechGuides/78googleMapsStruc.pdf
# pixel size at equator in meters
my @resolutions_3857 = (156543.03390000000945292413,
                        78271.51695000000472646207,
                        39135.75847500000236323103,
                        19567.87923750000118161552,
                        9783.93961875000059080776,
                        4891.96980937500029540388,
                        2445.98490468750014770194,
                        1222.99245234375007385097,
                        611.49622617187503692548,
                        305.74811308593751846274,
                        152.87405654296875923137,
                        76.43702827148437961569,
                        38.21851413574218980784,
                        19.10925706787109490392,
                        9.55462853393554745196,
                        4.77731426696777372598,
                        2.38865713348388686299,
                        1.19432856674194343150,
                        0.59716428337097171575,
                        0.29858214168548585787);
my $bounding_box_3857 = {SRS => 'EPSG:3857', 
                         minx => -20037508.34, 
                         miny => -20037508.34, 
                         maxx => 20037508.34, 
                         maxy => 20037508.34};

if ($ENV{REQUEST_METHOD} eq 'OPTIONS') {
    print $q->header(
	-type=>"text/plain", 
	-Access_Control_Allow_Origin=>'*',
	-Access_Control_Allow_Methods=>"GET,POST",
	-Access_Control_Allow_Headers=>"origin,x-requested-with,content-type",
	-Access_Control_Max_Age=>60*60*24
	);
} else {
    eval {
        $config = WxS::config();
        page();
    };
    error($q, $@, ()) if $@;
}

sub page {
    
    for ($q->param) {
        croak "Parameter ".uc($_)." given more than once.#" if exists $names{uc($_)};
        $names{uc($_)} = $_;
        print STDERR "$_ => ".$q->param($_)."\n" if $debug > 1;
    }
    my $request = $q->param($names{REQUEST}) || '';

    if ($request eq 'GetCapabilities' or $request eq 'capabilities') {
        GetCapabilities();
        return;
    }

    my($set, $zxy, $ext);
    my $layers = $q->param($names{LAYERS});
    ($layers, $zxy, $ext) = $my_url =~ /wmts\.pl\/(\w+)\/(.*?)\.(\w+)$/ 
        unless $layers;
    for my $s (@{$config->{TileSets}}) {
        $set = $s, last if $s->{Layers} eq $layers;
    }
    $ext = $set->{ext} unless $ext;

    if ($request eq 'GetMap') {
        my $bbox = $q->param($names{BBOX});
        my @bbox = split /,/, $bbox; # minx, miny, maxx, maxy
        my $units_per_pixel = ($bbox[2]-$bbox[0])/256;
        my $z;
        my $res;
        for my $r (@resolutions_3857) {
            if (abs($r - $units_per_pixel) < 0.1) {
                $res = $r;
                $z = $i;
                last;
            }
        }
        my $rows = 2**$z;

        #my $wh = ($bounding_box_3857->{maxx} - $bounding_box_3857->{minx})/$rows;
        #my $x = ($bbox[2]+$bbox[0])/2 - $bounding_box_3857->{minx};
        #my $y = ($bbox[3]+$bbox[1])/2 - $bounding_box_3857->{miny};
        #$x = int($x / $wh);
        #$y = int($y / $wh);

        my $x = int(($bbox[0] - $bounding_box_3857->{minx}) / ($res * 256) + 0.5);
        my $y = int(($bbox[1] - $bounding_box_3857->{miny}) / ($res * 256) + 0.5);
        $zxy = "$z/$x/$y";
    }

    ServeFile("$set->{path}/$zxy.$ext", $ext);
}

sub ServeFile {
    my($file, $ext) = @_;
    if ($ext eq 'html' or $ext eq 'xml') {
        print 
            $q->header( -type => "text/$ext",
                        -charset=>'utf-8',
                        -Access_Control_Allow_Origin=>'*' );
    } else {
        $file = $config->{blank} unless -r $file;
        my $length = (stat($file))[7];       
        print 
            $q->header( -type => "image/$ext",
                        -expires => '+1y',
                        -Content_length => $length,
                        -Access_Control_Allow_Origin=>'*' );
    }
    if (-r $file) {
        binmode STDOUT;
        open (FH,'<', $file);
        my $buffer = "";
        while (read(FH, $buffer, 10240)) {
            print $buffer;
        }
        close(FH);
    }
}

sub GetCapabilities {
    my($out, $var);
    open($out,'>', \$var);
    select $out;
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n");
    xml_element('WMT_MS_Capabilities', 
                { version => '1.1.1' }, 
                '<');
    xml_element(Service => [[Name => 'OGC:WMS'],
                            ['Title'],
                            [OnlineResource => {'xmlns:xlink' => "http://www.w3.org/1999/xlink",
                                                'xlink:href' => $my_url}]]);
    xml_element(Capability => '<');
    xml_element(Request => [[GetCapabilities => [[Format => 'application/vnd.ogc.wms_xml'],
                                                 [DCPType => 
                                                  [HTTP => 
                                                   [Get => 
                                                    [OnlineResource => 
                                                     {'xmlns:xlink' => "http://www.w3.org/1999/xlink",
                                                      'xlink:href' => $my_url}]]]]]],
                            [GetMap => [[Format => 'image/png'],
                                        [DCPType => 
                                         [HTTP => 
                                          [Get => 
                                           [OnlineResource => 
                                            {'xmlns:xlink' => "http://www.w3.org/1999/xlink",
                                             'xlink:href' => $my_url}]]]]]]
                ]);
    xml_element(Exception => [Format => 'text/plain']);
    
    for my $set (@{$config->{TileSets}}) {
        my($i0,$i1) = split /\.\./, $set->{Resolutions};
        my @resolutions = @resolutions_3857[$i0..$i1];
        xml_element(VendorSpecificCapabilities => [TileSet => [[SRS => $set->{SRS}],
                                                               [BoundingBox => $set->{BoundingBox}],
                                                               [Resolutions => "@resolutions"],
                                                               [Width => $set->{Width} || 256],
                                                               [Height => $set->{Height} || 256],
                                                               [Format => $set->{Format}],
                                                               [Layers => $set->{Layers}],
                                                               [Styles => undef]]]);
    }

    xml_element(UserDefinedSymbolization => 
                {SupportSLD => 0, UserLayer => 0, UserStyle => 0, RemoteWFS => 0});

    for my $set (@{$config->{TileSets}}) {
        xml_element(Layer => [[Title => 'TileCache Layers'],
                              [Layer => {queryable => 0, opaque => 0, cascaded => 1}, 
                               [[Name => $set->{Layers}],
                                [Title => $set->{Layers}],
                                [SRS => $set->{SRS}],
                                [BoundingBox => $set->{BoundingBox}]]]
                    ]);
    }

    xml_element(Capability => '/>');
    xml_element('/WMT_MS_Capabilities', '>');
    select(STDOUT);
    close $out;
    print $q->header( -Content_length => length(Encode::encode_utf8($var)), 
                      -type => $config->{MIME},
                      -charset => 'utf-8',
                      -expires=>'+1s',
                      -Access_Control_Allow_Origin => $config->{CORS} ), $var;
}
