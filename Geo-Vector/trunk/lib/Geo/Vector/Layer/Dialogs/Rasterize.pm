package Geo::Vector::Layer::Dialogs::Rasterize;
# @brief 

use strict;
use warnings;
use UNIVERSAL qw(isa);
use Carp;

## @method open_rasterize_dialog($gui)
# @brief present a rasterize dialog for the user
sub open {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{rasterize_dialog};
    unless ($dialog) {
	$self->{rasterize_dialog} = $dialog = $gui->get_dialog('rasterize_dialog');
	croak "rasterize_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('rasterize_dialog')->signal_connect(delete_event => \&cancel_rasterize, [$self, $gui]);

	$dialog->get_widget('rasterize_cancel_button')->signal_connect(clicked => \&cancel_rasterize, [$self, $gui]);
	$dialog->get_widget('rasterize_ok_button')->signal_connect(clicked => \&apply_rasterize, [$self, $gui, 1]);
    } elsif (!$dialog->get_widget('rasterize_dialog')->get('visible')) {
	$dialog->get_widget('rasterize_dialog')->move(@{$self->{rasterize_dialog_position}});
    }
    $dialog->get_widget('rasterize_dialog')->set_title("Rasterize ".$self->name);
	
    $dialog->get_widget('rasterize_name_entry')->set_text('r');

    # fill like_combobox: all available rasters

    my $combo = $dialog->get_widget('rasterize_like_combobox');
    my $model = $combo->get_model;
    $model->clear;

    $model->set ($model->append, 0, "Use current view");
    for my $layer (@{$gui->{overlay}->{layers}}) {
	next unless isa($layer, 'Geo::Raster');
	$model->set ($model->append, 0, $layer->name);
    }
    $combo->set_active(0);

    $combo = $dialog->get_widget('rasterize_render_as_combobox');
    $model = $combo->get_model;
    $model->clear;
    for (sort {$Geo::Vector::RENDER_AS{$a} <=> $Geo::Vector::RENDER_AS{$b}} keys %Geo::Vector::RENDER_AS) {
	$model->set ($model->append, 0, $_);
    }
    my $a = $self->render_as;
    $a = $Geo::Vector::RENDER_AS{$a} if defined $a;
    $combo->set_active($a);

    # fill rasterize_value_comboboxentry: int and float fields
    $combo = $dialog->get_widget('rasterize_value_field_combobox');
    $model = $combo->get_model;
    $model->clear;

    $model->set ($model->append, 0, 'Draw with value 1');
    if ($self->{OGR}->{Layer}) {
	my $schema = $self->{OGR}->{Layer}->GetLayerDefn();
	for my $i (0..$schema->GetFieldCount-1) {
	    my $column = $schema->GetFieldDefn($i);
	    my $type = $column->GetFieldTypeName($column->GetType);
	    if ($type eq 'Integer' or $type eq 'Real') {
		$model->set($model->append, 0, $column->GetName);
	    }
	}
	$combo->set_active(0);
    }

    $dialog->get_widget('rasterize_nodata_value_entry')->set_text(-9999);
    
    $dialog->get_widget('rasterize_dialog')->show_all;
    $dialog->get_widget('rasterize_dialog')->present;
}

##@ignore
sub apply_rasterize {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{rasterize_dialog};
    
    my %ret = (name => $dialog->get_widget('rasterize_name_entry')->get_text());
    my $model = $dialog->get_widget('rasterize_like_combobox')->get_active_text;
    
    if ($model eq "Use current view") {
	# need M (height), N (width), world
	($ret{M}, $ret{N}) = $gui->{overlay}->size;
	$ret{world} = [$gui->{overlay}->get_viewport];
    } else {
	$ret{like} = $gui->{overlay}->get_layer_by_name($model);
    }

    $ret{render_as} = $dialog->get_widget('rasterize_render_as_combobox')->get_active;
    $ret{render_as} = $Geo::Vector::Layer::INDEX2RENDER_AS{$ret{render_as}};

    $ret{feature} = $dialog->get_widget('rasterize_fid_entry')->get_text;
    $ret{feature} = -1 unless $ret{feature} =~ /^\d+$/;

    my $field = $dialog->get_widget('rasterize_value_field_combobox')->get_active_text;
    
    if ($field ne 'Draw with value 1') {
	$ret{value_field} = $field;
    }

    $ret{nodata_value} = $dialog->get_widget('rasterize_nodata_value_entry')->get_text();

    my $g = $self->rasterize(%ret);
    if ($g) {
	$gui->add_layer($g, $ret{name}, 1);
	$gui->{overlay}->render;
    }

    $self->{rasterize_dialog_position} = [$dialog->get_widget('rasterize_dialog')->get_position];
    $dialog->get_widget('rasterize_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

##@ignore
sub cancel_rasterize {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    
    my $dialog = $self->{rasterize_dialog}->get_widget('rasterize_dialog');
    $self->{rasterize_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    1;
}

1;
