package Geo::Raster::Layer::Dialogs::WMS;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw/:all/;
use Geo::Raster::Layer;
use Geo::Raster::Layer::Dialogs::EditWMS;
use XML::LibXML;
#use Data::Dumper;

## @ignore
sub open {
    my($gui) = @_;
    my $self = { gui => $gui };

    # bootstrap:
    my($dialog, $boot) = Gtk2::Ex::Geo::Layer::bootstrap_dialog
	($self, $gui, 'WMS_dialog', "Open from a WMS",
	 {
             WMS_dialog => [delete_event => \&cancel, $self],
	     WMS_connect_button => [clicked => \&connect, $self],
	     WMS_new_button => [clicked => \&new, $self],
	     WMS_edit_button => [clicked => \&edit, $self],
	     WMS_delete_button => [clicked => \&delete, $self],
	     WMS_apply_button => [clicked => \&apply, $self],
	     WMS_cancel_button => [clicked => \&cancel, $self],
	     WMS_ok_button => [clicked => \&ok, $self],
	 },
	 [
	  'WMS_combobox',
	  ]
	);
    if ($boot) {
	set_connections($self);
	my $tree_view = $dialog->get_widget('WMS_treeview');
	my $tree_store = Gtk2::TreeStore->new(qw/Glib::String/);
	$tree_view->set_model($tree_store);
	my $cell = Gtk2::CellRendererText->new;
	my $tree_column = Gtk2::TreeViewColumn->new_with_attributes("Title", $cell, text => 0);
	$tree_column->{column_number} = 0;
	$tree_view->append_column($tree_column);
	my $selection = $tree_view->get_selection;
	$selection->set_mode('multiple');
    }

}

##@ignore
sub set_connections {
    my $self = pop;
    my $combo = $self->{WMS_dialog}->get_widget('WMS_combobox');
    my $iter = $combo->get_active_iter();
    my $model = $combo->get_model;
    my $name = $model->get($iter) if $iter;
    $model->clear;
    my $i = 0;
    my $active = 0;
    for my $src (sort keys %{$self->{gui}{resources}{WMS}}) {
	$model->set($model->append, 0, $src);
	$active = $i if $name and $src eq $name;
	$i++;
    }
    $combo->set_active($active);
}

##@ignore
sub connection {
    my $self = pop;
    my $combo = $self->{WMS_dialog}->get_widget('WMS_combobox');
    my $iter = $combo->get_active_iter();
    my $model = $combo->get_model;
    return $model->get($iter);
}

##@ignore
sub connect {
    my $self = pop;
    my $name = connection($self);
    my $connection = $self->{gui}{resources}{WMS}{$name};
    my $ua = LWP::UserAgent->new;
    my $url = $connection->[0].'?service=WMS&version=1.1.1&request=GetCapabilities';
    my $req = HTTP::Request->new(GET => $url);
    $req->authorization_basic($connection->[1], $connection->[2]) if $connection->[1];
    my $res = $ua->request($req);
    unless ($res->is_success) {
	my $msg = $res->status_line;
	my $msgbox = Gtk2::MessageDialog->new(undef,
					      'destroy-with-parent',
					      'info',
					      'close',
					      $msg);
	$msgbox->run;
	$msgbox->destroy;
	return;
    }
    my $xml = $res->as_string;
    my @xml = split /\n/, $xml;
    while (not $xml[0] =~ /^<WMT_MS_Capabilities/) {
	shift @xml;
    }
    my $capabilities = XML::LibXML->load_xml(string => "<xml>@xml</xml>");

    my $parent;
    my $depth = -1;
    my @titles;
    my $data = \@titles;
    for my $layer ($capabilities->findnodes('//Layer')) {
	my @p = split /\//,$layer->nodePath;
	my $d = @p;
	my $title = $layer->findnodes('./Title')->to_literal;

	if (($depth < 0) or ($depth == @p)) {
	    $depth = @p;
	} elsif ($depth < @p) { # new child
	    $depth = @p;
	    $parent = $data;
	    $data->[$#$data][1] = [];
	    $data = $data->[$#$data][1];
	} else { # back up
	    $depth = @p;
	    $data = $parent;
	}
	push @$data, [$title];
    }

    my $tree_view = $self->{WMS_dialog}->get_widget('WMS_treeview');
    my $tree_store = $tree_view->get_model;
    $tree_store->clear;

    for my $title (@titles) {
	add_to_tree($title, $tree_store);
    }

}

sub add_to_tree {
    my($data, $tree_store, $iter) = @_;
    my $iter_child = $tree_store->append($iter);
    $tree_store->set($iter_child, 0 => $data->[0]);
    if ($data->[1]) {
	for my $data_child (@{$data->[1]}) {
	    add_to_tree($data_child, $tree_store, $iter_child);
	}
    }
}

##@ignore
sub new {
    my $self = pop;
    my $dialog = Geo::Raster::Layer::Dialogs::EditWMS::open($self->{gui}, "New WMS connection");
    my $ret;
    while (1) {
	$ret = $dialog->get_widget('WMS_edit_dialog')->run();
	last unless $ret eq 'apply';
    }
    if ($ret eq 'ok') {
	my $name = $dialog->get_widget('WMS_edit_name_entry')->get_text();
	$self->{gui}{resources}{WMS}{$name} =
	    [
	     $dialog->get_widget('WMS_edit_URL_entry')->get_text(),
	     $dialog->get_widget('WMS_edit_username_entry')->get_text(),
	     $dialog->get_widget('WMS_edit_password_entry')->get_text()
	    ];
	set_connections($self);
    }
    $dialog->get_widget('WMS_edit_dialog')->destroy();
}

##@ignore
sub edit {
    my $self = pop;
    my $dialog = Geo::Raster::Layer::Dialogs::EditWMS::open($self->{gui}, "Edit WMS connection");
    my $name = connection($self);
    my $connection = $self->{gui}{resources}{WMS}{$name};
    $dialog->get_widget('WMS_edit_name_entry')->set_text($name);
    $dialog->get_widget('WMS_edit_name_entry')->set_editable(0);
    $dialog->get_widget('WMS_edit_URL_entry')->set_text($connection->[0]);
    $dialog->get_widget('WMS_edit_username_entry')->set_text($connection->[1]);
    $dialog->get_widget('WMS_edit_password_entry')->set_text($connection->[2]);
    my $ret;
    while (1) {
	$ret = $dialog->get_widget('WMS_edit_dialog')->run();
	last unless $ret eq 'apply';
    }
    if ($ret eq 'ok') {
	$self->{gui}{resources}{WMS}{$name} =
	    [
	     $dialog->get_widget('WMS_edit_URL_entry')->get_text(),
	     $dialog->get_widget('WMS_edit_username_entry')->get_text(),
	     $dialog->get_widget('WMS_edit_password_entry')->get_text()
	    ];
    }
    $dialog->get_widget('WMS_edit_dialog')->destroy();
}

##@ignore
sub delete {
    my $self = pop;
    my $name = connection($self);
    delete $self->{gui}{resources}{WMS}{$name};
    set_connections($self);
}

##@ignore
sub cancel {
    my $self = pop;
    $self->{WMS_dialog}->get_widget('WMS_dialog')->destroy;
}

##@ignore
sub apply {
    my $self = pop;
    my $tree_view = $self->{WMS_dialog}->get_widget('WMS_treeview');
    my $tree_store = $tree_view->get_model;
    my $selection = $tree_view->get_selection;
    my @rows = $selection->get_selected_rows;
    my @titles;
    for my $row (@rows) {
	my $iter = $tree_store->get_iter_from_string($row->to_string);
	my $title = $tree_store->get_value($iter, 0);
	push @titles, $title;
    }
    add_layer($self, @titles);
}

##@ignore
sub add_layer {
    my($self, $title) = @_;

    my $name = connection($self);
    my $connection = $self->{gui}{resources}{WMS}{$name};
    my $url = $connection->[0];
    my $username = $connection->[1];
    my $passwd = $connection->[2];
    
    my($protocol) = $url =~ /^(https?:\/\/)/;
    my $address = $url;
    $address =~ s/^$protocol//;
    my $auth = $username ? $username.':'.$passwd.'@' : '';
    my $wms = 'WMS:'.$protocol.$auth.$address;
    
    my $dataset = Geo::GDAL::Open($wms);
    my $metadata = $dataset->Metadata("SUBDATASETS");
    my $i = 1;
    my $choice;
    while (1) {
        my $desc = 'SUBDATASET_'.$i.'_DESC';
        last unless $metadata->{$desc};
	if ($metadata->{$desc} eq $title) {
	    $choice = $i;
	    last;
	}
        $i++;
    }
    
    $url = $metadata->{'SUBDATASET_'.$choice.'_NAME'};
    ($protocol) = $url =~ /^WMS:(https?:\/\/)/;
    $address = $url;
    $address =~ s/^WMS:$protocol//;
    $wms = 'WMS:'.$protocol.$auth.$address;

    $dataset = Geo::GDAL::Open($wms);
    my $driver = Geo::GDAL::Driver('WMS');
    my $vsi = Geo::GDAL::VSIFOpenL('/vsimem/xml','w');
    my $xml = $driver->Copy('/vsimem/xml', $dataset);
    $dataset = Geo::GDAL::Open('/vsimem/xml');
    Geo::GDAL::VSIFCloseL($vsi);

    my $bands = $dataset->{RasterCount};
    my $layer = $bands == 1 ? 
        Geo::Raster::Layer->new(dataset => $dataset, 
                                name => $title) :
        Geo::Raster::MultiBandLayer->new(dataset => $dataset, 
                                         name => $title);
    $self->{gui}->add_layer($layer, $title, 1);
    $self->{gui}->{overlay}->render;
}

##@ignore
sub ok {
    my $self = pop;
    apply($self);
    $self->{WMS_dialog}->get_widget('WMS_dialog')->destroy;
}

1;
