# adds visualization capabilities to Geo::Vector
package Gtk2::Ex::Geo::Vector;

use strict;
use warnings;
use POSIX;
POSIX::setlocale( &POSIX::LC_NUMERIC, "C" ); # http://www.remotesensing.org/gdal/faq.html nr. 11
use Carp;
use Geo::Vector qw/:all/;

use vars qw//;

require Exporter;

our @ISA = qw(Exporter Geo::Vector Gtk2::Ex::Geo::Layer);

our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = '0.01';

sub new {
    my($package, %params) = @_;
    my $self = Geo::Vector::new($package, %params);
    Gtk2::Ex::Geo::Layer::new($package, self => $self, %params);
    $self->name($self->{ogr_layer}->GetName()) if $self->{ogr_layer};
    return $self;
}

## @method $type()
#
# @brief Returns the type of the layer.
# @return A string ('V'== vector layer, ' T' == feature layer, ' L'== ogr layer,
# ' U' == update layer) representing the type of the layer.
sub type {
    my $self = shift;
    my $type = 'V';
    if ( $self->{features} ) {
	$type .= ' T';
    }
    elsif ( $self->{ogr_layer} ) {
	$type .= ' L';
	}
    $type .= ' U' if $self->{update};
    return $type;
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
    elsif ( $self->{ogr_layer} ) {
	#$gui->{vector_dialogs}->properties_dialog($self);
	
	$self->open_properties_dialog($gui);
    }
    else {
	$gui->message("no data in this layer");
    }
}

## @method @menu_items()
#
# @brief The method returns a list of supported menu items names.
# @return A list list of menu item names as strings.
sub menu_items {
    my $self = shift;
    return ( $self->SUPER::menu_items(), '', 
	     'C_lip...', '_Features...', '_Vertices...', 'R_asterize...' );
}

## @method $menu_action($item, $gui)
#
# @brief The method executes the given menu item command.
# @param[in] item A name of menu item. One of the items gotten from menu_items().
# @param[in] gui A reference to a GUI object, like for example
# Gtk2::Ex::Geo::Glue.
# @return The method returns true if the given menu item was supported, else false.
sub menu_action {
    my ( $self, $item, $gui ) = @_;
    if ($self->SUPER::menu_action($item, $gui)) {
	#$gui->{vector_dialogs}->features_dialog($self);
	$self->open_features_dialog($gui);
	$gui->{overlay}->restore_pixmap;
	$gui->{overlay}->draw_selection;
    }
    if ( $self->{features} ) {
	return features_menu_action( $self, $item, $gui );
    }
    elsif ( $self->{ogr_layer} ) {
	return layer_menu_action( $self, $item, $gui );
    }
    else {
	my $ret = 0;
	$ret = 1
	    if $item eq 'C_lip...'
	    or $item eq '_Features...'
	    or $item eq '_Vertices...'
	    or $item eq 'R_asterize...';
	$gui->message("no data in this layer") if $ret;
	return $ret;
    }
}

## @method $features_menu_action($item, $gui)
#
# @brief The method executes the given menu item command for the feature layer.
# @param[in] item A name of menu item. One of the items gotten from menu_items().
# @param[in] gui A reference to a GUI object, like for example Gtk2::Ex::Geo::Glue.
# @return The method returns true if the given menu item was supported, else
# false.
# @todo Implementing C_lip..., _Vertices... and R_asterize...
sub features_menu_action {
    my ( $self, $item, $gui ) = @_;
  SWITCH: {
      if ( $item eq 'C_lip...' ) {
	  $gui->message("not yet implemented");
	  return 1;
      }
      if ( $item eq '_Features...' ) {
	  $gui->{vector_dialogs}->browse_features2($self);
	  return 1;
      }
      if ( $item eq '_Vertices...' ) {
	  $gui->message("not yet implemented");
	  return 1;
      }
      if ( $item eq 'R_asterize...' ) {
	  $gui->message("not yet implemented");
	  return 1;
      }
  }
    return 0;
}

## @method $layer_menu_action($item, $gui)
#
# @brief The method executes the given menu item command for the ogr layer.
# @param[in] item A name of menu item. One of the items gotten from menu_items().
# @param[out] gui A reference to a GUI object, like for example Gtk2::Ex::Geo::Glue.
# @return The method returns true if the given menu item was supported, else false.
sub layer_menu_action {
    my($self, $item, $gui) = @_;
    SWITCH: {
	if ($item eq 'C_lip...') {
	    #my $ret = $gui->{vector_dialogs}->clip_dialog($self);

	    $self->open_clip_dialog($gui);

	    return 1;
	}
	if ($item eq '_Features...') {
	    #$gui->{vector_dialogs}->features_dialog($self);

	    $self->open_features_dialog($gui);

	    return 1;
	}
	if ($item eq '_Vertices...') {
	    $self->open_vertices_dialog($gui);
	    return 1;
	}
	if ($item eq 'R_asterize...') {
	    $gui->{vector_dialogs}->rasterize_dialog($self);
	    return 1;
	}
    }
    return 0;
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
	    unless defined $RENDER_AS{$render_as};
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
# @brief Renders the vector layer into a Gdk-Pixbuf structure, which will be
# shown to the user by the gui.
#
# @param[in,out] pb Pixel buffer into which the vector layer is rendered.
# @note The layer has to be visible while using the method!
sub render {
    my ( $self, $pb, $cr, $overlay, $viewport ) = @_;
    return if !$self->visible();
    
    $self->_key2value();
    
    if ( $self->{features} ) {
	
	#$self->{COLOR_FIELD_VALUE} = -1;
	#$self->{SYMBOL_FIELD_VALUE} = -2;
	$self->{RENDER_AS}       = 'Native';
	$self->{RENDER_AS_VALUE} = $RENDER_AS{ $self->{RENDER_AS} };
	
	my $layer = ral_visual_feature_table_create( $self, $self->{features} );
	if ($layer) {
	    ral_visual_feature_table_render( $layer, $pb ) if $pb;
	    ral_visual_feature_table_destroy($layer);
	}
	
    }
    elsif ( $self->{ogr_layer} ) {
	
	my $schema = $self->schema();
	
	$self->{COLOR_FIELD_VALUE} =
	    exists $schema->{ $self->{COLOR_FIELD} } ? 
	    $schema->{ $self->{COLOR_FIELD} }{Number} : -1;
	
	$self->{SYMBOL_FIELD_VALUE} =
	    $self->{SYMBOL_FIELD} eq 'Fixed size' ? 
	    -2 : $schema->{ $self->{SYMBOL_FIELD} }{Number};
	
	$self->{RENDER_AS}       = 'Native' unless defined $self->{RENDER_AS};
	$self->{RENDER_AS_VALUE} = $RENDER_AS{ $self->{RENDER_AS} };
	
	# move xs from Geo::Vector into this package's xs code
	my $layer = Geo::Vector::ral_visual_layer_create( $self, $self->{OGRLayerH} );
	if ($layer) {
	    Geo::Vector::ral_visual_layer_render( $layer, $pb ) if $pb;
	    Geo::Vector::ral_visual_layer_destroy($layer);
	}
	
	if ( $self->{HAS_BORDER} ) {

	    my @color = @{$self->{BORDER_COLOR}};
	    push @color, 255;
	    my $border = Geo::Layer->new( alpha => $self->{ALPHA}, single_color => \@color );
	    $border->{RENDER_AS_VALUE} = $RENDER_AS{Lines};
	    my $layer = ral_visual_layer_create( $border, $self->{OGRLayerH} );
	    if ($layer) {
		ral_visual_layer_render( $layer, $pb ) if $pb;
		ral_visual_layer_destroy($layer);
	    }
	}

	my $labeling = $self->labeling;
	if ($labeling->{field} ne 'No Labels') {

	    my $field;
	    if ($labeling->{field} eq 'FID') {
		$field = -1;
	    } else {
		my $schema = $self->schema();
		$schema = $schema->{$labeling->{field}};
		croak "Geo::Vector::render: no such field: $labeling->{field}" unless $schema;
		$field = $schema->{Number};
	    }

	    my @color = @{$labeling->{color}};
	    $color[3] = int($self->{ALPHA}*$color[3]/255);
	    for (@color) {
		$_ /= 255;
	    }
	    $cr->set_source_rgba(@color);

	    my $wc = -0.5;
	    my $hc = -0.5;
	    my $dw = 0;
	    for ($labeling->{placement}) {
		$hc = -1.5 if /Top/;
		$hc = 0.5 if /Bottom/;
		if (/left/) {$wc = -1; $dw = -6};
		if (/right/) {$wc = 0; $dw = 10};
	    }
	    my $font_desc = Gtk2::Pango::FontDescription->from_string($labeling->{font});
	    
	    $self->{ogr_layer}->SetSpatialFilterRect(@$viewport);
	    $self->{ogr_layer}->ResetReading();

	    my $f;
	    while ($f = $self->{ogr_layer}->GetNextFeature()) {
	
		my $geometry = $f->GetGeometryRef();

		my ($size, @point) = label_placement($geometry, $overlay->{pixel_size});
		
		last unless (@point and defined($point[0]) and defined($point[1]));

		next if ($labeling->{min_size} > 0 and $size < $labeling->{min_size});

		next if 
		    $point[0] < $viewport->[0] or 
		    $point[0] > $viewport->[2] or
		    $point[1] < $viewport->[1] or
		    $point[1] > $viewport->[3];

		my @pixel = $overlay->point2pixmap_pixel(@point);

		my $str = $field < 0 ? $f->GetFID : $f->GetFieldAsString($field);
		next unless defined $str or $str eq '';

		my $layout = Gtk2::Pango::Cairo::create_layout($cr);
		$layout->set_font_description($font_desc);    
		$layout->set_text($str);
		my($width, $height) = $layout->get_pixel_size;
		$cr->move_to($pixel[0]+$wc*$width+$dw, $pixel[1]+$hc*$height);
		Gtk2::Pango::Cairo::show_layout($cr, $layout);

	    }
	}
    }
}

sub label_placement {
    my($geom, $scale) = @_;
    my $type = $geom->GetGeometryType;
    if ($type == $Geo::OGR::wkbPoint or $type == $Geo::OGR::wkbPoint25D) {
	return (0, $geom->GetX(0), $geom->GetY(0));
    } elsif ($type == $Geo::OGR::wkbLineString or $type == $Geo::OGR::wkbLineString25D) {
	my $len = line_string_length($geom);
	my $h = $len/2;
	my $x0 = $geom->GetX(0);
	my $y0 = $geom->GetY(0);
	return ($x0, $y0) if $len == 0;
	for (1..$geom->GetPointCount-1) {
	    my $x1 = $geom->GetX($_);
	    my $y1 = $geom->GetY($_);
	    my $l = sqrt(($x1-$x0)*($x1-$x0)+($y1-$y0)*($y1-$y0));
	    if ($h > $l) {
		$h -= $l;
	    } else {
		return ($len/$scale, $x0+($x1-$x0)*$h/$l, $y0+($y1-$y0)*$h/$l);
	    }
	    $x0 = $x1;
	    $y0 = $y1;
	}
    } elsif ($type == $Geo::OGR::wkbPolygon or $type == $Geo::OGR::wkbPolygon25D) {
	my $c = $geom->Centroid;
	return ($geom->GetArea/($scale*$scale), $c->GetX, $c->GetY);
    } elsif ($type == $Geo::OGR::wkbMultiLineString or $type == $Geo::OGR::wkbMultiLineString25D) {
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
    } elsif ($type == $Geo::OGR::wkbMultiPolygon or $type == $Geo::OGR::wkbMultiPolygon25D) {
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
	print STDERR "label placement not defined for geometry type Geo::OGR::GeometryType($type)\n";
	return ();
    }
    print STDERR "couldn't compute label placement\n";
    return ();
}

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
    
    for my $f (values %$features) {
	
	next unless $f; # should not happen
	
	my $geom = $f->GetGeometryRef();
	next unless $geom;
	
	$overlay->render_geometry($gc, $geom);
	
    }
}

sub open_properties_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{properties_dialog};
    unless ($dialog) {
	$self->{properties_dialog} = $dialog = $gui->get_dialog('properties_dialog');
	croak "properties_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('properties_dialog')->set_title("Properties of ".$self->name);
	$dialog->get_widget('properties_dialog')->signal_connect(delete_event => \&cancel_properties, [$self, $gui]);
	$dialog->get_widget('border_color_button')->signal_connect(clicked => \&border_color_dialog, [$self]);
	$dialog->get_widget('apply_properties_button')->signal_connect(clicked => \&apply_properties, [$self, $gui, 0]);
	$dialog->get_widget('cancel_properties_button')->signal_connect(clicked => \&cancel_properties, [$self, $gui]);
	$dialog->get_widget('ok_properties_button')->signal_connect(clicked => \&apply_properties, [$self, $gui, 1]);
    } else {
	$dialog->get_widget('properties_dialog')->move(@{$self->{properties_dialog_position}});
    }
    
    $self->{backup}->{name} = $self->name;
    $self->{backup}->{render_as} = $self->render_as;
    $self->{backup}->{alpha} = $self->alpha;
    $self->{backup}->{has_border} = $self->has_border;
    @{$self->{backup}->{border_color}} = $self->border_color;
    
    $dialog->get_widget('geom_type_lbl')->set_text($self->geometry_type);
    
    my $combo = $dialog->get_widget('property_render_as_combobox');
    my $model = $combo->get_model;
    $model->clear;
    for (sort {$RENDER_AS{$a} <=> $RENDER_AS{$b}} keys %RENDER_AS) {
	$model->set ($model->append, 0, $_);
    }
    my $a = 0;
    $a = $self->render_as;
    $a = $RENDER_AS{$a} if defined $a;
    $combo->set_active($a);
    
    my $count = $self->{ogr_layer}->GetFeatureCount();
    $count .= " (estimated)";
    $dialog->get_widget('feature_count_lbl')->set_text($count);
    
    $dialog->get_widget('datasource_lbl')->set_text($self->{datasource});
    $dialog->get_widget('sql_lbl')->set_text($self->{sql});
    
    $dialog->get_widget('name_entry')->set_text($self->name);
    $dialog->get_widget('alpha_spinbutton')->set_value($self->alpha);
    
    my $polygon = $self->geometry_type() =~ /Polygon/;
    $dialog->get_widget('border_checkbutton')->set_sensitive($polygon);
    $dialog->get_widget('border_color_button')->set_sensitive($polygon);
    $dialog->get_widget('ogr_properties_color0_label')->set_sensitive($polygon);
    $dialog->get_widget('ogr_properties_color_label')->set_sensitive($polygon);
    $dialog->get_widget('border_checkbutton')->set_active($self->has_border);
    
    my @color = $self->border_color;
    $dialog->get_widget('ogr_properties_color_label')->set_text("@color");
    
    $dialog->get_widget('properties_dialog')->show_all;
}

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
    $self->has_border($has_border);
    my @color = split(/ /, $dialog->get_widget('ogr_properties_color_label')->get_text);
    $self->border_color(@color);
    $self->{properties_dialog_position} = [$dialog->get_widget('properties_dialog')->get_position];
    $dialog->get_widget('properties_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

sub cancel_properties {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    $self->alpha($self->{backup}->{alpha});
    $self->name($self->{backup}->{name});
    $self->render_as($self->{backup}->{render_as});
    $self->has_border($self->{backup}->{has_border});
    $self->border_color(@{$self->{backup}->{border_color}});
    my $dialog = $self->{properties_dialog}->get_widget('properties_dialog');
    $self->{properties_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

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
	$dialog->get_widget('features_dialog')->set_title("Features of ".$self->name);
	$dialog->get_widget('features_dialog')->signal_connect(delete_event => \&close_features_dialog, [$self, $gui]);
	
	my $selection = $dialog->get_widget('feature_treeview')->get_selection;
	$selection->set_mode('multiple');
	$selection->signal_connect(changed => \&feature_activated, [$self, $gui]);
	
	$dialog->get_widget('spinbutton1')->signal_connect(value_changed => \&fill_ftv, [$self, $gui]);
	$dialog->get_widget('spinbutton2')->signal_connect(value_changed => \&fill_ftv, [$self, $gui]);
	
	$dialog->get_widget('features_vertices_button')->signal_connect(clicked => \&vertices_of_selected_features, [$self, $gui]);
	$dialog->get_widget('make_selection-button')->signal_connect(clicked => \&make_selection, [$self, $gui]);
	$dialog->get_widget('clip_selected-button')->signal_connect(clicked => \&clip_selected_features, [$self, $gui]);
	$dialog->get_widget('zoom-to-button')->signal_connect(clicked => \&zoom_to_selected_features, [$self, $gui]);
	$dialog->get_widget('close-button')->signal_connect(clicked => \&close_features_dialog, [$self, $gui]);

    } else {
	$dialog->get_widget('features_dialog')->move(@{$self->{features_dialog_position}}) if $self->{features_dialog_position};
    }
    
    my $schema = $self->schema;
    
    my @columns = ('ID');
    my @coltypes = ('Glib::Int');
    
    # OGR field name to GTK type name
    my %t2t = (Integer=>'Int', Real=>'Double');
    
    for my $name (sort {$schema->{$a}{Number} <=> $schema->{$b}{Number}} keys %$schema) {
	next if $name eq 'FID';
	my $n = $name;
	$n =~ s/_/__/g;
	my $type = $t2t{$schema->{$name}{TypeName}};
	$type = 'String' unless $type;
	push @columns, $n;
	push @coltypes, 'Glib::'.$type;
    }
    
    my $tv = $dialog->get_widget('feature_treeview');
    
    my $model = Gtk2::TreeStore->new(@coltypes);
    $tv->set_model($model);
    
    for ($tv->get_columns) {
	$tv->remove_column($_);
    }
    
    my $i = 0;
    foreach my $column (@columns) {
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
}

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


sub fill_ftv {
    my($self, $gui) = @{$_[1]};

    my $dialog = $self->{features_dialog};
    my $treeview = $dialog->get_widget('feature_treeview');
    my $overlay = $gui->{overlay};

    my $from = $dialog->get_widget('spinbutton1')->get_value_as_int;
    my $count = $dialog->get_widget('spinbutton2')->get_value_as_int;

    my $schema = $self->schema;
    my $model = $treeview->get_model;

    $model->clear;

    my @fnames;
    for my $name (sort {$schema->{$a}{Number} <=> $schema->{$b}{Number}} keys %$schema) {
	next if $name eq 'FID';
	push @fnames, $name;
    }

    my $features = $self->features( focus => [$overlay->get_focus()], from => $from, count => $count );

    my @recs;
    for my $f (@$features) {
	my @rec;
	my $rec = 0;

	push @rec, $rec++;
	push @rec, $f->GetFID;

	for my $name (@fnames) {
	    push @rec, $rec++;
	    push @rec, $f->GetField($name);
	}

	push @recs,\@rec;
    }
    
    for my $rec (@recs) {
	
	my $iter = $model->insert (undef, 999999);
	$model->set ($iter, @$rec);
	
    }

    $self->set_selected_features($treeview);
    
}

sub get_selected_features {
    my($self, $selection) = @_;
    my @sel = $selection->get_selected_rows;
    my %sel;
    for (@sel) {
	$sel{$_->to_string} = 1;
    }
    
    my $tv = $selection->get_tree_view;;
    my $model = $tv->get_model;
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

sub set_selected_features {
    my($self, $treeview) = @_;
    my $selected = $self->selected_features();
    my $selection = $treeview->get_selection;
    my $model = $treeview->get_model;
    my $iter = $model->get_iter_first();
    while ($iter) {
	my($id) = $model->get($iter, 0);
	$selection->select_iter($iter) if $selected->{$id};
	$iter = $model->iter_next($iter);
    }
}

sub feature_activated {
    my $selection = shift;
    my($self, $gui) = @{$_[0]};

    my $features = $self->get_selected_features($selection);
    $features = $self->features(with_id=>[keys %$features]);
    return unless $features;
    return unless @$features;
    $self->selected_features($features);

    my $overlay = $gui->{overlay};
    $overlay->create_backup_pixmap;
    $overlay->restore_pixmap;

    my $gc = Gtk2::Gdk::GC->new($overlay->{pixmap});
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535,0,0));

    for my $f (@$features) {

	next unless $f; # should not happen

	my $geom = $f->GetGeometryRef();
	next unless $geom;

	$overlay->render_geometry($gc, $geom);
	
    }

    $overlay->update_image;

}

sub zoom_to_selected_features {
    my($self, $gui) = @{$_[1]};

    my $dialog = $self->{features_dialog};
    my $treeview = $dialog->get_widget('feature_treeview');
    my $features = $self->get_selected_features($treeview->get_selection);
    $features = $self->features(with_id=>[keys %$features]);

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

    $gui->{overlay}->zoom_to(@extent) if @extent;
}

sub clip_selected_features {
    my($self, $gui) = @{$_[1]};
    $self->open_clip_dialog($gui);
}

sub vertices_of_selected_features {
    my($self, $gui) = @{$_[1]};
    $self->open_vertices_dialog($gui);
}

sub make_selection {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{features_dialog};
    my $treeview = $dialog->get_widget('feature_treeview');
    my $features = $self->get_selected_features($treeview->get_selection);
    $features = $self->features(with_id=>[keys %$features]);
    for (@$features) {
	my $geom = $_->GetGeometryRef();
	next unless $geom;
	$gui->{overlay}->{selection} = $geom->Clone();
	$gui->{overlay}->{selection}->ACQUIRE;
	last;
    }
}

# vertices dialog

sub open_vertices_dialog {
    my($self, $gui) = @_;
    my $dialog = $self->{vertices_dialog};
    unless ($dialog) {
	$self->{vertices_dialog} = $dialog = $gui->get_dialog('vertices_dialog');
	croak "vertices_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('vertices_dialog')->set_title("Vertices of ".$self->name);
	$dialog->get_widget('vertices_dialog')->signal_connect(delete_event => \&close_vertices_dialog, [$self, $gui]);
	
	my $selection = $dialog->get_widget('vertices_treeview')->get_selection;
	$selection->set_mode('multiple');
	$selection->signal_connect(changed => \&vertices_activated, [$self, $gui]);
	
	$dialog->get_widget('vertices_from_spinbutton')->signal_connect(value_changed => \&fill_vtv, [$self, $gui]);
	$dialog->get_widget('vertices_max_spinbutton')->signal_connect(value_changed => \&fill_vtv, [$self, $gui]);
	
	$dialog->get_widget('vertices_close_button')->signal_connect(clicked => \&close_vertices_dialog, [$self, $gui]);

    } else {
	$dialog->get_widget('vertices_dialog')->move(@{$self->{vertices_dialog_position}}) if $self->{vertices_dialog_position};
    }

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
}

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
    $features = $self->features(with_id=>[keys %$features]);
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
	my $l = $self->{ogr_layer};
	$l->SetSpatialFilterRect($overlay->get_focus());
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

    my $i = 0;
    for my $d (@data) {
	$self->set_geom_data($d, $i, $d->[2], $model);
	$i++;
    }
}

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

	my @rect = $gui->{overlay}->get_focus;
	my $s = $gui->{overlay}->{selection};
	my $a = ($s and ref($s) eq 'Geo::OGR::Geometry');
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

sub vertices_activated {
    my $selection = $_[0];
    my($self, $gui) = @{$_[1]};

    my $overlay = $gui->{overlay};

    my $pixmap = $overlay->{pixmap};
    my $GIDS = $self->{GIDS};

    $overlay->create_backup_pixmap;
    $overlay->restore_pixmap;

    my $gc = Gtk2::Gdk::GC->new($overlay->{pixmap});
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535, 0, 0));

    my @sel = $selection->get_selected_rows;

    for (@sel) {

	my $selected = $_->to_string;

	next unless exists $GIDS->{$selected};

	my @path = split /:/, $GIDS->{$selected};

	my $f = $self->{ogr_layer}->GetFeature($path[0]);
	my $geom = $f->GetGeometryRef();
	for my $i (1..$#path-1) {
	    $geom = $geom->GetGeometryRef($path[$i]);
	}
	my @p = ($geom->GetX($path[$#path]), $geom->GetY($path[$#path]));

	@p = $overlay->point2pixmap_pixel(@p);	
	
	$pixmap->draw_line($gc, $p[0]-4, $p[1], $p[0]+4, $p[1]);
	$pixmap->draw_line($gc, $p[0], $p[1]-4, $p[0], $p[1]+4);
	
    }

    $overlay->update_image;

}

# clip dialod

sub open_clip_dialog {
    my($self, $gui) = @_;

    my $dialog = $self->{clip_dialog};
    unless ($dialog) {
	$self->{clip_dialog} = $dialog = $gui->get_dialog('vector_clip_dialog');
	croak "clip_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('vector_clip_dialog')->set_title("Clip from ".$self->name);
	$dialog->get_widget('vector_clip_dialog')->signal_connect(delete_event => \&close_clip_dialog, [$self, $gui]);

	$dialog->get_widget('clip_datasource_button')->signal_connect
	    (clicked=>\&Gtk2::Ex::Geo::GDALDialog::select_directory, [$self, $gui]);

	$dialog->get_widget('clip_cancel_button')->signal_connect(clicked => \&cancel_clip, [$self, $gui]);
	$dialog->get_widget('clip_ok_button')->signal_connect(clicked => \&do_clip, [$self, $gui, 1]);
	$dialog->get_widget('clip_datasource_entry')->signal_connect(changed => \&clip_datasource_changed, [$self, $gui]);
	
    } else {
	$dialog->get_widget('vector_clip_dialog')->move(@{$self->{clip_dialog_position}}) if $self->{clip_dialog_position};
    }

    my %drivers = drivers();
    my $combo = $dialog->get_widget('clip_driver_combobox');
    my $model = $combo->get_model;
    $model->clear;
    #$model->set($model->append, 0, "");
    
    # remove this when #1687 is fixed
    my %buggy_drivers = ('UK .NTF' => 1,
			 SDTS => 1,
			 S57 => 1,
			 VRT => 1,
			 AVCBin => 1,
			 REC => 1,
			 CSV => 1,
			 GML => 1,
			 KML => 1,
			 OGDI => 1);

    for (sort keys %drivers) {

	next if $buggy_drivers{$_};

	$model->set($model->append, 0, $_);
    }
    $combo->set_active(0);
    $dialog->get_widget('clip_name_entry')->set_text('clip');
    $dialog->get_widget('clip_datasource_entry')->set_text('.');
    my $s = $self->selected_features;
    $s = keys %$s;
    $dialog->get_widget('clip_count_label')->set_label("$s features selected");

    $dialog->get_widget('vector_clip_dialog')->show_all;
}

sub do_clip {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{properties_dialog};

    my %ret;
    $ret{layer_name} = $dialog->get_widget('clip_name_entry')->get_text;
    $ret{datasource} = $dialog->get_widget('clip_datasource_entry')->get_text;
	
    my $vector = new Geo::Vector( datasource => $ret{datasource} );
    my $layers = $vector->layers();
    
    if ($layers->{$ret{layer_name}}) {
	
	$gui->message("Datasource '$ret{datasource}' already contains a layer '$ret{layer_name}'.");
	return;
	
    } else {
	
	my $combo = $dialog->get_widget('clip_driver_combobox');
	my $model = $combo->get_model;
	my $iter = $model->get_iter_from_string($combo->get_active());
	$ret{driver} = $model->get($iter);
	
	my $new_layer = $self->clip(%ret);
	$gui->add_layer($new_layer, $ret{layer_name}, 1);
	#$gui->set_layer($new_layer);
	$gui->{overlay}->render;
	
    }

    $self->{clip_dialog_position} = [$dialog->get_widget('vector_clip_dialog')->get_position];
    $dialog->get_widget('vector_clip_dialog')->hide();
    $gui->{overlay}->render;
}

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

sub clip_datasource_changed {
    my $entry = $_[0];
    my($self, $gui) = @{$_[1]};
    my $text = $entry->get_text();
    my $ds;
    eval {
	$ds = Geo::OGR::Open($text);
    };
    if ($@) {
	$gui->message("error opening datasource: '$text': $@");
	return;
    }
    return unless $ds; # can't be opened as a datasource
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

1;
