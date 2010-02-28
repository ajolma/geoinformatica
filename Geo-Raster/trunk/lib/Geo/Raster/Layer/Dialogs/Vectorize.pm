package Geo::Raster::Layer::Dialogs::Vectorize;
# @brief 

use strict;
use warnings;
use UNIVERSAL qw(isa);
use Carp;
use Glib qw/TRUE FALSE/;

## @ignore
sub open {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{vectorize_dialog};
    unless ($dialog) {
	$self->{vectorize_dialog} = $dialog = $gui->get_dialog('vectorize_dialog');
	croak "vectorize_dialog for Geo::Raster does not exist" unless $dialog;
	$dialog->get_widget('vectorize_dialog')
	    ->signal_connect(delete_event => \&cancel_vectorize, [$self, $gui]);
	$dialog->get_widget('vectorize_datasource_button')->signal_connect
	    (clicked=>\&select_directory, [$self, $dialog->get_widget('vectorize_datasource_entry')]);
	$dialog->get_widget('vectorize_cancel_button')
	    ->signal_connect(clicked => \&cancel_vectorize, [$self, $gui]);
	$dialog->get_widget('vectorize_ok_button')
	    ->signal_connect(clicked => \&apply_vectorize, [$self, $gui, 1]);
    } elsif (!$dialog->get_widget('vectorize_dialog')->get('visible')) {
	$dialog->get_widget('vectorize_dialog')->move(@{$self->{vectorize_dialog_position}});
    }
    $dialog->get_widget('vectorize_dialog')->set_title("Create a vector layer from ".$self->name);
	
    my $combo = $dialog->get_widget('vectorize_driver_combobox');
    my $model = $combo->get_model;
    $model->clear;
    $model->set($model->append, 0, "");
    for my $driver (Geo::OGR::Drivers) {
	next unless $driver->TestCapability('CreateDataSource');
	$model->set($model->append, 0, $driver->GetName);
    }

    $dialog->get_widget('vectorize_name_entry')->set_text('vector');
    $dialog->get_widget('vectorize_datasource_entry')->set_text('.');

    $dialog->get_widget('vectorize_dialog')->show_all;
    $dialog->get_widget('vectorize_dialog')->present;
}

##@ignore
sub apply_vectorize {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{vectorize_dialog};

    my %ret;
    $ret{layer} = $dialog->get_widget('vectorize_name_entry')->get_text();
    my $combo = $dialog->get_widget('vectorize_driver_combobox');
    my $model = $combo->get_model;
    my $iter = $combo->get_active_iter;
    $ret{driver} = $model->get($iter) if $iter;
    $ret{datasource} = $dialog->get_widget('vectorize_datasource_entry')->get_text();
    my $connectivity = $dialog->get_widget('vectorize_8connectivity_checkbutton')->get_active();
    $ret{connectivity} = $connectivity ? 8 : 4;
    
    my $v = $self->vectorize(%ret);
    if ($v) {
	$gui->add_layer($v, $ret{layer}, 1);
	$gui->{overlay}->render;
    }

    $self->{vectorize_dialog_position} = [$dialog->get_widget('vectorize_dialog')->get_position];
    $dialog->get_widget('vectorize_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

##@ignore
sub cancel_vectorize {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }

    
    my $dialog = $self->{vectorize_dialog}->get_widget('vectorize_dialog');
    $self->{vectorize_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

1;
