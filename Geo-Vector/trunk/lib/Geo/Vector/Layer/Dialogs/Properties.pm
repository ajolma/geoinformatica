package Geo::Vector::Layer::Dialogs::Properties;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Geo::Vector::Layer qw/:all/;
use Geo::Vector::Layer::Dialogs::New;

## @ignore
sub open {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{properties_dialog};
    unless ($dialog) {
	$self->{properties_dialog} = $dialog = $gui->get_dialog('properties_dialog');
	croak "properties_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('properties_dialog')
	    ->signal_connect(delete_event => \&cancel_properties, [$self, $gui]);
	$dialog->get_widget('properties_color_button')
	    ->signal_connect(clicked => \&border_color_dialog, [$self]);
	$dialog->get_widget('properties_apply_button')
	    ->signal_connect(clicked => \&apply_properties, [$self, $gui, 0]);
	$dialog->get_widget('properties_cancel_button')
	    ->signal_connect(clicked => \&cancel_properties, [$self, $gui]);
	$dialog->get_widget('properties_ok_button')
	    ->signal_connect(clicked => \&apply_properties, [$self, $gui, 1]);
    } elsif (!$dialog->get_widget('properties_dialog')->get('visible')) {
	$dialog->get_widget('properties_dialog')->move(@{$self->{properties_dialog_position}});
    }
    $dialog->get_widget('properties_dialog')->set_title("Properties of ".$self->name);

    $self->{backup}->{name} = $self->name;
    $self->{backup}->{render_as} = $self->render_as;
    $self->{backup}->{alpha} = $self->alpha;
    @{$self->{backup}->{border_color}} = $self->border_color;
    
    $dialog->get_widget('properties_geometry_type_label')
	->set_text($self->geometry_type or 'unknown type');
    
    my $combo = $dialog->get_widget('properties_render_as_combobox');
    my $renderer = Gtk2::CellRendererText->new;
    $combo->pack_start ($renderer, TRUE);
    $combo->add_attribute ($renderer, text => 0);
    my $model = Gtk2::ListStore->new('Glib::String');
    for (sort {$Geo::Vector::RENDER_AS{$a} <=> $Geo::Vector::RENDER_AS{$b}} keys %Geo::Vector::RENDER_AS) {
	$model->set ($model->append, 0, $_);
    }
    my $a = 0;
    $a = $self->render_as;
    $a = $Geo::Vector::RENDER_AS{$a} if defined $a;
    $combo->set_model($model);
    $combo->set_active($a);
    
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
    
    $dialog->get_widget('properties_dialog')->show_all;
    $dialog->get_widget('properties_dialog')->present;
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
    $self->{properties_dialog_position} = [$dialog->get_widget('properties_dialog')->get_position];
    $dialog->get_widget('properties_dialog')->hide() if $close;
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
    my $dialog = $self->{properties_dialog}->get_widget('properties_dialog');
    $self->{properties_dialog_position} = [$dialog->get_position];
    $dialog->hide();
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
