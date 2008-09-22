# adds visualization capabilities to Geo::Raster
package Gtk2::Ex::Geo::Raster;

use strict;
use warnings;
use UNIVERSAL qw(isa);
use POSIX;
POSIX::setlocale( &POSIX::LC_NUMERIC, "C" ); # http://www.remotesensing.org/gdal/faq.html nr. 11
use Carp;
use Geo::Raster qw/$INTEGER_GRID $REAL_GRID/;

use vars qw//;

require Exporter;

our @ISA = qw(Exporter Geo::Raster Gtk2::Ex::Geo::Layer);

our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = '0.01';

sub new {
    my($package, %params) = @_;
    my $self = Geo::Raster::new($package, %params);
    Gtk2::Ex::Geo::Layer::new($package, self => $self, %params);
    $self->palette_type('Color table') if $self->{COLOR_TABLE};
    return $self;
}

## @method $type()
#
# @brief Returns the layers type.
# @return Return as type 'int', 'real' or ' ' if no datatype has been set. If 
# the layer is an GDAL-layer then the method returns 'G int' or 'G real'.
sub type {
    my $self = shift;
    my $type = $self->data_type;
    if ($type) {
		$type = $type eq 'Integer' ? 'int' : 'real';
    } else {
		$type = '';
    }
    $type = "G $type" if $self->{GDAL};
    return $type;
}

## @method @supported_palette_types()
# 
# @brief Returns supported color palettes according to the raster grids datatype.
# @return Array of supported palette types names.
# @note Overrides Geo::Layer::supported_palette_types().
sub supported_palette_types {
    my($self) = @_;
    return ('Single color') unless $self->{DATATYPE}; # may happen if not cached
    if ($self->{DATATYPE} == $INTEGER_GRID) {
	return ('Single color','Grayscale','Rainbow','Color table','Color bins','Red channel','Green channel','Blue channel');
    } else {
	return ('Single color','Grayscale','Rainbow','Color bins','Red channel','Green channel','Blue channel');

    }
}

## @method @supported_symbol_types()
#
# @brief Returns supported symbol types according to the raster grids datatype.
# @return Array of supported symbol types names.
# @note Overrides Geo::Layer::supported_symbol_types().
sub supported_symbol_types {
    my($self) = @_;
    return ('No symbol') unless $self->{DATATYPE}; # may happen if not cached
    if ($self->{DATATYPE} == $INTEGER_GRID) {
		return ('No symbol', 'Flow_direction', 'Square', 'Dot', 'Cross');
    } else {
		return ('No symbol', 'Flow_direction', 'Square', 'Dot', 'Cross');
    }
}

## @method void properties_dialog(Gtk2::Ex::Glue gui)
# 
# @brief A request to invoke the properties dialog for this layer object.
# @param[in] gui A Gtk2::Ex::Glue object (contains predefined dialogs).
sub properties_dialog {
    my($self, $gui) = @_;
    if ($self->{GDAL}) {
	$self->open_gdal_properties_dialog($gui);
    } else {
	$self->open_libral_properties_dialog($gui);
    }
}

## @method @menu_items()
#
# @brief Returns a list containing names for the layers supported menu items.
# @return List having the name of each supported menu item.
sub menu_items {
    my $self = shift;
    my @items;
    push @items, ('S_ave...') unless $self->{GDAL};
    push @items, ('C_lip...') if $self->{GDAL};
    push @items, ('V_ectorize...');
    return @items;
}

## @method $menu_action($item, Gtk2::Ex::Glue gui)
#
# @brief Carries out the given menu action.
# @param[in] item Name for the menu action. Supported action names can be gotten 
# with the Geo::Raster::menu_items() method.
# @param[in,out] gui Gtk2::Ex::Glue object.
# @return If it was possible to carry out the requested menu action true, else 
# false.
sub menu_action {
    my($self, $item, $gui) = @_;

    SWITCH: {
	if ($item eq 'S_ave...') {
	    $gui->save_raster($self);
	    return 1;
	}
	if ($item eq 'C_lip...') {
	    $gui->{raster_dialogs}->clip_dialog($self);
	    return 1;
	}
	if ($item eq 'V_ectorize...') {
	    my $ret = $gui->{raster_dialogs}->vectorize_dialog($self);
	    return 1;
	}
    }
    
    return 0;
}

## @method void render($pb)
#
# @brief Renders the raster layer into a Gdk-Pixbuf structure, which will be
# shown to the user by the gui.
#
# @param[in,out] pb Pixel buffer into which the vector layer is rendered.
# @note The layer has to be visible or the method will do nothing.
# @note The grid can have as datatype integer or real.
sub render {
    my($self, $pb) = @_;

    return if !$self->visible();

    $self->_key2value();

    #this will need to be done when there's support in the layer for attributes
    #my $schema = $self->schema();
    #$self->{COLOR_FIELD_VALUE} = $schema->{$self->{COLOR_FIELD}}{Number};

    my $pbw = Geo::Raster::ral_pixbuf_get_world($pb);
    my($minX,$minY,$maxX,$maxY,$pixel_size,$w,$h) = @$pbw;

    my $gdal = $self->{GDAL};

    if ($gdal) {
	$self->cache($minX,$minY,$maxX,$maxY,$pixel_size);
	return unless $self->{GRID} and Geo::Raster::ral_grid_get_height($self->{GRID});
    }

    if ($self->{DATATYPE} == $INTEGER_GRID) {	    

	my $layer = Geo::Raster::ral_make_integer_grid_layer($self);
	if ($layer) {
	    Geo::Raster::ral_render_igrid($pb, $self->{GRID}, $layer);
	    Geo::Raster::ral_destroy_integer_grid_layer($layer);
	}

    } elsif ($self->{DATATYPE} == $REAL_GRID) {
	
	my $layer = Geo::Raster::ral_make_real_grid_layer($self);
	if ($layer) {
	    Geo::Raster::ral_render_rgrid($pb, $self->{GRID}, $layer);
	    Geo::Raster::ral_destroy_real_grid_layer($layer);
	}

    } else {
	croak("bad Gtk2::Ex::Geo::Raster");
    }
}

sub open_gdal_properties_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{gdal_properties_dialog};
    unless ($dialog) {
	$self->{gdal_properties_dialog} = $dialog = $gui->get_dialog('gdal_properties_dialog');
	croak "gdal_properties_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('gdal_properties_dialog')->set_title("Properties of ".$self->name);
	$dialog->get_widget('gdal_properties_dialog')->signal_connect(delete_event => \&cancel_gdal_properties, [$self, $gui]);
	$dialog->get_widget('gdal_properties_apply_button')->signal_connect(clicked => \&apply_gdal_properties, [$self, $gui, 0]);
	$dialog->get_widget('gdal_properties_cancel_button')->signal_connect(clicked => \&cancel_gdal_properties, [$self, $gui]);
	$dialog->get_widget('gdal_properties_ok_button')->signal_connect(clicked => \&apply_gdal_properties, [$self, $gui, 1]);
    } else {
	$dialog->get_widget('gdal_properties_dialog')->move(@{$self->{gdal_properties_dialog_position}});
    }
    
    $self->{backup}->{name} = $self->name;
    $self->{backup}->{alpha} = $self->alpha;
    $self->{backup}->{nodata_value} = $self->nodata_value;

    $dialog->get_widget('gdal_name_entry')->set_text($self->name);
    $dialog->get_widget('gdal_alpha_spinbutton')->set_value($self->alpha);

    my @size = $self->size(of_GDAL=>1);
    $dialog->get_widget('gdal_size_label')->set_text("@size");

    @size = $self->world(of_GDAL=>1);
    $dialog->get_widget('gdal_min_x_label')->set_text($size[0]);
    $dialog->get_widget('gdal_min_y_label')->set_text($size[1]);
    $dialog->get_widget('gdal_max_x_label')->set_text($size[2]);
    $dialog->get_widget('gdal_max_y_label')->set_text($size[3]);

    $dialog->get_widget('gdal_cellsize_label')->set_text($self->cell_size(of_GDAL=>1));

    my $nodata = $self->nodata_value();
    $nodata = '' unless defined $nodata;
    $dialog->get_widget('gdal_nodata_entry')->set_text($nodata);

    @size = $self->value_range(of_GDAL=>1);
    my $text = defined $size[0] ? "@size" : "not available";
    $dialog->get_widget('gdal_minmax_label')->set_text($text);
    
    $dialog->get_widget('gdal_properties_dialog')->show_all;
}

sub apply_gdal_properties {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{gdal_properties_dialog};

    eval {
	my $name = $dialog->get_widget('gdal_name_entry')->get_text;
	$self->name($name);
	my $alpha = $dialog->get_widget('gdal_alpha_spinbutton')->get_value_as_int;
	$self->alpha($alpha);
	
	my $nodata = get_number($dialog->get_widget('gdal_nodata_entry'));
	my $band = $self->{GDAL}->{dataset}->GetRasterBand($self->{GDAL}->{band});
	$band->SetNoDataValue($nodata) if $nodata ne '';
    };
    $gui->message("$@") if $@;

    $self->{gdal_properties_dialog_position} = [$dialog->get_widget('gdal_properties_dialog')->get_position];
    $dialog->get_widget('gdal_properties_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

sub cancel_gdal_properties {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }

    eval {
	$self->alpha($self->{backup}->{alpha});
	$self->name($self->{backup}->{name});
	my $band = $self->{GDAL}->{dataset}->GetRasterBand($self->{GDAL}->{band});
	$band->SetNoDataValue($self->{backup}->{nodata}) if $self->{backup}->{nodata} and $self->{backup}->{nodata} ne '';
    };
    $self->message("$@") if $@;

    my $dialog = $self->{gdal_properties_dialog}->get_widget('gdal_properties_dialog');
    $self->{gdal_properties_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

sub open_libral_properties_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{libral_properties_dialog};
    unless ($dialog) {
	$self->{libral_properties_dialog} = $dialog = $gui->get_dialog('libral_properties_dialog');
	croak "libral_properties_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('libral_properties_dialog')->set_title("Properties of ".$self->name);
	$dialog->get_widget('libral_properties_dialog')->signal_connect(delete_event => \&cancel_libral_properties, [$self, $gui]);
	$dialog->get_widget('libral_properties_apply_button')->signal_connect(clicked => \&apply_libral_properties, [$self, $gui, 0]);
	$dialog->get_widget('libral_properties_cancel_button')->signal_connect(clicked => \&cancel_libral_properties, [$self, $gui]);
	$dialog->get_widget('libral_properties_ok_button')->signal_connect(clicked => \&apply_libral_properties, [$self, $gui, 1]);
    } else {
	$dialog->get_widget('libral_properties_dialog')->move(@{$self->{libral_properties_dialog_position}});
    }
    
    $self->{backup}->{name} = $self->name;
    $self->{backup}->{alpha} = $self->alpha;
    $self->{backup}->{nodata_value} = $self->nodata_value;
    my @world = $self->world();
    $self->{backup}->{world} = \@world;
    $self->{backup}->{cell_size} = $self->cell_size();

    $dialog->get_widget('libral_name_entry')->set_text($self->name);
    $dialog->get_widget('libral_alpha_spinbutton')->set_value($self->alpha);

    my @size = $self->size();
    $dialog->get_widget('libral_size_label')->set_text("@size");

    $dialog->get_widget('libral_min_x_entry')->set_text($world[0]);
    $dialog->get_widget('libral_min_y_entry')->set_text($world[1]);
    $dialog->get_widget('libral_max_x_entry')->set_text($world[2]);
    $dialog->get_widget('libral_max_y_entry')->set_text($world[3]);

    $dialog->get_widget('libral_cellsize_entry')->set_text($self->cell_size());

    my $nodata = $self->nodata_value();
    $nodata = '' unless defined $nodata;
    $dialog->get_widget('libral_nodata_entry')->set_text($nodata);

    @size = $self->value_range();
    my $text = defined $size[0] ? "@size" : "not available";
    $dialog->get_widget('libral_minmax_label')->set_text($text);
    
    $dialog->get_widget('libral_properties_dialog')->show_all;
}

sub apply_libral_properties {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{libral_properties_dialog};

    eval {
	my $name = $dialog->get_widget('libral_name_entry')->get_text;
	$self->name($name);
	my $alpha = $dialog->get_widget('libral_alpha_spinbutton')->get_value_as_int;
	$self->alpha($alpha);

	my @world;
	$world[0] = get_number($dialog->get_widget('libral_min_x_entry'));
	$world[1] = get_number($dialog->get_widget('libral_min_y_entry'));
	$world[2] = get_number($dialog->get_widget('libral_max_x_entry'));
	$world[3] = get_number($dialog->get_widget('libral_max_y_entry'));
	my $cell_size = get_number($dialog->get_widget('libral_cellsize_entry'));
    
	my ($minX,$minY) = ($world[0], $world[1]);
	my ($maxX,$maxY) = ($world[2], $world[3]);
    
	for ($minX,$minY,$maxX,$maxY,$cell_size) {
	    $_ = undef if /^\s*$/;
	}
    
	$self->world(minX=>$minX, minY=>$minY, maxX=>$maxX, maxY=>$maxY, cell_size=>$cell_size);
	
	my $nodata = get_number($dialog->get_widget('libral_nodata_entry'));
	$self->nodata_value($nodata);
    };
    $gui->message("$@") if $@;

    $self->{libral_properties_dialog_position} = [$dialog->get_widget('libral_properties_dialog')->get_position];
    $dialog->get_widget('libral_properties_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

sub cancel_libral_properties {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }

    $self->alpha($self->{backup}->{alpha});
    $self->name($self->{backup}->{name});
    $self->world( minX => $self->{backup}->{world}->[0], 
		  minY => $self->{backup}->{world}->[1],
		  cell_size => $self->{backup}->{cell_size} );
    $self->nodata_value($self->{backup}->{nodata});
    
    my $dialog = $self->{libral_properties_dialog}->get_widget('libral_properties_dialog');
    $self->{libral_properties_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

sub get_number {
    my($entry) = @_;
    my $text = $entry->get_text;
    $text =~ s/\s//g;
    $text =~ s/,/./;
    $text;
}

1;
