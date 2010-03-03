package Gtk2::Ex::Geo::Dialogs::Colors;
# @brief 

use strict;
use warnings;
use Carp;
use Graphics::ColorUtils qw /:all/;
use Glib qw/TRUE FALSE/;

use vars qw/$MAX_INT $MAX_REAL $COLOR_CELL_SIZE/;

$MAX_INT = 999999;
$MAX_REAL = 999999999.99;
$COLOR_CELL_SIZE = 20;

# open colors dialog

sub open {
    my($self, $gui) = @_;

    my $dialog = $self->bootstrap_dialog
	($gui, 'colors_dialog', "Colors for ".$self->name,
	 {
	     colors_dialog => [delete_event => \&cancel_colors, [$self, $gui]],
	     color_scale_button => [clicked => \&fill_color_scale_fields, [$self, $gui]],
	     color_legend_button => [clicked => \&make_color_legend, [$self, $gui]],
	     get_colors_button => [clicked => \&get_colors, [$self, $gui]],
	     open_colors_button => [clicked => \&open_colors_file, [$self, $gui]],
	     save_colors_button => [clicked => \&save_colors_file, [$self, $gui]],
	     edit_color_button => [clicked => \&edit_color, [$self, $gui]],
	     delete_color_button => [clicked => \&delete_color, [$self, $gui]],
	     add_color_button => [clicked => \&add_color, [$self, $gui]],
	     palette_type_combobox => [changed => \&palette_type_changed, [$self, $gui]],
	     color_field_combobox => [changed => \&color_field_changed, [$self, $gui]],
	     min_hue_button => [clicked => \&set_hue_range, [$self, $gui, 'min']],
	     max_hue_button => [clicked => \&set_hue_range, [$self, $gui, 'max']],
	     hue_button => [clicked => \&set_hue, [$self, $gui]],
	     colors_apply_button => [clicked => \&apply_colors, [$self, $gui, 0]],
	     colors_cancel_button => [clicked => \&cancel_colors, [$self, $gui]],
	     colors_ok_button => [clicked => \&apply_colors, [$self, $gui, 1]],
	 });
    
    my $palette_type_combo = $dialog->get_widget('palette_type_combobox');
    my $field_combo = $dialog->get_widget('color_field_combobox');
    my $scale_min = $dialog->get_widget('color_scale_min_entry');
    my $scale_max = $dialog->get_widget('color_scale_max_entry');
    my $hue_min = $dialog->get_widget('min_hue_label');
    my $hue_max = $dialog->get_widget('max_hue_label');
    my $hue_range_sel = $dialog->get_widget('hue_range_combobox');
    my $hue_button = $dialog->get_widget('hue_checkbutton');
    my $hue = $dialog->get_widget('hue_label');

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

    fill_palette_type_combo($self, $palette_type);
    fill_color_field_combo($self, $palette_type);
    $scale_min->set_text($scale[0]);
    $scale_max->set_text($scale[1]);
    $hue_min->set_text($hue_range[0]);
    $hue_max->set_text($hue_range[1]);
    $hue_range_sel->set_active($hue_range[2] == 1 ? 0 : 1);
    $hue_button->set_active($self->hue > 0 ? TRUE : FALSE);
    my @color = $self->hue;
    $hue->set_text("@color");
    palette_type_changed(undef, [$self, $gui]);
    color_field_changed(undef, [$self, $gui]);
    if ($palette_type eq 'Single color') {
	fill_colors_treeview($self, [[@single_color]]);
    } elsif ($palette_type eq 'Color table') {
	fill_colors_treeview($self, $table);
    } elsif ($palette_type eq 'Color bins') {
	fill_colors_treeview($self, $bins);
    }

    $dialog->get_widget('colors_dialog')->show_all;
}

##@ignore
sub apply_colors {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{colors_dialog};
    
    my $palette_type = get_selected_palette_type($self);
    $self->palette_type($palette_type);
    my $field_combo = $dialog->get_widget('color_field_combobox');
    my $field = $self->{index2field}{$field_combo->get_active()};
    $self->color_field($field) if defined $field;
    my $scale_min = $dialog->get_widget('color_scale_min_entry');
    my $scale_max = $dialog->get_widget('color_scale_max_entry');
    $self->color_scale($scale_min->get_text(), $scale_max->get_text());

    $self->hue_range($dialog->get_widget('min_hue_label')->get_text,
		     $dialog->get_widget('max_hue_label')->get_text,
		     $dialog->get_widget('hue_range_combobox')->get_active == 0 ? 1 : -1);
    my $hue = $dialog->get_widget('hue_checkbutton')->get_active();
    $self->hue($hue ? $dialog->get_widget('hue_label')->get_text : -1);
    
    if ($palette_type eq 'Single color') {
	my $table = get_table_from_treeview($self);
	$self->single_color(@{$table->[0]});
    } elsif ($palette_type eq 'Color table') {
	my $table = get_table_from_treeview($self);
	$self->color_table($table);
    } elsif ($palette_type eq 'Color bins') {
	my $table = get_table_from_treeview($self);
	$self->color_bins($table);
    }

    if ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow') {
	put_scale_in_treeview($self, $dialog->get_widget('colors_treeview'), $palette_type);
    }

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

    $self->hide_dialog('colors_dialog');
    $gui->{overlay}->render;
    1;
}

##@ignore
sub get_selected_palette_type {
    my $self = shift;
    my $combo = $self->{colors_dialog}->get_widget('palette_type_combobox');
    ($self->{index2palette_type}{$combo->get_active()} or '');
}

##@ignore
sub get_selected_color_field {
    my $self = shift;
    my $combo = $self->{colors_dialog}->get_widget('color_field_combobox');
    ($self->{index2field}{$combo->get_active()} or '');
}

##@ignore
sub get_colors {
    my($self, $gui) = @{$_[1]};
    my $table = $self->colors_from_dialog($gui);
    fill_colors_treeview($self, $table) if $table;
}

##@ignore
sub open_colors_file {
    my($self, $gui) = @{$_[1]};
    my $palette_type = get_selected_palette_type($self);
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
	    fill_colors_treeview($self, $table);
	}
    } else {
	$file_chooser->destroy;
    }
}

##@ignore
sub save_colors_file {
    my($self, $gui) = @{$_[1]};
    my $palette_type = get_selected_palette_type($self);
    my $file_chooser =
	Gtk2::FileChooserDialog->new ("Save $palette_type file as",
				      undef, 'save',
				      'gtk-cancel' => 'cancel',
				      'gtk-ok' => 'ok');
    my $filename;
    if ($file_chooser->run eq 'ok') {
	$filename = $file_chooser->get_filename;
	$file_chooser->destroy;
	my $table = get_table_from_treeview($self);
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

##@ignore
sub edit_color {
    my($self, $gui) = @{$_[1]};
    my $palette_type = get_selected_palette_type($self);
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows;
    return unless @selected;
	
    my $table = get_table_from_treeview($self);

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
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    $s->set_current_alpha($color[3]*257);
    
    if ($d->run eq 'ok') {
	$d->destroy;
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	$color[3] = int($s->get_current_alpha()/257);

	if ($palette_type eq 'Single color') {
	    fill_colors_treeview($self, [[@color]]);
	} else {
	    for (@selected) {
		my $i = $_->to_string;
		@{$table->[$i]}[1..4] = @color;
	    }
	    fill_colors_treeview($self, $table);
	}	
    } else {
	$d->destroy;
    }
    
    for (@selected) {
	$selection->select_path($_);
    }
}

##@ignore
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

##@ignore
sub add_color {
    my($self, $gui) = @{$_[1]};
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $selection = $treeview->get_selection;
    my @selected = $selection->get_selected_rows if $selection;
    my $at = $selected[0]->to_string if @selected;
    my $model = $treeview->get_model;
    my $palette_type = get_selected_palette_type($self);
    my $table = get_table_from_treeview($self);
    $at = $#$table unless defined $at;
    my $value;
    if (@$table) {
	if ($palette_type eq 'Color table') {
	    if (current_coloring_type($self) eq 'Int') {
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
		if (current_coloring_type($self) eq 'Int') {
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
	if (current_coloring_type($self) eq 'String') {
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

##@ignore
sub cell_in_colors_treeview_changed {
    my($cell, $path, $new_value, $data) = @_;
    my($self, $column) = @$data;
    my $table = get_table_from_treeview($self);
    $table->[$path]->[$column] = $new_value;
    fill_colors_treeview($self, $table);
}

##@ignore
sub palette_type_changed {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{colors_dialog};
    my $palette_type = get_selected_palette_type($self);
    
    fill_color_field_combo($self);

    my $tv = $dialog->get_widget('colors_treeview');

    $dialog->get_widget('color_field_label')->set_sensitive(0);
    $dialog->get_widget('color_field_combobox')->set_sensitive(0);
    $dialog->get_widget('color_scale_min_entry')->set_sensitive(0);
    $dialog->get_widget('color_scale_max_entry')->set_sensitive(0);
    $dialog->get_widget('min_hue_button')->set_sensitive(0);
    $dialog->get_widget('max_hue_button')->set_sensitive(0);
    $dialog->get_widget('hue_range_combobox')->set_sensitive(0);
    $dialog->get_widget('hue_checkbutton')->set_sensitive(0);
    $dialog->get_widget('hue_button')->set_sensitive(0);
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
	$dialog->get_widget('hue_checkbutton')->set_sensitive(1);
	$dialog->get_widget('hue_button')->set_sensitive(1);
    } elsif ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow') {
	$dialog->get_widget('min_hue_button')->set_sensitive(1);
	$dialog->get_widget('max_hue_button')->set_sensitive(1);
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
	my $s = 1; # current_coloring_type($self) eq 'Int' ? 1 : 0; this may change!
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
    create_colors_treeview($self);
}

##@ignore
sub create_colors_treeview {
    my($self) = @_;

    my $palette_type = get_selected_palette_type($self);
    my $tv = $self->{colors_dialog}->get_widget('colors_treeview');
    
    if ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow') {
	put_scale_in_treeview($self, $tv,$palette_type);
	return;
    }

    my $select = $tv->get_selection;
    $select->set_mode('multiple');

    my $model;
    my $table;
    my $type = current_coloring_type($self);
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
	$cell->signal_connect(edited => \&cell_in_colors_treeview_changed, [$self, $i]);
	$column = Gtk2::TreeViewColumn->new_with_attributes('value', $cell, text => $i++);
	$tv->append_column($column);
    }

    $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($COLOR_CELL_SIZE-2,$COLOR_CELL_SIZE-2);
    $column = Gtk2::TreeViewColumn->new_with_attributes('color', $cell, pixbuf => $i++);
    $tv->append_column($column);

    foreach my $c ('red','green','blue','alpha') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited => \&cell_in_colors_treeview_changed, [$self, $i-1]);
	$column = Gtk2::TreeViewColumn->new_with_attributes($c, $cell, text => $i++);
	$tv->append_column($column);
    }
    fill_colors_treeview($self, $table);
}

##@ignore
sub color_field_changed {
    my($self, $gui) = @{$_[1]};
    my $palette_type = get_selected_palette_type($self);
    if (($palette_type eq 'Color bins' or $palette_type eq 'Color table') and 
	$self->{current_coloring_type} ne current_coloring_type($self)) {
	create_colors_treeview($self);
    }
}

##@ignore
sub fill_color_scale_fields {
    my($self, $gui) = @{$_[1]};
    my @range;
    my $field = get_selected_color_field($self);
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
    my $palette_type = get_selected_palette_type($self);
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    put_scale_in_treeview($self, $treeview, $palette_type);
}

##@ignore
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

##@ignore
sub fill_color_field_combo {
    my($self, $palette_type) = @_;
    $palette_type = get_selected_palette_type($self) unless $palette_type;
    my $combo = $self->{colors_dialog}->get_widget('color_field_combobox');
    my $model = $combo->get_model;
    $model->clear;
    delete $self->{index2field};
    my $active = 0;
    my $i = 0;
    for my $field ($self->schema()->fields) {
	next unless $field->{Type};
	next if $palette_type eq 'Single color';
	next if ($palette_type eq 'Grayscale' or $palette_type eq 'Rainbow' or 
		 $palette_type eq 'Color bins') 
	    and not($field->{Type} eq 'Integer' or $field->{Type} eq 'Real');
	next if $palette_type eq 'Color table' and 
	    !($field->{Type} eq 'Integer' or $field->{Type} eq 'String');
	$model->set($model->append, 0, $field->{Name});
	$active = $i if $field->{Name} eq $self->color_field();
	$self->{index2field}{$i} = $field->{Name};
	$i++;
    }
    $combo->set_active($active);
}

##@ignore
sub current_coloring_type {
    my($self) = @_;
    my $type = '';
    my $field = get_selected_color_field($self);
    return unless defined $field;
    $field = $self->schema->field($field);
    return unless $field;
    if (!$field->{Type} or $field->{Type} eq 'Integer') {
	$type = 'Int';
    } elsif ($field->{Type} eq 'Real') {
	$type = 'Double';
    } elsif ($field->{Type} eq 'String') {
	$type = 'String';
    }
    return $type;
}

##@ignore
sub get_table_from_treeview {
    my ($self) = @_;
    my $palette_type = get_selected_palette_type($self);
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

##@ignore
sub fill_colors_treeview {
    my ($self, $table) = @_;

    my $palette_type = get_selected_palette_type($self);
    my $treeview = $self->{colors_dialog}->get_widget('colors_treeview');
    my $model = $treeview->get_model;
    return unless $model;
    $model->clear;

    return unless $table and @$table;

    if ($palette_type eq 'Single color') {
	
	my $iter = $model->append(undef);
	set_color($model,$iter,undef,@{$table->[0]});

    } elsif ($palette_type eq 'Color table') {

	if (current_coloring_type($self) eq 'Int') {
	    @$table = sort {$a->[0] <=> $b->[0]} @$table;
	}
	for my $color (@$table) {
	    my $iter = $model->append(undef);
	    set_color($model,$iter,@$color);
	}

    } elsif ($palette_type eq 'Color bins') {

	@$table = sort {$a->[0] <=> $b->[0]} @$table;
	$self->{current_coloring_type} = current_coloring_type($self);
	my $int = $self->{current_coloring_type} eq 'Int';

	for my $i (0..$#$table) {
	    my $color = $table->[$i];
	    $color->[0] = $int ? $MAX_INT : $MAX_REAL if $i == $#$table;
	    my $iter = $model->append(undef);
	    set_color($model,$iter,@$color);
	}
	
    }

}

##@ignore
sub set_color {
    my($model,$iter,$value,@color) = @_;
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
sub set_hue_range {
    my($self, $gui, $dir) = @{$_[1]};
    my $dialog = $self->{colors_dialog};
    my $hue = $dialog->get_widget($dir.'_hue_label')->get_text();
    my @color = hsv2rgb($hue, 1, 1);
    my $color_chooser = Gtk2::ColorSelectionDialog->new('Choose $dir hue for rainbow palette');
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	@color = rgb2hsv(@color);
	my $hue = $dialog->get_widget($dir.'_hue_label')->set_text(int($color[0]));
    }
    $color_chooser->destroy;
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
	my $hue = $dialog->get_widget('hue_label')->set_text(int($color[0]));
	$dialog->get_widget('hue_checkbutton')->set_active(TRUE);
    }
    $color_chooser->destroy;
}

##@ignore
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
    $cell->set_fixed_size($COLOR_CELL_SIZE-2,$COLOR_CELL_SIZE-2);
    my $column = Gtk2::TreeViewColumn->new_with_attributes('color', $cell, pixbuf => $i++);
    $tv->append_column($column);

    $cell = Gtk2::CellRendererText->new;
    $cell->set(editable => 0);
    $column = Gtk2::TreeViewColumn->new_with_attributes('value', $cell, text => $i++);
    $tv->append_column($column);

    my $dialog = $self->{colors_dialog};
    my $min = $dialog->get_widget('color_scale_min_entry')->get_text();
    my $max = $dialog->get_widget('color_scale_max_entry')->get_text();
    my ($hue_min) = $dialog->get_widget('min_hue_label')->get_text() =~ /(\d+)/;
    my ($hue_max) = $dialog->get_widget('max_hue_label')->get_text() =~ /(\d+)/;
    my $hue_dir = $dialog->get_widget('hue_range_combobox')->get_active == 0 ? 1 : -1; # up is 1, down is -1
    if ($hue_dir == 1) {
	$hue_max += 360 if $hue_max < $hue_min;
    } else {
	$hue_max -= 360 if $hue_max > $hue_min;
    }
    my $hue = $dialog->get_widget('hue_checkbutton')->get_active() ? 
	$dialog->get_widget('hue_label')->get_text() : -1;
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
    $dialog->get_widget('colors_from_dialog')->present;

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

1;
