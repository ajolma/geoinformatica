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
use Geo::Vector::Layer::Dialogs;

BEGIN {
    if ($^O eq 'MSWin32') {
	require Win32::OLE;
	import Win32::OLE qw(in);
    }
}

use vars qw/%RENDER_AS2INDEX %INDEX2RENDER_AS $oneself $dialog_folder
            $BORDER_COLOR/;

require Exporter;
our @ISA = qw(Exporter Geo::Vector Gtk2::Ex::Geo::Layer);
our @EXPORT = qw();
our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our $VERSION = 0.03;

%RENDER_AS2INDEX = (Native => 0, Points => 1, Lines => 2, Polygons => 3);
for (keys %RENDER_AS2INDEX) {
    $INDEX2RENDER_AS{$RENDER_AS2INDEX{$_}} = $_;
}
$oneself = {};

# default values for new objects:

$BORDER_COLOR = [255, 255, 255];

sub registration {
    my $dialogs = Geo::Vector::Layer::Dialogs->new();
    my $commands = {
	open => {
	    nr => 1,
	    text => 'Open vector',
	    tip => 'Add a new vector layer.',
	    pos => 0,
	    sub => sub {
		my(undef, $gui) = @_;
		$gui->{history}->enter(''); # open_vector dialog uses the same history
		open_open_vector_dialog($gui);
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
    if (ref($object) eq 'Geo::Vector') {
	bless($object, 'Geo::Vector::Layer');
	$object->defaults();
	return 1;
    }
    return 0;
}

sub new {
    my($package, %params) = @_;
    my $self = Geo::Vector::new($package, %params);
    Gtk2::Ex::Geo::Layer::new($package, self => $self, %params);
    return $self;
}

## @ignore
sub DESTROY {
}

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
sub properties_dialog {
    my ( $self, $gui ) = @_;
    if ( $self->{features} ) {
	$gui->message("not yet implemented");
    }
    elsif ( $self->{OGR}->{Layer} ) {
	$self->open_properties_dialog($gui);
    }
    else {
	$gui->message("no data in this layer");
    }
}

## @method hashref menu_items()
#
# @brief Reports the class menu items (name and sub) for the GUI.
# @return A reference to an anonymous hash.
sub menu_items {
    my($self, $items) = @_;
    $items = $self->SUPER::menu_items($items);
    $items->{x10} =
    {
	nr => 10,
    };

    if ( $self->{features} ) {

	$items->{'_Features...'} = 
	{
	    nr => 11,
	    sub => sub {
		my($self, $gui) = @{$_[1]};
		$self->open_feature_list_dialog($gui);
	    }
	};

    }
    elsif ( $self->{OGR}->{Layer} ) {

	$items->{'C_lip...'} = 
	{
	    nr => 11,
	    sub => sub {
		my($self, $gui) = @{$_[1]};
		$self->open_clip_dialog($gui);
	    }
	};
	$items->{'_Features...'} = 
	{
	    nr => 11,
	    sub => sub {
		my($self, $gui) = @{$_[1]};
		$self->open_features_dialog($gui);
	    }
	};
	$items->{'_Vertices...'} = 
	{
	    nr => 11,
	    sub => sub {
		my($self, $gui) = @{$_[1]};
		$self->open_vertices_dialog($gui);
	    }
	};
	$items->{'R_asterize...'} = 
	{
	    nr => 11,
	    sub => sub {
		my($self, $gui) = @{$_[1]};
		$self->open_rasterize_dialog($gui);
	    }
	};

    }
    else {

    }

    return $items;
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
    for my $name ( keys %$schema ) {
	$has_int = 1, next if $schema->{$name}{TypeName} eq 'Integer';
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
	
	#$self->{COLOR_FIELD_VALUE} = -1;
	#$self->{SYMBOL_FIELD_VALUE} = -2;
	$self->{RENDER_AS}       = 'Native';
	$self->{RENDER_AS_VALUE} = $Geo::Vector::RENDER_AS{ $self->{RENDER_AS} };
	
	my $layer = Geo::Vector::ral_visual_feature_table_create( $self, $self->{features} );
	if ($layer) {
	    Geo::Vector::ral_visual_feature_table_render( $layer, $pb ) if $pb;
	    Geo::Vector::ral_visual_feature_table_destroy($layer);
	}
	
    }
    elsif ( $self->{OGR}->{Layer} ) {
	
	my $schema = $self->schema();
	
	$self->{COLOR_FIELD_VALUE} =
	    exists $schema->{ $self->{COLOR_FIELD} } ? 
	    $schema->{ $self->{COLOR_FIELD} }{Number} : -1;
	
	$self->{SYMBOL_FIELD_VALUE} =
	    $self->{SYMBOL_FIELD} eq 'Fixed size' ? 
	    -2 : $schema->{ $self->{SYMBOL_FIELD} }{Number};
	
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
	print STDERR "label placement not defined for geometry type $Geo::Vector::GEOMETRY_TYPE_INV{$type}\n";
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

sub open_properties_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{properties_dialog};
    unless ($dialog) {
	$self->{properties_dialog} = $dialog = $gui->get_dialog('properties_dialog');
	croak "properties_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('properties_dialog')->signal_connect(delete_event => \&cancel_properties, [$self, $gui]);
	$dialog->get_widget('border_color_button')->signal_connect(clicked => \&border_color_dialog, [$self]);
	$dialog->get_widget('apply_properties_button')->signal_connect(clicked => \&apply_properties, [$self, $gui, 0]);
	$dialog->get_widget('cancel_properties_button')->signal_connect(clicked => \&cancel_properties, [$self, $gui]);
	$dialog->get_widget('ok_properties_button')->signal_connect(clicked => \&apply_properties, [$self, $gui, 1]);
    } elsif (!$dialog->get_widget('properties_dialog')->get('visible')) {
	$dialog->get_widget('properties_dialog')->move(@{$self->{properties_dialog_position}});
    }
    $dialog->get_widget('properties_dialog')->set_title("Properties of ".$self->name);

    $self->{backup}->{name} = $self->name;
    $self->{backup}->{render_as} = $self->render_as;
    $self->{backup}->{alpha} = $self->alpha;
    @{$self->{backup}->{border_color}} = $self->border_color;
    
    $dialog->get_widget('geom_type_lbl')->set_text($self->geometry_type or 'unknown type');
    
    my $combo = $dialog->get_widget('property_render_as_combobox');
    my $model = $combo->get_model;
    $model->clear;
    for (sort {$Geo::Vector::RENDER_AS{$a} <=> $Geo::Vector::RENDER_AS{$b}} keys %Geo::Vector::RENDER_AS) {
	$model->set ($model->append, 0, $_);
    }
    my $a = 0;
    $a = $self->render_as;
    $a = $Geo::Vector::RENDER_AS{$a} if defined $a;
    $combo->set_active($a);
    
    my $count = $self->{OGR}->{Layer}->GetFeatureCount();
    $count .= " (estimated)";
    $dialog->get_widget('feature_count_lbl')->set_text($count);
    
    my $ds = $self->{OGR}->{DataSource} if $self->{OGR}->{DataSource};
    my $driver = $self->driver;
    $dialog->get_widget('properties_driver_label')->set_text($driver ? $driver : 'unknown');
    $dialog->get_widget('datasource_lbl')->set_text($ds->GetName) if $ds;
    $dialog->get_widget('sql_lbl')->set_text($self->{SQL});
    
    $dialog->get_widget('name_entry')->set_text($self->name);
    $dialog->get_widget('alpha_spinbutton')->set_value($self->alpha);
    
    #my $polygon = $self->geometry_type() =~ /Polygon/; # may be undefined in some cases
    my $polygon = 1;
    $dialog->get_widget('border_checkbutton')->set_sensitive($polygon);
    $dialog->get_widget('border_color_button')->set_sensitive($polygon);
    $dialog->get_widget('ogr_properties_color0_label')->set_sensitive($polygon);
    $dialog->get_widget('ogr_properties_color_label')->set_sensitive($polygon);
    $dialog->get_widget('border_checkbutton')->set_active($self->border_color > 0);
    
    my @color = $self->border_color;
    @color = (0, 0, 0) unless @color;
    $dialog->get_widget('ogr_properties_color_label')->set_text("@color");
    
    $dialog->get_widget('properties_dialog')->show_all;
    $dialog->get_widget('properties_dialog')->present;
}

##@ignore
sub apply_properties {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{properties_dialog};
    my $alpha = $dialog->get_widget('alpha_spinbutton')->get_value_as_int;
    $self->alpha($alpha);
    my $name = $dialog->get_widget('name_entry')->get_text;
    $self->name($name);
    my $combo = $dialog->get_widget('property_render_as_combobox');
    my $model = $combo->get_model;
    my $iter = $model->get_iter_from_string($combo->get_active());
    $self->render_as($model->get_value($iter));
    my $has_border = $dialog->get_widget('border_checkbutton')->get_active();
    my @color = split(/ /, $dialog->get_widget('ogr_properties_color_label')->get_text);
    @color = () unless $has_border;
    $self->border_color(@color);
    $self->{properties_dialog_position} = [$dialog->get_widget('properties_dialog')->get_position];
    $dialog->get_widget('properties_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

##@ignore
sub cancel_properties {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    $self->alpha($self->{backup}->{alpha});
    $self->name($self->{backup}->{name});
    $self->render_as($self->{backup}->{render_as});
    $self->border_color(@{$self->{backup}->{border_color}});
    my $dialog = $self->{properties_dialog}->get_widget('properties_dialog');
    $self->{properties_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

##@ignore
sub border_color_dialog {
    my($self) = @{$_[1]};
    my $dialog = $self->{properties_dialog};
    my @color = split(/ /, $dialog->get_widget('ogr_properties_color_label')->get_text);
    my $color_chooser = Gtk2::ColorSelectionDialog->new('Choose color for the border of '.$self->name);
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    #$s->set_current_alpha($color[3]*257);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	#$color[3] = int($s->get_current_alpha()/257);
	$dialog->get_widget('ogr_properties_color_label')->set_text("@color");
    }
    $color_chooser->destroy;
}

# features dialog

sub open_features_dialog {
    my($self, $gui) = @_;
    my $dialog = $self->{features_dialog};
    unless ($dialog) {
	$self->{features_dialog} = $dialog = $gui->get_dialog('features_dialog');
	croak "features_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('features_dialog')->signal_connect(delete_event => \&close_features_dialog, [$self, $gui]);
	
	my $selection = $dialog->get_widget('feature_treeview')->get_selection;
	$selection->set_mode('multiple');
	$selection->signal_connect(changed => \&feature_activated, [$self, $gui]);
	
	$dialog->get_widget('spinbutton1')->signal_connect(value_changed => \&fill_ftv, [$self, $gui]);
	$dialog->get_widget('spinbutton2')->signal_connect(value_changed => \&fill_ftv, [$self, $gui]);

	$dialog->get_widget('features_limit_checkbutton')->signal_connect(toggled => \&fill_ftv, [$self, $gui]);
	
	$dialog->get_widget('features_vertices_button')->signal_connect(clicked => \&vertices_of_selected_features, [$self, $gui]);
	$dialog->get_widget('make_selection-button')->signal_connect(clicked => \&make_selection, [$self, $gui]);
	$dialog->get_widget('clip_selected-button')->signal_connect(clicked => \&clip_selected_features, [$self, $gui]);
	$dialog->get_widget('zoom-to-button')->signal_connect(clicked => \&zoom_to_selected_features, [$self, $gui]);
	$dialog->get_widget('close-button')->signal_connect(clicked => \&close_features_dialog, [$self, $gui]);

    } elsif (!$dialog->get_widget('features_dialog')->get('visible')) {
	$dialog->get_widget('features_dialog')->move(@{$self->{features_dialog_position}}) if $self->{features_dialog_position};
    }
    $dialog->get_widget('features_dialog')->set_title("Features of ".$self->name);
	
    my @columns;
    my @coltypes;
    my @ctypes;
    my $schema = $self->schema;    
    for my $name (sort {$schema->{$a}{VisualOrder} <=> $schema->{$b}{VisualOrder}} keys %$schema) {
	my $n = $name;
	$n =~ s/_/__/g;
	$n =~ s/^\.//;
	push @columns, $n;
	push @coltypes, 'Glib::String'; # use custom sort
	push @ctypes, $schema->{$name}{TypeName};
    }
    
    my $tv = $dialog->get_widget('feature_treeview');
    
    my $model = Gtk2::TreeStore->new(@coltypes);
    $tv->set_model($model);
    
    for ($tv->get_columns) {
	$tv->remove_column($_);
    }
    
    my $i = 0;
    foreach my $column (@columns) {
	if ($ctypes[$i] eq 'Integer' or $ctypes[$i] eq 'Real') { 
	    $model->set_sort_func($i, sub {
		my($model, $a, $b, $column) = @_;
		$a = $model->get($a, $column);
		$a = 0 unless $a;
		$b = $model->get($b, $column);
		$b = 0 unless $b;
		return $a <=> $b}, $i);
	} else {
	    $model->set_sort_func($i, sub {
		my($model, $a, $b, $column) = @_;
		$a = $model->get($a, $column);
		$a = '' unless $a;
		$b = $model->get($b, $column);
		$b = '' unless $b;
		return $a cmp $b}, $i);
	}
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }
    
    $i = 0;
    for ($tv->get_columns) {
	$_->set_sort_column_id($i++);
	$_->signal_connect(clicked => sub {
	    shift;
	    my($self, $tv) = @{$_[0]};
	    fill_ftv(undef, [$self, $gui]);
	}, [$self, $tv]);
    }
    
    fill_ftv(undef, [$self, $gui]);
    
    $dialog->get_widget('features_dialog')->show_all;
    $dialog->get_widget('features_dialog')->present;
}

##@ignore
sub close_features_dialog {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    my $dialog = $self->{features_dialog}->get_widget('features_dialog');
    $self->{features_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    1;
}


##@ignore
sub in_field_order {
    my $_a = $a;
    my $_b = $b;
    
}


##@ignore
sub fill_ftv {
    my($self, $gui) = @{$_[1]};

    my $dialog = $self->{features_dialog};
    my $treeview = $dialog->get_widget('feature_treeview');
    my $overlay = $gui->{overlay};

    my $from = $dialog->get_widget('spinbutton1')->get_value_as_int;
    my $count = $dialog->get_widget('spinbutton2')->get_value_as_int;
    my $limit = $dialog->get_widget('features_limit_checkbutton')->get_active;

    my $schema = $self->schema;
    my $model = $treeview->get_model;

    $model->clear;

    my @fnames = sort { $schema->{$a}{VisualOrder} <=> $schema->{$b}{VisualOrder} } keys %$schema;

    my $features = $self->selected_features;

    my %added;
    $self->add_features($treeview, $model, \@fnames, $features, 1, \%added);

    $count -= @$features;
    my $is_all = 1;
    if ($count > 0) {
	if ($limit) {
	    my @r = $overlay->get_viewport;
	    ($features, $is_all) = Geo::Vector::features( $self, filter_with_rect => \@r, from => $from, limit => $count );
	} else {
	    ($features, $is_all) = Geo::Vector::features( $self, from => $from, limit => $count );
	}
	$self->add_features($treeview, $model, \@fnames, $features, 0, \%added);
    }
    $dialog->get_widget('all_features_label')->set_sensitive($is_all);
}

##@ignore
sub add_features {
    my($self, $treeview, $model, $fnames, $features, $select, $added) = @_;

    my $selection = $treeview->get_selection;

    for my $f (@$features) {
	my @rec;
	my $rec = 0;

	my $id = $f->GetFID;
	next if exists $added->{$id};
	$added->{$id} = 1;

	for my $name (@$fnames) {
	    if ($name =~ /^\./ or $f->IsFieldSet($name)) {
		push @rec, $rec++;
		my $v = Geo::Vector::feature_attribute($f, $name);
		$v = decode($self->{encoding}, $v) if $self->{encoding};
		push @rec, $v;
	    } else {
		push @rec, $rec++;
		push @rec, undef;
	    }
	}

	my $iter = $model->insert (undef, 999999);
	$model->set ($iter, @rec);

	$selection->select_iter($iter) if $select;
    }
}

##@ignore
sub get_selected {
    my $selection = shift;
    my @sel = $selection->get_selected_rows;
    my %sel;
    for (@sel) {
	$sel{$_->to_string} = 1;
    }
    my $model = $selection->get_tree_view->get_model;
    my $iter = $model->get_iter_first();
    my $i = 0;
    my %s;
    while ($iter) {
	my($id) = $model->get($iter, 0);
	$s{$id} = 1 if $sel{$i++};
	$iter = $model->iter_next($iter);
    }
    return \%s;
}

sub get_hash_of_selected_features {
    my $self = shift;
    my %selected;
    my $s = $self->selected_features();
    for my $f (@$s) {
	$selected{$f->GetFID} = $f;
    }
    return \%selected;
}

##@ignore
sub set_selected_features {
    my($self, $treeview) = @_;
    my $selected = $self->get_hash_of_selected_features;
    my $selection = $treeview->get_selection;
    my $model = $treeview->get_model;
    my $iter = $model->get_iter_first();
    while ($iter) {
	my($id) = $model->get($iter, 0);
	$selection->select_iter($iter) if $selected->{$id};
	$iter = $model->iter_next($iter);
    }
}

##@ignore
sub feature_activated {
    my $selection = shift;
    my($self, $gui) = @{$_[0]};

    my $features = get_selected($selection);
    $features = $self->features(with_id=>[keys %$features]);
    return unless $features;
    return unless @$features;
    $self->selected_features($features);

    my $overlay = $gui->{overlay};
    $overlay->reset_pixmap;

    my $gc = Gtk2::Gdk::GC->new($overlay->{pixmap});
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535,0,0));

    for my $f (@$features) {

	next unless $f; # should not happen

	my $geom = $f->GetGeometryRef();
	next unless $geom;

	$overlay->render_geometry($gc, Geo::OGC::Geometry->new(Text => $geom->ExportToWkt));
	
    }

    $overlay->reset_image;

}

##@ignore
sub zoom_to_selected_features {
    my($self, $gui) = @{$_[1]};

    my $dialog = $self->{features_dialog};
    my $treeview = $dialog->get_widget('feature_treeview');
    my $features = get_selected($treeview->get_selection);
    $features = $self->features(with_id=>[keys %$features]);

    my @viewport = $gui->{overlay}->get_viewport;
    my @extent = ();
    
    for (@$features) {

	my $geom = $_->GetGeometryRef();
	next unless $geom;

	my $env = $geom->GetEnvelope; 
	$extent[0] = $env->[0] if !defined($extent[0]) or $env->[0] < $extent[0];
	$extent[1] = $env->[2] if !defined($extent[1]) or $env->[2] < $extent[1];
	$extent[2] = $env->[1] if !defined($extent[2]) or $env->[1] > $extent[2];
	$extent[3] = $env->[3] if !defined($extent[3]) or $env->[3] > $extent[3];
	
    }

    if (@extent) {
	
	# a point?
	if ($extent[2] - $extent[0] <= 0) {
	    $extent[0] -= ($viewport[2] - $viewport[0])/10;
	    $extent[2] += ($viewport[2] - $viewport[0])/10;
	}
	if ($extent[3] - $extent[1] <= 0) {
	    $extent[1] -= ($viewport[3] - $viewport[1])/10;
	    $extent[3] += ($viewport[3] - $viewport[1])/10;
	}
	
	$gui->{overlay}->zoom_to(@extent);
    }
}

##@ignore
sub clip_selected_features {
    my($self, $gui) = @{$_[1]};
    $self->open_clip_dialog($gui);
}

##@ignore
sub vertices_of_selected_features {
    my($self, $gui) = @{$_[1]};
    $self->open_vertices_dialog($gui);
}

##@ignore
sub make_selection {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{features_dialog};
    my $treeview = $dialog->get_widget('feature_treeview');
    my $features = get_selected($treeview->get_selection);
    $features = $self->features(with_id=>[keys %$features]);
    delete $gui->{overlay}->{selection};
    for (@$features) {
	my $geom = $_->GetGeometryRef();
	next unless $geom;
	my $g = Geo::OGC::Geometry->new(Text => $geom->ExportToWkt);
	unless ($gui->{overlay}->{selection}) {
	    unless (isa($g, 'Geo::OGC::GeometryCollection')) {
		my $coll = $g->MakeCollection;
		$coll->AddGeometry($g);
		$gui->{overlay}->{selection} = $coll;
	    } else {
		$gui->{overlay}->{selection} = $g;
	    }
	} else {
	    $gui->{overlay}->{selection}->AddGeometry($g);
	}
    }
    $gui->{overlay}->update_image;
}

sub open_feature_list_dialog {
    my($self, $gui) = @_;
    my $dialog = $self->{feature_list_dialog};
    unless ($dialog) {
	$self->{feature_list_dialog} = $dialog = $gui->get_dialog('feature_list_dialog');
	croak "feature_list_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('feature_list_dialog')->signal_connect(delete_event => \&close_feature_list_dialog, [$self, $gui]);
	
	my $selection = $dialog->get_widget('feature_list_treeview')->get_selection;
	$selection->set_mode('multiple');
	$selection->signal_connect(changed => \&feature_activated2, [$self, $gui]);
	
	$dialog->get_widget('feature_list_from_spinbutton')->signal_connect(value_changed => \&fill_ftv2, [$self, $gui]);
	$dialog->get_widget('feature_list_max_spinbutton')->signal_connect(value_changed => \&fill_ftv2, [$self, $gui]);
	
	$dialog->get_widget('feature_list_zoom_to_button')->signal_connect(clicked => \&zoom_to_selected_feature_list, [$self, $gui]);
	$dialog->get_widget('feature_list_close_button')->signal_connect(clicked => \&close_feature_list_dialog, [$self, $gui]);

    } elsif (!$dialog->get_widget('feature_list_dialog')->get('visible')) {
	$dialog->get_widget('feature_list_dialog')->move(@{$self->{feature_list_dialog_position}}) if $self->{feature_list_dialog_position};
    }
    $dialog->get_widget('feature_list_dialog')->set_title("Feature_List of ".$self->name);

    my $treeview = $dialog->get_widget('feature_list_treeview');

    my $model = Gtk2::TreeStore->new('Glib::Int');
    $treeview->set_model($model);

    for ($treeview->get_columns) {
	$treeview->remove_column($_);
    }

    my $i = 0;
    for my $column ('index') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
    }

    for ($treeview->get_columns) {
	$_->set_clickable(1);
	$_->signal_connect(clicked => sub {
	    shift;
	    my($self, $gui) = @{$_[0]};
	    fill_ftv2(undef, [$self, $gui]);
	}, [$self, $gui]);
    }

    fill_ftv2(undef, [$self, $gui]);

    $treeview = $dialog->get_widget('feature_list_attributes_treeview');

    my @columns = ('Field', 'Value');
    my @coltypes = ('Glib::String', 'Glib::String');

    $model = Gtk2::TreeStore->new(@coltypes);
    $treeview->set_model($model);

    for ($treeview->get_columns) {
	$treeview->remove_column($_);
    }

    $i = 0;
    foreach my $column (@columns) {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
    }
    
    $dialog->get_widget('feature_list_dialog')->show_all;
    $dialog->get_widget('feature_list_dialog')->present;
}

##@ignore
sub close_feature_list_dialog {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    my $dialog = $self->{feature_list_dialog}->get_widget('feature_list_dialog');
    $self->{feature_list_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    1;
}

sub fill_ftv2 {
    shift;
    my($self, $gui) = @{$_[0]};

    my $dialog = $self->{feature_list_dialog};

    my $from = $dialog->get_widget('feature_list_from_spinbutton')->get_value_as_int;
    my $count = $dialog->get_widget('feature_list_max_spinbutton')->get_value_as_int;

    my $model = $dialog->get_widget('feature_list_treeview')->get_model;

    $model->clear;

    my @recs;
    my $i = 1;
    my $k = 0;
    while ($i < $from+$count) {
	my $f = $self->{features}->[$k++];
	$i++;
	next if $i <= $from;
	last unless $f;
	my @rec;
	my $rec = 0;

	push @rec,$rec++;
	push @rec,$k-1; # $f->GetFID;
	
	push @recs,\@rec;
    }
    $k = @recs;

    for my $rec (@recs) {
	
	my $iter = $model->insert (undef, 999999);
	$model->set ($iter, @$rec);
	
    }
    
}

sub feature_activated2 {
    my $selection = shift;
    my($self, $gui) = @{$_[0]};

    my $dialog = $self->{feature_list_dialog};
    my $model = $dialog->get_widget('feature_list_attributes_treeview')->get_model;

    my $ids = get_selected($selection);
    my $features = $self->features(with_id=>[keys %$ids]);
    return unless $features;
    return unless @$features;

    if (@$features == 1) {
	my @k = keys %$ids;
	my $f = $features->[0];
	my $schema = $self->schema($k[0]);
	$model->clear;

	my @recs;
	for my $name (sort {$schema->{$a}{VisualOrder} <=> $schema->{$b}{VisualOrder}} keys %$schema) {
	    my @rec;
	    my $rec = 0;
	    push @rec, $rec++;
	    my $n = $name;
	    $n =~ s/^\.//;
	    push @rec, $n;
	    push @rec, $rec++;
	    push @rec, Geo::Vector::feature_attribute($f, $name);
	    push @recs,\@rec;
	}

	for my $rec (@recs) {
	
	    my $iter = $model->insert (undef, 999999);
	    $model->set ($iter, @$rec);
	    
	}
	
    }

    my $overlay = $gui->{overlay};

    $overlay->reset_pixmap;

    my $gc = Gtk2::Gdk::GC->new($overlay->{pixmap});
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535,0,0));

    for my $f (@$features) {

	next unless $f; # should not happen

	my $geom = $f->GetGeometryRef();
	next unless $geom;

	$overlay->render_geometry($gc, $geom);
	
    }

    $overlay->reset_image;

}



# vertices dialog

sub open_vertices_dialog {
    my($self, $gui) = @_;
    my $dialog = $self->{vertices_dialog};
    unless ($dialog) {
	$self->{vertices_dialog} = $dialog = $gui->get_dialog('vertices_dialog');
	croak "vertices_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('vertices_dialog')->signal_connect(delete_event => \&close_vertices_dialog, [$self, $gui]);
	
	my $selection = $dialog->get_widget('vertices_treeview')->get_selection;
	$selection->set_mode('multiple');
	$selection->signal_connect(changed => \&vertices_activated, [$self, $gui]);
	
	$dialog->get_widget('vertices_from_spinbutton')->signal_connect(value_changed => \&fill_vtv, [$self, $gui]);
	$dialog->get_widget('vertices_max_spinbutton')->signal_connect(value_changed => \&fill_vtv, [$self, $gui]);
	
	$dialog->get_widget('vertices_close_button')->signal_connect(clicked => \&close_vertices_dialog, [$self, $gui]);

    } elsif (!$dialog->get_widget('vertices_dialog')->get('visible')) {
	$dialog->get_widget('vertices_dialog')->move(@{$self->{vertices_dialog_position}}) if $self->{vertices_dialog_position};
    }
    $dialog->get_widget('vertices_dialog')->set_title("Vertices of ".$self->name);
	
    my $tv = $dialog->get_widget('vertices_treeview');
    my @c = $tv->get_columns;
    for (@c) {
	$tv->remove_column($_);
    }

    my $model = Gtk2::TreeStore->new(qw/Glib::String/);
    my $cell = Gtk2::CellRendererText->new;
    my $col = Gtk2::TreeViewColumn->new_with_attributes('Vertices', $cell, text => 0);
    $tv->append_column($col);
    $tv->set_model($model);

    fill_vtv(undef, [$self, $gui]);
     
    $dialog->get_widget('vertices_dialog')->show_all;
    $dialog->get_widget('vertices_dialog')->present;
}

##@ignore
sub close_vertices_dialog {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    my $dialog = $self->{vertices_dialog}->get_widget('vertices_dialog');
    $self->{vertices_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    1;
}

##@ignore
sub fill_vtv {
    my($self, $gui) = @{$_[1]};

    my $overlay = $gui->{overlay};
    my $dialog = $self->{vertices_dialog};
    
    my $from = $dialog->get_widget('vertices_from_spinbutton')->get_value_as_int;
    my $count = $dialog->get_widget('vertices_max_spinbutton')->get_value_as_int;
    my $tv = $dialog->get_widget('vertices_treeview');
    my $model = $tv->get_model;
    $model->clear;

    delete $self->{GIDS};    
    my @data;
    my $vertex = 0;
    my $vertices = 0;
	
    my $features = $self->selected_features;
    if (@$features) {
	for my $f (@$features) {
	    my $geom = $f->GetGeometryRef();
	    my $fid = $f->GetFID;
	    my $name = $geom->GetGeometryName;
	    my $vertices2 = $vertices;
	    my $d = $self->get_geom_data($gui, $geom, \$vertex, \$vertices2, $from, $count);
	    push @data,["Feature (fid=$fid) ($name)",$d,$fid] if $vertices2 > $vertices;
	    $vertices = $vertices2;
	    last if $vertices >= $count;
	}
    } else {
	my $l = $self->{OGR}->{Layer};
	if ($l) {
	    my @r = $gui->{overlay}->get_viewport; #_of_selection;
	    #@r = $gui->{overlay}->get_viewport unless @r;
	    $l->SetSpatialFilterRect(@r);
	    $l->ResetReading();
	    while (my $f = $l->GetNextFeature) {
		my $geom = $f->GetGeometryRef();
		my $fid = $f->GetFID;
		my $name = $geom->GetGeometryName;
		my $vertices2 = $vertices;
		my $d = $self->get_geom_data($gui, $geom, \$vertex, \$vertices2, $from, $count);
		push @data,["Feature (fid=$fid) ($name)",$d,$fid] if $vertices2 > $vertices;
		$vertices = $vertices2;
		last if $vertices >= $count;
	    }
	}
    }

    my $i = 0;
    for my $d (@data) {
	$self->set_geom_data($d, $i, $d->[2], $model);
	$i++;
    }
}

##@ignore
sub set_geom_data {
    my($self, $data, $path, $gid, $tree_store, $iter) = @_;
    
    my $iter2 = $tree_store->append($iter);
    $tree_store->set ($iter2,0 => $data->[0]);
    
    if ($data->[1]) {

	my $i = 0;
	for my $d (@{$data->[1]}) {
	    $self->set_geom_data($d, "$path:$i", "$gid:$d->[2]", $tree_store, $iter2);
	    $i++;
	}

    } else {

	$self->{GIDS}->{$path} = $gid;

    }
}

##@ignore
sub get_geom_data {
    my($self, $gui, $geom, $vertex, $vertices, $from, $count) = @_;

    return if $$vertices >= $count;
    
    if ($geom->GetGeometryCount) {
	
	my @d;
	for my $i2 (0..$geom->GetGeometryCount-1) {
	    
	    my $geom2 = $geom->GetGeometryRef($i2);
	    my $name = $geom2->GetGeometryName;
	    
	    my $vertices2 = $$vertices;
	    my $data = $self->get_geom_data($gui, $geom2, $vertex, \$vertices2, $from, $count);
	    push @d, [($i2+1).'. '.$name, $data, $i2] if $vertices2 > $$vertices;
	    $$vertices = $vertices2;
	    last if $$vertices >= $count;
	    
	}
	return \@d if @d;
	
    } else {

	my @rect = $gui->{overlay}->get_viewport; #_of_selection;
	#@rect = $gui->{overlay}->get_viewport unless @rect;
	my $s = $gui->{overlay}->{selection};
	my $a = ($s and isa($s, 'Geo::OGR::Geometry'));
	my @d;
	for my $i (0..$geom->GetPointCount-1) {	    
	    my $x = $geom->GetX($i);
	    next if $x < $rect[0] or $x > $rect[2];
	    my $y = $geom->GetY($i);
	    next if $y < $rect[1] or $y > $rect[3];
	    if ($a) {
		my $point = new Geo::OGR::Geometry($Geo::OGR::wkbPoint);
		$point->ACQUIRE;
		$point->AddPoint($x, $y);
		next unless $point->Within($s);
	    }
	    my $z = $geom->GetZ($i);
	    $$vertex++;
	    if ($$vertex >= $from) {
		push @d, [($i+1).": $x $y $z", undef, $i];
		$$vertices++;
	    }
	    last if $$vertices >= $count;
	}
	
	return \@d;
	
    }

    return undef;

}

##@ignore
sub vertices_activated {
    my $selection = $_[0];
    my($self, $gui) = @{$_[1]};

    my @sel = $selection->get_selected_rows;
    return unless @sel;

    my $overlay = $gui->{overlay};
    $overlay->reset_pixmap;

    my $pixmap = $overlay->{pixmap};
    my $GIDS = $self->{GIDS};

    my $gc = Gtk2::Gdk::GC->new($pixmap);
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535, 0, 0));

    for (@sel) {

	my $selected = $_->to_string;

	next unless exists $GIDS->{$selected};

	my @path = split(/:/, $GIDS->{$selected});

	my $f = $self->{OGR}->{Layer}->GetFeature($path[0]);
	my $geom = $f->GetGeometryRef();
	for my $i (1..$#path-1) {
	    $geom = $geom->GetGeometryRef($path[$i]);
	}
	my @p = ($geom->GetX($path[$#path]), $geom->GetY($path[$#path]));

	@p = $overlay->point2pixmap_pixel(@p);	
	
	$pixmap->draw_line($gc, $p[0]-4, $p[1], $p[0]+4, $p[1]);
	$pixmap->draw_line($gc, $p[0], $p[1]-4, $p[0], $p[1]+4);
	
    }

    $overlay->reset_image;

}

# clip dialod

sub open_clip_dialog {
    my($self, $gui) = @_;

    my $dialog = $self->{clip_dialog};
    unless ($dialog) {
	$self->{clip_dialog} = $dialog = $gui->get_dialog('vector_clip_dialog');
	croak "clip_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('vector_clip_dialog')->signal_connect(delete_event => \&close_clip_dialog, [$self, $gui]);

	my $entry = $dialog->get_widget('clip_datasource_entry');
	$dialog->get_widget('clip_datasource_button')->signal_connect
	    ( clicked=>\&select_directory2, [$self, $entry] );

	$dialog->get_widget('clip_cancel_button')->signal_connect(clicked => \&cancel_clip, [$self, $gui]);
	$dialog->get_widget('clip_ok_button')->signal_connect(clicked => \&do_clip, [$self, $gui, 1]);
	#$entry->signal_connect(changed => \&clip_data_source_changed, [$self, $gui]);
	
    } elsif (!$dialog->get_widget('vector_clip_dialog')->get('visible')) {
	$dialog->get_widget('vector_clip_dialog')->move(@{$self->{clip_dialog_position}}) if $self->{clip_dialog_position};
    }
    $dialog->get_widget('vector_clip_dialog')->set_title("Clip from ".$self->name);
	
    my $combo = $dialog->get_widget('clip_driver_combobox');
    my $model = $combo->get_model;
    $model->clear;

    for my $driver (Geo::OGR::Drivers) {
	next unless $driver->TestCapability('CreateDataSource');
	$model->set($model->append, 0, $driver->GetName);
    }

    $combo->set_active(0);
    $dialog->get_widget('clip_name_entry')->set_text('clip');
    $dialog->get_widget('clip_datasource_entry')->set_text('.');
    my $s = $self->selected_features;
    $dialog->get_widget('clip_count_label')->set_label(($#$s+1)." features selected");

    $dialog->get_widget('vector_clip_dialog')->show_all;
    $dialog->get_widget('vector_clip_dialog')->present;
}

sub select_directory2 {
    my $button = shift;
    my($self, $entry) = @{$_[0]};
    my $file_chooser =
	Gtk2::FileChooserDialog->new ("Select a folder",
				      undef, 'select_folder',
				      'gtk-cancel' => 'cancel',
				      'gtk-ok' => 'ok');
    $file_chooser->set_current_folder($dialog_folder) if $dialog_folder;
    my $uri;
    if ($file_chooser->run eq 'ok') {
	$dialog_folder = $file_chooser->get_current_folder();
	$uri = $file_chooser->get_uri;
	#print "$uri\n";
	#print "$dialog_folder\n";
	$uri =~ s/^file:\/\///;
	$uri =~ s/^\/// if $uri =~ /^\/\w:/; # hack for windows
	$entry->set_text($uri);
    }

    $file_chooser->destroy;
}

##@ignore
sub do_clip {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{clip_dialog};

    my %ret = (
	create => $dialog->get_widget('clip_name_entry')->get_text,
	data_source => $dialog->get_widget('clip_datasource_entry')->get_text,
	selected_features => $self->selected_features,
	driver => $dialog->get_widget('clip_driver_combobox')->get_active_text
	);
    
    my $layers;

    eval {
	$layers = Geo::Vector::layers($ret{driver}, $ret{data_source});
    };
    
    if ($layers and $layers->{$ret{create}}) {
	
	$gui->message("Data source '$ret{data_source}' already contains a layer '$ret{layer_name}'.");
	return;
	
    } else {

	my $new_layer = $self->clip(%ret);
	$gui->add_layer($new_layer, $ret{layer_name}, 1);
	#$gui->set_layer($new_layer);
	$gui->{overlay}->render;
	
    }

    $self->{clip_dialog_position} = [$dialog->get_widget('vector_clip_dialog')->get_position];
    $dialog->get_widget('vector_clip_dialog')->hide();
    $gui->{overlay}->render;
}

##@ignore
sub cancel_clip {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    my $dialog = $self->{clip_dialog}->get_widget('vector_clip_dialog');
    $self->{clip_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->{overlay}->render;
    1;
}

##@ignore
sub clip_data_source_changed {
    my $entry = $_[0];
    my($self, $gui) = @{$_[1]};
    my $text = $entry->get_text();
    my $ds;
    eval {
	$ds = Geo::OGR::Open($text);
    };
    if ($@) {
	$gui->message("error opening data_source: '$text': $@");
	return;
    }
    return unless $ds; # can't be opened as a data_source
    my $driver = $ds->GetDriver; # default driver
    if ($driver) {
	my $name = $driver->GetName;
	# get from combo
	my $combo = $self->{clip_dialog}->get_widget('clip_driver_combobox');
	my $model = $combo->get_model;
	my $i = 0;
	my $iter = $model->get_iter_first;
      LOOP: {
	  do {
	      my $d = $model->get_value($iter);
	      if ($d eq $name) {
		  $combo->set_active($i);
		  last;
	      }
	      $i++;
	  } while ($iter = $model->iter_next($iter));
      }
    }
}

## @method open_rasterize_dialog($gui)
# @brief present a rasterize dialog for the user
sub open_rasterize_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{rasterize_dialog};
    unless ($dialog) {
	$self->{rasterize_dialog} = $dialog = $gui->get_dialog('rasterize_dialog');
	croak "rasterize_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('rasterize_dialog')->signal_connect(delete_event => \&cancel_rasterize, [$self, $gui]);

	$dialog->get_widget('rasterize_cancel_button')->signal_connect(clicked => \&cancel_rasterize, [$self, $gui]);
	$dialog->get_widget('rasterize_ok_button')->signal_connect(clicked => \&apply_rasterize, [$self, $gui, 1]);
    } elsif (!$dialog->get_widget('rasterize_dialog')->get('visible')) {
	$dialog->get_widget('rasterize_dialog')->move(@{$self->{rasterize_dialog_position}});
    }
    $dialog->get_widget('rasterize_dialog')->set_title("Rasterize ".$self->name);
	
    $dialog->get_widget('rasterize_name_entry')->set_text('r');

    # fill like_combobox: all available rasters

    my $combo = $dialog->get_widget('rasterize_like_combobox');
    my $model = $combo->get_model;
    $model->clear;

    $model->set ($model->append, 0, "Use current view");
    for my $layer (@{$gui->{overlay}->{layers}}) {
	next unless isa($layer, 'Geo::Raster');
	$model->set ($model->append, 0, $layer->name);
    }
    $combo->set_active(0);

    $combo = $dialog->get_widget('rasterize_render_as_combobox');
    $model = $combo->get_model;
    $model->clear;
    for (sort {$Geo::Vector::RENDER_AS{$a} <=> $Geo::Vector::RENDER_AS{$b}} keys %Geo::Vector::RENDER_AS) {
	$model->set ($model->append, 0, $_);
    }
    my $a = $self->render_as;
    $a = $Geo::Vector::RENDER_AS{$a} if defined $a;
    $combo->set_active($a);

    # fill rasterize_value_comboboxentry: int and float fields
    $combo = $dialog->get_widget('rasterize_value_field_combobox');
    $model = $combo->get_model;
    $model->clear;

    $model->set ($model->append, 0, 'Draw with value 1');
    if ($self->{OGR}->{Layer}) {
	my $schema = $self->{OGR}->{Layer}->GetLayerDefn();
	for my $i (0..$schema->GetFieldCount-1) {
	    my $column = $schema->GetFieldDefn($i);
	    my $type = $column->GetFieldTypeName($column->GetType);
	    if ($type eq 'Integer' or $type eq 'Real') {
		$model->set($model->append, 0, $column->GetName);
	    }
	}
	$combo->set_active(0);
    }

    $dialog->get_widget('rasterize_nodata_value_entry')->set_text(-9999);
    
    $dialog->get_widget('rasterize_dialog')->show_all;
    $dialog->get_widget('rasterize_dialog')->present;
}

##@ignore
sub apply_rasterize {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{rasterize_dialog};
    
    my %ret = (name => $dialog->get_widget('rasterize_name_entry')->get_text());
    my $model = $dialog->get_widget('rasterize_like_combobox')->get_active_text;
    
    if ($model eq "Use current view") {
	# need M (height), N (width), world
	($ret{M}, $ret{N}) = $gui->{overlay}->size;
	$ret{world} = [$gui->{overlay}->get_viewport];
    } else {
	$ret{like} = $gui->{overlay}->get_layer_by_name($model);
    }

    $ret{render_as} = $dialog->get_widget('rasterize_render_as_combobox')->get_active;
    $ret{render_as} = $INDEX2RENDER_AS{$ret{render_as}};

    $ret{feature} = $dialog->get_widget('rasterize_fid_entry')->get_text;
    $ret{feature} = -1 unless $ret{feature} =~ /^\d+$/;

    my $field = $dialog->get_widget('rasterize_value_field_combobox')->get_active_text;
    
    if ($field ne 'Draw with value 1') {
	$ret{value_field} = $field;
    }

    $ret{nodata_value} = $dialog->get_widget('rasterize_nodata_value_entry')->get_text();

    my $g = $self->rasterize(%ret);
    if ($g) {
	$gui->add_layer($g, $ret{name}, 1);
	$gui->{overlay}->render;
    }

    $self->{rasterize_dialog_position} = [$dialog->get_widget('rasterize_dialog')->get_position];
    $dialog->get_widget('rasterize_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

##@ignore
sub cancel_rasterize {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    
    my $dialog = $self->{rasterize_dialog}->get_widget('rasterize_dialog');
    $self->{rasterize_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    1;
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

sub FormatName {
    my($self) = @_;
    my $n = $self->GetName;
    return $FormatNames{$n};
}

package Geo::Vector::Layer;

sub open_open_vector_dialog {
    my($gui) = @_;

    $oneself->{gui} = $gui;
    my $d = $oneself->{dialog} = $gui->get_dialog('open_vector_dialog');
    croak "open_vector_dialog for Geo::Vector::Layer does not exist" unless $d;
    $d->get_widget('open_vector_dialog')->set_title("Open a vector layer");
    $d->get_widget('open_vector_dialog')->signal_connect(delete_event => \&cancel_open_vector, $oneself);

    my $model = Gtk2::ListStore->new('Glib::String');
    for my $driver (Geo::OGR::Drivers()) {
	my @t = $driver->DataSourceTemplate;
	next if $t[0] eq '<filename>';
	my $n = $driver->FormatName;
	$model->set ($model->append, 0, $n);
    }
    my $combo = $d->get_widget('open_vector_driver_combobox');
    $combo->set_model($model);
    my $renderer = Gtk2::CellRendererText->new;
    $combo->pack_start ($renderer, TRUE);
    $combo->add_attribute ($renderer, text => 0);
    $combo->set_active(0);

    $d->get_widget('open_vector_datasource_combobox')
	->signal_connect(changed => sub { empty_layer_data($_[1]) }, $oneself);

    $d->get_widget('open_vector_build_connection_button')
	->signal_connect(clicked => \&build_data_source, $oneself);

    fill_named_data_sources_combobox($oneself);
    
    $d->get_widget('open_vector_delete_datasource_button')
	->signal_connect(clicked => \&delete_data_source, $oneself);
    $d->get_widget('open_vector_connect_datasource_button')
	->signal_connect(clicked => \&connect_data_source, $oneself);
    
    my $treeview = $d->get_widget('open_vector_directory_treeview');
    $treeview->set_model(Gtk2::TreeStore->new('Glib::String'));
    my $i = 0;
    foreach my $column ('directory') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, markup => $i++);
	$treeview->append_column($col);
    }
    $treeview->signal_connect(button_press_event => sub 
			      {
                                  if ($combo->get_active) {
                                      $combo->set_active(0);
                                      $d->get_widget('open_vector_layer_treeview')->get_model->clear;
                                  }
				  my($treeview, $event, $oneself) = @_;
				  select_directory($oneself, $treeview) if $event->type =~ /^2button/;
				  return 0;
			      }, $oneself);
    $treeview->signal_connect(key_press_event => sub
			      {
                                  if ($combo->get_active) {
                                      $combo->set_active(0);
                                      $d->get_widget('open_vector_layer_treeview')->get_model->clear;
                                  }
				  my($treeview, $event, $oneself) = @_;
				  select_directory($oneself, $treeview) if $event->keyval == $Gtk2::Gdk::Keysyms{Return};
				  return 0;
			      }, $oneself);
    
    $treeview = $d->get_widget('open_vector_layer_treeview');
    $treeview->set_model(Gtk2::TreeStore->new(qw/Glib::String Glib::String/));
    $treeview->get_selection->set_mode('multiple');
    $i = 0;
    for my $column ('layer', 'geometry') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
    }
    $treeview->signal_connect(cursor_changed => \&on_layer_treeview_cursor_changed, $oneself);
    
    $treeview = $d->get_widget('open_vector_property_treeview');
    $treeview->set_model(Gtk2::TreeStore->new(qw/Glib::String Glib::String/));
    $i = 0;
    foreach my $column ('property', 'value') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
    }
    
    $treeview = $d->get_widget('open_vector_schema_treeview');
    $treeview->set_model(Gtk2::TreeStore->new(qw/Glib::String Glib::String/));
    $i = 0;
    foreach my $column ('field', 'type') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
    }
    
    $oneself->{directory_toolbar} = [];

    my $entry = $d->get_widget('open_vector_SQL_entry');
    $entry->signal_connect(key_press_event => \&edit_entry, $oneself);
    $entry->signal_connect(changed => \&on_SQL_entry_changed, $oneself);
    
    $d->get_widget('open_vector_remove_button')->signal_connect(clicked => \&remove_layer, $oneself);
    $d->get_widget('open_vector_schema_button')->signal_connect(clicked => \&show_schema, $oneself);
    $d->get_widget('open_vector_cancel_button')->signal_connect(clicked => \&cancel_open_vector, $oneself);
    $d->get_widget('open_vector_ok_button')->signal_connect(clicked => \&open_vector, $oneself);

    $oneself->{path} = $gui->{folder} if $gui->{folder};
    $oneself->{path} = File::Spec->rel2abs('.') unless $oneself->{path};

    fill_directory_treeview($oneself);
    fill_layer_treeview($oneself);

    $d->get_widget('open_vector_update_checkbutton')->set_active(0);

    $d->get_widget('open_vector_dialog')->show_all;
    $d->get_widget('open_vector_dialog')->present;

}

sub fill_named_data_sources_combobox {
    my($self, $default) = @_;
    $default = '' unless $default;
    my $model = Gtk2::ListStore->new('Glib::String');
    $model->set ($model->append, 0, '');
    my $i = 1;
    my $active = 0;
    for my $data_source (sort keys %{$self->{gui}{resources}{datasources}}) {
	$model->set ($model->append, 0, $data_source);
	$active = $i if $data_source eq $default;
	$i++;
    }
    my $combo = $self->{dialog}->get_widget('open_vector_datasource_combobox');
    if ($combo->get_active == -1) {
	my $renderer = Gtk2::CellRendererText->new;
	$combo->pack_start ($renderer, TRUE);
	$combo->add_attribute ($renderer, text => 0);
    }
    $combo->set_model($model);
    $combo->set_active($active);
}

sub get_data_source {
    my $self = shift;
    my $combo = $self->{dialog}->get_widget('open_vector_datasource_combobox');
    my $active = $combo->get_active();
    return ('', $self->{path}) if $active < 0;
    my $model = $combo->get_model;
    my $iter = $model->get_iter_from_string($active);
    my $name = $model->get($iter, 0);
    return ('', $self->{path}) if $name eq '';
    return @{$self->{gui}{resources}{datasources}{$name}};
}

##@ignore
sub open_vector {
    my($button, $self) = @_;

    $self->{gui}->{folder} = $oneself->{path};

    my($driver, $data_source) = get_data_source($self);

    my $sql = $self->{dialog}->get_widget('open_vector_SQL_entry')->get_text;
    $sql =~ s/^\s+//;
    $sql =~ s/\s+$//;
    $self->{gui}{history}->editing($sql);

    my $layers = get_selected($self->{dialog}->get_widget('open_vector_layer_treeview')->get_selection);

    if ($sql) {
	$self->{gui}{history}->enter();
	$self->{dialog}->get_widget('open_vector_SQL_entry')->set_text('');
    }
	
    my $wish = $self->{dialog}->get_widget('open_vector_layer_name_entry')->get_text;
    my $update = $self->{dialog}->get_widget('open_vector_update_checkbutton')->get_active;
    my $hidden = $self->{dialog}->get_widget('open_vector_open_hidden_button')->get_active;
	
    for my $name (keys %$layers) {
	my $layer;
	my $encoding = 'utf8' if $data_source =~ /^Pg:/; # not really the case always but...
	eval {
	    $layer = Geo::Vector::Layer->new
		( data_source=>$data_source, layer=>$name, sql=>$sql, update=>$update, encoding=>$encoding );
	};
	if ($@) {
	    my $err = $@;
	    if ($err) {
		$err =~ s/\n/ /g;
		$err =~ s/\s+$//;
		$err =~ s/\s+/ /g;
		$err =~ s/^\s+$//;
	    } else {
		$err = "data_source=$data_source, layer=$name, sql=$sql, update=$update";
	    }
	    $self->{gui}->message("Could not open layer: $err");
	    return;
	}
	$name = $wish if (keys %$layers) == 1;
	$layer->visible(0) if $hidden;
	$self->{gui}->add_layer($layer, $name, 1);
    }
    $self->{gui}{tree_view}->set_cursor(Gtk2::TreePath->new(0));
    $self->{gui}{overlay}->render;
    delete $self->{directory_toolbar};
    $self->{dialog}->get_widget('open_vector_dialog')->destroy;
}

##@ignore
sub cancel_open_vector {
    my $self = pop;
    delete $self->{directory_toolbar};
    $self->{dialog}->get_widget('open_vector_dialog')->destroy;
}

##@ignore
sub remove_layer {
    my($button, $self) = @_;
    my($driver, $data_source) = get_data_source($self);
    my $layers = get_selected($self->{dialog}->get_widget('open_vector_layer_treeview')->get_selection);
    eval {
	my $ds = Geo::OGR::Open($data_source, 1);
	for my $i (0..$ds->GetLayerCount-1) {
	    my $l = $ds->GetLayerByIndex($i);
	    $ds->DeleteLayer($i) if $layers->{$l->GetName()};
	}
    };
    $self->{gui}->message("$@") if $@;
}

##@ignore
sub fill_directory_treeview {
    my $self = shift;
    my $treeview = $self->{dialog}->get_widget('open_vector_directory_treeview');
    my $model = $treeview->get_model;
    $model->clear;

    my $toolbar = $self->{dialog}->get_widget('open_vector_directory_toolbar');
    for (@{$self->{directory_toolbar}}) {
	$toolbar->remove($_);
    }
    $self->{directory_toolbar} = [];

    if ($self->{path} eq '') {
	@{$self->{dir_list}} = ();
	my @d;

	my $fso = Win32::OLE->new('Scripting.FileSystemObject');
	for ( in $fso->Drives ) {
	    push @d, $_->{DriveLetter}.':';
	}

	for (@d) {
	    s/\\$//;
	    push @{$self->{dir_list}},$_;
	}
	@{$self->{dir_list}} = reverse @{$self->{dir_list}} if $self->{dir_list};
	for my $i (0..$#{$self->{dir_list}}) {
	    my $iter = $model->insert (undef, 0);
	    $model->set ($iter, 0, $self->{dir_list}->[$i] );
	}
	$self->{dialog}->get_widget('open_vector_directory_treeview')->set_cursor(Gtk2::TreePath->new(0));
	@{$self->{dir_list}} = reverse @{$self->{dir_list}} if $self->{dir_list};
	return;
    }

    my($volume, $directories, $file) = File::Spec->splitpath($self->{path}, 1);
    $self->{volume} = $volume;
    my @dirs = File::Spec->splitdir($directories);
    unshift @dirs, File::Spec->rootdir();
    if ($^O eq 'MSWin32') {
	unshift @dirs, $volume;
    }
    
    for (reverse @dirs) {
	next if /^\s*$/;
	my $label = Gtk2::Label->new($_);
	my $b = Gtk2::ToolButton->new($label,$_);
	$b->signal_connect("clicked", 
			   sub {
			       my($button, $self) = @_;
                               $self->{dialog}->get_widget('open_vector_datasource_combobox')->set_active(0);
			       my $n = $button->get_label;
			       if ($n eq $self->{volume}) {
				   $self->{path} = '';
			       } else {
				   my @directories;
				   for (reverse @{$self->{directory_toolbar}}) {
				       push @directories, $_->get_label;
				       last if $_ == $_[0];
				   }
				   if ($^O eq 'MSWin32') {
				       shift @directories; # remove volume
				   }
				   my $directory = File::Spec->catdir(@directories);
				   $self->{path} = File::Spec->catpath($self->{volume}, $directory, '');
			       }
			       fill_directory_treeview($self);
			       fill_layer_treeview($self);
			   },
			   $self);
	$label->show;
	$b->show;
	$toolbar->insert($b,0);
	push @{$self->{directory_toolbar}}, $b;
    }
    
    @{$self->{dir_list}} = ();
    if (opendir(DIR, $self->{path})) {
	
	my @files = sort {$b cmp $a} readdir(DIR);
	closedir DIR;

	my @dirs;
	my @fs;
	for (@files) {
	    my $test = File::Spec->catpath( $volume, $directories, $_ );
	    next if (/^\./ and not $_ eq File::Spec->updir);
	    #next unless -d $test;
	    my $dir = 1 if -d $test;
	    next if $_ eq File::Spec->curdir;
	    s/&/&amp;/g;
	    s/</&lt;/g;
	    s/>/&gt;/g;
	    if ($dir) {
		push @dirs, "<b>[$_]</b>";
	    } else {
		push @fs, $_;
	    }
	}
	for (@fs) {
	    push @{$self->{dir_list}}, $_;
	}
	for (@dirs) {
	    push @{$self->{dir_list}}, $_;
	}
	
	for my $i (0..$#{$self->{dir_list}}) {
	    my $iter = $model->insert (undef, 0);
	    $model->set ($iter, 0, $self->{dir_list}->[$i] );
	}
	
	$treeview->set_cursor(Gtk2::TreePath->new(0));
	
    }
    @{$self->{dir_list}} = reverse @{$self->{dir_list}} if $self->{dir_list};
}

sub empty_layer_data {
    my($self) = @_;
    my $model = $self->{dialog}->get_widget('open_vector_layer_treeview')->get_model;
    $model->clear if $model;
    $model = $self->{dialog}->get_widget('open_vector_property_treeview')->get_model;
    $model->clear if $model;
    $model = $self->{dialog}->get_widget('open_vector_schema_treeview')->get_model;
    $model->clear if $model;
}

## @ignore
sub fill_layer_treeview {
    my($self, $driver, $data_source) = @_;

    empty_layer_data($self);

    my $treeview = $self->{dialog}->get_widget('open_vector_layer_treeview');
    my $model = $treeview->get_model;

    $data_source = $self->{path} unless $data_source;
    return unless $data_source;

    $self->{_open_data_source} = $data_source;
    my $layers;
    eval {
        $layers = Geo::Vector::layers($driver, $data_source);
    };
    my @layers = sort {$b cmp $a} keys %$layers;
    if (@layers) {
        for my $name (@layers) {
            my $iter = $model->insert (undef, 0);
            $model->set ($iter, 0, $name, 1, $layers->{$name});
        }
        $treeview->set_cursor(Gtk2::TreePath->new(0));
    } 
    else {
        my $iter = $model->insert (undef, 0);
        $model->set ($iter, 0, "no layers found", 1, "");
        unless ($@ =~ /no reason given/) {
            $@ =~ s/RuntimeError\s+//;
            $@ =~ s/FATAL:\s+(\w)/uc($1)/e;
            $@ =~ s/\s+at\s+\w+\.\w+\s+line\s+\d+\s+//;
            $model->set ($model->append(undef), 0, $@, 1, "");
        }
    }
    on_layer_treeview_cursor_changed($treeview, $self);
    return @layers > 0;
}

sub on_SQL_entry_changed {
    my($entry, $self) = @_;
    my $sql = $entry->get_text;
    $sql =~ s/^\s+//;
    $sql =~ s/\s+$//;
    $self->{dialog}->get_widget('open_vector_layer_name_entry')->set_text('SQL') if $sql;
}

sub on_layer_treeview_cursor_changed {
    my($treeview, $self) = @_;
    my($path, $focus_column) = $treeview->get_cursor;
    if ($path) {
	my $model = $treeview->get_model;
	my $iter = $model->get_iter($path);
	my $layer_name = $model->get($iter, 0);
	$self->{dialog}->get_widget('open_vector_layer_name_entry')->set_text($layer_name);
    }
    $self->{gui}{history}->editing('');
    $self->{dialog}->get_widget('open_vector_SQL_entry')->set_text('');
}

sub build_data_source {
    my($button, $self) = @_;
    my $combo = $self->{dialog}->get_widget('open_vector_driver_combobox');
    my $index = $combo->get_active;
    my $code = '';
    my $format;
    my $template = '';
    my $help = '';
    my $i = -1;
    for my $driver (Geo::OGR::Drivers()) {
	($template, $help) = $driver->DataSourceTemplate;
	next if $template eq '<filename>';
	$i++;
	next unless $i == $index;
	$code = $driver->GetName;
	$format = $driver->FormatName;
	last;
    }
    my @template = split(/[\[\]]/, $template);
    #print STDERR "build $code data source, t = $template\n";

    # ask from user the name for the new data source, and things defined by the template
    my $data_source_name;
    my %input;
    my @ask;
    $i = 0;
    for my $c (@template) {
	my @c = $c =~ /\<(\w+)\>/;
	if ($i % 2 == 1) { # optional
	} else {
	    for (@c) {
		$_ .= '*';
	    }
	}
	push @ask, @c;
	$i++;
    }

    my $dialog = Gtk2::Dialog->new('Build a non-file data source', 
				   $self->{dialog}->get_widget('open_vector_dialog'),
				   'destroy-with-parent',
				   'gtk-cancel' => 'reject',
				   'gtk-ok' => 'ok');
    
    my $vbox = Gtk2::VBox->new(FALSE, 0);
    $vbox->pack_start(Gtk2::Label->new("Define a connection to a $format data source"), FALSE, FALSE, 0);

    my $table = Gtk2::Table->new(1+@ask, 2, TRUE);
    $table->attach(Gtk2::Label->new("Unique name for the data source*:"), 0, 1, 0, 1, 'fill', 'fill', 0, 0);
    my $e = Gtk2::Entry->new();
    $e->set_name('data_source_name');
    $table->attach($e, 1, 2, 0, 1, 'fill', 'fill', 0, 0);
    $i = 1;
    for my $a (@ask) {
	my $l = Gtk2::Label->new($a.":");
	$l->set_justify('left');
	$table->attach($l, 0, 1, $i, $i+1, 'expand', 'fill', 0, 0);
	$e = Gtk2::Entry->new();
	$a =~ s/\*$//;
	$e->set_name($a);
	$table->attach($e, 1, 2, $i, $i+1, 'fill', 'fill', 0, 0);
	$i++;
    }
    $vbox->pack_start($table, FALSE, TRUE, 0);

    my $l = Gtk2::Label->new("* denotes a required entry");
    $l->set_justify('left');
    $vbox->pack_start($l, FALSE, TRUE, 0);
    $l = Gtk2::Label->new($help);
    $l->set_justify('left');
    $vbox->pack_start($l, FALSE, TRUE, 0);

    $dialog->get_content_area()->add($vbox);
 
    $dialog->signal_connect(response => \&add_data_source, [$self, $template, $code]);
    $dialog->show_all;
}

sub get_entries {
    my($widget, $entries) = @_;
    if (isa($widget, 'Gtk2::Container')) {
	$widget->foreach(\&get_entries, $entries);
    } elsif (isa($widget, 'Gtk2::Entry')) {
	my $n = $widget->get_name;
	my $t = $widget->get_text;
	if ($n and $t) {
	    $entries->{$n} = $t;
	}
    }
}

sub add_data_source {
    my($dialog, $response, $x) = @_;

    unless ($response eq 'ok') {
	$dialog->destroy;
	return;
    }

    my($self, $template, $driver) = @$x;

    my %input;

    get_entries($dialog, \%input);

    my @template = split(/[\[\]]/, $template);
    # build connection string;
    my $connection_string = '';
    # at indexes 1,3,.. the contents are optional
    my $i = 0;
    for my $c (@template) {
	my @c = $c =~ /\<(\w+)\>/;
	my $got_input = 0;
	for my $k (keys %input) {
	    for my $p (@c) {
		$got_input = 1 if $k eq $p;
	    }
	    $c =~ s/\<$k\>/$input{$k}/;
	}
	if ($i % 2 == 1) { # optional
	    if ($got_input) {
		$connection_string .= $c;
	    }
	} else {
	    $connection_string .= $c;
	}
	$i++;
    }

    #print STDERR "connection string: $connection_string\n";
    $self->{gui}{resources}{datasources}{$input{data_source_name}} = [$driver, $connection_string];
    fill_named_data_sources_combobox($self, $input{data_source_name});

    # Ensure that the dialog box is destroyed when the user responds.
    $dialog->destroy;
}

sub delete_data_source {
    my($button, $self) = @_;
    my $combo = $self->{dialog}->get_widget('open_vector_datasource_combobox');
    my $active = $combo->get_active();
    return if $active < 0;

    my $model = $combo->get_model;
    my $iter = $model->get_iter_from_string($active);
    my $name = $model->get($iter, 0);
    return if $name eq '';

    $model->remove($iter);
    delete $self->{gui}{resources}{datasources}{$name};
    fill_named_data_sources_combobox($self);
}

sub connect_data_source {
    my($button, $self) = @_;
    my($driver, $data_source) = get_data_source($self);
    unless (fill_layer_treeview($self, $driver, $data_source)) {
	# No layers found in data source
	fill_directory_treeview($self);
    }
}

sub select_directory {
    my($self, $treeview) = @_;
    my($path, $focus_column) = $treeview->get_cursor;
    my $index = $path->to_string if $path;
    if (defined $index) {
	my $dir = $self->{dir_list}->[$index];
	$dir =~ s/^<b>\[//;
	$dir =~ s/\]<\/b>$//;
	my $directory;
	if ($self->{path} eq '') {
	    $self->{volume} = $dir;
	    $directory = File::Spec->rootdir();
	} else {
	    my @directories;
	    for (reverse @{$self->{directory_toolbar}}) {
		push @directories, $_->get_label;
	    }
	    if ($^O eq 'MSWin32') {
		shift @directories; # remove volume
	    }
	    if ($dir eq File::Spec->updir) {
		pop @directories;
	    } else {
		push @directories, $dir;
	    }
	    $directory = File::Spec->catdir(@directories);
	}
	$self->{path} = File::Spec->catpath($self->{volume}, $directory, '');
	fill_directory_treeview($self);
	fill_layer_treeview($self);
    }
}

sub show_schema {
    my($button, $self) = @_;

    my $property_model = $self->{dialog}->get_widget('open_vector_property_treeview')->get_model;
    $property_model->clear;
    my $schema_model = $self->{dialog}->get_widget('open_vector_schema_treeview')->get_model;
    $schema_model->clear;
    my $label = '';
    my $sql = $self->{dialog}->get_widget('open_vector_SQL_entry')->get_text;

    my $vector;
    if ($sql) {

	eval {
	    $vector = Geo::Vector->new( data_source => $self->{_open_data_source}, 
					sql => $sql );
	};
	croak("$@ Is the SQL statement correct?") if $@;
	$label = 'Schema of the SQL query';
	
    } else {

	my $treeview = $self->{dialog}->get_widget('open_vector_layer_treeview');
	my($path, $focus_column) = $treeview->get_cursor;
	my $model = $treeview->get_model;
	my $iter = $model->get_iter($path);
	my $name = $model->get($iter, 0);
	if (defined $name) {
	    $vector = Geo::Vector->new( data_source => $self->{_open_data_source}, 
					layer => $name );
	    $label = "Schema of $name";
	}

    }

    $self->{dialog}->get_widget('open_vector_schema_label')->set_label($label);
    
    my $iter = $property_model->insert (undef, 0);
    $property_model->set ($iter,
			  0, 'Features',
			  1, $vector->feature_count()
			  );
    
    my @world = $vector->world;
    $iter = $property_model->insert (undef, 0);
    $property_model->set ($iter,
			  0, 'Bounding box',
			  1, "minX = $world[0], minY = $world[1], maxX = $world[2], maxY = $world[3]"
			  );
    
    $iter = $property_model->insert (undef, 0);
    my $srs = $vector->srs(format=>'Wkt');
    $srs = 'undefined' unless $srs;
    $property_model->set ($iter,
			  0, 'SpatialRef',
			  1, $srs
			  );
    
    my $schema = $vector->schema();
    for my $name (sort {$b cmp $a} keys %$schema) {
	my $iter = $schema_model->insert (undef, 0);
	my $n = $name;
	$n =~ s/^\.//;
	$schema_model->set ($iter,
			    0, $n,
			    1, $schema->{$name}{TypeName}
			    );
    }
    
}

sub edit_entry {
    my($entry, $event, $self) = @_;
    my $key = $event->keyval;
    if ($key == $Gtk2::Gdk::Keysyms{Up}) {
	$entry->set_text($self->{gui}{history}->arrow_up);
	return 1;
    } elsif ($key == $Gtk2::Gdk::Keysyms{Down}) {
	$entry->set_text($self->{gui}{history}->arrow_down);
	return 1;
    }
}

1;
