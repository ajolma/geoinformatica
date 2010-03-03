package Geo::Vector::Layer::Dialogs::Vertices;
# @brief 

use strict;
use warnings;
use Carp;
use UNIVERSAL qw(isa);
use Geo::Vector::Layer::Dialogs qw/:all/;

## @ignore
# vertices dialog
sub open {
    my($self, $gui) = @_;
    my $dialog = $self->{vertices_dialog};
    unless ($dialog) {
	$self->{vertices_dialog} = $dialog = $gui->get_dialog('vertices_dialog');
	croak "vertices_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('vertices_dialog')->signal_connect(delete_event => \&close_vertices_dialog, [$self, $gui]);
	
	my $selection = $dialog->get_widget('vertices_treeview')->get_selection;
	$selection->set_mode('multiple');
	$selection->signal_connect(changed => \&vertices_activated, [$self, $gui]);
	
	$dialog->get_widget('vertices_from_spinbutton')->signal_connect(value_changed => \&fill_vtv, [$self, $gui]);
	$dialog->get_widget('vertices_max_spinbutton')->signal_connect(value_changed => \&fill_vtv, [$self, $gui]);
	
	$dialog->get_widget('vertices_close_button')->signal_connect(clicked => \&close_vertices_dialog, [$self, $gui]);

    } elsif (!$dialog->get_widget('vertices_dialog')->get('visible')) {
	$dialog->get_widget('vertices_dialog')->move(@{$self->{vertices_dialog_position}}) if $self->{vertices_dialog_position};
    }
    $dialog->get_widget('vertices_dialog')->set_title("Vertices of ".$self->name);
	
    my $tv = $dialog->get_widget('vertices_treeview');
    my @c = $tv->get_columns;
    for (@c) {
	$tv->remove_column($_);
    }

    my $model = Gtk2::TreeStore->new(qw/Glib::String/);
    my $cell = Gtk2::CellRendererText->new;
    my $col = Gtk2::TreeViewColumn->new_with_attributes('Vertices', $cell, text => 0);
    $tv->append_column($col);
    $tv->set_model($model);

    fill_vtv(undef, [$self, $gui]);
     
    $dialog->get_widget('vertices_dialog')->show_all;
    $dialog->get_widget('vertices_dialog')->present;
}

##@ignore
sub close_vertices_dialog {
    my($self, $gui);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    my $dialog = $self->{vertices_dialog}->get_widget('vertices_dialog');
    $self->{vertices_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    1;
}

##@ignore
sub fill_vtv {
    my($self, $gui) = @{$_[1]};

    my $overlay = $gui->{overlay};
    my $dialog = $self->{vertices_dialog};
    
    my $from = $dialog->get_widget('vertices_from_spinbutton')->get_value_as_int;
    my $count = $dialog->get_widget('vertices_max_spinbutton')->get_value_as_int;
    my $tv = $dialog->get_widget('vertices_treeview');
    my $model = $tv->get_model;
    $model->clear;

    delete $self->{GIDS};    
    my @data;
    my $vertex = 0;
    my $vertices = 0;
	
    my $features = $self->selected_features;
    if (@$features) {
	for my $f (@$features) {
	    my $geom = $f->GetGeometryRef();
	    my $fid = $f->GetFID;
	    my $name = $geom->GetGeometryName;
	    my $vertices2 = $vertices;
	    my $d = get_geom_data($self, $gui, $geom, \$vertex, \$vertices2, $from, $count);
	    push @data,["Feature (fid=$fid) ($name)",$d,$fid] if $vertices2 > $vertices;
	    $vertices = $vertices2;
	    last if $vertices >= $count;
	}
    } else {
	my $l = $self->{OGR}->{Layer};
	if ($l) {
	    my @r = $gui->{overlay}->get_viewport; #_of_selection;
	    #@r = $gui->{overlay}->get_viewport unless @r;
	    $l->SetSpatialFilterRect(@r);
	    $l->ResetReading();
	    while (my $f = $l->GetNextFeature) {
		my $geom = $f->GetGeometryRef();
		my $fid = $f->GetFID;
		my $name = $geom->GetGeometryName;
		my $vertices2 = $vertices;
		my $d = get_geom_data($self, $gui, $geom, \$vertex, \$vertices2, $from, $count);
		push @data,["Feature (fid=$fid) ($name)",$d,$fid] if $vertices2 > $vertices;
		$vertices = $vertices2;
		last if $vertices >= $count;
	    }
	}
    }

    my $i = 0;
    for my $d (@data) {
	set_geom_data($self, $d, $i, $d->[2], $model);
	$i++;
    }
}

##@ignore
sub set_geom_data {
    my($self, $data, $path, $gid, $tree_store, $iter) = @_;
    
    my $iter2 = $tree_store->append($iter);
    $tree_store->set ($iter2,0 => $data->[0]);
    
    if ($data->[1]) {

	my $i = 0;
	for my $d (@{$data->[1]}) {
	    set_geom_data($self, $d, "$path:$i", "$gid:$d->[2]", $tree_store, $iter2);
	    $i++;
	}

    } else {

	$self->{GIDS}->{$path} = $gid;

    }
}

##@ignore
sub get_geom_data {
    my($self, $gui, $geom, $vertex, $vertices, $from, $count) = @_;

    return if $$vertices >= $count;
    
    if ($geom->GetGeometryCount) {
	
	my @d;
	for my $i2 (0..$geom->GetGeometryCount-1) {
	    
	    my $geom2 = $geom->GetGeometryRef($i2);
	    my $name = $geom2->GetGeometryName;
	    
	    my $vertices2 = $$vertices;
	    my $data = get_geom_data($self, $gui, $geom2, $vertex, \$vertices2, $from, $count);
	    push @d, [($i2+1).'. '.$name, $data, $i2] if $vertices2 > $$vertices;
	    $$vertices = $vertices2;
	    last if $$vertices >= $count;
	    
	}
	return \@d if @d;
	
    } else {

	my @rect = $gui->{overlay}->get_viewport; #_of_selection;
	#@rect = $gui->{overlay}->get_viewport unless @rect;
	my $s = $gui->{overlay}->{selection};
	my $a = ($s and isa($s, 'Geo::OGR::Geometry'));
	my @d;
	for my $i (0..$geom->GetPointCount-1) {	    
	    my $x = $geom->GetX($i);
	    next if $x < $rect[0] or $x > $rect[2];
	    my $y = $geom->GetY($i);
	    next if $y < $rect[1] or $y > $rect[3];
	    if ($a) {
		my $point = Geo::OGR::Geometry->create('Point');
		$point->ACQUIRE;
		$point->AddPoint($x, $y);
		next unless $point->Within($s);
	    }
	    my $z = $geom->GetZ($i);
	    $$vertex++;
	    if ($$vertex >= $from) {
		push @d, [($i+1).": $x $y $z", undef, $i];
		$$vertices++;
	    }
	    last if $$vertices >= $count;
	}
	
	return \@d;
	
    }

    return undef;

}

##@ignore
sub vertices_activated {
    my $selection = $_[0];
    my($self, $gui) = @{$_[1]};

    my @sel = $selection->get_selected_rows;
    return unless @sel;

    $gui->{overlay}->update_image(
	sub {
	    my($overlay, $pixmap, $gc) = @_;
	    my $GIDS = $self->{GIDS};
	    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535, 0, 0));
	    for my $selected (@sel) {
		$selected = $selected->to_string;
		next unless exists $GIDS->{$selected};
		my @path = split(/:/, $GIDS->{$selected});
		my $f = $self->{OGR}->{Layer}->GetFeature($path[0]);
		my $geom = $f->GetGeometryRef();
		for my $i (1..$#path-1) {
		    $geom = $geom->GetGeometryRef($path[$i]);
		}
		my @p = ($geom->GetX($path[$#path]), $geom->GetY($path[$#path]));
		@p = $overlay->point2pixmap_pixel(@p);
		$pixmap->draw_line($gc, $p[0]-4, $p[1], $p[0]+4, $p[1]);
		$pixmap->draw_line($gc, $p[0], $p[1]-4, $p[0], $p[1]+4);
	    }
	});
}

1;
