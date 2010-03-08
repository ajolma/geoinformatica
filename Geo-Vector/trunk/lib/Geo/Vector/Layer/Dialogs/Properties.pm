package Geo::Vector::Layer::Dialogs::Properties;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Geo::Vector;
use Geo::Vector::Layer;
use Geo::Vector::Layer::Dialogs::New;

## @ignore
sub open {
    my($self, $gui) = @_;

    # bootstrap:
    my($dialog, $boot) = $self->bootstrap_dialog
	($gui, 'properties_dialog', "Properties of ".$self->name,
	 {
	     properties_dialog => [delete_event => \&cancel_properties, [$self, $gui]],
	     properties_dialog => [delete_event => \&cancel_properties, [$self, $gui]],
	     properties_color_button => [clicked => \&border_color_dialog, [$self]],
	     properties_apply_button => [clicked => \&apply_properties, [$self, $gui, 0]],
	     properties_cancel_button => [clicked => \&cancel_properties, [$self, $gui]],
	     properties_ok_button => [clicked => \&apply_properties, [$self, $gui, 1]],
	 });
    
    if ($boot) {
	Geo::Vector::Layer::Dialogs::fill_render_as_combobox(
	    $dialog->get_widget('properties_render_as_combobox') );
    }
    $dialog->get_widget('properties_dialog')->set_title("Properties of ".$self->name);

    $self->{backup}->{name} = $self->name;
    $self->{backup}->{render_as} = $self->render_as;
    $self->{backup}->{alpha} = $self->alpha;
    @{$self->{backup}->{border_color}} = $self->border_color;
    
    $dialog->get_widget('properties_geometry_type_label')
	->set_text($self->geometry_type or 'unknown type');
    
    my $a = $self->render_as;
    $a = defined $a ? $Geo::Vector::RENDER_AS{$a} : 0;
    $dialog->get_widget('properties_render_as_combobox')->set_active($a);
    
    my $count = $self->{OGR}->{Layer}->GetFeatureCount();
    $count .= " (estimated)";
    $dialog->get_widget('properties_feature_count_label')->set_text($count);
    
    my $ds = $self->{OGR}->{DataSource} if $self->{OGR}->{DataSource};
    my $driver = $self->driver;
    $dialog->get_widget('properties_driver_label')->set_text($driver ? $driver : 'unknown');
    $dialog->get_widget('properties_data_source_label')->set_text($ds->GetName) if $ds;
    $dialog->get_widget('properties_SQL_label')->set_text($self->{SQL});
    
    $dialog->get_widget('properties_name_entry')->set_text($self->name);
    $dialog->get_widget('properties_transparency_spinbutton')->set_value($self->alpha);
    
    #my $polygon = $self->geometry_type() =~ /Polygon/; # may be undefined in some cases
    my $polygon = 1;
    $dialog->get_widget('properties_border_checkbutton')->set_sensitive($polygon);
    $dialog->get_widget('properties_color_button')->set_sensitive($polygon);
    $dialog->get_widget('properties_color_label')->set_sensitive($polygon);
    $dialog->get_widget('properties_border_checkbutton')->set_active($self->border_color > 0);
    
    my @color = $self->border_color;
    @color = (0, 0, 0) unless @color;
    $dialog->get_widget('properties_color_label')->set_text("@color");

    my $t = $dialog->get_widget('properties_schema_treeview');
    Geo::Vector::Layer::Dialogs::New::schema_to_treeview(undef, $t, 0, $self->schema);

}

##@ignore
sub apply_properties {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{properties_dialog};
    my $alpha = $dialog->get_widget('properties_transparency_spinbutton')->get_value_as_int;
    $self->alpha($alpha);
    my $name = $dialog->get_widget('properties_name_entry')->get_text;
    $self->name($name);
    my $combo = $dialog->get_widget('properties_render_as_combobox');
    my $model = $combo->get_model;
    my $iter = $model->get_iter_from_string($combo->get_active());
    $self->render_as($model->get_value($iter));
    my $has_border = $dialog->get_widget('properties_border_checkbutton')->get_active();
    my @color = split(/ /, $dialog->get_widget('properties_color_label')->get_text);
    @color = () unless $has_border;
    $self->border_color(@color);
    $self->hide_dialog('properties_dialog') if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

##@ignore
sub cancel_properties {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    $self->alpha($self->{backup}->{alpha});
    $self->name($self->{backup}->{name});
    $self->render_as($self->{backup}->{render_as});
    $self->border_color(@{$self->{backup}->{border_color}});
    $self->hide_dialog('properties_dialog');
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

##@ignore
sub border_color_dialog {
    my($self) = @{$_[1]};
    my $dialog = $self->{properties_dialog};
    my @color = split(/ /, $dialog->get_widget('properties_color_label')->get_text);
    my $color_chooser = Gtk2::ColorSelectionDialog->new('Choose color for the border of '.$self->name);
    my $s = $color_chooser->colorsel;
    $s->set_has_opacity_control(0);
    my $c = Gtk2::Gdk::Color->new($color[0]*257,$color[1]*257,$color[2]*257);
    $s->set_current_color($c);
    #$s->set_current_alpha($color[3]*257);
    if ($color_chooser->run eq 'ok') {
	$c = $s->get_current_color;
	@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
	#$color[3] = int($s->get_current_alpha()/257);
	$dialog->get_widget('properties_color_label')->set_text("@color");
    }
    $color_chooser->destroy;
}

1;
