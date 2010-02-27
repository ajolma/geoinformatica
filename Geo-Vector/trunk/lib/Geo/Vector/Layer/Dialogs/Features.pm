package Geo::Vector::Layer::Dialogs::Features;
# @brief 

use strict;
use warnings;
use Carp;
use Geo::Vector::Layer::Dialogs qw/:all/;

## @ignore
# features dialog
sub open {
    my($self, $gui) = @_;
    my $dialog = $self->{features_dialog};
    unless ($dialog) {
	$self->{features_dialog} = $dialog = $gui->get_dialog('features_dialog');
	croak "features_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('features_dialog')->signal_connect(delete_event => \&close_features_dialog, [$self, $gui]);
	
	my $selection = $dialog->get_widget('feature_treeview')->get_selection;
	$selection->set_mode('multiple');
	$selection->signal_connect(changed => \&feature_activated, [$self, $gui]);
	
	$dialog->get_widget('from_feature_spinbutton')
	    ->signal_connect(value_changed => \&fill_features_table, [$self, $gui]);
	$dialog->get_widget('max_features_spinbutton')
	    ->signal_connect(value_changed => \&fill_features_table, [$self, $gui]);

	$dialog->get_widget('features_limit_checkbutton')
	    ->signal_connect(toggled => \&fill_features_table, [$self, $gui]);
	
	$dialog->get_widget('features_vertices_button')
	    ->signal_connect(clicked => \&vertices_of_selected_features, [$self, $gui]);
	$dialog->get_widget('make_selection_button')
	    ->signal_connect(clicked => \&make_selection, [$self, $gui]);
	$dialog->get_widget('from_selection_button')
	    ->signal_connect(clicked => \&from_selection, [$self, $gui]);
	$dialog->get_widget('copy_selected_button')
	    ->signal_connect(clicked => \&copy_selected_features, [$self, $gui]);
	$dialog->get_widget('zoom_to_button')
	    ->signal_connect(clicked => \&zoom_to_selected_features, [$self, $gui]);
	$dialog->get_widget('close_features_button')
	    ->signal_connect(clicked => \&close_features_dialog, [$self, $gui]);

    } elsif (!$dialog->get_widget('features_dialog')->get('visible')) {
	$dialog->get_widget('features_dialog')
	    ->move(@{$self->{features_dialog_position}}) if $self->{features_dialog_position};
    }
    $dialog->get_widget('features_dialog')->set_title("Features of ".$self->name);
	
    my @columns;
    my @coltypes;
    my @ctypes;
    my $schema = $self->schema;    
    for my $name (sort {$schema->{$a}{VisualOrder} <=> $schema->{$b}{VisualOrder}} keys %$schema) {
	my $n = $name;
	$n =~ s/_/__/g;
	$n =~ s/^\.//;
	push @columns, $n;
	push @coltypes, 'Glib::String'; # use custom sort
	push @ctypes, $schema->{$name}{TypeName};
    }
    
    my $tv = $dialog->get_widget('feature_treeview');
    
    my $model = Gtk2::TreeStore->new(@coltypes);
    $tv->set_model($model);
    
    for ($tv->get_columns) {
	$tv->remove_column($_);
    }
    
    my $i = 0;
    foreach my $column (@columns) {
	if ($ctypes[$i] eq 'Integer' or $ctypes[$i] eq 'Real') { 
	    $model->set_sort_func($i, sub {
		my($model, $a, $b, $column) = @_;
		$a = $model->get($a, $column);
		$a = 0 unless $a;
		$b = $model->get($b, $column);
		$b = 0 unless $b;
		return $a <=> $b}, $i);
	} else {
	    $model->set_sort_func($i, sub {
		my($model, $a, $b, $column) = @_;
		$a = $model->get($a, $column);
		$a = '' unless $a;
		$b = $model->get($b, $column);
		$b = '' unless $b;
		return $a cmp $b}, $i);
	}
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }
    
    $i = 0;
    for ($tv->get_columns) {
	$_->set_sort_column_id($i++);
	$_->signal_connect(clicked => sub {
	    shift;
	    my($self, $tv) = @{$_[0]};
	    fill_features_table(undef, [$self, $gui]);
	}, [$self, $tv]);
    }
    
    fill_features_table(undef, [$self, $gui]);
    
    $dialog->get_widget('features_dialog')->show_all;
    $dialog->get_widget('features_dialog')->present;
}

##@ignore
sub close_features_dialog {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    my $dialog = $self->{features_dialog}->get_widget('features_dialog');
    $self->{features_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    1;
}


##@ignore
sub in_field_order {
    my $_a = $a;
    my $_b = $b;
    
}


##@ignore
sub fill_features_table {
    my($self, $gui) = @{$_[1]};

    my $dialog = $self->{features_dialog};
    my $treeview = $dialog->get_widget('feature_treeview');
    my $overlay = $gui->{overlay};

    my $from = $dialog->get_widget('from_feature_spinbutton')->get_value_as_int;
    my $count = $dialog->get_widget('max_features_spinbutton')->get_value_as_int;
    my $limit = $dialog->get_widget('features_limit_checkbutton')->get_active;

    my $schema = $self->schema;
    my $model = $treeview->get_model;

    $model->clear;

    my @fnames = sort { $schema->{$a}{VisualOrder} <=> $schema->{$b}{VisualOrder} } keys %$schema;

    my $features = $self->selected_features;

    my %added;
    add_features($self, $treeview, $model, \@fnames, $features, 1, \%added);

    $count -= @$features;
    my $is_all = 1;
    if ($count > 0) {
	if ($limit) {
	    my @r = $overlay->get_viewport;
	    ($features, $is_all) = Geo::Vector::features( $self, filter_with_rect => \@r, from => $from, limit => $count );
	} else {
	    ($features, $is_all) = Geo::Vector::features( $self, from => $from, limit => $count );
	}
	add_features($self, $treeview, $model, \@fnames, $features, 0, \%added);
    }
    $dialog->get_widget('all_features_label')->set_sensitive($is_all);
}

##@ignore
sub add_features {
    my($self, $treeview, $model, $fnames, $features, $select, $added) = @_;

    my $selection = $treeview->get_selection;

    for my $f (@$features) {
	my @rec;
	my $rec = 0;

	my $id = $f->GetFID;
	next if exists $added->{$id};
	$added->{$id} = 1;

	for my $name (@$fnames) {
	    if ($name =~ /^\./ or $f->IsFieldSet($name)) {
		push @rec, $rec++;
		my $v = Geo::Vector::feature_attribute($f, $name);
		$v = decode($self->{encoding}, $v) if $self->{encoding};
		push @rec, $v;
	    } else {
		push @rec, $rec++;
		push @rec, undef;
	    }
	}

	my $iter = $model->insert (undef, 999999);
	$model->set ($iter, @rec);

	$selection->select_iter($iter) if $select;
    }
}

## @ignore
sub get_hash_of_selected_features {
    my $self = shift;
    my %selected;
    my $s = $self->selected_features();
    for my $f (@$s) {
	$selected{$f->GetFID} = $f;
    }
    return \%selected;
}

##@ignore
sub set_selected_features {
    my($self, $treeview) = @_;
    my $selected = $self->get_hash_of_selected_features;
    my $selection = $treeview->get_selection;
    my $model = $treeview->get_model;
    my $iter = $model->get_iter_first();
    while ($iter) {
	my($id) = $model->get($iter, 0);
	$selection->select_iter($iter) if $selected->{$id};
	$iter = $model->iter_next($iter);
    }
}

##@ignore
sub feature_activated {
    my $selection = shift;
    my($self, $gui) = @{$_[0]};

    my $features = get_selected($selection);
    $features = $self->features(with_id=>[keys %$features]);
    return unless $features;
    return unless @$features;
    $self->selected_features($features);

    my $overlay = $gui->{overlay};
    $overlay->reset_pixmap;

    my $gc = Gtk2::Gdk::GC->new($overlay->{pixmap});
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535,0,0));

    for my $f (@$features) {

	next unless $f; # should not happen

	my $geom = $f->GetGeometryRef();
	next unless $geom;

	$overlay->render_geometry($gc, Geo::OGC::Geometry->new(Text => $geom->ExportToWkt));
	
    }

    $overlay->reset_image;

}

##@ignore
sub zoom_to_selected_features {
    my($self, $gui) = @{$_[1]};

    my $dialog = $self->{features_dialog};
    my $treeview = $dialog->get_widget('feature_treeview');
    my $features = get_selected($treeview->get_selection);
    $features = $self->features(with_id=>[keys %$features]);

    my @viewport = $gui->{overlay}->get_viewport;
    my @extent = ();
    
    for (@$features) {

	my $geom = $_->GetGeometryRef();
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

##@ignore
sub copy_selected_features {
    my($self, $gui) = @{$_[1]};
    Geo::Vector::Layer::Dialogs::Copy($self, $gui);
}

##@ignore
sub vertices_of_selected_features {
    my($self, $gui) = @{$_[1]};
    $self->open_vertices_dialog($gui);
}

##@ignore
sub make_selection {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{features_dialog};
    my $treeview = $dialog->get_widget('feature_treeview');
    my $features = get_selected($treeview->get_selection);
    $features = $self->features(with_id=>[keys %$features]);
    delete $gui->{overlay}->{selection};
    for (@$features) {
	my $geom = $_->GetGeometryRef();
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
sub from_selection {
    my($self, $gui) = @{$_[1]};
    return unless $gui->{overlay}->{selection};
    $self->add_feature({ geometry => $gui->{overlay}->{selection} });
    fill_features_table(undef, [$self, $gui]);
}

1;
