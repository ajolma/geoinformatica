package Gtk2::Ex::Geo::Dialogs::Colors;
# @brief 

use strict;
use warnings;
use Carp;
use Graphics::ColorUtils qw /:all/;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw /:all/;
use Gtk2::Ex::Geo::Dialogs qw/:all/;

use vars qw/$MAX_INT $MAX_REAL $COLOR_CELL_SIZE/;

$MAX_INT = 999999;
$MAX_REAL = 999999999.99;
$COLOR_CELL_SIZE = 20;

# open colors dialog

sub open {
    my($self, $gui) = @_;

    my($dialog, $boot) = $self->bootstrap_dialog
	($gui, 'colors_dialog', "Colors for ".$self->name,
	 {
	     colors_dialog => [delete_event => \&cancel_colors, [$self, $gui]],
	     color_scale_button => [clicked => \&fill_color_scale_fields, [$self, $gui]],
	     color_legend_button => [clicked => \&make_color_legend, [$self, $gui]],
	     copy_colors_button => [clicked => \&copy_colors, [$self, $gui]],
	     open_colors_button => [clicked => \&open_colors_file, [$self, $gui]],
	     save_colors_button => [clicked => \&save_colors_file, [$self, $gui]],
	     edit_color_button => [clicked => \&edit_color, [$self, $gui]],
	     delete_color_button => [clicked => \&delete_color, [$self, $gui]],
	     add_color_button => [clicked => \&add_color, [$self, $gui]],
	     min_hue_button => [clicked => \&set_hue_range, [$self, $gui, 'min']],
	     max_hue_button => [clicked => \&set_hue_range, [$self, $gui, 'max']],
	     hue_button => [clicked => \&set_hue, [$self, $gui]],
	     border_color_button => [clicked => \&border_color_dialog, [$self]],
	     colors_apply_button => [clicked => \&apply_colors, [$self, $gui, 0]],
	     colors_cancel_button => [clicked => \&cancel_colors, [$self, $gui]],
	     colors_ok_button => [clicked => \&apply_colors, [$self, $gui, 1]],

	     palette_type_combobox => [changed => \&palette_type_changed, [$self, $gui]],
	     color_field_combobox => [changed => \&color_field_changed, [$self, $gui]],

	     color_scale_min_entry => [changed => \&color_scale_changed, [$self, $gui]],
	     color_scale_max_entry => [changed => \&color_scale_changed, [$self, $gui]],

	     hue_range_combobox => [changed => \&hue_changed, $self],
	     
	 });

    if ($boot) {
	my $combo = $self->{colors_dialog}->get_widget('palette_type_combobox');
	my $renderer = Gtk2::CellRendererText->new;
	$combo->pack_start($renderer, TRUE);
	$combo->add_attribute($renderer, text => 0);
	my $model = Gtk2::ListStore->new('Glib::String');
	$combo->set_model($model);

	$combo = $self->{colors_dialog}->get_widget('color_field_combobox');
	$renderer = Gtk2::CellRendererText->new;
	$combo->pack_start($renderer, TRUE);
	$combo->add_attribute($renderer, text => 0);
	$model = Gtk2::ListStore->new('Glib::String');
	$combo->set_model($model);

	$combo = $self->{colors_dialog}->get_widget('hue_range_combobox');
	$renderer = Gtk2::CellRendererText->new;
	$combo->pack_start($renderer, TRUE);
	$combo->add_attribute($renderer, text => 0);
	$model = Gtk2::ListStore->new('Glib::String');
	$combo->set_model($model);
    }

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
    @{$self->{backup}->{border_color}} = $self->border_color;

    $self->{current_coloring_type} = '';

    # set up the controllers

    my $combo = $dialog->get_widget('palette_type_combobox');
    my $model = $combo->get_model;
    $model->clear;
    my $i = 0;
    my $active = 0;
    for my $type ($self->supported_palette_types()) {
	$active = $i if $type eq $palette_type;
	$model->set($model->append, 0, $type);
	$i++;
    }
    $combo->set_active($active);

    $combo = $dialog->get_widget('hue_range_combobox');
    $model = $combo->get_model;
    $model->clear;
    for my $type ('up to', 'down to') {
	$model->set($model->append, 0, $type);
	$i++;
    }

    fill_color_field_combo($self); 

    $dialog->get_widget('color_scale_min_entry')->set_text($scale[0]);
    $dialog->get_widget('color_scale_max_entry')->set_text($scale[1]);
    $dialog->get_widget('min_hue_label')->set_text($hue_range[0]);
    $dialog->get_widget('max_hue_label')->set_text($hue_range[1]);
    $dialog->get_widget('hue_range_combobox')->set_active($hue_range[2] == 1 ? 0 : 1);
    $dialog->get_widget('hue_checkbutton')->set_active($self->hue > 0 ? TRUE : FALSE);
    $dialog->get_widget('hue_label')->set_text($self->hue);
    $dialog->get_widget('border_color_checkbutton')->set_active($self->border_color > 0);

    my @color = $self->border_color;
    @color = (0, 0, 0) unless @color;
    $dialog->get_widget('border_color_label')->set_text("@color");

    fill_colors_treeview($self);
    return $self->{colors_dialog}->get_widget('colors_dialog');
}

# set ups

##@ignore
sub fill_color_field_combo {
    my($self) = @_;
    my $palette_type = $self->palette_type;
    my $combo = $self->{colors_dialog}->get_widget('color_field_combobox');
    my $model = $combo->get_model;
    $model->clear;
    my $i = 0;
    my $active;
    my $color_field = $self->color_field();
    my @fields = $self->schema()->fields;
    for my $field (@fields) {
	next unless $field->{Type};
	next if $palette_type eq 'Single color';
	next if ($palette_type eq 'Grayscale' or
		 $palette_type eq 'Rainbow' or 
		 $palette_type eq 'Color bins') 
	    and not($field->{Type} eq 'Integer' or 
		    $field->{Type} eq 'Real');
	next if ($palette_type eq 'Color table' and 
		 !($field->{Type} eq 'Integer' or 
		   $field->{Type} eq 'String'));
	$model->set($model->append, 0, $field->{Name});
	$active = $i if $field->{Name} eq $self->color_field();
	$i++;
    }
    if (@fields and !defined($active)) {
	$active = 0;
	$self->color_field($fields[0]->{Name});
    }
    $combo->set_active($active) if defined $active;
}

# callbacks for edits

##@ignore
sub palette_type_changed {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{colors_dialog};
    my $palette_type = get_value_from_combo($self->{colors_dialog}, 'palette_type_combobox');
    return unless $palette_type;
    $self->palette_type($palette_type);

    fill_color_field_combo($self);

    my $tv = $dialog->get_widget('colors_treeview');
    
    for my $w (qw/color_field_label color_field_combobox 
            color_scale_min_entry color_scale_max_entry color_legend_button
            rainbow_label rainbow_2_label
            min_hue_label min_hue_button max_hue_label max_hue_button hue_range_combobox 
            hue_checkbutton hue_label hue_button 
            edit_color_button delete_color_button add_color_button
            copy_colors_button open_colors_button save_colors_button/) {
	$dialog->get_widget($w)->set_sensitive(0);
    }
    $tv->set_sensitive(0);

    return unless create_colors_treeview($self);
    
    if ($palette_type ne 'Single color') {
	for my $w (qw/color_field_label color_field_combobox/) {
	    $dialog->get_widget($w)->set_sensitive(1);
	}
    }
    
    if ($palette_type eq 'Grayscale') {
	for my $w (qw/hue_checkbutton hue_label hue_button/) {
	    $dialog->get_widget($w)->set_sensitive(1);
	}
    } elsif ($palette_type eq 'Rainbow') {
	for my $w (qw/rainbow_label rainbow_2_label
                      min_hue_label min_hue_button max_hue_label max_hue_button hue_range_combobox/) {
	    $dialog->get_widget($w)->set_sensitive(1);
	}
    }
    
    if ($palette_type eq 'Single color') {
	$dialog->get_widget('edit_color_button')->set_sensitive(1);
	$tv->set_sensitive(1);
    } elsif ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow' or $palette_type =~ 'channel') {
	for my $w (qw/color_legend_button color_scale_min_entry color_scale_max_entry/) {
	    $dialog->get_widget($w)->set_sensitive(1);
	}
	$tv->set_sensitive(1);
    } elsif ($palette_type eq 'Color table') {
	for my $w (qw/copy_colors_button open_colors_button save_colors_button 
                edit_color_button delete_color_button add_color_button/) {
	    $dialog->get_widget($w)->set_sensitive(1);
	}
	$tv->set_sensitive(1);
	
    } elsif ($palette_type eq 'Color bins') {
	for my $w (qw/copy_colors_button open_colors_button save_colors_button 
                edit_color_button delete_color_button add_color_button/) {
	    $dialog->get_widget($w)->set_sensitive(1);
	}
	$tv->set_sensitive(1);
    }
}

##@ignore
sub color_field_changed {
    my($self, $gui) = @{$_[1]};
    my $field = get_value_from_combo($self->{colors_dialog}, 'color_field_combobox');
    return unless $field; # model is cleared
    $self->color_field($field);
    my $palette_type = $self->palette_type;
    if (($palette_type eq 'Color bins' or $palette_type eq 'Color table') and 
	$self->{current_coloring_type} ne current_coloring_type($self)) {
	create_colors_treeview($self);
    }
}

## @ignore
sub color_scale_changed {
    my($self, $gui) = @{$_[1]};
    my $d = $self->{colors_dialog};
    my $min = get_number_from_entry($d->get_widget('color_scale_min_entry'));
    my $max = get_number_from_entry($d->get_widget('color_scale_max_entry'));
    $self->color_scale($min, $max);
}

## @ignore
sub hue_changed {
    my(undef, $self) = @_;
    my $d = $self->{colors_dialog};
    my $min = get_number_from_entry($d->get_widget('min_hue_label'));
    my $max = get_number_from_entry($d->get_widget('max_hue_label'));
    my $dir = $d->get_widget('hue_range_combobox')->get_active == 0 ? 1 : -1; # up is 1, down is -1
    $self->hue_range($min, $max, $dir);
    my $hue = $d->get_widget('hue_checkbutton')->get_active() ? 
	$d->get_widget('hue_label')->get_text() : -1;
    $self->hue($hue);
    create_colors_treeview($self);
}

# button callbacks

##@ignore
sub apply_colors {
    my($self, $gui, $close) = @{$_[1]};
    my @color = split(/ /, $self->{colors_dialog}->get_widget('border_color_label')->get_text);
    my $has_border = $self->{colors_dialog}->get_widget('border_color_checkbutton')->get_active();
    @color = () unless $has_border;
    $self->border_color(@color);
    $self->hide_dialog('colors_dialog') if $close;
    $gui->{overlay}->render;
}

##@ignore
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
    $self->border_color(@{$self->{backup}->{border_color}});

    $self->hide_dialog('colors_dialog');
    $gui->{overlay}->render;
    1;
}

##@ignore
sub copy_colors {
    my($self, $gui) = @{$_[1]};
    my $table = copy_colors_dialog($self, $gui);
    if ($table) {
	my $palette_type = $self->palette_type;
	if ($palette_type eq 'Color table') {
	    $self->color_table($table);
	} elsif ($palette_type eq 'Color bins') {
	    $self->color_bins($table);
	}
	fill_colors_treeview($self);
    }
}

##@ignore
sub open_colors_file {
    my($self, $gui) = @{$_[1]};
    my $palette_type = $self->palette_type;
    my $filename = file_chooser("Select a $palette_type file", 'open');
    if ($filename) {
	if ($palette_type eq 'Color table') {
	    eval {
		$self->color_table($filename);
	    }
	} elsif ($palette_type eq 'Color bins') {
	    eval {
		$self->color_bins($filename);
	    }
	}
	if ($@) {
	    $gui->message("$@");
	} else {
	    fill_colors_treeview($self);
	}
    }
}

##@ignore
sub save_colors_file {
    my($self, $gui) = @{$_[1]};
    my $palette_type = $self->palette_type;
    my $filename = file_chooser("Save $palette_type file as", 'save');
    if ($filename) {
	if ($palette_type eq 'Color table') {
	    eval {
		$self->save_color_table($filename); 
	    }
	} elsif ($palette_type eq 'Color bins') {
	    eval {
		$self->save_color_bins($filename);
	    }
	}
	if ($@) {
	    $gui->message("$@");
	}
    }
}

##@ignore
sub edit_color {
    my($self, $gui) = @{$_[1]};
    my $palette_type = $self->palette_type;
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows;
    return unless @selected;

    my $i = $selected[0]->to_string;
    my $x;
    my @color;
    if ($palette_type eq 'Single color') {
	@color = $self->color;
    } else {
	@color = $self->color($i);
	$x = shift @color;
	@color = @color;
    }
	    
    my $d = Gtk2::ColorSelectionDialog->new('Choose color for selected entries');
    my $s = $d->colorsel;
	    
    $s->set_has_opacity_control(1);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    $s->set_current_alpha($color[3]*257);
    
    if ($d->run eq 'ok') {
	$d->destroy;
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	$color[3] = int($s->get_current_alpha()/257);

	if ($palette_type eq 'Single color') {
	    $self->color(@color);
	} else {
	    for my $selected (@selected) {
		my $i = $selected->to_string;
		$self->color($i, $x, @color);
	    } 
	}
	fill_colors_treeview($self);
    } else {
	$d->destroy;
    }
    
    for my $selected (@selected) {
	$selection->select_path($selected);
    }
}

##@ignore
sub delete_color {
    my($self, $gui) = @{$_[1]};
    my $palette_type = $self->palette_type;
    my $table = $palette_type eq 'Color table' ?
	$self->color_table() : 
	( $palette_type eq 'Color bins' ? $self->color_bins() : undef );
    return unless $table and @$table;
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows if $selection;
    my $model = $treeview->get_model;
    return unless $model;
    my $at;
    for my $selected (@selected) {
	$at = $selected->to_string;
	my $iter = $model->get_iter_from_string($at);
	$model->remove($iter);
	$self->remove_color($at);
    }
    #$at--;
    $at = 0 if $at < 0;
    $at = $#$table if $at > $#$table;
    return if $at < 0;
    $treeview->set_cursor(Gtk2::TreePath->new($at));
}

##@ignore
sub add_color {
    my($self, $gui) = @{$_[1]};
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows if $selection;
    my $index = $selected[0]->to_string+1 if @selected;
    my $model = $treeview->get_model;
    return unless $model;
    my $palette_type = $self->palette_type;
    my @color = (255, 255, 255, 255);
    my $table = $palette_type eq 'Color table' ? $self->color_table : $self->color_bins;
    $index = @$table unless $index;
    my $x;
    if (@$table) {
	if ($palette_type eq 'Color table') {
	    if (current_coloring_type($self) eq 'Int') {
		if ($index > 0) {
		    $x = $table->[$index-1]->[0]+1;
		    while ($index < @$table and $x == $table->[$index]->[0]) {
			$x++;
			$index++;
		    }
		} else {
		    $x = 0;
		}
	    } else {
		$x = 'change this';
	    }
	} elsif ($palette_type eq 'Color bins') {
	    if (@$table == 1 or $index <= 0 or $index > $#$table) {
		$x = $table->[$#$table]->[0] + 1;
	    } else {
		if (current_coloring_type($self) eq 'Int') {
		    $x = $table->[$index-1]->[0]+1;
		    while ($index < @$table and $x == $table->[$index]->[0]) {
			$x++;
			$index++;
		    } 
		} else {
		    $x = ($table->[$index-1]->[0] + $table->[$index]->[0])/2;
		}
	    }
	}
    } else {
	if (current_coloring_type($self) eq 'String') {
	    $x = 'change this';
	} else {
	    $x = 0;
	}
	$index = 0;
    }
    $self->add_color($index, $x, @color);
    my $iter = $model->insert(undef, $index);
    set_color($model, $iter, $x, @color);
    $treeview->set_cursor(Gtk2::TreePath->new($index));
}

##@ignore
sub set_hue_range {
    my($self, $gui, $dir) = @{$_[1]};
    my $dialog = $self->{colors_dialog};
    my $hue = $dialog->get_widget($dir.'_hue_label')->get_text();
    my @color = hsv2rgb($hue, 1, 1);
    my $color_chooser = Gtk2::ColorSelectionDialog->new("Choose $dir hue for rainbow palette");
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	@color = rgb2hsv(@color);
	$dialog->get_widget($dir.'_hue_label')->set_text(int($color[0]));
    }
    $color_chooser->destroy;
    hue_changed(undef, $self);
}

##@ignore
sub set_hue {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{colors_dialog};
    my $hue = $dialog->get_widget('hue_label')->get_text();
    $hue = 0 if $hue < 0;
    my @color = hsv2rgb($hue, 1, 1);
    my $color_chooser = Gtk2::ColorSelectionDialog->new('Choose hue for grayscale palette');
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	@color = rgb2hsv(@color);
	$dialog->get_widget('hue_label')->set_text(int($color[0]));
	$dialog->get_widget('hue_checkbutton')->set_active(TRUE);
    }
    $color_chooser->destroy;
    hue_changed(undef, $self);
}

##@ignore
sub border_color_dialog {
    my($self) = @{$_[1]};
    my $dialog = $self->{colors_dialog};
    my @color = split(/ /, $dialog->get_widget('border_color_label')->get_text);
    my $color_chooser = Gtk2::ColorSelectionDialog->new('Choose color for the border lines in '.$self->name);
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    #$s->set_current_alpha($color[3]*257);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	#$color[3] = int($s->get_current_alpha()/257);
	$dialog->get_widget('border_color_label')->set_text("@color");
    }
    $color_chooser->destroy;
}

##@ignore
sub fill_color_scale_fields {
    my($self, $gui) = @{$_[1]};
    my @range;
    my $field = $self->color_field;
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

##@ignore
sub make_color_legend {
    my($self, $gui) = @{$_[1]};
    put_scale_in_treeview($self);
}

# color treeview subs

##@ignore
sub cell_in_colors_treeview_changed {
    my($cell, $path, $new_value, $data) = @_;
    my($self, $column) = @$data;
    my $palette_type = $self->palette_type;
    my @color;
    if ($palette_type eq 'Single color') {
	@color = $self->color();
    } else {
	@color = $self->color($path);
    }
    $color[$column] = $new_value;
    if ($palette_type eq 'Single color') {
	$self->color(@color);
    } else {
	$self->color($path, @color);
    }
    fill_colors_treeview($self);
}

##@ignore
sub create_colors_treeview {
    my($self) = @_;

    my $palette_type = $self->palette_type;
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    
    if ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow') {
	put_scale_in_treeview($self);
	return 1;
    }
    
    my $model = $treeview->get_model;
    $model->clear if $model;
    my $type = $self->{current_coloring_type} = current_coloring_type($self);
    if ($palette_type eq 'Single color') {
	$model = Gtk2::TreeStore->new(qw/Gtk2::Gdk::Pixbuf Glib::Int Glib::Int Glib::Int Glib::Int/);
    } elsif ($palette_type eq 'Color table') {
	return unless $type;
	$model = Gtk2::TreeStore->new("Glib::$type","Gtk2::Gdk::Pixbuf","Glib::Int","Glib::Int","Glib::Int","Glib::Int");
    } elsif ($palette_type eq 'Color bins') {
	return unless $type;
	$model = Gtk2::TreeStore->new("Glib::$type","Gtk2::Gdk::Pixbuf","Glib::Int","Glib::Int","Glib::Int","Glib::Int");
    }
    $treeview->set_model($model);
    for my $col ($treeview->get_columns) {
	$treeview->remove_column($col);
    }

    my $i = 0;
    my $cell;
    my $column;

    if ($palette_type ne 'Single color') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited => \&cell_in_colors_treeview_changed, [$self, $i]);
	$column = Gtk2::TreeViewColumn->new_with_attributes('value', $cell, text => $i++);
	$treeview->append_column($column);
    }

    $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($COLOR_CELL_SIZE-2,$COLOR_CELL_SIZE-2);
    $column = Gtk2::TreeViewColumn->new_with_attributes('color', $cell, pixbuf => $i++);
    $treeview->append_column($column);

    for my $c ('red','green','blue','alpha') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited => \&cell_in_colors_treeview_changed, [$self, $i-1]);
	$column = Gtk2::TreeViewColumn->new_with_attributes($c, $cell, text => $i++);
	$treeview->append_column($column);
    }
    $treeview->get_selection->set_mode('multiple');
    fill_colors_treeview($self);
    return 1;
}

##@ignore
sub current_coloring_type {
    my($self) = @_;
    my $field = $self->color_field;
    return '' unless defined $field;
    $field = $self->schema->field($field);
    return '' unless $field;
    return 'Int' if $field->{Type} eq 'Integer';
    return 'Double' if $field->{Type} eq 'Real';
    return 'String' if $field->{Type} eq 'String';
    return '';
}

##@ignore
sub fill_colors_treeview {
    my($self) = @_;

    my $palette_type = $self->palette_type;
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $model = $treeview->get_model;
    return unless $model;
    $model->clear;

    if ($palette_type eq 'Single color') {
	
	my $iter = $model->append(undef);
	set_color($model,$iter, undef, $self->single_color());

    } elsif ($palette_type eq 'Color table') {

	my $table = $self->color_table();

	for my $color (@$table) {
	    my $iter = $model->append(undef);
	    set_color($model, $iter, @$color);
	}
	
    } elsif ($palette_type eq 'Color bins') {

	my $table = $self->color_bins();

	for my $color (@$table) {
	    my $iter = $model->append(undef);
	    set_color($model, $iter, @$color);
	}
	
    }

}

##@ignore
sub set_color {
    my($model, $iter, $value, @color) = @_;
    my @set = ($iter);
    my $j = 0;
    push @set, ($j++, $value) if defined $value;
    my $pb = Gtk2::Gdk::Pixbuf->new('rgb',0,8,$COLOR_CELL_SIZE,$COLOR_CELL_SIZE);
    $pb->fill($color[0] << 24 | $color[1] << 16 | $color[2] << 8);
    push @set, ($j++, $pb);
    for my $k (0..3) {
	push @set, ($j++, $color[$k]);
    }
    $model->set(@set);
}


##@ignore
sub put_scale_in_treeview {
    my($self) = @_;
    my $palette_type = $self->palette_type;
    my $dialog = $self->{colors_dialog};
    my $treeview = $dialog->get_widget('colors_treeview');

    my $model = Gtk2::TreeStore->new(qw/Gtk2::Gdk::Pixbuf Glib::Double/);
    $treeview->set_model($model);
    for my $col ($treeview->get_columns) {
	$treeview->remove_column($col);
    }

    my $i = 0;
    my $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($COLOR_CELL_SIZE-2, $COLOR_CELL_SIZE-2);
    my $column = Gtk2::TreeViewColumn->new_with_attributes('color', $cell, pixbuf => $i++);
    $treeview->append_column($column);

    $cell = Gtk2::CellRendererText->new;
    $cell->set(editable => 0);
    $column = Gtk2::TreeViewColumn->new_with_attributes('value', $cell, text => $i++);
    $treeview->append_column($column);

    my($min, $max) = $self->color_scale;
    my($hue_min, $hue_max, $hue_dir) = $self->hue_range;
    if ($hue_dir == 1) {
	$hue_max += 360 if $hue_max < $hue_min;
    } else {
	$hue_max -= 360 if $hue_max > $hue_min;
    }
    my $hue = $self->hue;
    return if $min eq '' or $max eq '';
    my $delta = ($max-$min)/14;
    my $x = $max;
    for my $i (1..15) {
	my $iter = $model->append(undef);

	my @set = ($iter);

	my($h,$s,$v);
	if ($palette_type eq 'Grayscale') {
	    if ($hue < 0) {
		$h = 0;
		$s = 0;
	    } else {
		$h = $hue;
		$s = 1;
	    }
	    $v = $delta == 0 ? 0 : ($x - $min)/($max - $min)*1;
	} else {
	    $h = $delta == 0 ? 0 : int($hue_min + ($x - $min)/($max-$min) * ($hue_max-$hue_min) + 0.5);
	    $h -= 360 if $h > 360;
	    $h += 360 if $h < 0;
	    $s = 1;
	    $v = 1;
	}
	
	my $pb = Gtk2::Gdk::Pixbuf->new('rgb', 0, 8, $COLOR_CELL_SIZE, $COLOR_CELL_SIZE);
	my @color = hsv2rgb($h, $s, $v);
	$pb->fill($color[0] << 24 | $color[1] << 16 | $color[2] << 8);

	my $j = 0;
	push @set, ($j++, $pb);
	push @set, ($j++, $x);
	$model->set(@set);
	$x -= $delta;
    }
}

##@ignore
sub copy_colors_dialog {
    my($self, $gui) = @_;

    my $palette_type = $self->palette_type;
    my $dialog = $gui->get_dialog('colors_from_dialog');
    $dialog->get_widget('colors_from_dialog')->set_title("Get $palette_type from");
    my $treeview = $dialog->get_widget('colors_from_treeview');

    my $model = Gtk2::TreeStore->new(qw/Glib::String/);
    $treeview->set_model($model);

    for my $col ($treeview->get_columns) {
	$treeview->remove_column($col);
    }

    my $i = 0;
    for my $column ('Layer') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
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
    $dialog->get_widget('colors_from_dialog')->present;

    my $response = $dialog->get_widget('colors_from_dialog')->run;

    my $table;
    #print STDERR "response=$response\n";

    if ($response eq 'ok') {

	my @sel = $treeview->get_selection->get_selected_rows;
	if (@sel) {
	    my $i = $sel[0]->to_string if @sel;
	    #print STDERR "index=$i, name=$names[$i]\n";
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

1;
