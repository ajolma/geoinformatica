package Geo::Vector::Layer::Dialogs::FeatureCollection;
# @brief 

use strict;
use warnings;
use Carp;
use Geo::Vector::Layer::Dialogs qw/:all/;

## @ignore
sub open {
    my($self, $gui) = @_;
    my $dialog = $self->{feature_collection_dialog};
    unless ($dialog) {
	$self->{feature_collection_dialog} = $dialog = $gui->get_dialog('feature_collection_dialog');
	croak "feature_collection_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('feature_collection_dialog')
	    ->signal_connect(delete_event => \&close_feature_collection_dialog, [$self, $gui]);
	
	my $selection = $dialog->get_widget('feature_collection_treeview')->get_selection;
	$selection->set_mode('multiple');
	$selection->signal_connect(changed => \&feature_activated2, [$self, $gui]);
	
	$dialog->get_widget('feature_collection_from_spinbutton')
	    ->signal_connect(value_changed => \&fill_features_table2, [$self, $gui]);
	$dialog->get_widget('feature_collection_max_spinbutton')
	    ->signal_connect(value_changed => \&fill_features_table2, [$self, $gui]);

	$dialog->get_widget('feature_collection_from_selection_button')
	    ->signal_connect(clicked => \&from_selection, [$self, $gui]);
	
	$dialog->get_widget('feature_collection_zoom_to_button')
	    ->signal_connect(clicked => \&zoom_to_selected_feature_collection, [$self, $gui]);
	$dialog->get_widget('feature_collection_close_button')
	    ->signal_connect(clicked => \&close_feature_collection_dialog, [$self, $gui]);

    } elsif (!$dialog->get_widget('feature_collection_dialog')->get('visible')) {
	$dialog->get_widget('feature_collection_dialog')
	    ->move(@{$self->{feature_collection_dialog_position}}) 
	    if $self->{feature_collection_dialog_position};
    }
    $dialog->get_widget('feature_collection_dialog')
	->set_title("Features of ".$self->name);

    my $treeview = $dialog->get_widget('feature_collection_treeview');

    my $model = Gtk2::TreeStore->new('Glib::Int');
    $treeview->set_model($model);

    for ($treeview->get_columns) {
	$treeview->remove_column($_);
    }

    my $i = 0;
    for my $column ('index') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
    }

    for ($treeview->get_columns) {
	$_->set_clickable(1);
	$_->signal_connect(clicked => sub {
	    shift;
	    my($self, $gui) = @{$_[0]};
	    fill_features_table2(undef, [$self, $gui]);
	}, [$self, $gui]);
    }

    fill_features_table2(undef, [$self, $gui]);

    $treeview = $dialog->get_widget('feature_collection_attributes_treeview');

    my @columns = ('Field', 'Value');
    my @coltypes = ('Glib::String', 'Glib::String');

    $model = Gtk2::TreeStore->new(@coltypes);
    $treeview->set_model($model);

    for ($treeview->get_columns) {
	$treeview->remove_column($_);
    }

    $i = 0;
    foreach my $column (@columns) {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
    }
    
    $dialog->get_widget('feature_collection_dialog')->show_all;
    $dialog->get_widget('feature_collection_dialog')->present;
}

##@ignore
sub close_feature_collection_dialog {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    my $dialog = $self->{feature_collection_dialog}->get_widget('feature_collection_dialog');
    $self->{feature_collection_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    1;
}

## @ignore
sub fill_features_table2 {
    shift;
    my($self, $gui) = @{$_[0]};

    my $dialog = $self->{feature_collection_dialog};

    my $from = $dialog->get_widget('feature_collection_from_spinbutton')->get_value_as_int;
    my $count = $dialog->get_widget('feature_collection_max_spinbutton')->get_value_as_int;

    my $model = $dialog->get_widget('feature_collection_treeview')->get_model;

    $model->clear;

    my @recs;
    my $i = 1;
    my $k = 0;
    while ($i < $from+$count) {
	my $f = $self->{features}->[$k++];
	$i++;
	next if $i <= $from;
	last unless $f;
	my @rec;
	my $rec = 0;

	push @rec,$rec++;
	push @rec,$k-1; # $f->GetFID;
	
	push @recs,\@rec;
    }
    $k = @recs;

    for my $rec (@recs) {
	
	my $iter = $model->insert (undef, 999999);
	$model->set ($iter, @$rec);
	
    }
    
}

## @ignore
sub feature_activated2 {
    my $selection = shift;
    my($self, $gui) = @{$_[0]};

    my $dialog = $self->{feature_collection_dialog};
    my $model = $dialog->get_widget('feature_collection_attributes_treeview')->get_model;

    my $ids = get_selected($selection);
    my $features = $self->features(with_id=>[keys %$ids]);
    return unless $features;
    return unless @$features;

    if (@$features == 1) {
	my @k = keys %$ids;
	my $f = $features->[0];
	my $schema = $self->schema($k[0]);
	$model->clear;

	my @recs;
	for my $name (sort {$schema->{$a}{VisualOrder} <=> $schema->{$b}{VisualOrder}} keys %$schema) {
	    my @rec;
	    my $rec = 0;
	    push @rec, $rec++;
	    my $n = $name;
	    $n =~ s/^\.//;
	    push @rec, $n;
	    push @rec, $rec++;
	    push @rec, Geo::Vector::feature_attribute($f, $name);
	    push @recs,\@rec;
	}

	for my $rec (@recs) {
	
	    my $iter = $model->insert (undef, 999999);
	    $model->set ($iter, @$rec);
	    
	}
	
    }

    my $overlay = $gui->{overlay};

    $overlay->reset_pixmap;

    my $gc = Gtk2::Gdk::GC->new($overlay->{pixmap});
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535,0,0));

    for my $f (@$features) {

	next unless $f; # should not happen

	my $geom = $f->GetGeometryRef();
	next unless $geom;

	$overlay->render_geometry($gc, $geom);
	
    }

    $overlay->reset_image;

}

1;
