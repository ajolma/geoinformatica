package Geo::Vector::Layer;
# @brief A subclass of Gtk2::Ex::Geo::Layer

=pod

=head1 NAME

Geo::Vector::Layer - A geospatial vector layer class for Gtk2::Ex::Geo

=cut

use strict;
use warnings;
use UNIVERSAL qw(isa);
use POSIX;
POSIX::setlocale( &POSIX::LC_NUMERIC, "C" ); # http://www.remotesensing.org/gdal/faq.html nr. 11
use Carp;
use Encode;
use File::Spec;
use Glib qw/TRUE FALSE/;
use Gtk2;
use Gtk2::Ex::Geo::Layer qw/:all/;
use Geo::OGC::Geometry;
use Geo::Raster::Layer qw /:all/;
use Geo::Vector::Layer::Dialogs;
use Geo::Vector::Layer::Dialogs::New;
use Geo::Vector::Layer::Dialogs::Copy;
use Geo::Vector::Layer::Dialogs::Open;
use Geo::Vector::Layer::Dialogs::Rasterize;
use Geo::Vector::Layer::Dialogs::Vertices;
use Geo::Vector::Layer::Dialogs::Features;
use Geo::Vector::Layer::Dialogs::FeatureCollection;
use Geo::Vector::Layer::Dialogs::Properties;

BEGIN {
    if ($^O eq 'MSWin32') {
	require Win32::OLE;
	import Win32::OLE qw(in);
    }
}

use vars qw/%RENDER_AS2INDEX %INDEX2RENDER_AS $BORDER_COLOR/;

require Exporter;
our @ISA = qw(Exporter Geo::Vector Gtk2::Ex::Geo::Layer);
our @EXPORT = qw();
our %EXPORT_TAGS = ( 'all' => [ qw(%RENDER_AS2INDEX %INDEX2RENDER_AS $BORDER_COLOR) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our $VERSION = 0.03;

%RENDER_AS2INDEX = (Native => 0, Points => 1, Lines => 2, Polygons => 3);
for (keys %RENDER_AS2INDEX) {
    $INDEX2RENDER_AS{$RENDER_AS2INDEX{$_}} = $_;
}

# default values for new objects:

$BORDER_COLOR = [255, 255, 255];

## @ignore
sub registration {
    my $dialogs = Geo::Vector::Layer::Dialogs->new();
    my $commands = {
	new => {
	    nr => 1,
	    text => 'New vector',
	    tip => 'Create a new OGR layer',
	    pos => 0,
	    sub => sub {
		my(undef, $gui) = @_;
		Geo::Vector::Layer::Dialogs::New::open($gui);
	    }
	},
	open => {
	    nr => 2,
	    text => 'Open vector',
	    tip => 'Add a new vector layer from a data source.',
	    pos => 1,
	    sub => sub {
		my(undef, $gui) = @_;
		$gui->{history}->enter(''); # open_vector dialog uses the same history
		Geo::Vector::Layer::Dialogs::Open::open($gui);
	    }
	}
    };
    return { dialogs => $dialogs, commands => $commands };
}

## @cmethod $upgrade($object)
#
# @brief Upgrade (strictly) Geo::Vector objects to Geo::Vector::Layers
sub upgrade {
    my($object) = @_;
    if (isa($object, 'Geo::Vector') and !isa($object, 'Geo::Vector::Layer')) {
	bless($object, 'Geo::Vector::Layer');
	$object->defaults();
	return 1;
    }
    return 0;
}

## @ignore
sub new {
    my($package, %params) = @_;
    my $self = Geo::Vector::new($package, %params);
    Gtk2::Ex::Geo::Layer::new($package, self => $self, %params);
    return $self;
}

## @ignore
sub DESTROY {
}

## @ignore
sub defaults {
    my($self, %params) = @_;
    $self->name($self->{OGR}->{Layer}->GetName()) if $self->{OGR}->{Layer};
    my $gt = $self->geometry_type;
    @{$self->{BORDER_COLOR}} = @$BORDER_COLOR if $gt and $gt =~ /Polygon/;
    $self->SUPER::defaults(%params);
    $self->{RENDER_AS} = 'Native' unless exists $self->{RENDER_AS};
    $self->{RENDER_AS} = $params{render_as} if exists $params{render_as};
    $self->{LINE_WIDTH} = 1;
}

## @method $type()
#
# @brief Returns the type of the layer.
# @return A string ('V'== vector layer, ' T' == feature layer, ' L'== ogr layer,
# ' U' == update layer) representing the type of the layer.
sub type {
    my($self, $format) = @_;
    my $type = ($format and $format eq 'long') ? 'Vector layer' : 'V';
    if ( $self->{features} ) {
	$type .= ($format and $format eq 'long') ? ' features' : ' T';
    }
    elsif ( $self->{OGR}->{Layer} ) {
	$type = ($format and $format eq 'long') ? 'OGR '.$type : 'OGR';
	}
    $type .= ($format and $format eq 'long') ? ', updateable' : ' U' if $self->{update};
    return $type;
}

## @ignore
# convert the values of the params hash from OGC to OGR
sub features {
    my($self, %params) = @_;
    my %new_params;
    for my $key (keys %params) {
	if (isa($params{$key}, 'Geo::OGC::Geometry')) {
	    $new_params{$key} = Geo::OGR::CreateGeometryFromWkt($params{$key}->AsText);
	} else {
	    $new_params{$key} = $params{$key};
	}
    }
    return Geo::Vector::features($self, %new_params);
}

## @method void properties_dialog($gui)
#
# @brief If the layer is an ogr layer then the method opens trough the given GUI
# a dialog with layer's properties.
#
# The method calls for example the Gtk2::Ex::Geo::OGRDialog of the
# Gtk2::Ex::Geo::Glue.
# @param[in] gui A reference to a GUI object, like for example Gtk2::Ex::Geo::Glue.
# @todo Support for feature layer.
sub open_properties_dialog {
    my ( $self, $gui ) = @_;
    if ( $self->{features} ) {
	$gui->message("not yet implemented");
    }
    elsif ( $self->{OGR}->{Layer} ) {
	Geo::Vector::Layer::Dialogs::Properties::open($self, $gui);
    }
    else {
	$gui->message("no data in this layer");
    }
}

## @ignore
sub menu_items {
    my($self) = @_;
    my @items;
    if ( $self->{features} ) {
	push @items, ( 
	    '_Features...' => sub {
		my($self, $gui) = @{$_[1]};
		Geo::Vector::Layer::Dialogs::FeatureCollection::open($self, $gui);
	    });	
    } elsif ( $self->{OGR}->{Layer} ) {
	push @items, ( 
	    'C_opy...' => sub {
		my($self, $gui) = @{$_[1]};
		Geo::Vector::Layer::Dialogs::Copy::open($self, $gui);
	    },
	    '_Features...' => sub {
		my($self, $gui) = @{$_[1]};
		Geo::Vector::Layer::Dialogs::Features::open($self, $gui);
	    },
	    '_Vertices...' => sub {
		open_vertices_dialog(@{$_[1]});
	    },
	    'R_asterize...' => sub {
		my($self, $gui) = @{$_[1]};
		Geo::Vector::Layer::Dialogs::Rasterize::open($self, $gui);
	    } );
    }
    push @items, ( 1 => 0 );
    push @items, $self->SUPER::menu_items();
    return @items;
}

## @ignore
sub open_features_dialog {
    my($self) = @_;
    if ( $self->{features} ) {
	Geo::Vector::Layer::Dialogs::FeatureCollection::open(@_);
    }
    elsif ( $self->{OGR}->{Layer} ) {
	Geo::Vector::Layer::Dialogs::Features::open(@_);
    }
}

## @ignore
sub open_vertices_dialog {
    Geo::Vector::Layer::Dialogs::Vertices::open(@_);
}

## @ignore
sub open_rasterize_dialog {
}

## @method $render_as($render_as)
#
# @brief Get or set the rendering mode.
# @param[in] render_as (optional) Mode of how to render the layers vector data.
# Has to be one of the modes given by render_as_modes().
# @return The current rendering mode as a string.
sub render_as {
    my ( $self, $render_as ) = @_;
    if ( defined $render_as ) {
	croak "Unknown rendering mode: $render_as"
	    unless defined $Geo::Vector::RENDER_AS{$render_as};
	$self->{RENDER_AS} = $render_as;
    }
    else {
	return $self->{RENDER_AS};
    }
}

## @method @supported_palette_types()
#
# @brief Returns a list of supported palette types.
# @return A list (strings) of supported palette types.
sub supported_palette_types {
    my ($self)  = @_;
    my $schema  = $self->schema;
    my $has_int = 0;
    for my $field ( $schema->fields ) {
	$has_int = 1, next if $field->{Type} eq 'Integer';
    }
    if ($has_int) {
	return (
	    'Single color',
	    'Grayscale',
	    'Rainbow',
	    'Color table',
	    'Color bins'
	    );
    }
    else {
	return ( 'Single color', 'Grayscale', 'Rainbow', 'Color bins' );
    }
}

## @method @supported_symbol_types()
#
# @brief Returns a list of supported symbol types.
# @return A list (strings) of supported symbol types.
sub supported_symbol_types {
    my ($self) = @_;
    
    # symbol if rendered as points or as a point (centroid of a polygon)
    return ( 'No symbol', 'Square', 'Dot', 'Cross', 'Wind rose' );
    my $t = $self->geometry_type;
    if ( $t =~ /Point/ ) {
	return ( 'Square', 'Dot', 'Cross' );
    }
    elsif ( $t =~ /Polygon/ ) {
	return ( 'No symbol', 'Square', 'Dot', 'Cross' );
    }
    else {
	return ();
    }
}

## @ignore
sub ohoh {
    for my $x (@_) {
	return $x if defined $x;
    }
}

## @method void render($pb)
#
# @brief Renders the vector layer onto a memory image.
#
# @param[in,out] pb Pixel buffer into which the vector layer is rendered.
# @note The layer has to be visible while using the method!
sub render {
    my ( $self, $pb, $cr, $overlay, $viewport ) = @_;
    return if !$self->visible();
    
    $self->{PALETTE_VALUE} = $PALETTE_TYPE{$self->{PALETTE_TYPE}};
    $self->{SYMBOL_VALUE} = $SYMBOL_TYPE{$self->{SYMBOL_TYPE}};
    if ($self->{SYMBOL_FIELD} eq 'Fixed size') {
		$self->{SYMBOL_SCALE_MIN} = 0; # similar to grayscale scale
		$self->{SYMBOL_SCALE_MAX} = 0;
    }
    
    if ( $self->{features} ) {
	
	$self->{COLOR_FIELD_VALUE} = ohoh(Geo::Vector::field_index($self->{COLOR_FIELD}),
					  Geo::Vector::undefined_field_index());
	$self->{SYMBOL_FIELD_VALUE} = ohoh(Geo::Vector::field_index($self->{SYMBOL_FIELD}),
					   Geo::Vector::undefined_field_index());
	$self->{RENDER_AS}       = 'Native';
	$self->{RENDER_AS_VALUE} = $Geo::Vector::RENDER_AS{ $self->{RENDER_AS} };
	
	my $layer = Geo::Vector::ral_visual_feature_table_create( $self, $self->{features} );
	if ($layer) {
	    Geo::Vector::ral_visual_feature_table_render( $layer, $pb ) if $pb;
	    Geo::Vector::ral_visual_feature_table_destroy($layer);
	}

	if ( 0 and @{$self->{BORDER_COLOR}} ) { # not yet functional, waiting to exploit Geo::Vector::Feature...
	    
	    my @color = @{$self->{BORDER_COLOR}};
	    push @color, 255;
	    my $layer = Geo::Vector::ral_visual_feature_table_create( $self, $self->{features} );
	    if ($layer) {
		Geo::Vector::ral_visual_feature_table_render( $layer, $pb ) if $pb;
		Geo::Vector::ral_visual_feature_table_destroy($layer);
	    }
	}
	
    }
    elsif ( $self->{OGR}->{Layer} ) {
	
	my $schema = $self->schema();
	$self->{COLOR_FIELD_VALUE} = ohoh(Geo::Vector::field_index($self->{COLOR_FIELD}),
					  $schema->field_index($self->{COLOR_FIELD}),
					  Geo::Vector::undefined_field_index());
	$self->{SYMBOL_FIELD_VALUE} = ohoh(Geo::Vector::field_index($self->{SYMBOL_FIELD}),
					   $schema->field_index($self->{SYMBOL_FIELD}),
					   Geo::Vector::undefined_field_index());
	
	$self->{RENDER_AS}       = 'Native' unless defined $self->{RENDER_AS};
	$self->{RENDER_AS_VALUE} = $Geo::Vector::RENDER_AS{ $self->{RENDER_AS} };
	
        if ( not $self->{RENDERER} ) {
            my $layer = Geo::Vector::ral_visual_layer_create( $self, Geo::Vector::OGRLayerH($self->{OGR}->{Layer}) );
            if ($layer) {
                Geo::Vector::ral_visual_layer_render( $layer, $pb ) if $pb;
                Geo::Vector::ral_visual_layer_destroy($layer);
            }
        }
	
	if ( @{$self->{BORDER_COLOR}} and ($self->{RENDER_AS} eq 'Native' or $self->{RENDER_AS} eq 'Polygons')) {
	    
	    my @color = @{$self->{BORDER_COLOR}};
	    push @color, 255;
	    my $border = Geo::Vector::Layer->new( alpha => $self->{ALPHA}, single_color => \@color );
	    $border->{RENDER_AS_VALUE} = $Geo::Vector::RENDER_AS{Lines};
	    my $layer = Geo::Vector::ral_visual_layer_create( $border, Geo::Vector::OGRLayerH($self->{OGR}->{Layer}) );
	    if ($layer) {
		Geo::Vector::ral_visual_layer_render( $layer, $pb ) if $pb;
		Geo::Vector::ral_visual_layer_destroy($layer);
	    }
	}

	my $labeling = $self->labeling;
	if ($labeling->{field} ne 'No Labels') {

	    my @label_color = @{$labeling->{color}};
	    $label_color[3] = int($self->{ALPHA}*$label_color[3]/255);
	    for (@label_color) {
		$_ /= 255;
	    }

	    my $wc = -0.5;
	    my $hc = -0.5;
	    my $dw = 0;
	    for ($labeling->{placement}) {
		$hc = -1 - $self->{LABEL_VERT_NUDGE} if /Top/;
		$hc = $self->{LABEL_VERT_NUDGE} if /Bottom/;
		if (/left/) {$wc = -1; $dw = -1*$self->{LABEL_HORIZ_NUDGE_LEFT}};
		if (/right/) {$wc = 0; $dw = $self->{LABEL_HORIZ_NUDGE_RIGHT}};
	    }
	    my $font_desc = Gtk2::Pango::FontDescription->from_string($labeling->{font});
	    
	    $self->{OGR}->{Layer}->SetSpatialFilterRect(@$viewport);
	    $self->{OGR}->{Layer}->ResetReading();

            my %geohash;
	    my $f;

            # later this should be as in libral, color may be a function
            my @color = @{$self->{SINGLE_COLOR}};
            $label_color[3] = int($self->{ALPHA}*$color[3]/255);
            for (@color) {
                $_ /= 255;
            }

	    while ($f = $self->{OGR}->{Layer}->GetNextFeature()) {
	
		my $geometry = $f->GetGeometryRef();

		my @placements = label_placement($geometry, $overlay->{pixel_size}, @$viewport, $f->GetFID);
		
		for (@placements) {

		    my ($size, @point) = @$_;
		
		    last unless (@point and defined($point[0]) and defined($point[1]));

		    next if ($labeling->{min_size} > 0 and $size < $labeling->{min_size});

		    next if 
			$point[0] < $viewport->[0] or 
			$point[0] > $viewport->[2] or
			$point[1] < $viewport->[1] or
			$point[1] > $viewport->[3];
		    
		    my @pixel = $overlay->point2pixmap_pixel(@point);
                    if ($self->{INCREMENTAL_LABELS}) {
                        # this is fast but not very good
                        my $geokey = int($pixel[0]/120) .'-'. int($pixel[1]/50);
                        next if $geohash{$geokey};
                        $geohash{$geokey} = 1;
                    }

                    if ($self->{RENDERER} eq 'Cairo') {
                        my $points = $geometry->Points;
                        # now only for points
                        my @p = $overlay->point2pixmap_pixel(@{$points->[0]});
                        my $d = $self->{SYMBOL_SIZE}/2;
                        $cr->move_to($p[0]-$d, $p[1]);
                        $cr->line_to($p[0]+$d, $p[1]);
                        $cr->move_to($p[0], $p[1]-$d);
                        $cr->line_to($p[0], $p[1]+$d);
                        $cr->set_line_width($self->{LINE_WIDTH});
                        $cr->set_source_rgba(@color);
                        $cr->stroke();
                    }
		    
		    my $str = Geo::Vector::feature_attribute($f, $labeling->{field});
		    next unless defined $str or $str eq '';
		    $str = decode($self->{encoding}, $str) if $self->{encoding};
		    
		    my $layout = Gtk2::Pango::Cairo::create_layout($cr);
		    $layout->set_font_description($font_desc);    
		    $layout->set_text($str);
		    my($width, $height) = $layout->get_pixel_size;
		    $cr->move_to($pixel[0]+$wc*$width+$dw, $pixel[1]+$hc*$height);
                    $cr->set_source_rgba(@label_color);
		    Gtk2::Pango::Cairo::show_layout($cr, $layout);

		}

	    }
	}
    }
}

##@ignore
sub piece_of_line_string {
    my($geom, $i0, $minx, $miny, $maxx, $maxy) = @_;
    my($x, $y);
    while(1) {
	$x = $geom->GetX($i0);
	$y = $geom->GetY($i0);
	last if $x >= $minx and $y >= $miny and $x <= $maxx and $y <= $maxy;
	$i0++;
	return if $i0 >= $geom->GetPointCount-1;
    }
    my $l = 0;
    my $i1 = $i0+1;
    my $x0 = $x;
    my $y0 = $y;
    while (1) {
	$x = $geom->GetX($i1);
	$y = $geom->GetY($i1);
	$l += sqrt(($x0-$x)*($x0-$x)+($y0-$y)*($y0-$y));
	last if $x < $minx or $y < $miny or $x > $maxx or $y > $maxy;
	$i1++;
	last if $i1 >= $geom->GetPointCount;
	$x0 = $x;
	$y0 = $y;
    }
    return ($i0, $i1, $l);
}

##@ignore
sub label_placement {
    my($geom, $scale, $minx, $miny, $maxx, $maxy, $fid) = @_;
    my $type = $geom->GetGeometryType & ~0x80000000;
    if ($type == $Geo::OGR::wkbPoint) {
	return ([0, $geom->GetX(0), $geom->GetY(0)]);
    } 
    elsif ($type == $Geo::OGR::wkbLineString) {

	my $i0 = 0;
	my $i1;
	my $len;
	my @placements;
	while (1) {
	    ($i0, $i1, $len) = piece_of_line_string($geom, $i0, $minx, $miny, $maxx, $maxy);
	    last unless defined $i0;
	    # a label between i0 and i1

	    my $h = $len/2;
	    my $x0 = $geom->GetX($i0);
	    my $y0 = $geom->GetY($i0);
	    if ($len == 0 or $scale == 0) {
		push @placements, [0, $x0, $y0];
	    } 
	    else {
		for ($i0+1..$i1) {
		    my $x1 = $geom->GetX($_);
		    my $y1 = $geom->GetY($_);
		    my $l = sqrt(($x1-$x0)*($x1-$x0)+($y1-$y0)*($y1-$y0));
		    if ($h > $l) {
			$h -= $l;
		    } else {
			$x0 += $l == 0 ? 0 : ($x1-$x0)*$h/$l;
			$y0 += $l == 0 ? 0 : ($y1-$y0)*$h/$l;
		       
			push @placements, [$len/$scale, $x0, $y0];
			last;
		    }
		    $x0 = $x1;
		    $y0 = $y1;
		}
	    }

	    last if $i1 >= $geom->GetPointCount;
	    $i0 = $i1;
	}
	return @placements;
	
    } 
    elsif ($type == $Geo::OGR::wkbPolygon) {
	my $c = $geom->Centroid;
	return ([$geom->GetArea/($scale*$scale), $c->GetX, $c->GetY]);
    } 
    elsif ($type == $Geo::OGR::wkbMultiLineString or $type == $Geo::OGR::wkbMultiLineString25D) {
	my $len = 0;
	my $longest = -1;
	for my $i (0..$geom->GetGeometryCount()-1) {
	    my $a = line_string_length($geom->GetGeometryRef($i));
	    if ($a > $len) {
		$len = $a;
		$longest = $i;
	    }
	}
	return label_placement($geom->GetGeometryRef($longest), $scale) if $longest >= 0;
    } 
    elsif ($type == $Geo::OGR::wkbMultiPolygon or $type == $Geo::OGR::wkbGeometryCollection) {
	my $size = 0;
	my $largest = -1;
	for my $i (0..$geom->GetGeometryCount()-1) {
	    my $a = $geom->GetGeometryRef($i)->GetArea;
	    if ($a > $size) {
		$size = $a;
		$largest = $i;
	    }
	}
	return label_placement($geom->GetGeometryRef($largest), $scale) if $largest >= 0;
    } else {
	my $t = Geo::OGR::Geometry::TYPE_INT2STRING{$type};
	print STDERR "label placement not defined for geometry type $t\n";
	return ();
    }
    print STDERR "couldn't compute label placement\n";
    return ();
}

##@ignore
sub line_string_length {
    my $line = shift;
    my $l = 0;
    my $x0 = $line->GetX(0);
    my $y0 = $line->GetY(0);
    for (1..$line->GetPointCount-1) {
	my $x1 = $line->GetX($_);
	my $y1 = $line->GetY($_);
	$l += sqrt(($x1-$x0)*($x1-$x0)+($y1-$y0)*($y1-$y0));
	$x0 = $x1;
	$y0 = $y1;
    }
    return $l;
}

## @ignore
sub render_selection {
    my($self, $gc, $overlay) = @_;

    my $features = $self->selected_features();
    
    for my $f (@$features) {
	
	next unless $f; # should not happen
	
	my $geom = $f->GetGeometryRef();
	next unless $geom;
	
	# this could be a bit faster without conversion
	$overlay->render_geometry($gc, Geo::OGC::Geometry->new(Text => $geom->ExportToWkt));
	
    }
}

# this piece should probably go into GDAL:
package Geo::OGR::Driver;

use vars qw /%FormatNames/;

%FormatNames = (
    'AVCBin' => 'Arc/Info Binary Coverage',
    'AVCE00' => 'Arc/Info .E00 (ASCII) Coverage',
    'BNA' => 'Atlas BNA',
    'DXF' => 'AutoCAD DXF',
    'CSV' => 'Comma Separated Value (.csv)',
    'DODS' => 'DODS/OPeNDAP',
    'PGeo' => 'ESRI Personal GeoDatabase',
    'SDE' => 'ESRI ArcSDE',
    'ESRI Shapefile' => 'ESRI Shapefile',
    'FMEObjects Gateway' => 'FMEObjects Gateway',
    'GeoJSON' => 'GeoJSON',
    'Geoconcept' => 'Geoconcept Export',
    'GeoRSS' => 'GeoRSS',
    'GML' => 'GML',
    'GMT' => 'GMT',
    'GPX' => 'GPX',
    'GRASS' => 'GRASS',
    'GPSTrackMaker' => 'GPSTrackMaker (.gtm, .gtz)',
    'IDB' => 'Informix DataBlade',
    'Interlis 1' => 'INTERLIS',
    'Interlis 2' => 'INTERLIS',
    'INGRES' => 'INGRES',
    'KML' => 'KML',
    'MapInfo File' => 'Mapinfo File',
    'DGN' => 'Microstation DGN',
    'Memory' => 'Memory',
    'MySQL' => 'MySQL',
    'OCI' => 'Oracle Spatial',
    'ODBC' => 'ODBC',
    'OGDI' => 'OGDI Vectors',
    'PCIDSK' => 'PCI Geomatics Database File',
    'PostgreSQL' => 'PostgreSQL',
    'REC' => 'EPIInfo .REC',
    'S57' => 'S-57 (ENC)',
    'SDTS' => 'SDTS',
    'SQLite' => 'SQLite/SpatiaLite',
    'UK. NTF' => 'UK .NTF',
    'TIGER' => 'U.S. Census TIGER/Line',
    'VFK' => 'VFK data',
    'VRT' => 'VRT - Virtual Datasource',
    'XPLANE' => 'X-Plane/Flightgear aeronautical data',
    );

## @ignore
sub DataSourceTemplate {
    my($self) = @_;
    my $n = $self->GetName;
    # return simplified BNF and tell more in help string
    if ($n eq 'DODS') {
	return ('DODS:<URL>','');
    } elsif ($n eq 'SDE') {
	return ('SDE:<server>,<instance>,<database>,<username>,<password>,<layer>[,<parentversion>][,<childversion>]','');
    } elsif ($n eq 'GeoJSON') {
	return ('<URL>','');
    } elsif ($n eq 'IDB') {
	return ('IDB:dbname=<database> server=<host> user=<username> pass=<password> table=<tablename>','');
    } elsif ($n eq 'INGRES') {
	return ('@driver=ingres,dbname=<database>[,userid=<username>][,password=<password>][,tables=<tables>]','');
    } elsif ($n eq 'MySQL') {
	return ('MYSQL:<database>[,user=<username>][,password=<password>][,host=<host>][,port=<port>][,tables=<tables>]','');
    } elsif ($n eq 'OCI') {
	return ('OCI:<username>/<password>@<database>[:<tables>]','');
    } elsif ($n eq 'PostgreSQL') {
	return ('PG:dbname=<database>[ user=<username>][ password=<password>][ host=<host>][ port=<port>][ tables=<tables>][ schemas=<schemas>][ active_schema=<active_schema>]',
		"tables is a comma separated list of [schema.]table[(geometry_column)]");
    } else {
	return ('<filename>','');
    }
}

## @ignore
sub FormatName {
    my($self) = @_;
    my $n = $self->GetName;
    return $FormatNames{$n};
}

1;
