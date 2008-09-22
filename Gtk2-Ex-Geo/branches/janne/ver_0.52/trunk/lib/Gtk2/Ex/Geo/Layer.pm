# adds visualization capabilities to Geo::Layer
package Gtk2::Ex::Geo::Layer;

use strict;
use warnings;
use POSIX;
POSIX::setlocale( &POSIX::LC_NUMERIC, "C" ); # http://www.remotesensing.org/gdal/faq.html nr. 11
use Carp;

use vars qw/$MAX_INT $MAX_REAL $color_cell_size %PALETTE_TYPE %SYMBOL_TYPE %LABEL_PLACEMENT/;

require Exporter;

our @ISA = qw(Exporter Geo::Layer);

our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = '0.01';

$MAX_INT = 999999;
$MAX_REAL = 999999999.99;

$color_cell_size = 20;

%PALETTE_TYPE = ( 'Single color' => 0, 
		  Grayscale => 1, 
		  Rainbow => 2, 
		  'Color table' => 3, 
		  'Color bins' => 4,
		  'Red channel' => 5, 
		  'Green channel' => 6, 
		  'Blue channel' => 7,
		  );

%SYMBOL_TYPE = ( 'No symbol' => 0, 
		 'Flow_direction' => 1, 
		 Square => 2, 
		 Dot => 3, 
		 Cross => 4, 
		 'Wind rose' => 6,
		 );

%LABEL_PLACEMENT = ( 'Center' => 0, 
		     'Center left' => 1, 
		     'Center right' => 2, 
		     'Top left' => 3, 
		     'Top center' => 4, 
		     'Top right' => 5, 
		     'Bottom left' => 6, 
		     'Bottom center' => 7, 
		     'Bottom right' => 8,
		     );

## @cmethod @palette_types()
#
# @brief Returns a list of valid palette types (strings).
# @return a list of valid palette types (strings).
sub palette_types {
    my($class) = @_;
    return keys %PALETTE_TYPE;
}

## @cmethod @symbol_types()
#
# @brief Returns a list of valid symbol types (strings).
# @return a list of valid symbol types (strings).
sub symbol_types {
    my($class) = @_;
    return keys %SYMBOL_TYPE;
}

sub new {
    my($class, %params) = @_;
    my $self = $params{self} ? $params{self} : {};
    defaults($self, %params);
    return $self if $params{self};
    bless $self => (ref($class) or $class);
}

sub defaults {
    my($self, %params) = @_;

    # set defaults for all

    $self->{NAME} = '' unless exists $self->{NAME};
    $self->{ALPHA} = 255 unless exists $self->{ALPHA};
    $self->{VISIBLE} = 1 unless exists $self->{VISIBLE};
    $self->{PALETTE_TYPE} = 'Single color' unless exists $self->{PALETTE_TYPE};

    $self->{SYMBOL_TYPE} = 'No symbol' unless exists $self->{SYMBOL_TYPE};
    $self->{SYMBOL_SIZE} = 5 unless exists $self->{SYMBOL_SIZE}; # also the max size of the symbol, if symbol_scale is used
    $self->{SYMBOL_SCALE_MIN} = 0 unless exists $self->{SYMBOL_SCALE_MIN}; # similar to grayscale scale
    $self->{SYMBOL_SCALE_MAX} = 0 unless exists $self->{SYMBOL_SCALE_MAX};

    $self->{HUE_AT_MIN} = 235 unless exists $self->{HUE_AT_MIN}; # as in libral visual.h
    $self->{HUE_AT_MAX} = 0 unless exists $self->{HUE_AT_MAX}; # as in libral visual.h
    $self->{HUE_DIR} = 1 unless exists $self->{HUE_DIR}; # from min up to max
    $self->{HUE} = -1 unless exists $self->{HUE}; # grayscale is gray scale

    $self->{SINGLE_COLOR} = [255,255,255,255] unless exists $self->{SINGLE_COLOR};

    $self->{COLOR_BINS} = [] unless exists $self->{COLOR_BINS};

    # scales are used in rendering in some palette types
    $self->{COLOR_SCALE_MIN} = 0 unless exists $self->{COLOR_SCALE_MIN};
    $self->{COLOR_SCALE_MAX} = 0 unless exists $self->{COLOR_SCALE_MAX};

    # focus field is used in rendering and rasterization
    # this is the name of the field
    $self->{COLOR_FIELD} = '' unless exists $self->{COLOR_FIELD};
    $self->{SYMBOL_FIELD} = 'Fixed size' unless exists $self->{SYMBOL_FIELD};
    $self->{LABEL_FIELD} = 'No Labels'  unless exists $self->{LABEL_FIELD};

    $self->{LABEL_PLACEMENT} = 'Center' unless exists $self->{LABEL_PLACEMENT};
    $self->{LABEL_FONT} = 'sans 12' unless exists $self->{LABEL_FONT};
    $self->{LABEL_COLOR} = [0, 0, 0, 255] unless exists $self->{LABEL_COLOR};
    $self->{LABEL_MIN_SIZE} = 0 unless exists $self->{LABEL_MIN_SIZE};

    $self->{HAS_BORDER} = 0 unless exists $self->{HAS_BORDER};
    $self->{BORDER_COLOR} = [0, 0, 0] unless exists $self->{BORDER_COLOR};

    # set from input
    
    $self->{NAME} = $params{name} if exists $params{name};
    $self->{ALPHA} = $params{alpha} if exists $params{alpha};
    $self->{VISIBLE} = $params{visible} if exists $params{visible};
    $self->{PALETTE_TYPE} = $params{palette_type} if exists $params{palette_type};
    $self->{SYMBOL_TYPE} = $params{symbol_type} if exists $params{symbol_type};
    $self->{SINGLE_COLOR} = $params{single_color} if exists $params{single_color};
    $self->{COLOR_FIELD} = $params{color_field} if exists $params{color_field};
    $self->{SYMBOL_FIELD} = $params{symbol_field} if exists $params{symbol_field};
    $self->{LABEL_FIELD} = $params{label_field} if exists $params{label_field};  

}

sub DESTROY {
    my $self = shift;
    $self->destroy_dialogs;
}

sub destroy_dialogs {
    my $self = shift;
    for (keys %$self) {
	next unless /_dialog$/;
	my $dialog = $self->{$_};
	next unless $dialog;
	$dialog = $dialog->get_widget($_);
	next unless $dialog;
	$dialog->hide();
	$dialog->destroy();
	delete $self->{$_};
    }
}

## @method $type()
#
# @brief Reports the type of the layer class for the GUI (human readable code).
# @return Type of the layer class for the GUI (human readable code).
sub type {
    my $self = shift;
    return '?';
}

## @method $name($name)
#
# @brief Get or set the name of the layer.
# @param[in] name (optional) Layers name.
# @return Name of layer, if no name is given to the method.
sub name {
    my($self, $name) = @_;
    defined $name ? $self->{NAME} = $name : $self->{NAME};
}

## @method $alpha($alpha)
#
# @brief Get or set the alpha (transparency) of the layer.
# @param[in] alpha (optional) Layers alpha channels value (0 ... 255).
# @return Current alpha value, if no parameter is given.
sub alpha {
    my($self, $alpha) = @_;
    defined $alpha ? $self->{ALPHA} = $alpha : $self->{ALPHA};
}

## @method visible($visible)
# 
# @brief[in] Show or hide the layer.
# @param visible If true then the layer is made visible, else hidden.
sub visible {
    my($self, $visible) = @_;
    defined $visible ? $self->{VISIBLE} = $visible : $self->{VISIBLE};
}

sub has_border {
    my($self, $has_border) = @_;
    defined $has_border ?
	$self->{HAS_BORDER} = $has_border :
	$self->{HAS_BORDER};
}

sub border_color {
    my($self, @color) = @_;
    @color ?
	@{$self->{BORDER_COLOR}} = @color :
	@{$self->{BORDER_COLOR}};
}

## @method void properties_dialog(Gtk2::Ex::Glue gui)
# 
# @brief A request to invoke the properties dialog for this layer object.
# @param gui A Gtk2::Ex::Glue object (contains predefined dialogs).
sub properties_dialog {
    my($self, $gui) = @_;
}

## @method void symbols_dialog(Gtk2::Ex::Glue gui)
#
# @brief A request to invoke the symbols dialog for this layer object.
# @param gui A Gtk2::Ex::Glue object (contains predefined dialogs).
sub symbols_dialog {
    my($self, $gui) = @_;
    $self->open_symbols_dialog($gui);
}

## @method void colors_dialog(Gtk2::Ex::Glue gui)
#
# @brief A request to invoke the colors dialog for this layer object.
# @param gui A Gtk2::Ex::Glue object (contains predefined dialogs).
sub colors_dialog {
    my($self, $gui) = @_;
    $self->open_colors_dialog($gui);
}

## @method void labeling_dialog(Gtk2::Ex::Glue gui)
#
# @brief A request to invoke the labeling dialog for this layer object.
# @param gui A Gtk2::Ex::Glue object (contains predefined dialogs).
sub labels_dialog {
    my($self, $gui) = @_;
    $self->open_labels_dialog($gui);
}

## @cmethod @menu_items()
#
# @brief Reports the class menu items for the GUI.
# @return Class menu items for the GUI.
sub menu_items {
    my $self = shift;
    return ('_Deselect all');
}

## @method $menu_action($item, Gtk2::Ex::Glue gui)
#
# @brief Reports the class menu items for the GUI.
# @param item The selected menu item.
# @param gui A Gtk2::Ex::Glue object (contains predefined dialogs).
# @return true if item was recognized.
# @todo The method is not yet ready!
sub menu_action {
    my($self, $item, $gui) = @_;
    if ($item eq '_Deselect all') {
	$self->select;
	return 1;
    }
    return 0;
}

## private @method _key2value()
#
# @brief Convert string attributes to integers for libral.
sub _key2value {
    my $self = shift;
    $self->{PALETTE_VALUE} = $PALETTE_TYPE{$self->{PALETTE_TYPE}};
    $self->{SYMBOL_VALUE} = $SYMBOL_TYPE{$self->{SYMBOL_TYPE}};
    if ($self->{SYMBOL_FIELD} eq 'Fixed size') {
		$self->{SYMBOL_SCALE_MIN} = 0; # similar to grayscale scale
		$self->{SYMBOL_SCALE_MAX} = 0;
    }
}

## @method $palette_type($palette_type)
#
# @brief Get or set the palette type.
# @param[in] palette_type (optional) New palette type to set to the layer.
# @return The current palette type of the layer.
sub palette_type {
    my($self, $palette_type) = @_;
    if (defined $palette_type) {
		croak "Unknown palette type: $palette_type" unless defined $PALETTE_TYPE{$palette_type};
		$self->{PALETTE_TYPE} = $palette_type;
    } else {
		return $self->{PALETTE_TYPE};
    }
}

## @method @supported_palette_types()
# 
# @brief Return a list of all by this class supported palette types.
# @return A list of all by this class supported palette types.
sub supported_palette_types {
    my($class) = @_;
    my @ret;
    for my $t (sort {$PALETTE_TYPE{$a} <=> $PALETTE_TYPE{$b}} keys %PALETTE_TYPE) {
		push @ret, $t;
    }
    return @ret;
}

## @method $symbol_type($type)
#
# @brief Get or set the symbol type.
# @param[in] type (optional) New symbol type to set to the layer.
# @return The current symbol type of the layer.
sub symbol_type {
    my($self, $symbol_type) = @_;
    if (defined $symbol_type) {
		croak "Unknown symbol type: $symbol_type" unless defined $SYMBOL_TYPE{$symbol_type};
		$self->{SYMBOL_TYPE} = $symbol_type;
    } else {
		return $self->{SYMBOL_TYPE};
    }
}

## @method @supported_symbol_types()
# 
# @brief Return a list of all by this class supported symbol types.
# @return A list of all by this class supported symbol types.
sub supported_symbol_types {
    my($self) = @_;
    my @ret;
    for my $t (sort {$SYMBOL_TYPE{$a} <=> $SYMBOL_TYPE{$b}} keys %SYMBOL_TYPE) {
		push @ret, $t;
    }
    return @ret;
}

## @method $symbol_size($size)
# 
# @brief Get or set the symbol size.
# @param[in] size (optional) The layers symbols new size.
# @return The current size of the layers symbol.
# @note Even if the layer has at the moment no symbol, the symbol size can be 
# defined.
sub symbol_size {
    my($self, $size) = @_;
    defined $size ?
	$self->{SYMBOL_SIZE} = $size+0 :
	$self->{SYMBOL_SIZE};
}

## @method @symbol_scale($scale_min, $scale_max)
# 
# @brief Get or set the symbol scale.
# @param[in] scale_min (optional) The layers symbols new minimum scale. Scale under
# which the symbol is hidden even if the layer is visible.
# @param[in] scale_max (optional) The layers symbols new maximum scale. Scale over
# which the symbol is hidden even if the layer is visible.
# @return The current scale minimum and maximum of the layers symbol.
# @note Even if the layer has at the moment no symbol, the symbol scales can be 
# defined.
sub symbol_scale {
    my($self, $min, $max) = @_;
    if (defined $min) {
		$self->{SYMBOL_SCALE_MIN} = $min+0;
		$self->{SYMBOL_SCALE_MAX} = $max+0;
    }
    return ($self->{SYMBOL_SCALE_MIN}, $self->{SYMBOL_SCALE_MAX});
}

## @method @hue_range($min, $max, $dir)
#
# @brief Determines the hue range (for example in )
# @param min The minimum hue value.
# @param max The maximum hue value.
# @param by default the rainbow is red->green->blue (hue increases), 
# anything else means red->blue->green (hue decreases).
# @return 
sub hue_range {
    my($self, $min, $max, $dir) = @_;
    if (defined $min) {
		$self->{HUE_AT_MIN} = $min+0;
		$self->{HUE_AT_MAX} = $max+0;
		$self->{HUE_DIR} = $dir ? -1 : 1;
    }
    return ($self->{HUE_AT_MIN}, $self->{HUE_AT_MAX}, $self->{HUE_DIR});
}

## @method $hue($hue)
#
# @brief Get or set the layers hue.
# @param hue (optional) Hue to set to the layer.
# @return Returns the layers hue value.
# @todo Add a check that the given hue value is between the minimum and maximum?
sub hue {
    my($self, $hue) = @_;
    defined $hue ?
	$self->{HUE} = $hue+0 :
	$self->{HUE};
}

## @method $has_field($field_name)
#
# @brief Tells if the layer has a certain field by name.
# @param[in] field_name Name of the field, which existence is wanted to know.
# @return Returns true this layer has a certain attribute, else false (0).
sub has_field {
    my($self, $field_name) = @_;
    return 0;
}

## @method $symbol_field($field_name)
#
# @brief Get or set the field, which is used for determining the size of the 
# symbol.
# @param[in] field_name (optional) Name of the field determining symbol size.
# @return Name of the field determining symbol size.
# @exception If field name is given as a parameter, but the field does not 
# exist in the layer.
sub symbol_field {
    my($self, $field_name) = @_;
    if (defined $field_name) {
	if ($field_name eq 'Fixed size' or $self->has_field($field_name)) {
	    $self->{SYMBOL_FIELD} = $field_name;
	} else {
	    croak "Layer ".$self->name()." does not have field with name: $field_name";
	}
    }
    return $self->{SYMBOL_FIELD};
}

## @method @single_color(@rgba)
#
# @brief Get or set the color, which is used if palette is 'single color'
# @param[in] rgba (optional) A list of channels defining the RGBA color.
# @return The current color.
# @exception Some color channels are given, but not exactly all four channels.
sub single_color {
    my $self = shift;
    croak "@_ is not a RGBA color" if @_ and @_ != 4;
    $self->{SINGLE_COLOR} = [@_] if @_;
    return @{$self->{SINGLE_COLOR}};
}

## @method @color_scale($scale_min, $scale_max)
# 
# @brief Get or set the range, which is used for coloring in continuous palette 
# types.
# @param[in] scale_min (optional) The layers colors new minimum scale. Scale under
# which the color is not shown even if the layer is visible.
# @param[in] scale_max (optional) The layers colors new maximum scale. Scale over
# which the color is not shown even if the layer is visible.
# @return The current scale minimum and maximum of the layers color.
sub color_scale {
    my($self, $min, $max) = @_;
    if (defined $min) {
	$self->{COLOR_SCALE_MIN} = $min+0;
	$self->{COLOR_SCALE_MAX} = $max+0;
    }
    return ($self->{COLOR_SCALE_MIN}, $self->{COLOR_SCALE_MAX});
}

## @method $color_field($field_name)
#
# @brief Get or set the field, which is used for determining the color.
# @param[in] field_name (optional) Name of the field determining color.
# @return Name of the field determining color.
# @exception If field name is given as a parameter, but the field does not 
# exist in the layer.
sub color_field {
    my($self, $field_name) = @_;
    if (defined $field_name) {
	if ($self->has_field($field_name)) {
	    $self->{COLOR_FIELD} = $field_name;
	} else {
	    croak "Layer ",$self->name,"does not have field: $field_name";
	}
    }
    return $self->{COLOR_FIELD};
}

## @method @color_bins($color_bins)
#
# @brief Get or set the color bins.
# @param[in] color_bins (optional) Name of file from where the color bins can be 
# read.
# @return The current color bins if no parameter is given.
# @exception A filename is given, which can't be opened/read or does not have 
# the color bins.

## @method @color_bins(listref color_bins)
#
# @brief Get or set the color bins.
# @param[in] color_bins (optional) Array including the color bins.
# @return The current color bins if no parameter is given.
sub color_bins {
    my($self, $color_bins) = @_;
    unless (defined $color_bins) {
		$self->{COLOR_BINS} = [] unless $self->{COLOR_BINS};
		return $self->{COLOR_BINS};
    }
	if (ref($color_bins) eq 'ARRAY') {
		$self->{COLOR_BINS} = [];
		for (@$color_bins) {
			push @{$self->{COLOR_BINS}}, [@$_];
		}
	} else {
		my $fh = new FileHandle;
		croak "can't read from $color_bins: $!\n" unless $fh->open("< $color_bins");
		$self->{COLOR_BINS} = [];
		while (<$fh>) {
		    next if /^#/;
		    my @tokens = split /\s+/;
		    next unless @tokens > 3;
		    $tokens[4] = 255 unless defined $tokens[4];
		    for (@tokens[1..4]) {
				$_ =~ s/\D//g;
				$_ = 0 if $_ < 0;
				$_ = 255 if $_ > 255;
		    }
		    push @{$self->{COLOR_BINS}},\@tokens;
		}
		$fh->close;
    }
}

## @method save_color_bins($filename)
#
# @brief Saves the layers color bins into the file, which name is given as 
# parameter.
# @param[in] filename Name of file where the color bins are saved.
# @exception A filename is given, which can't be written to.
sub save_color_bins {
    my($self, $filename) = @_;
    my $fh = new FileHandle;
    croak "can't write to $filename: $!\n" unless $fh->open("> $filename");
    for my $color (@{$self->{COLOR_BINS}}) {
		print $fh "@$color\n";
    }
    $fh->close;
}

## @method hashref labeling($labeling)
#
# @brief Sets the labeling for the layer.
# @param[in] labeling An anonymous hash containing the labeling: 
# { field => , font => , color => [r,g,b,a], min_size => }
# @return labeling in an anonymous hash
sub labeling {
    my($self, $labeling) = @_;
    if ($labeling) {
	$self->{LABEL_FIELD} = $labeling->{field};
	$self->{LABEL_PLACEMENT} = $labeling->{placement};
	$self->{LABEL_FONT} = $labeling->{font};
	@{$self->{LABEL_COLOR}} =@{$labeling->{color}};
	$self->{LABEL_MIN_SIZE} = $labeling->{min_size};
    } else {
	$labeling = {};
	$labeling->{field} = $self->{LABEL_FIELD};
	$labeling->{placement} = $self->{LABEL_PLACEMENT};
	$labeling->{font} = $self->{LABEL_FONT};
	@{$labeling->{color}} = @{$self->{LABEL_COLOR}};
	$labeling->{min_size} = $self->{LABEL_MIN_SIZE};
    }
    return $labeling;
}

## @method render_selection($gc)
#
# @brief Render the selection using the given graphics context
# @param $gc Gtk2::Gdk::GC
sub render_selection {
}

sub open_symbols_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{symbols_dialog};
    unless ($dialog) {
	$self->{symbols_dialog} = $dialog = $gui->get_dialog('symbols_dialog');
	croak "symbols_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('symbols_dialog')->set_title("Symbols for ".$self->name);
	$dialog->get_widget('symbols_dialog')->signal_connect(delete_event => \&cancel_symbols, [$self, $gui]);

	$dialog->get_widget('symbols_scale_button')->signal_connect(clicked=>\&fill_symbol_scale_fields, [$self, $gui]);
	$dialog->get_widget('symbols_field_combobox')->signal_connect(changed=>\&symbol_field_changed, [$self, $gui]);
	$dialog->get_widget('symbols_type_combobox')->signal_connect(changed=>\&symbol_field_changed, [$self, $gui]);

	$dialog->get_widget('symbols_apply_button')->signal_connect(clicked => \&apply_symbols, [$self, $gui, 0]);
	$dialog->get_widget('symbols_cancel_button')->signal_connect(clicked => \&cancel_symbols, [$self, $gui]);
	$dialog->get_widget('symbols_ok_button')->signal_connect(clicked => \&apply_symbols, [$self, $gui, 1]);
    } else {
	$dialog->get_widget('symbols_dialog')->move(@{$self->{symbols_dialog_position}});
    }
    
    my $symbol_type_combo = $dialog->get_widget('symbols_type_combobox');
    my $field_combo = $dialog->get_widget('symbols_field_combobox');
    my $scale_min = $dialog->get_widget('symbols_scale_min_entry');
    my $scale_max = $dialog->get_widget('symbols_scale_max_entry');
    my $size_spin = $dialog->get_widget('symbols_size_spinbutton');

    # back up data

    my $symbol_type = $self->symbol_type();
    my $size = $self->symbol_size();
    my $field = $self->symbol_field();
    my @scale = $self->symbol_scale();
    $self->{backup}->{symbol_type} = $symbol_type;
    $self->{backup}->{symbol_size} = $size;
    $self->{backup}->{symbol_field} = $field;
    $self->{backup}->{symbol_scale} = \@scale;
    
    # set up the controllers

    $self->fill_symbol_type_combo($symbol_type);
    $self->fill_symbol_field_combo($field);
    $scale_min->set_text($scale[0]);
    $scale_max->set_text($scale[1]);
    $size_spin->set_value($size);
    
    $dialog->get_widget('symbols_dialog')->show_all;
}

sub apply_symbols {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{symbols_dialog};
    
    my $symbol_type = $self->get_selected_symbol_type();
    $self->symbol_type($symbol_type);
    my $field_combo = $dialog->get_widget('symbols_field_combobox');
    my $field = $self->{index2symbol_field}{$field_combo->get_active()};
    $self->symbol_field($field) if defined $field;
    my $scale_min = $dialog->get_widget('symbols_scale_min_entry');
    my $scale_max = $dialog->get_widget('symbols_scale_max_entry');
    $self->symbol_scale($scale_min->get_text(), $scale_max->get_text());
    my $size_spin = $dialog->get_widget('symbols_size_spinbutton');
    my $size = $size_spin->get_value();
    $self->symbol_size($size);

    $self->{symbols_dialog_position} = [$dialog->get_widget('symbols_dialog')->get_position];
    $dialog->get_widget('symbols_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

sub cancel_symbols {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    
    $self->symbol_type($self->{backup}->{symbol_type});
    $self->symbol_field($self->{backup}->{symbol_field}) if $self->{backup}->{symbol_field};
    $self->symbol_scale(@{$self->{backup}->{symbol_scale}});
    $self->symbol_size($self->{backup}->{symbol_size});

    my $dialog = $self->{symbols_dialog}->get_widget('symbols_dialog');
    $self->{symbols_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

sub fill_symbol_type_combo {
    my($self, $symbol_type) = @_;
    $symbol_type = '' unless defined $symbol_type;
    my $combo = $self->{symbols_dialog}->get_widget('symbols_type_combobox');
    my $model = $combo->get_model;
    $model->clear;
    my @symbol_types = $self->supported_symbol_types();
    my $i = 0;
    my $active = 0;
    for (@symbol_types) {
	$model->set ($model->append, 0, $_);
	$self->{index2symbol_type}{$i} = $_;
	$self->{symbol_type2index}{$_} = $i;
	$active = $i if $_ eq $symbol_type;
	$i++;
    }
    $combo->set_active($active);
}

sub get_selected_symbol_type {
    my $self = shift;
    my $combo = $self->{symbols_dialog}->get_widget('symbols_type_combobox');
    $self->{index2symbol_type}{$combo->get_active()};
}

sub fill_symbol_field_combo {
    my($self, $symbol_field) = @_;
    my $combo = $self->{symbols_dialog}->get_widget('symbols_field_combobox');
    my $model = $combo->get_model;
    $model->clear;
    delete $self->{index2symbol_field};
    my $active = 0;
    my $i = 0;

    my $name = 'Fixed size';
    $model->set($model->append, 0, $name);
    $active = $i if $name eq $self->symbol_field();
    $self->{index2symbol_field}{$i} = $name;
    $i++;

    my $schema = $self->schema();
    for my $name (sort keys %$schema) {
	my $type = $schema->{$name}{TypeName};
	next unless $type;
	next unless $type eq 'Integer' or $type eq 'Real';
	$model->set($model->append, 0, $name);
	$active = $i if $name eq $symbol_field;
	$self->{index2symbol_field}{$i} = $name;
	$i++;
    }
    $combo->set_active($active);
}

sub get_selected_symbol_field {
    my $self = shift;
    my $combo = $self->{symbols_dialog}->get_widget('symbols_field_combobox');
    $self->{index2symbol_field}{$combo->get_active()};
}

sub fill_symbol_scale_fields {
    my($self, $gui) = @{$_[1]};
    my @range;
    my $field = $self->get_selected_symbol_field();
    return if $field eq 'Fixed size';
    eval {
	@range = $self->value_range(field_name => $field, filter_rect => [$self->{overlay}->get_focus()]);
    };
    if ($@) {
	$self->message("$@");
	return;
    }
    $self->{symbols_dialog}->get_widget('symbols_scale_min_entry')->set_text($range[0]);
    $self->{symbols_dialog}->get_widget('symbols_scale_max_entry')->set_text($range[1]);
}

sub symbol_field_changed {
    my($self, $gui) = @{$_[1]};
    my $type = $self->get_selected_symbol_type();
    my $field = $self->get_selected_symbol_field();
    my $dialog = $self->{symbols_dialog};
    if ($type eq 'No symbol') {
	$dialog->get_widget('symbols_size_spinbutton')->set_sensitive(0);
	$dialog->get_widget('symbols_field_combobox')->set_sensitive(0);
    } else {
	$dialog->get_widget('symbols_size_spinbutton')->set_sensitive(1);
	$dialog->get_widget('symbols_field_combobox')->set_sensitive(1);
    }
    if (!$field or $field eq 'Fixed size') {
	$dialog->get_widget('symbols_scale_min_entry')->set_sensitive(0);
	$dialog->get_widget('symbols_scale_max_entry')->set_sensitive(0);
	$dialog->get_widget('symbols_size_label')->set_text('Size: ');
    } else {
	$dialog->get_widget('symbols_scale_min_entry')->set_sensitive(1);
	$dialog->get_widget('symbols_scale_max_entry')->set_sensitive(1);
	$dialog->get_widget('symbols_size_label')->set_text('Maximum size: ');
    }
}

# open colors dialog

sub open_colors_dialog {
    my($self, $gui) = @_;
    # bootstrap:
    my $dialog = $self->{colors_dialog};
    unless ($dialog) {
	$self->{colors_dialog} = $dialog = $gui->get_dialog('colors_dialog');
	croak "colors_dialog for Geo::Layer does not exist" unless $dialog;
	$dialog->get_widget('colors_dialog')->set_title("Colors for ".$self->name);
	$dialog->get_widget('colors_dialog')->signal_connect(delete_event => \&cancel_colors, [$self, $gui]);

	$dialog->get_widget('color_scale_button')->signal_connect(clicked=>\&fill_color_scale_fields, [$self, $gui]);
	$dialog->get_widget('color_legend_button')->signal_connect(clicked=>\&make_color_legend, [$self, $gui]);
	$dialog->get_widget('get_colors_button')->signal_connect(clicked=>\&get_colors, [$self, $gui]);
	$dialog->get_widget('open_colors_button')->signal_connect(clicked=>\&open_colors_file, [$self, $gui]);
	$dialog->get_widget('save_colors_button')->signal_connect(clicked=>\&save_colors_file, [$self, $gui]);
	$dialog->get_widget('edit_color_button')->signal_connect(clicked=>\&edit_color, [$self, $gui]);
	$dialog->get_widget('delete_color_button')->signal_connect(clicked=>\&delete_color, [$self, $gui]);
	$dialog->get_widget('add_color_button')->signal_connect(clicked=>\&add_color, [$self, $gui]);
	$dialog->get_widget('palette_type_combobox')->signal_connect(changed=>\&palette_type_changed, [$self, $gui]);
	$dialog->get_widget('color_field_combobox')->signal_connect(changed=>\&color_field_changed, [$self, $gui]);
	
	$dialog->get_widget('colors_apply_button')->signal_connect(clicked => \&apply_colors, [$self, $gui, 0]);
	$dialog->get_widget('colors_cancel_button')->signal_connect(clicked => \&cancel_colors, [$self, $gui]);
	$dialog->get_widget('colors_ok_button')->signal_connect(clicked => \&apply_colors, [$self, $gui, 1]);
    } else {
	$dialog->get_widget('colors_dialog')->move(@{$self->{colors_dialog_position}});
    }

    my $palette_type_combo = $dialog->get_widget('palette_type_combobox');
    my $field_combo = $dialog->get_widget('color_field_combobox');
    my $scale_min = $dialog->get_widget('color_scale_min_entry');
    my $scale_max = $dialog->get_widget('color_scale_max_entry');
    my $hue_min = $dialog->get_widget('hue_min_entry');
    my $hue_max = $dialog->get_widget('hue_max_entry');
    my $hue_range_sel = $dialog->get_widget('hue_range_combobox');
    my $hue = $dialog->get_widget('hue_entry');

    $self->{current_coloring_type} = '';

    # back up data

    my $palette_type = $self->palette_type();
    my @single_color = $self->single_color();
    my $field = $self->color_field();
    my @scale = $self->color_scale();
    my @hue_range = $self->hue_range;
    my $table = $self->color_table();
    my $bins = $self->color_bins();

    $self->{backup}->{palette_type} = $palette_type;
    $self->{backup}->{single_color} = \@single_color;
    $self->{backup}->{field} = $field;
    $self->{backup}->{scale} = \@scale;
    $self->{backup}->{hue_range} = \@hue_range;
    $self->{backup}->{hue} = $self->hue;
    $self->{backup}->{table} = $table;
    $self->{backup}->{bins} = $bins;
    
    # set up the controllers

    $self->fill_palette_type_combo($palette_type);
    $self->fill_color_field_combo($palette_type);
    $scale_min->set_text($scale[0]);
    $scale_max->set_text($scale[1]);
    $hue_min->set_text($hue_range[0]);
    $hue_max->set_text($hue_range[1]);
    $hue_range_sel->set_active($hue_range[2]);
    $hue->set_text($self->hue);
    if ($palette_type eq 'Single color') {
	$self->fill_colors_treeview([[@single_color]]);
    } elsif ($palette_type eq 'Color table') {
	$self->fill_colors_treeview($table);
    } elsif ($palette_type eq 'Color bins') {
	$self->fill_colors_treeview($bins);
    }    

    $dialog->get_widget('colors_dialog')->show_all;
}

sub apply_colors {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{colors_dialog};

    my $palette_type = $self->get_selected_palette_type();
    $self->palette_type($palette_type);
    my $field_combo = $dialog->get_widget('color_field_combobox');
    my $field = $self->{index2field}{$field_combo->get_active()};
    $self->color_field($field) if defined $field;
    my $scale_min = $dialog->get_widget('color_scale_min_entry');
    my $scale_max = $dialog->get_widget('color_scale_max_entry');
    $self->color_scale($scale_min->get_text(), $scale_max->get_text());

    $self->hue_range($dialog->get_widget('hue_min_entry')->get_text,
		     $dialog->get_widget('hue_max_entry')->get_text,
		     $dialog->get_widget('hue_range_combobox')->get_active);
    $self->hue($dialog->get_widget('hue_entry')->get_text);
    
    if ($palette_type eq 'Single color') {
	my $table = $self->get_table_from_treeview();
	$self->single_color(@{$table->[0]});
    } elsif ($palette_type eq 'Color table') {
	my $table = $self->get_table_from_treeview();
	$self->color_table($table);
    } elsif ($palette_type eq 'Color bins') {
	my $table = $self->get_table_from_treeview();
	$self->color_bins($table);
    }

    $dialog->get_widget('colors_dialog')->hide() if $close;
    $gui->{overlay}->render;
}

sub cancel_colors {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    $self->palette_type($self->{backup}->{palette_type});
    $self->single_color(@{$self->{backup}->{single_color}});
    $self->color_field($self->{backup}->{field}) if $self->{backup}->{field};
    $self->color_table($self->{backup}->{table});
    $self->color_bins($self->{backup}->{bins});
    $self->color_scale(@{$self->{backup}->{scale}});

    $self->hue_range(@{$self->{backup}->{hue_range}});
    $self->hue($self->{backup}->{hue});

    my $dialog = $self->{colors_dialog}->get_widget('colors_dialog');
    $self->{colors_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->{overlay}->render;
    1;
}

sub get_selected_palette_type {
    my $self = shift;
    my $combo = $self->{colors_dialog}->get_widget('palette_type_combobox');
    $self->{index2palette_type}{$combo->get_active()};
}

sub get_selected_color_field {
    my $self = shift;
    my $combo = $self->{colors_dialog}->get_widget('color_field_combobox');
    $self->{index2field}{$combo->get_active()};
}

sub get_colors {
    my($self, $gui) = @{$_[1]};
    my $table = $self->colors_from_dialog($gui);
    $self->fill_colors_treeview($table) if $table;
}

sub open_colors_file {
    my($self, $gui) = @{$_[1]};
    my $palette_type = $self->get_selected_palette_type();
    my $file_chooser =
	Gtk2::FileChooserDialog->new ("Select a $palette_type file",
				      undef, 'open',
				      'gtk-cancel' => 'cancel',
				      'gtk-ok' => 'ok');
    if ($file_chooser->run eq 'ok') {
	my $filename = $file_chooser->get_filename;
	$file_chooser->destroy;
	my $table = {};
	if ($palette_type eq 'Color table') {
	    eval {
		color_table($table, $filename); 
		$table = color_table($table);
	    }
	} elsif ($palette_type eq 'Color bins') {
	    eval {
		color_bins($table, $filename);
		$table = color_bins($table);
	    }
	}
	if ($@) {
	    $gui->message("$@");
	} else {
	    $self->fill_colors_treeview($table);
	}
    } else {
	$file_chooser->destroy;
    }
}

sub save_colors_file {
    my($self, $gui) = @{$_[1]};
    my $palette_type = $self->get_selected_palette_type();
    my $file_chooser =
	Gtk2::FileChooserDialog->new ("Save $palette_type file as",
				      undef, 'save',
				      'gtk-cancel' => 'cancel',
				      'gtk-ok' => 'ok');
    my $filename;
    if ($file_chooser->run eq 'ok') {
	$filename = $file_chooser->get_filename;
	$file_chooser->destroy;
	my $table = $self->get_table_from_treeview();
	my $obj = {};
	if ($palette_type eq 'Color table') {
	    eval {
		color_table($obj, $table);
		save_color_table($obj, $filename); 
	    }
	} elsif ($palette_type eq 'Color bins') {
	    eval {
		color_bins($obj, $table);
		save_color_bins($obj, $filename);
	    }
	}
	if ($@) {
	    $gui->message("$@");
	}
    } else {
	$file_chooser->destroy;
    }
}

sub edit_color {
    my($self, $gui) = @{$_[1]};
    my $palette_type = $self->get_selected_palette_type();
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows;
    return unless @selected;
	
    my $table = $self->get_table_from_treeview();

    my $i = $selected[0]->to_string;
    my @color;
    if ($palette_type eq 'Single color') {
	@color = @{$table->[$i]};
    } else {
	@color = @{$table->[$i]}[1..4];
    }
	    
    my $d = Gtk2::ColorSelectionDialog->new('Choose color for selected entries');
    my $s = $d->colorsel;
	    
    $s->set_has_opacity_control(1);
    my $c = new Gtk2::Gdk::Color ($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    $s->set_current_alpha($color[3]*257);
    
    if ($d->run eq 'ok') {
	$d->destroy;
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	$color[3] = int($s->get_current_alpha()/257);

	if ($palette_type eq 'Single color') {
	    $self->fill_colors_treeview([[@color]]);
	} else {
	    for (@selected) {
		my $i = $_->to_string;
		@{$table->[$i]}[1..4] = @color;
	    }
	    $self->fill_colors_treeview($table);
	}	
    } else {
	$d->destroy;
    }
    
    for (@selected) {
	$selection->select_path($_);
    }
}

sub delete_color {
    my($self, $gui) = @{$_[1]};
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows if $selection;
    my $model = $treeview->get_model;
    my $at;
    for my $selected (@selected) {
	$at = $selected->to_string;
	my $iter = $model->get_iter_from_string($at);
	$model->remove($iter);
	#splice @$table,$at,1;
    }
    $at--;
    $at = 0 if $at < 0;
    $treeview->set_cursor(Gtk2::TreePath->new($at));
}

sub add_color {
    my($self, $gui) = @{$_[1]};
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows if $selection;
    my $at = $selected[0]->to_string if @selected;
    my $model = $treeview->get_model;
    my $palette_type = $self->get_selected_palette_type();
    my $table = $self->get_table_from_treeview();
    $at = $#$table unless defined $at;
    my $value;
    if (@$table) {
	if ($palette_type eq 'Color table') {
	    if ($self->current_coloring_type eq 'Int') {
		do {
		    $value = $table->[$at]->[0]+1;
		    $at++;
		} until $at == @$table or $value != $table->[$at]->[0];
	    } else {
		$value = 'change this';
		$at++;
	    }
	} elsif ($palette_type eq 'Color bins') {
	    if ($at == $#$table) {
		if ($self->current_coloring_type eq 'Int') {
		    $value = $MAX_INT;
		} else {
		    $value = $MAX_REAL;
		}
		$at++;
	    } else {
		$value = ($table->[$at]->[0] + $table->[$at+1]->[0])/2;
		$at++;
	    }
	}
    } else {
	if ($self->current_coloring_type eq 'String') {
	    $value = 'change this';
	} else {
	    $value = 0;
	}
	$at = 0;
    }

    my $iter = $model->insert(undef, $at);
    set_color($model,$iter,$value,255,255,255,255);

    $treeview->set_cursor(Gtk2::TreePath->new($at));
}

sub cell_in_colors_treeview_changed {
    my($cell, $path, $new_value, $data) = @_;
    my($self, $column) = @$data;
    my $table = $self->get_table_from_treeview();
    $table->[$path]->[$column] = $new_value;
    $self->fill_colors_treeview($table);
}

sub palette_type_changed {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{colors_dialog};
    my $palette_type = $self->get_selected_palette_type();
    
    fill_color_field_combo($self);

    my $tv = $dialog->get_widget('colors_treeview');

    $dialog->get_widget('color_field_label')->set_sensitive(0);
    $dialog->get_widget('color_field_combobox')->set_sensitive(0);
    $dialog->get_widget('color_scale_min_entry')->set_sensitive(0);
    $dialog->get_widget('color_scale_max_entry')->set_sensitive(0);
    $dialog->get_widget('hue_min_entry')->set_sensitive(0);
    $dialog->get_widget('hue_max_entry')->set_sensitive(0);
    $dialog->get_widget('hue_range_combobox')->set_sensitive(0);
    $dialog->get_widget('hue_entry')->set_sensitive(0);
    $tv->set_sensitive(0);
    $dialog->get_widget('get_colors_button')->set_sensitive(0);
    $dialog->get_widget('open_colors_button')->set_sensitive(0);
    $dialog->get_widget('save_colors_button')->set_sensitive(0);
    $dialog->get_widget('edit_color_button')->set_sensitive(0);
    $dialog->get_widget('delete_color_button')->set_sensitive(0);
    $dialog->get_widget('add_color_button')->set_sensitive(0);

    if ($palette_type ne 'Single color') {
	$dialog->get_widget('color_field_label')->set_sensitive(1);
	$dialog->get_widget('color_field_combobox')->set_sensitive(1);
    }

    if ($palette_type eq 'Grayscale') {
	$dialog->get_widget('hue_entry')->set_sensitive(1);
    } elsif ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow') {
	$dialog->get_widget('hue_min_entry')->set_sensitive(1);
	$dialog->get_widget('hue_max_entry')->set_sensitive(1);
	$dialog->get_widget('hue_range_combobox')->set_sensitive(1);
    }

    if ($palette_type eq 'Single color') {
	$dialog->get_widget('color_scale_button')->set_sensitive(0);
	$dialog->get_widget('color_legend_button')->set_sensitive(0);
	$dialog->get_widget('edit_color_button')->set_sensitive(1);
	$tv->set_sensitive(1);
    } elsif ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow' or $palette_type =~ 'channel') {
	$dialog->get_widget('color_scale_button')->set_sensitive(1);
	$dialog->get_widget('color_legend_button')->set_sensitive(1);
	$dialog->get_widget('color_scale_min_entry')->set_sensitive(1);
	$dialog->get_widget('color_scale_max_entry')->set_sensitive(1);
	$tv->set_sensitive(1);
    } elsif ($palette_type eq 'Color table') {
	my $s = 1; # $self->current_coloring_type eq 'Int' ? 1 : 0; this may change!
	$tv->set_sensitive($s);
	$dialog->get_widget('color_scale_button')->set_sensitive(0);
	$dialog->get_widget('color_legend_button')->set_sensitive(0);
	$dialog->get_widget('get_colors_button')->set_sensitive($s);
	$dialog->get_widget('open_colors_button')->set_sensitive($s);
	$dialog->get_widget('save_colors_button')->set_sensitive($s);
	$dialog->get_widget('edit_color_button')->set_sensitive($s);
	$dialog->get_widget('delete_color_button')->set_sensitive($s);
	$dialog->get_widget('add_color_button')->set_sensitive($s);
    } elsif ($palette_type eq 'Color bins') {
	$tv->set_sensitive(1);
	$dialog->get_widget('color_scale_button')->set_sensitive(0);
	$dialog->get_widget('color_legend_button')->set_sensitive(0);
	$dialog->get_widget('get_colors_button')->set_sensitive(1);
	$dialog->get_widget('open_colors_button')->set_sensitive(1);
	$dialog->get_widget('save_colors_button')->set_sensitive(1);
	$dialog->get_widget('edit_color_button')->set_sensitive(1);
	$dialog->get_widget('delete_color_button')->set_sensitive(1);
	$dialog->get_widget('add_color_button')->set_sensitive(1);
    }
    $self->create_colors_treeview();
}

sub create_colors_treeview {
    my($self) = @_;

    my $palette_type = $self->get_selected_palette_type();
    my $tv = $self->{colors_dialog}->get_widget('colors_treeview');
    
    if ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow') {
	$self->put_scale_in_treeview($tv,$palette_type);
	return;
    }

    my $select = $tv->get_selection;
    $select->set_mode('multiple');

    my $model;
    my $table;
    my $type = $self->current_coloring_type;
    if ($palette_type eq 'Single color') {
	$model = Gtk2::TreeStore->new(qw/Gtk2::Gdk::Pixbuf Glib::Int Glib::Int Glib::Int Glib::Int/);
	$table = [[$self->single_color()]];
    } elsif ($palette_type eq 'Color table') {
	$model = Gtk2::TreeStore->new("Glib::$type","Gtk2::Gdk::Pixbuf","Glib::Int","Glib::Int","Glib::Int","Glib::Int");
	$table = $self->color_table();
    } elsif ($palette_type eq 'Color bins') {
	$model = Gtk2::TreeStore->new("Glib::$type","Gtk2::Gdk::Pixbuf","Glib::Int","Glib::Int","Glib::Int","Glib::Int");
	$table = $self->color_bins();
    }
    $tv->set_model($model);
    for ($tv->get_columns) {
	$tv->remove_column($_);
    }

    my $i = 0;
    my $cell;
    my $column;

    if ($palette_type ne 'Single color') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited=>\&cell_in_colors_treeview_changed, [$self, $i]);
	$column = Gtk2::TreeViewColumn->new_with_attributes('value', $cell, text => $i++);
	$tv->append_column($column);
    }

    $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($color_cell_size-2,$color_cell_size-2);
    $column = Gtk2::TreeViewColumn->new_with_attributes('color', $cell, pixbuf => $i++);
    $tv->append_column($column);

    foreach my $c ('red','green','blue','alpha') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited=>\&cell_in_colors_treeview_changed, [$self, $i-1]);
	$column = Gtk2::TreeViewColumn->new_with_attributes($c, $cell, text => $i++);
	$tv->append_column($column);
    }

    $self->fill_colors_treeview($table);
}

sub color_field_changed {
    my($self, $gui) = @{$_[1]};
    my $palette_type = $self->get_selected_palette_type();
    if (($palette_type eq 'Color bins' or $palette_type eq 'Color table') and 
	$self->{current_coloring_type} ne $self->current_coloring_type) {
	$self->create_colors_treeview();
    }
}

sub fill_color_scale_fields {
    my($self, $gui) = @{$_[1]};
    my @range;
    my $field = $self->get_selected_color_field();
    eval {
	@range = $self->value_range($field);
    };
    if ($@) {
	$gui->message("$@");
	return;
    }
    $self->{colors_dialog}->get_widget('color_scale_min_entry')->set_text($range[0]);
    $self->{colors_dialog}->get_widget('color_scale_max_entry')->set_text($range[1]);
}

sub make_color_legend {
    my($self, $gui) = @{$_[1]};
    my $palette_type = $self->get_selected_palette_type();
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    $self->put_scale_in_treeview($treeview, $palette_type);
}

sub fill_palette_type_combo {
    my($self, $palette_type) = @_;
    $palette_type = '' unless defined $palette_type;
    my $combo = $self->{colors_dialog}->get_widget('palette_type_combobox');
    my $model = $combo->get_model;
    $model->clear;
    my @palette_types = $self->supported_palette_types();
    my $i = 0;
    my $active = 0;
    delete $self->{index2palette_type};
    delete $self->{palette_type2index};
    for (@palette_types) {
	$model->set ($model->append, 0, $_);
	$self->{index2palette_type}{$i} = $_;
	$self->{palette_type2index}{$_} = $i;
	$active = $i if $_ eq $palette_type;
	$i++;
    }
    $combo->set_active($active);
    return $#palette_types+1;
}

sub fill_color_field_combo {
    my($self, $palette_type) = @_;
    $palette_type = $self->get_selected_palette_type() unless $palette_type;
    my $combo = $self->{colors_dialog}->get_widget('color_field_combobox');
    my $model = $combo->get_model;
    $model->clear;
    delete $self->{index2field};
    my $active = 0;
    my $i = 0;
    my $schema = $self->schema();
    for my $name (sort keys %$schema) {
	my $type = $schema->{$name}{TypeName};
	next unless $type;
	next if $palette_type eq 'Single color';
	next if ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow' or $palette_type eq 'Color bins') 
	    and not($type eq 'Integer' or $type eq 'Real');
	next if $palette_type eq 'Color table' and !($type eq 'Integer' or $type eq 'String');
	$model->set($model->append, 0, $name);
	$active = $i if $name eq $self->color_field();
	$self->{index2field}{$i} = $name;
	$i++;
    }
    $combo->set_active($active);
}

sub current_coloring_type {
    my($self) = @_;
    my $type = '';
    my $field = $self->get_selected_color_field();
    return unless defined $field;
    my $schema = $self->schema();
    if ($schema->{$field}{TypeName} eq 'Integer') {
	$type = 'Int';
    } elsif ($schema->{$field}{TypeName} eq 'Real') {
	$type = 'Double';
    } elsif ($schema->{$field}{TypeName} eq 'String') {
	$type = 'String';
    }
    return $type;
}

sub get_table_from_treeview {
    my ($self) = @_;
    my $palette_type = $self->get_selected_palette_type();
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $model = $treeview->get_model;
    return unless $model;
    my %types = ('Glib::String'=>1, 'Glib::Int'=>1, 'Glib::Double'=>1);
    my @indices;
    if ($palette_type eq 'Single color') {
	@indices = (1,2,3,4);
    } else {
	@indices = (0,2,3,4,5);
    }
    my $iter = $model->get_iter_first();
    my @table;
    while ($iter) {
	my @row = $model->get($iter, @indices);
	push @table, [@row];
	$iter = $model->iter_next($iter);
    }
    return \@table;
}

sub fill_colors_treeview {
    my ($self, $table) = @_;

    my $palette_type = $self->get_selected_palette_type();
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $model = $treeview->get_model;
    return unless $model;
    $model->clear;

    return unless $table and @$table;

    if ($palette_type eq 'Single color') {
	
	my $iter = $model->append(undef);
	set_color($model,$iter,undef,@{$table->[0]});

    } elsif ($palette_type eq 'Color table') {

	if ($self->current_coloring_type eq 'Int') {
	    @$table = sort {$a->[0] <=> $b->[0]} @$table;
	}
	for my $color (@$table) {
	    my $iter = $model->append(undef);
	    set_color($model,$iter,@$color);
	}

    } elsif ($palette_type eq 'Color bins') {

	@$table = sort {$a->[0] <=> $b->[0]} @$table;
	$self->{current_coloring_type} = $self->current_coloring_type;
	my $int = $self->{current_coloring_type} eq 'Int';

	for my $i (0..$#$table) {
	    my $color = $table->[$i];
	    $color->[0] = $int ? $MAX_INT : $MAX_REAL if $i == $#$table;
	    my $iter = $model->append(undef);
	    set_color($model,$iter,@$color);
	}
	
    }

}

sub set_color {
    my($model,$iter,$value,@color) = @_;
    my @set = ($iter);
    my $j = 0;
    push @set, ($j++, $value) if defined $value;
    my $pb = Gtk2::Gdk::Pixbuf->new('rgb',0,8,$color_cell_size,$color_cell_size);
    $pb->fill($color[0] << 24 | $color[1] << 16 | $color[2] << 8);
    push @set, ($j++, $pb);
    for my $k (0..3) {
	push @set, ($j++, $color[$k]);
    }
    $model->set(@set);
}

sub put_scale_in_treeview {
    my($self, $tv, $palette_type) = @_;

    my $model;
    $model = Gtk2::TreeStore->new(qw/Gtk2::Gdk::Pixbuf Glib::Double/);
    $tv->set_model($model);
    for ($tv->get_columns) {
	$tv->remove_column($_);
    }

    my $i = 0;
    my $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($color_cell_size-2,$color_cell_size-2);
    my $column = Gtk2::TreeViewColumn->new_with_attributes('color', $cell, pixbuf => $i++);
    $tv->append_column($column);

    $cell = Gtk2::CellRendererText->new;
    $cell->set(editable => 0);
    $column = Gtk2::TreeViewColumn->new_with_attributes('value', $cell, text => $i++);
    $tv->append_column($column);

    my $dialog = $self->{colors_dialog};
    my $min = $dialog->get_widget('color_scale_min_entry')->get_text();
    my $max = $dialog->get_widget('color_scale_max_entry')->get_text();
    my $hue_min = MAX(MIN($dialog->get_widget('hue_min_entry')->get_text() || 0,360),0);
    my $hue_max = MAX(MIN($dialog->get_widget('hue_max_entry')->get_text() || 0,360),0);
    my $hue_dir = $dialog->get_widget('hue_range_combobox')->get_active;
    if ($hue_dir == 1) {
	$hue_max += 360 if $hue_max < $hue_min;
    } else {
	$hue_max -= 360 if $hue_max > $hue_min;
    }
    my $hue = $dialog->get_widget('hue_entry')->get_text();
    return if $min eq '' or $max eq '';
    my $delta = ($max-$min)/14;
    my $x = $min;
    for my $i (1..15) {
	my $iter = $model->append(undef);

	my @set = ($iter);

	my($h,$s,$v);
	if ($palette_type eq 'Grayscale') {
	    if ($hue < 0) {
		$h = 0;
		$s = 0;
	    } else {
		$h = min($hue, 360);
		$s = 100;
	    }
	    $v = $delta == 0 ? 0 : ($x - $min)/($max - $min)*100;
	} else {
	    $h = $delta == 0 ? 0 : int($hue_min + ($x - $min)/($max-$min) * ($hue_max-$hue_min) + 0.5);
	    $h -= 360 if $h > 360;
	    $h += 360 if $h < 0;
	    $s = 100;
	    $v = 100;
	}
	
	my $pb = Gtk2::Gdk::Pixbuf->new('rgb',0,8,$color_cell_size,$color_cell_size);
	my @color = hsv2rgb($h, $s, $v);
	$pb->fill($color[0] << 24 | $color[1] << 16 | $color[2] << 8);

	my $j = 0;
	push @set, ($j++, $pb);
	push @set, ($j++, $x);
	$model->set(@set);
	$x += $delta;
    }
}

sub hsv2rgb {
    # /* after www.cs.rit.edu/~ncs/color/t_convert.html */
    my($h, $s, $v) = @_;
    if( $s == 0 ) {
	#// achromatic (grey)
	my $grey = floor(255.999*$v/100);
	return ($grey, $grey, $grey);
    }

    $h /= 60;			#// sector 0 to 5
    $s /= 100;
    $v /= 100;
    my $i = floor( $h );
    $i = 5 if $i == 6;
    my $f = $h - $i;		#// factorial part of h
    my $p = $v * ( 1 - $s );
    my $q = $v * ( 1 - $s * $f );
    my $t = $v * ( 1 - $s * ( 1 - $f ) );
    my ($r, $g, $b);

    if ( $i == 0 ) {
	$r = $v;
	$g = $t;
	$b = $p;
    } elsif ( $i == 1 ) {
	$r = $q;
	$g = $v;
	$b = $p;
    } elsif ( $i == 2 ) {
	$r = $p;
	$g = $v;
	$b = $t;
    } elsif ( $i == 3 ) {
	$r = $p;
	$g = $q;
	$b = $v;
    } elsif ( $i == 4 ) {
	$r = $t;
	$g = $p;
	$b = $v;
    } else { # 5
	$r = $v;
	$g = $p;
	$b = $q;
    }
    return (floor(255.999*$r), floor(255.999*$g), floor(255.999*$b));
}

sub colors_from_dialog {
    my($self, $gui) = @_;

    my $palette_type = $self->{colors_dialog}->get_widget('palette_type_combobox')->get_active();
    $palette_type = $self->{index2palette_type}{$palette_type};
    my $dialog = $gui->get_dialog('colors_from_dialog');
    $dialog->get_widget('colors_from_dialog')->set_title("Get $palette_type from");
    my $tv = $dialog->get_widget('colors_from_treeview');

    my $model = Gtk2::TreeStore->new(qw/Glib::String/);
    $tv->set_model($model);

    for ($tv->get_columns) {
	$tv->remove_column($_);
    }

    my $i = 0;
    foreach my $column ('Layer') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }

    $model->clear;
    my @names;
    for my $layer (@{$gui->{overlay}->{layers}}) {
	next if $layer->name() eq $self->name();
	push @names, $layer->name();
	$model->set ($model->append(undef), 0, $layer->name());
    }

    #$dialog->move(@{$self->{colors_from_position}}) if $self->{colors_from_position};
    $dialog->get_widget('colors_from_dialog')->show_all;

    my $response = $dialog->get_widget('colors_from_dialog')->run;

    my $table;

    if ($response eq 'ok') {

	my @sel = $tv->get_selection->get_selected_rows;
	if (@sel) {
	    my $i = $sel[0]->to_string if @sel;
	    my $from_layer = $gui->{overlay}->get_layer_by_name($names[$i]);

	    if ($palette_type eq 'Color table') {
		$table = $from_layer->color_table();
	    } elsif ($palette_type eq 'Color bins') {
		$table = $from_layer->color_bins();
	    }
	}
	
    }

    $dialog->get_widget('colors_from_dialog')->destroy;

    return $table;
}

# labels dialog

sub open_labels_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{labels_dialog};
    unless ($dialog) {
	$self->{labels_dialog} = $dialog = $gui->get_dialog('labels_dialog');
	croak "labels_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('labels_dialog')->set_title("Labels for ".$self->name);
	$dialog->get_widget('labels_dialog')->signal_connect(delete_event => \&cancel_labels, [$self, $gui]);

	$dialog->get_widget('labels_font_button')->signal_connect(clicked => \&labels_font, [$self, $gui, 0]);
	$dialog->get_widget('labels_color_button')->signal_connect(clicked => \&labels_color, [$self, $gui, 0]);
	
	$dialog->get_widget('apply_labels_button')->signal_connect(clicked => \&apply_labels, [$self, $gui, 0]);
	$dialog->get_widget('cancel_labels_button')->signal_connect(clicked => \&cancel_labels, [$self, $gui]);
	$dialog->get_widget('ok_labels_button')->signal_connect(clicked => \&apply_labels, [$self, $gui, 1]);
    } else {
	$dialog->get_widget('labels_dialog')->move(@{$self->{labels_dialog_position}});
    }

    # backup

    my $labeling = $self->{backup}->{labeling} = $self->labeling;
    
    # set up controllers

    my $schema = $self->schema;

    my $combo = $dialog->get_widget('labels_field_combobox');
    my $model = $combo->get_model;
    $model->clear;
    my $i = 0;
    my $active = 0;
    $model->set ($model->append, 0, 'No Labels');
    $active = $i if $labeling->{field} eq 'No Labels';
    $i++;
    for my $fname (sort keys %$schema) {
	$model->set ($model->append, 0, $fname);
	$active = $i if $labeling->{field} eq $fname;
	$i++;
    }
    $combo->set_active($active);

    $combo = $dialog->get_widget('labels_placement_combobox');
    $model = $combo->get_model;
    $model->clear;
    $i = 0;
    $active = 0;
    my $h = \%Gtk2::Ex::Geo::Layer::LABEL_PLACEMENT;
    for my $e (sort {$h->{$a} <=> $h->{$b}} keys %$h) {
	$model->set ($model->append, 0, $e);
	$active = $i if $labeling->{placement} eq $e;
	$i++;
    }
    $combo->set_active($active);

    $dialog->get_widget('labels_font_label')->set_text($labeling->{font});
    $dialog->get_widget('labels_color_label')->set_text("@{$labeling->{color}}");
    $dialog->get_widget('labels_min_size_entry')->set_text($labeling->{min_size});
    
    $dialog->get_widget('labels_dialog')->show_all;
}

sub apply_labels {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{labels_dialog};

    my $labeling = {};

    my $combo = $dialog->get_widget('labels_field_combobox');
    my $model = $combo->get_model;
    my $iter = $model->get_iter_from_string($combo->get_active());
    $labeling->{field} = $model->get_value($iter);

    $combo = $dialog->get_widget('labels_placement_combobox');
    $model = $combo->get_model;
    $iter = $model->get_iter_from_string($combo->get_active());
    $labeling->{placement} = $model->get_value($iter);

    $labeling->{min_size} = $dialog->get_widget('labels_min_size_entry')->get_text;
    $labeling->{font} = $dialog->get_widget('labels_font_label')->get_text;
    @{$labeling->{color}} = split(/ /, $dialog->get_widget('labels_color_label')->get_text);
    $labeling->{min_size} = $dialog->get_widget('labels_min_size_entry')->get_text;

    $self->labeling($labeling);

    $self->{labels_dialog_position} = [$dialog->get_widget('labels_dialog')->get_position];
    $dialog->get_widget('labels_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

sub cancel_labels {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }

    $self->labeling($self->{labeling_backup});

    my $dialog = $self->{labels_dialog}->get_widget('labels_dialog');
    $self->{labels_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

sub labels_font {
    my($self, $gui) = @{$_[1]};
    my $font_chooser = Gtk2::FontSelectionDialog->new ("Select font for the labels");
    my $font_name = $self->{labels_dialog}->get_widget('labels_font_label')->get_text;
    $font_chooser->set_font_name($font_name);
    if ($font_chooser->run eq 'ok') {
	$font_name = $font_chooser->get_font_name;
	$self->{labels_dialog}->get_widget('labels_font_label')->set_text($font_name);
    }
    $font_chooser->destroy;
}

sub labels_color {
    my($self, $gui) = @{$_[1]};
    my @color = split(/ /, $self->{labels_dialog}->get_widget('labels_color_label')->get_text);
    my $color_chooser = Gtk2::ColorSelectionDialog->new('Choose color for the label font');
    my $s = $color_chooser->colorsel;    
    $s->set_has_opacity_control(1);
    my $c = new Gtk2::Gdk::Color ($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    $s->set_current_alpha($color[3]*257);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	$color[3] = int($s->get_current_alpha()/257);
	$self->{labels_dialog}->get_widget('labels_color_label')->set_text("@color");
    }
    $color_chooser->destroy;
}

## @ignore
sub MIN {
    $_[0] > $_[1] ? $_[1] : $_[0];
}

## @ignore
sub MAX {
    $_[0] > $_[1] ? $_[0] : $_[1];
}

1;
