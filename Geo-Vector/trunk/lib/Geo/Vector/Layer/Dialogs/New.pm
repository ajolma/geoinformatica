package Geo::Vector::Layer::Dialogs::New;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw/:all/;

## @ignore
sub open {
    my($gui) = @_;
    my $self = {};
    $self->{gui} = $gui;
    my $d = $self->{new_vector_dialog} = $gui->get_dialog('new_vector_dialog');
    croak "new_vector_dialog for Geo::Vector::Layer does not exist" unless $d;
    $d->get_widget('new_vector_dialog')->set_title("Create a new OGR vector layer");
    $d->get_widget('new_vector_dialog')->signal_connect(delete_event => \&cancel_new_vector, $self);

    my $model = Gtk2::ListStore->new('Glib::String');
    $model->set ($model->append, 0, '');
    my @drivers;
    for my $driver (Geo::OGR::Drivers()) {
	my $n = $driver->FormatName;
	$n = $driver->GetName unless $n;
	$self->{drivers}{$n} = $driver->GetName;
	push @drivers, $n;
    }
    for my $n (sort @drivers) {
	$model->set ($model->append, 0, $n);
    }
    my $combo = $d->get_widget('new_vector_driver_combobox');
    $combo->set_model($model);
    my $renderer = Gtk2::CellRendererText->new;
    $combo->pack_start ($renderer, TRUE);
    $combo->add_attribute ($renderer, text => 0);
    $combo->set_active(0);

    $model = Gtk2::ListStore->new('Glib::String');
    $model->set ($model->append, 0, '');
    for my $data_source (sort keys %{$gui->{resources}{datasources}}) {
	$model->set ($model->append, 0, $data_source);
    }
    $combo = $d->get_widget('new_vector_data_source_combobox');
    $combo->set_model($model);
    $renderer = Gtk2::CellRendererText->new;
    $combo->pack_start ($renderer, TRUE);
    $combo->add_attribute ($renderer, text => 0);
    $combo->set_active(0);

    my $entry = $d->get_widget('new_vector_folder_entry');
    $d->get_widget('new_vector_open_button')
	->signal_connect( clicked=>\&select_file_data_source, [$self, $entry, 'select_folder']);

    $model = Gtk2::ListStore->new('Glib::String');
    for my $type (@Geo::Vector::GEOMETRY_TYPES) {
	$model->set ($model->append, 0, $type);
    }
    $combo = $d->get_widget('new_vector_geometry_type_combobox');
    $combo->set_model($model);
    $renderer = Gtk2::CellRendererText->new;
    $combo->pack_start ($renderer, TRUE);
    $combo->add_attribute ($renderer, text => 0);
    $combo->set_active(0);

    my $treeview = $d->get_widget('new_vector_schema_treeview');
    $model = Gtk2::TreeStore->new(qw/Glib::String Glib::String/);
    $treeview->set_model($model);

    my $i = 0;
    my $cell = Gtk2::CellRendererText->new;
    $cell->set(editable => 1);
    my $column = Gtk2::TreeViewColumn->new_with_attributes('name', $cell, text => $i++);
    $treeview->append_column($column);

    $cell = Gtk2::CellRendererCombo->new;
    $cell->set(editable => 1);
    $cell->set(text_column => 0);
    $cell->set(has_entry => 0);
    my $m = Gtk2::ListStore->new('Glib::String');
    for my $type (@Geo::Vector::GEOMETRY_TYPES) {
	$m->set($m->append, 0, $type);
    }
    $cell->set(model=>$m);
    $column = Gtk2::TreeViewColumn->new_with_attributes('type', $cell, text => $i++);
    $treeview->append_column($column);

    $self->{schema} = $model;

    $d->get_widget('new_vector_add_button')
	->signal_connect( clicked=>\&add_field_to_schema, $self);
    $d->get_widget('new_vector_delete_button')
	->signal_connect( clicked=>\&delete_field_from_schema, $self);

    $d->get_widget('new_vector_cancel_button')
	->signal_connect(clicked => \&cancel_new_vector, $self);
    $d->get_widget('new_vector_ok_button')
	->signal_connect(clicked => \&ok_new_vector, $self);
    
    $d->get_widget('new_vector_dialog')->show_all;
    $d->get_widget('new_vector_dialog')->present;
}

## @ignore
sub cancel_new_vector {
    my $self = pop;
    $self->{new_vector_dialog}->get_widget('new_vector_dialog')->destroy;
}

## @ignore
sub ok_new_vector {
    my $self = pop;
    my $d = $self->{new_vector_dialog};
    my $layer;
    my $driver = get_value_from_combo($d, 'new_vector_driver_combobox');
    $driver = $self->{drivers}{$driver};
    my $create_options = $d->get_widget('new_vector_create_options_entry')->get_text;
    $create_options = {split(/[(=>),]/,$create_options)};
    my $data_source = get_value_from_combo($d, 'new_vector_data_source_combobox');
    $data_source = $d->get_widget('new_vector_folder_entry')->get_text unless $data_source;
    my $name = $d->get_widget('new_vector_layer_entry')->get_text;
    my $layer_options = $d->get_widget('new_vector_layer_options_entry')->get_text;
    my $geometry_type = get_value_from_combo($d, 'new_vector_geometry_type_combobox');
    my $encoding = $d->get_widget('new_vector_encoding_entry')->get_text;
    my $srs = $d->get_widget('new_vector_srs_entry')->get_text;
    eval {
	$layer = Geo::Vector::Layer->new
	    ( driver => $driver,
	      create_options => $create_options,
	      data_source => $data_source, 
	      create => $name,
	      layer_options => $layer_options,
	      geometry_type => $geometry_type,
	      encoding => $encoding,
	      srs => $srs,
	      schema => $self->{schema_}
	    );
    };
    if ($@) {
	my $err = $@;
	if ($err) {
	    $err =~ s/\n/ /g;
	    $err =~ s/\s+$//;
	    $err =~ s/\s+/ /g;
	    $err =~ s/^\s+$//;
	} else {
	    $err = "unknown error";
	}
	$self->{gui}->message("Could not create a vector layer: $err");
	return;
    }
    $self->{gui}->add_layer($layer, $name, 1);
    $d->get_widget('new_vector_dialog')->destroy;
}

## @ignore
sub add_field_to_schema {
    my $self = pop;
    my $iter = $self->{schema}->append(undef);
    my @set = ($iter);
    my $i = 0;
    push @set, ($i++, 'name');
    push @set, ($i++, 'Integer');
    $self->{schema}->set(@set);
}

## @ignore
sub delete_field_from_schema {
    my $self = pop;
}

1;
