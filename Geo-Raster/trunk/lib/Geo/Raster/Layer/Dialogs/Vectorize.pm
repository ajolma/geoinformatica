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
    my($dialog, $boot) = $self->bootstrap_dialog
	($gui, 'vectorize_dialog', "Polygonize ".$self->name,
	 {
	     vectorize_dialog => [delete_event => \&cancel_vectorize, [$self, $gui]],
	     vectorize_cancel_button => [clicked => \&cancel_vectorize, [$self, $gui]],
	     vectorize_ok_button => [clicked => \&apply_vectorize, [$self, $gui, 1]],
	 });
    
    if ($boot) {
	$dialog->get_widget('vectorize_datasource_button')
	    ->signal_connect(clicked => \&select_directory,
			     [$dialog->get_widget('vectorize_datasource_entry')]);
	my $combo = $dialog->get_widget('vectorize_driver_combobox');
	my $model = $combo->get_model;
	$model->clear;
	$model->set($model->append, 0, "");
	for my $driver (Geo::OGR::Drivers) {
	    next unless $driver->TestCapability('Create');
	    $model->set($model->append, 0, $driver->GetName);
	}
    }
    return $dialog->get_widget('vectorize_dialog');
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
    $self->hide_dialog('vectorize_dialog') if $close;
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

    $self->hide_dialog('vectorize_dialog');
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

1;
