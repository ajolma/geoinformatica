package Geo::Vector::Layer::Dialogs::Copy;
# @brief 

use strict;
use warnings;
use UNIVERSAL qw(isa);
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw/:all/;
use Geo::Vector::Layer::Dialogs qw/:all/;
use Geo::Raster::Layer qw /:all/;

## @ignore
# copy dialog
sub open {
    my($self, $gui) = @_;

    # bootstrap:
    my($dialog, $boot) = $self->bootstrap_dialog
	($gui, 'copy_dialog', "Copy from ".$self->name,
	 {
	     copy_dialog => [delete_event => \&cancel_copy, [$self, $gui]],
	     copy_cancel_button => [clicked => \&cancel_copy, [$self, $gui]],
	     copy_ok_button => [clicked => \&do_copy, [$self, $gui, 1]],
	     from_EPSG_entry => [changed => \&Geo::Raster::Layer::update_srs_labels, [$self, $gui]],
	     to_EPSG_entry => [changed => \&Geo::Raster::Layer::update_srs_labels, [$self, $gui]],
	     copy_add_button => [clicked => \&add_to_mappings, $self],
	     copy_delete_button => [clicked => \&delete_from_mappings, $self],
	     copy_driver_combobox => [changed => \&copy_driver_changed, $self],
	     copy_name_comboboxentry => [changed => \&copy_into_changed, [$self, $gui]],
	 },
	);
    
    if ($boot) {
	$dialog->get_widget('copy_datasource_button')
	    ->signal_connect( clicked=> sub {
		my(undef, $self) = @_;
		my $entry = $self->{copy_dialog}->get_widget('copy_datasource_entry');
		file_chooser('Select folder', 'select_folder', $entry);
			      }, $self);
	
	my $combo = $dialog->get_widget('copy_driver_combobox');
	my $renderer = Gtk2::CellRendererText->new;
	$combo->pack_start($renderer, TRUE);
	$combo->add_attribute($renderer, text => 0);

	$combo = $dialog->get_widget('copy_datasource_combobox');
	$renderer = Gtk2::CellRendererText->new;
	$combo->pack_start($renderer, TRUE);
	$combo->add_attribute($renderer, text => 0);

	$combo = $dialog->get_widget('copy_name_comboboxentry');
	$combo->set_text_column(0);
    }

    my $model = Gtk2::ListStore->new('Glib::String');
    my $i = 1;
    my $active = 0;
    $model->set($model->append, 0, ''); # create into existing data source 
    for my $driver (Geo::OGR::Drivers) {
	next unless $driver->TestCapability('CreateDataSource');
	my $name = $driver->GetName;
	$active = $i if $name eq 'Memory';
	$model->set($model->append, 0, $name);
	$i++;
    }
    my $combo = $dialog->get_widget('copy_driver_combobox');
    $combo->set_model($model);
    $combo->set_active($active);
    copy_driver_changed($combo, $self);

    $model = Gtk2::ListStore->new('Glib::String');
    $model->set ($model->append, 0, '');
    for my $data_source (sort keys %{$self->{gui}{resources}{datasources}}) {
	$model->set ($model->append, 0, $data_source);
    }
    $combo = $dialog->get_widget('copy_datasource_combobox');
    $combo->set_model($model);
    $combo->set_active(0);

    $model = Gtk2::ListStore->new('Glib::String');
    for my $layer (@{$gui->{overlay}->{layers}}) {
	my $n = $layer->name();
	next unless isa($layer, 'Geo::Vector');
	next if $n eq $self->name();
	$model->set($model->append, 0, $n);
    }
    $combo = $dialog->get_widget('copy_name_comboboxentry');
    $combo->child->set_text('copy');
    $combo->set_model($model);

    $dialog->get_widget('copy_datasource_entry')->set_text('');
    my $s = $self->selected_features;
    $dialog->get_widget('copy_count_label')->set_label($#$s+1);

    copy_into_changed(undef, [$self, $gui]);
}

## @ignore
sub copy_driver_changed {
    my($combo, $self) = @_;
    my $dialog = $self->{copy_dialog};
    my $active = $combo->get_active();
    return if $active < 0;
    my $model = $combo->get_model;
    my $iter = $model->get_iter_from_string($active);
    my $name = $model->get($iter, 0);
    for my $w ('copy_datasource_combobox','copy_datasource_button',
	       'copy_file_source_label','copy_non_file_source_label',
	       'copy_datasource_entry') {
	$dialog->get_widget($w)->set_sensitive($name ne 'Memory');
    }
}

##@ignore
sub do_copy {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{copy_dialog};

    my $into_layer;
    my $name = $dialog->get_widget('copy_name_comboboxentry')->child->get_text;
    for my $layer (@{$gui->{overlay}->{layers}}) {
	my $n = $layer->name();
	next unless isa($layer, 'Geo::Vector');
	if ($n eq $name) {
	    $into_layer = $layer;
	    last;
	}
    }

    my %ret = ( selected_features => $self->selected_features ) 
	unless $dialog->get_widget('copy_all_checkbutton')->get_active;

    unless ($into_layer) {

	my $data_source;
	my $combo = $dialog->get_widget('copy_datasource_combobox');
	my $active = $combo->get_active();
	if ($active > 0) {
	    my $model = $combo->get_model;
	    my $iter = $model->get_iter_from_string($active);
	    $data_source = $model->get($iter, 0);
	} else {
	    $data_source = $dialog->get_widget('copy_datasource_entry')->get_text;
	}

	$ret{create} = $name;
	$ret{data_source} = $data_source;
	$ret{driver} = $dialog->get_widget('copy_driver_combobox')->get_active_text;

	if (!($ret{create} =~ /^\w+$/) or $gui->layer($ret{create})) {
	    $gui->message("Layer with name '$ret{create}' is already open or the name is not valid.");
	    return;
	}
    
	my $layers;
	
	unless ($ret{driver} ne 'Memory') {
	    eval {
		$layers = Geo::Vector::layers($ret{driver}, $ret{data_source});
	    };
	}
    
	if ($layers and $layers->{$ret{create}}) {
	
	    $gui->message("Data source '$ret{data_source}' already contains a layer with name '$ret{create}'.");
	    return;
	
	}

    }

    my $from = $dialog->get_widget('from_EPSG_entry')->get_text;
    my $to = $dialog->get_widget('to_EPSG_entry')->get_text;
    my $ct;
    my $p = $dialog->get_widget('copy_projection_checkbutton')->get_active;
    #print STDERR "do proj: $p\n";
    if ($p) {
	if ($EPSG{$from} and $EPSG{$to}) {
	    my $src = Geo::OSR::SpatialReference->create( EPSG => $from );
	    my $dst = Geo::OSR::SpatialReference->create( EPSG => $to );
	    eval {
		$ct = Geo::OSR::CoordinateTransformation->new($src, $dst);
	    };
	}
	#print STDERR "ct=$ct\n";
	if ($@ or !$ct) {
	    $@ = '' unless $@;
	    $@ = ": $@" if $@;
	    $gui->message("can't create coordinate transformation$@");
	    return;
	}
	$ret{transformation} = $ct;
    }

    unless ($into_layer) {

	my $new_layer;
	eval {
	    $new_layer = $self->copy(%ret);
	};
	if ($@ or !$new_layer) {
	    $gui->message("can't copy: $@");
	    return;
	}
	$gui->add_layer($new_layer, $ret{create}, 1);
	#$gui->set_layer($new_layer);
	#$gui->{overlay}->render;
	
    } else {

	$into_layer->add($self, %ret);

    }

    $self->hide_dialog('copy_dialog');
    $gui->{overlay}->render;
}

sub mappings_changed {
    my($cell, $path, $new_value, $data) = @_;
    my($self, $column) = @$data;
    my $iter = $self->{mappings}->get_iter_from_string($path);
    my @set = ($iter, $column, $new_value);
    $self->{mappings}->set(@set);
}

##@ignore
sub cancel_copy {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    $self->hide_dialog('copy_dialog');
    1;
}

##@ignore
sub copy_data_source_changed {
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
	my $combo = $self->{copy_dialog}->get_widget('copy_driver_combobox');
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

## @ignore
sub copy_into_changed {
    my($combo) = @_;
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{copy_dialog};
    my $into = get_value_from_combo($dialog, 'copy_name_comboboxentry') if $combo;
    my $into_layer;
    if ($into) {
	for my $layer (@{$gui->{overlay}->{layers}}) {
	    my $n = $layer->name();
	    next unless isa($layer, 'Geo::Vector');
	    if ($into eq $layer->name()) {
		$into_layer = $layer;
		last;
	    }
	}
    }

    my $treeview = $dialog->get_widget('copy_mappings_treeview');
    my $model = Gtk2::TreeStore->new(qw/Glib::String Glib::String/);
    $self->{mappings} = $model;
    $treeview->set_model($model);
    for ($treeview->get_columns) {
	$treeview->remove_column($_);
    }

    my $i = 0;
    my $cell = Gtk2::CellRendererCombo->new;
    $cell->set(editable => 1);
    $cell->set(text_column => 0);
    $cell->set(has_entry => 0);
    $cell->signal_connect(edited => \&mappings_changed, [$self, $i]);
    my $m = Gtk2::ListStore->new('Glib::String');
    for my $name ($self->schema->field_names) {
	next if $name =~ /^\./;
	$m->set($m->append, 0, $name);
    }
    $cell->set(model=>$m);
    my $column = Gtk2::TreeViewColumn->new_with_attributes('From', $cell, text => $i++);
    $treeview->append_column($column);
    
    $cell = Gtk2::CellRendererCombo->new;
    $cell->set(editable => 1);
    $cell->set(text_column => 0);
    $cell->set(has_entry => 1);
    $cell->signal_connect(edited => \&mappings_changed, [$self, $i]);
    $m = Gtk2::ListStore->new('Glib::String');
    if ($into_layer) {
	for my $name ($into_layer->schema->field_names) {
	    next if $name =~ /^\./;
	    $m->set($m->append, 0, $name);
	}
    }
    $cell->set(model=>$m);
    $column = Gtk2::TreeViewColumn->new_with_attributes('To', $cell, text => $i++);
    $treeview->append_column($column);

}

## @ignore
sub add_to_mappings {
    my $self = pop;
    my $iter = $self->{mappings}->append(undef);
    my @set = ($iter);
    my $i = 0;
    push @set, ($i++, '');
    push @set, ($i++, '');
    $self->{mappings}->set(@set);
}

## @ignore
sub delete_from_mappings {
    my $self = pop;
    my $treeview = $self->{copy_dialog}->get_widget('copy_mappings_treeview');
    my($path, $focus_column) = $treeview->get_cursor;
    return unless $path;
    my $iter = $self->{mappings}->get_iter($path);
    $self->{mappings}->remove($iter);
}

1;
