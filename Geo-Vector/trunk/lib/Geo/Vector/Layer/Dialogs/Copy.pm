package Geo::Vector::Layer::Dialogs::Copy;
# @brief 

use strict;
use warnings;
use UNIVERSAL qw(isa);
use Carp;
use Glib qw/TRUE FALSE/;
use Geo::Vector::Layer::Dialogs qw/:all/;
use Geo::Raster::Layer qw /:all/;

## @ignore
# copy dialog
sub open {
    my($self, $gui) = @_;

    my $dialog = $self->{copy_dialog};
    unless ($dialog) {
	$self->{copy_dialog} = $dialog = $gui->get_dialog('copy_vector_dialog');
	croak "copy_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('copy_vector_dialog')
	    ->signal_connect( delete_event => \&cancel_copy, [$self, $gui]);

	my $entry = $dialog->get_widget('copy_datasource_entry');
	$dialog->get_widget('copy_datasource_button')
	    ->signal_connect( clicked=>\&select_file_data_source, [$self, $entry, 'select_folder']);

	$dialog->get_widget('copy_cancel_button')
	    ->signal_connect(clicked => \&cancel_copy, [$self, $gui]);
	$dialog->get_widget('copy_ok_button')
	    ->signal_connect(clicked => \&do_copy, [$self, $gui, 1]);
	#$entry->signal_connect(changed => \&copy_data_source_changed, [$self, $gui]);

	$dialog->get_widget('from_EPSG_entry')
	    ->signal_connect(changed => \&Geo::Raster::Layer::update_srs_labels, [$self, $gui]);
	$dialog->get_widget('to_EPSG_entry')
	    ->signal_connect(changed => \&Geo::Raster::Layer::update_srs_labels, [$self, $gui]);

	my $combo = $dialog->get_widget('copy_driver_combobox');
	my $renderer = Gtk2::CellRendererText->new;
	$combo->pack_start ($renderer, TRUE);
	$combo->add_attribute ($renderer, text => 0);
	$combo->signal_connect(changed => \&copy_driver_changed, $self);

	$combo = $dialog->get_widget('copy_datasource_combobox');
	$renderer = Gtk2::CellRendererText->new;
	$combo->pack_start ($renderer, TRUE);
	$combo->add_attribute ($renderer, text => 0);

	$combo = $dialog->get_widget('copy_name_comboboxentry');
	$combo->set_text_column(0);
	
    } elsif (!$dialog->get_widget('copy_vector_dialog')->get('visible')) {
	$dialog->get_widget('copy_vector_dialog')
	    ->move(@{$self->{copy_dialog_position}}) if $self->{copy_dialog_position};
    }

    $dialog->get_widget('copy_vector_dialog')->set_title("Copy features from layer ".$self->name);

    my $model = Gtk2::ListStore->new('Glib::String');
    my $i = 0;
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

    $dialog->get_widget('copy_vector_dialog')->show_all;
    $dialog->get_widget('copy_vector_dialog')->present;
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

    my %ret = ( features => $self->selected_features ) 
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

    $self->{copy_dialog_position} = [$dialog->get_widget('copy_vector_dialog')->get_position];
    $dialog->get_widget('copy_vector_dialog')->hide();
    $gui->{overlay}->render;
}

##@ignore
sub cancel_copy {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    my $dialog = $self->{copy_dialog}->get_widget('copy_vector_dialog');
    $self->{copy_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    #$gui->{overlay}->render;
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

1;
