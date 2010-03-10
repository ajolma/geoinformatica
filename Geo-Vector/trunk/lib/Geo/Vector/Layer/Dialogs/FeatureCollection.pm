package Geo::Vector::Layer::Dialogs::FeatureCollection;
# @brief 

use strict;
use warnings;
use Carp;
use UNIVERSAL qw(isa);
use Gtk2::Ex::Geo::Dialogs qw/:all/;
use Geo::Vector::Layer::Dialogs qw/:all/;
use Geo::Vector::Layer::Dialogs::Feature;

## @ignore
sub open {
    my($self, $gui) = @_;

    # bootstrap:
    my($dialog, $boot) = $self->bootstrap_dialog
	($gui, 'feature_collection_dialog', "Features of ".$self->name,
	 {
	     feature_collection_dialog => [delete_event => \&close_feature_collection_dialog, [$self, $gui]],
	     feature_collection_from_spinbutton => [value_changed => \&fill_features_table, [$self, $gui]],
	     feature_collection_max_spinbutton => [value_changed => \&fill_features_table, [$self, $gui]],

	     feature_collection_add_button => [clicked => \&add_feature, [$self, $gui]],
	     feature_collection_delete_feature_button => [clicked => \&delete_selected_features, [$self, $gui]],
	     feature_collection_from_drawing_button => [clicked => \&from_drawing, [$self, $gui]],
	     feature_collection_copy_to_drawing_button => [clicked => \&copy_to_drawing, [$self, $gui]],
	     feature_collection_copy_from_drawing_button => [clicked => \&copy_from_drawing, [$self, $gui]],

	     feature_collection_vertices_button => [clicked => \&vertices_of_selected_features, [$self, $gui]],
	     feature_collection_make_selection_button => [clicked => \&make_selection, [$self, $gui]],
	     feature_collection_copy_selected_button => [clicked => \&copy_selected_features, [$self, $gui]],
	     feature_collection_zoom_to_button => [clicked => \&zoom_to_selected_features, [$self, $gui]],
	     feature_collection_close_button => [clicked => \&close_feature_collection_dialog, [$self, $gui]],
	 },
	);
    
    if ($boot) {	
	my $selection = $dialog->get_widget('feature_collection_treeview')->get_selection;
	$selection->set_mode('multiple');
	$selection->signal_connect(changed => \&feature_activated, [$self, $gui]);
    }

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
	    fill_features_table(undef, [$self, $gui]);
	}, [$self, $gui]);
    }

    fill_features_table(undef, [$self, $gui]);

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

    return $dialog->get_widget('feature_collection_dialog');
}

##@ignore
sub close_feature_collection_dialog {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    $self->hide_dialog('feature_collection_dialog');
    1;
}

##@ignore
sub add_feature {
    my($self, $gui) = @{$_[1]};
    Geo::Vector::Layer::Dialogs::Feature::open($self, $gui);
}

##@ignore
sub delete_selected_features {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{feature_collection_dialog};
    my $treeview = $dialog->get_widget('feature_collection_treeview');
    my $delete = get_selected_from_selection($treeview->get_selection);
    my @features;
    for my $i (0..$#{$self->{features}}) {
	next if exists $delete->{$i};
	my $f = $self->{features}[$i];
	push @features, $f;
	$f->FID($#features);
    }
    $self->{features} = \@features;
    fill_features_table(undef, [$self, $gui]);
    $gui->{overlay}->render;
}

##@ignore
sub from_drawing {
    my($self, $gui) = @{$_[1]};
    return unless $gui->{overlay}->{drawing};
    my $feature = Geo::Vector::Feature->new();
    $feature->Geometry(Geo::OGR::CreateGeometryFromWkt( $gui->{overlay}->{drawing}->AsText ));
    $self->feature($feature);
    fill_features_table(undef, [$self, $gui]);
    $gui->{overlay}->render;
}

##@ignore
sub copy_to_drawing {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{feature_collection_dialog};
    my $treeview = $dialog->get_widget('feature_collection_treeview');
    my $features = get_selected_from_selection($treeview->get_selection);
    my @features = keys %$features;
    if (@features == 0 or @features > 1) {
	$gui->message("Select one and only one feature.");
	return;
    }
    $features = $self->features(with_id=>[@features]);
    for my $f (@$features) {
	my $geom = $f->GetGeometryRef();
	next unless $geom;
	my $g = Geo::OGC::Geometry->new(Text => $geom->ExportToWkt);
	$gui->{overlay}->{drawing} = $g;
	last;
    }
    $gui->{overlay}->update_image;
}

##@ignore
sub copy_from_drawing {
    my($self, $gui) = @{$_[1]};
    unless ($gui->{overlay}->{drawing}) {
	$gui->message("Create a drawing first.");
	return;
    }
    my $dialog = $self->{feature_collection_dialog};
    my $treeview = $dialog->get_widget('feature_collection_treeview');
    my $features = get_selected_from_selection($treeview->get_selection);
    my @features = keys %$features;
    if (@features == 0 or @features > 1) {
	$gui->message("Select one and only one feature.");
	return;
    }
    $features = $self->features(with_id=>[@features]);
    for my $f (@$features) {
	my $geom = Geo::OGR::Geometry->create(WKT => $gui->{overlay}->{drawing}->AsText);
	$f->SetGeometry($geom);
	$self->feature($f->FID, $f);
	last;
    }
    fill_features_table(undef, [$self, $gui]);
    $gui->{overlay}->render;
}

##@ignore
sub vertices_of_selected_features {
    my($self, $gui) = @{$_[1]};
    # add title to the call
    $self->open_vertices_dialog($gui);
}

##@ignore
sub make_selection {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{feature_collection_dialog};
    my $treeview = $dialog->get_widget('feature_collection_treeview');
    my $features = get_selected_from_selection($treeview->get_selection);
    $features = $self->features(with_id=>[keys %$features]);
    delete $gui->{overlay}->{selection};
    for my $f (@$features) {
	my $geom = $f->GetGeometryRef();
	next unless $geom;
	my $g = Geo::OGC::Geometry->new(Text => $geom->ExportToWkt);
	unless ($gui->{overlay}->{selection}) {
	    unless (isa($g, 'Geo::OGC::GeometryCollection')) {
		my $coll = $g->MakeCollection;
		$coll->AddGeometry($g);
		$gui->{overlay}->{selection} = $coll;
	    } else {
		$gui->{overlay}->{selection} = $g;
	    }
	} else {
	    $gui->{overlay}->{selection}->AddGeometry($g);
	}
    }
    $gui->{overlay}->update_image;
}

##@ignore
sub copy_selected_features {
    my($self, $gui) = @{$_[1]};
    Geo::Vector::Layer::Dialogs::Copy::open($self, $gui);
}

##@ignore
sub zoom_to_selected_features {
    my($self, $gui) = @{$_[1]};

    my $dialog = $self->{feature_collection_dialog};
    my $treeview = $dialog->get_widget('feature_collection_treeview');
    my $features = get_selected_from_selection($treeview->get_selection);
    $features = $self->features(with_id=>[keys %$features]);

    my @viewport = $gui->{overlay}->get_viewport;
    my @extent = ();
    
    for my $f (@$features) {

	my $geom = $f->Geometry();
	next unless $geom;

	my $env = $geom->GetEnvelope; 
	$extent[0] = $env->[0] if !defined($extent[0]) or $env->[0] < $extent[0];
	$extent[1] = $env->[2] if !defined($extent[1]) or $env->[2] < $extent[1];
	$extent[2] = $env->[1] if !defined($extent[2]) or $env->[1] > $extent[2];
	$extent[3] = $env->[3] if !defined($extent[3]) or $env->[3] > $extent[3];
	
    }

    if (@extent) {
	
	# a point?
	if ($extent[2] - $extent[0] <= 0) {
	    $extent[0] -= ($viewport[2] - $viewport[0])/10;
	    $extent[2] += ($viewport[2] - $viewport[0])/10;
	}
	if ($extent[3] - $extent[1] <= 0) {
	    $extent[1] -= ($viewport[3] - $viewport[1])/10;
	    $extent[3] += ($viewport[3] - $viewport[1])/10;
	}
	
	$gui->{overlay}->zoom_to(@extent);
    }
}

## @ignore
sub fill_features_table {
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
	$i++;
	next if $i <= $from;
	$k++, next if ($k < 0 or $k > $#{$self->{features}});
	my $f = $self->{features}->[$k++]; 
	my @rec;
	my $rec = 0;

	push @rec, $rec++;
	push @rec, $k-1; # $f->GetFID;
	
	push @recs, \@rec;
    }
    $k = @recs;

    for my $rec (@recs) {
	
	my $iter = $model->insert(undef, 999999);
	$model->set($iter, @$rec);
	
    }
    
}

## @ignore
sub feature_activated {
    my $selection = shift;
    my($self, $gui) = @{$_[0]};

    my $dialog = $self->{feature_collection_dialog};
    my $model = $dialog->get_widget('feature_collection_attributes_treeview')->get_model;

    my $ids = get_selected_from_selection($selection);
    my $features = $self->features(with_id=>[keys %$ids]);
    return unless $features;
    return unless @$features;
    $self->selected_features($features);

    if (@$features == 1) {
	my @k = keys %$ids;
	my $f = $features->[0];
	my $schema = $self->schema($k[0]);
	$model->clear;

	my @recs;
	for my $field ($schema->fields) {
	    my $n = $field->{Name};
	    next if $n =~ /^\./;
	    my @rec;
	    my $rec = 0;
	    push @rec, $rec++;	    
	    push @rec, $n;
	    push @rec, $rec++;
	    push @rec, Geo::Vector::feature_attribute($f, $n);
	    push @recs, \@rec;
	}

	for my $rec (@recs) {
	
	    my $iter = $model->insert (undef, 999999);
	    $model->set ($iter, @$rec);
	    
	}
	
    }

    $gui->{overlay}->update_image(
	sub {
	    my($overlay, $pixmap, $gc) = @_;
	    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535,0,0));
	    for my $f (@$features) {
		next unless $f; # should not happen
		my $geom = $f->GetGeometryRef();
		next unless $geom;
		$overlay->render_geometry($gc, Geo::OGC::Geometry->new(Text => $geom->ExportToWkt));
	    }
	});

}

1;
