package Geo::Vector::Layer::Dialogs::Open;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw/:all/;
use Geo::Vector::Layer::Dialogs qw/:all/;
require Win32::DriveInfo if $Config::Config{'osname'} eq 'MSWin32';

## @ignore
sub open {
    my($gui) = @_;
    my $self = { gui => $gui };

    # bootstrap:
    my($dialog, $boot) = Gtk2::Ex::Geo::Layer::bootstrap_dialog
	($self, $gui, 'open_dialog', "Open vector layer",
	 {
	     open_dialog => [delete_event => \&cancel, $self],
	     open_vector_add_datasource_button => [clicked => \&edit_datasource, $self],
	     open_vector_datasource_combobox => [changed => \&datasource_changed, $self],
	     open_vector_filesystem_driver_combobox => [changed => \&fill_layer_treeview, $self],
	     open_vector_edit_datasource_button => [clicked => \&edit_datasource, $self],
	     open_vector_delete_datasource_button => [clicked => \&delete_datasource, $self],
	     open_vector_layer_treeview => [cursor_changed => \&layer_cursor_changed, $self],
	     open_vector_remove_button => [clicked => \&remove_layer, $self],
	     open_vector_describe_button => [clicked => \&describe_layer, $self],
	     open_vector_cancel_button => [clicked => \&cancel, $self],
	     open_vector_ok_button => [clicked => \&ok, $self],
	     open_vector_auto_update_schema_checkbutton => [toggled => \&describe_layer, $self],
	 },
	 [
	  'open_vector_driver_combobox',
	  'open_vector_filesystem_driver_combobox',
	  'open_vector_datasource_combobox'
	 ]
	);
    
    if ($boot) {
	my $combo = $dialog->get_widget('open_vector_driver_combobox');
	my $model = $combo->get_model();
	for my $driver (Geo::OGR::Drivers()) {
	    my @t = $driver->DataSourceTemplate;
	    next if $t[0] eq '<filename>';
	    my $n = $driver->FormatName;
	    $model->set($model->append, 0, $n);
	}
	$combo->set_active(0);
	
	$combo = $dialog->get_widget('open_vector_filesystem_driver_combobox');
	$model = $combo->get_model();
	$model->set($model->append, 0, 'auto');
	for my $driver (Geo::OGR::Drivers()) {
	    my $n = $driver->GetName;
	    $model->set($model->append, 0, $n);
	}
	$combo->set_active(0);
	
	fill_datasource_combobox($self);
    
	my $treeview = $dialog->get_widget('open_vector_directory_treeview');
	$treeview->set_model(Gtk2::TreeStore->new('Glib::String'));
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes('', $cell, markup => 0);
	$treeview->append_column($col);
	$treeview->signal_connect(
	    button_press_event => sub 
	    {
		my($treeview, $event, $self) = @_;
		select_directory($self, $treeview) if $event->type =~ /^2button/;
		return 0;
	    }, $self);
	
	$treeview->signal_connect(
	    key_press_event => sub
	    {
		my($treeview, $event, $self) = @_;
		select_directory($self, $treeview) if $event->keyval == $Gtk2::Gdk::Keysyms{Return};
		return 0;
	    }, $self);
	
	$treeview = $dialog->get_widget('open_vector_metadata_treeview');
	$treeview->set_model(Gtk2::TreeStore->new(qw/Glib::String Glib::String/));
	my $i = 0;
	foreach my $column ('Key', 'Value') {
	    my $cell = Gtk2::CellRendererText->new;
	    if ($column eq 'value') {
		$cell->set(wrap_width => 400);
		$cell->set(wrap_mode => 'word');
	    }
	    my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	    $treeview->append_column($col);
	}
	
	$treeview = $dialog->get_widget('open_vector_schema_treeview');
	$treeview->set_model(Gtk2::TreeStore->new(qw/Glib::String Glib::String/));
	$i = 0;
	foreach my $column ('Field', 'Type') {
	    my $cell = Gtk2::CellRendererText->new;
	    my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	    $treeview->append_column($col);
	}
	
	$self->{directory_toolbar} = [];

	my $entry = $dialog->get_widget('open_vector_SQL_entry');
	$entry->signal_connect(key_press_event => sub {
	    my($entry, $event, $history) = @_;
	    my $key = $event->keyval;
	    if ($key == $Gtk2::Gdk::Keysyms{Up}) {
		$entry->set_text($history->arrow_up);
		return 1;
	    } elsif ($key == $Gtk2::Gdk::Keysyms{Down}) {
		$entry->set_text($history->arrow_down);
		return 1;
	    }
			       }, $self->{gui}{history});
	$entry->signal_connect(changed => \&on_SQL_entry_changed, $self);
    }
    
    $self->{path} = $gui->{folder} if $gui->{folder};
    $self->{path} = File::Spec->rel2abs('.') unless $self->{path};

    fill_directory_treeview($self);
    fill_layer_treeview($self);

    $dialog->get_widget('open_vector_update_checkbutton')->set_active(0);

}

## @ignore
sub fill_datasource_combobox {
    my($self, $default) = @_;
    my $model = Gtk2::ListStore->new('Glib::String');
    $model->set($model->append, 0, 'Filesystem');
    my $i = 1;
    my $active = 0;
    for my $datasource (sort keys %{$self->{gui}{resources}{datasources}}) {
	$model->set($model->append, 0, $datasource);
	$active = $i if $default and $datasource eq $default;
	$i++;
    }
    my $combo = $self->{open_dialog}->get_widget('open_vector_datasource_combobox');
    $combo->set_model($model);
    $combo->set_active($active);
}

## @ignore
sub datasource_changed {
    my(undef, $self) = @_;
    my $datasource = get_value_from_combo($self->{open_dialog}, 'open_vector_datasource_combobox');
    my($driver,undef) = @{$self->{gui}{resources}{datasources}{$datasource}} unless $datasource eq 'Filesystem';
    for my $widget (qw/filesystem_driver_label filesystem_driver_combobox directory_treeview directory_toolbar/) {
	$self->{open_dialog}->get_widget('open_vector_'.$widget)->set_sensitive($datasource eq 'Filesystem');
    }
    for my $widget (qw/edit_datasource_button delete_datasource_button/) {
	$self->{open_dialog}->get_widget('open_vector_'.$widget)->set_sensitive($datasource ne 'Filesystem');
    }
    my $notWFS = !($driver and $driver eq 'WFS');
    for my $widget (qw/label entry/) {
	$self->{open_dialog}->get_widget('open_vector_SQL_'.$widget)->set_sensitive($notWFS);
    }
    $self->{open_dialog}->get_widget('open_vector_update_checkbutton')->set_sensitive($notWFS);
    $self->{open_dialog}->get_widget('open_vector_remove_button')->set_sensitive($notWFS);
    fill_layer_treeview($self);
}

## @ignore
sub get_driver_and_datasource {
    my $self = shift;
    my $datasource = get_value_from_combo($self->{open_dialog}, 'open_vector_datasource_combobox');
    return unless $datasource;
    if ($datasource eq 'Filesystem') {
	my $driver = get_value_from_combo($self->{open_dialog}, 'open_vector_filesystem_driver_combobox');
	$driver = undef if $driver eq 'auto';
	return ($datasource, $driver, $self->{path});
    } else {
	my($driver, $connection) = @{$self->{gui}{resources}{datasources}{$datasource}};
	my($template) = Geo::OGR::Driver($driver)->DataSourceTemplate;
	my @template = split(/[\[\]]/, $template);
	my @kv = split(/ /, $connection);
	if (@kv) {
	    my $ok = 1;
	    my %map;
	    for my $kv (@kv) {
		my($k,$v) = $kv =~ /^(\w+)=(\S+)$/;
		$ok = 0, last unless $k; # old style data source, the connection string
		$map{$k} = $v;
	    }
	    if ($ok) {
		if ($map{URL} and $map{username} and $map{password}) { # convert to CURL style
		    my($protocol) = $map{URL} =~ /(https?:\/\/)/;
		    $protocol = '' unless defined $protocol;
		    $map{URL} =~ s/$protocol/$protocol$map{username}:$map{password}\@/;
		    delete $map{username};
		    delete $map{password};
		}
		# put it all together with data from the resources:
		$connection = '';
		for my $t (@template) {
		    next unless $t and $t ne '';
		    my $a = 0;
		    for my $k (keys %map) {
			$a = 1 if $t =~ /\<$k\>/;
			$t =~ s/\<$k\>/$map{$k}/;
		    }
		    $connection .= $t if $a;
		}
	    }
	}
	#print STDERR "got: $connection\n";
	return ($datasource, $driver, $connection);
    }
}

## @ignore
sub delete_datasource {
    my($button, $self) = @_;
    my $combo = $self->{open_dialog}->get_widget('open_vector_datasource_combobox');
    my $model = $combo->get_model;
    my $active = $combo->get_active();
    my $iter = $model->get_iter_from_string($active);
    my $datasource = $model->get($iter, 0);
    return if $datasource eq 'Filesystem';
    $combo->set_active(0);
    $model->remove($iter);
    delete $self->{gui}{resources}{datasources}{$datasource};
}

##@ignore
sub ok {
    my($button, $self) = @_;

    my $dialog = $self->{open_dialog};
    $self->{gui}->{folder} = $self->{path};

    my($system, $driver, $datasource) = get_driver_and_datasource($self);

    my $sql = $dialog->get_widget('open_vector_SQL_entry')->get_text;
    my $wish = $dialog->get_widget('open_vector_layer_name_entry')->get_text;
    my $update = $dialog->get_widget('open_vector_update_checkbutton')->get_active;
    my $hidden = $dialog->get_widget('open_vector_open_hidden_button')->get_active;

    my $layers = get_selected_from_selection($dialog->get_widget('open_vector_layer_treeview')->get_selection);

    my %params = (data_source => $datasource);
    my $ok = 1;
    my @o = keys %$layers;
    for (@o) {
	for my $l (@{$self->{layers}}) { # convert title to name
	    if ($l->{Title} and $_ eq $l->{Title}) {
		$_ = $l->{Name};
		last;
	    }
	}
    }
    Geo::GDAL::SetConfigOption("OGR_WFS_LOAD_MULTIPLE_LAYER_DEFN","FALSE");
    if ($sql) {
	$sql =~ s/^\s+//;
	$sql =~ s/\s+$//;
	$self->{gui}{history}->editing($sql);
	$self->{gui}{history}->enter();
	$dialog->get_widget('open_vector_SQL_entry')->set_text('');
	$params{sql} = $sql;
	$params{layer_name} = $wish;
	$ok = add_layer($self, %params);
    } elsif (@o == 1) {
	$params{driver} = $driver if $driver;
	$params{open} = $o[0];
	$params{update} = $update;
	$params{layer_name} = $wish;
	$ok = add_layer($self, %params);
    } else {
	$params{driver} = $driver if $driver;
	$params{update} = $update;
	for my $name (@o) {
	    $params{open} = $name;
	    my $k = add_layer($self, %params);
	    $ok = $k if !$k;
	}
    }
    
    $self->{gui}{tree_view}->set_cursor(Gtk2::TreePath->new(0));
    $self->{gui}{overlay}->render;
    return unless $ok;
    delete $self->{directory_toolbar};
    $dialog->get_widget('open_dialog')->destroy;
}

##@ignore
sub add_layer {
    my($self, %arg) = @_;
    my $layer_name = delete $arg{layer_name};
    my $layer;
    eval {
	$layer = Geo::Vector::Layer->new(%arg);
    };
    if ($@) {
	my $err = $@;
	if ($err) {
	    $err =~ s/\n/ /g;
	    $err =~ s/\s+$//;
	    $err =~ s/\s+/ /g;
	    $err =~ s/\^ at .*$//;
	}
	utf8::decode($err);
	$self->{gui}->message("Could not open layer: ".$err);
	return 0;
    }
    $layer->visible(0) if $arg{hidden};
    $self->{gui}->add_layer($layer, $layer_name, 1);
    return 1;
}

##@ignore
sub cancel {
    my $self = pop;
    delete $self->{directory_toolbar};
    $self->{open_dialog}->get_widget('open_dialog')->destroy;
}

##@ignore
sub remove_layer {
    my($button, $self) = @_;
    my($system, $driver, $datasource) = get_driver_and_datasource($self);
    my $layers = get_selected_from_selection(
	$self->{open_dialog}->get_widget('open_vector_layer_treeview')->get_selection);
    eval {
	my $ds = Geo::OGR::Open($datasource, 1);
	for my $i (0..$ds->GetLayerCount-1) {
	    my $l = $ds->GetLayerByIndex($i);
	    $ds->DeleteLayer($i) if $layers->{$l->GetName()};
	}
    };
    $self->{gui}->message("$@") if $@;
}

##@ignore
sub fill_directory_treeview {
    my $self = shift;

    my $treeview = $self->{open_dialog}->get_widget('open_vector_directory_treeview');
    my $model = $treeview->get_model;
    $model->clear;

    my $toolbar = $self->{open_dialog}->get_widget('open_vector_directory_toolbar');
    for (@{$self->{directory_toolbar}}) {
	$toolbar->remove($_);
    }
    $self->{directory_toolbar} = [];

    if ($self->{path} eq '') {
	@{$self->{dir_list}} = ();
	my @d = Win32::DriveInfo::DrivesInUse();

	#my $fso = Win32::OLE->new('Scripting.FileSystemObject');
	#for ( in $fso->Drives ) {
	#    push @d, $_->{DriveLetter}.':';
	#}
	for (@d) {
	    $_ .= ':';
	}

	for (@d) {
	    s/\\$//;
	    push @{$self->{dir_list}},$_;
	}
	@{$self->{dir_list}} = reverse @{$self->{dir_list}} if $self->{dir_list};
	for my $i (0..$#{$self->{dir_list}}) {
	    my $iter = $model->insert (undef, 0);
	    $model->set($iter, 0, $self->{dir_list}->[$i] );
	}
	$self->{open_dialog}->get_widget('open_vector_directory_treeview')->set_cursor(Gtk2::TreePath->new(0));
	@{$self->{dir_list}} = reverse @{$self->{dir_list}} if $self->{dir_list};
	return;
    }

    my($volume, $directories, $file) = File::Spec->splitpath($self->{path}, 1);
    $self->{volume} = $volume;
    my @dirs = File::Spec->splitdir($directories);
    unshift @dirs, File::Spec->rootdir();
    if ($^O eq 'MSWin32') {
	unshift @dirs, $volume;
    }
    
    for (reverse @dirs) {
	next if /^\s*$/;
	my $filename;
	eval {
	    $filename = Glib->filename_to_unicode($_);
	};
	next if $@;
	#my $label = Gtk2::Label->new($filename) if Gtk2->CHECK_VERSION(2, 18, 0);
	my $label = Gtk2::Label->new($filename) unless $Config::Config{'osname'} eq 'MSWin32';
	my $b = Gtk2::ToolButton->new($label, $filename);
	$b->signal_connect(
	    clicked => sub {
		my($button, $self) = @_;
		$self->{open_dialog}->get_widget('open_vector_datasource_combobox')->set_active(0);
		my $n = $button->get_label;
		if ($n eq $self->{volume}) {
		    $self->{path} = '';
		} else {
		    my @directories;
		    for (reverse @{$self->{directory_toolbar}}) {
			push @directories, $_->get_label;
			last if $_ == $_[0];
		    }
		    if ($^O eq 'MSWin32') {
			shift @directories; # remove volume
		    }
		    my $directory = File::Spec->catdir(@directories);
		    $self->{path} = File::Spec->catpath($self->{volume}, $directory, '');
		}
		fill_directory_treeview($self);
		fill_layer_treeview($self);
	    },
	    $self);
	#$label->show;
	$b->show_all;
	$toolbar->insert($b,0);
	push @{$self->{directory_toolbar}}, $b;
    }
    
    @{$self->{dir_list}} = ();

    my @files;
    eval {
	@files = Geo::GDAL::ReadDir($self->{path});
    };
    @dirs = ();
    my @fs;
    for (sort {$b cmp $a} @files) {
	my $test = File::Spec->catfile($self->{path}, $_);
	my $m;
	eval {
	    ($m) = Geo::GDAL::Stat($test);
	};
	next if $@;
	my $is_dir = $m eq 'd';
	next if (/^\./ and not $_ eq File::Spec->updir);
	next if $_ eq File::Spec->curdir;
	s/&/&amp;/g;
	s/</&lt;/g;
	s/>/&gt;/g;
	if ($is_dir) {
	    push @dirs, "<b>[$_]</b>";
	} else {
	    push @fs, $_;
	}
    }
    for (@fs) {
	push @{$self->{dir_list}}, $_;
    }
    for (@dirs) {
	push @{$self->{dir_list}}, $_;
    }

    # in a file
    push @{$self->{dir_list}},'..' unless @{$self->{dir_list}};
	
    for (@{$self->{dir_list}}) {
	my $iter = $model->insert(undef, 0);
	eval {
	    $_ = Glib->filename_to_unicode($_);
	};
	next if $@;
	$model->set($iter, 0, $_ );
    }
	
    $treeview->set_cursor(Gtk2::TreePath->new(0));

    @{$self->{dir_list}} = reverse @{$self->{dir_list}};
}

## @ignore
sub fill_layer_treeview {
    my(undef, $self) = @_ == 2 ? @_ : (undef, $_[0]);

    my $treeview;
    my $model;
    for my $widget (qw/metadata schema layer/) {
	$treeview = $self->{open_dialog}->get_widget('open_vector_'.$widget.'_treeview');
	$model = $treeview->get_model;
	$model->clear if $model;
    }
    # layer treeview remains
    
    ($self->{system}, $self->{driver}, $self->{datasource}) = get_driver_and_datasource($self);
    delete $self->{layers};
    eval {
	$self->{layers} = Geo::Vector::layers($self->{driver}, $self->{datasource});
    };
    if ($@ and $self->{system} ne 'Filesystem') {
	my $dialog = Gtk2::MessageDialog->new(undef, 'destroy-with-parent', 'info', 'close', $@);
	$dialog->signal_connect(response => sub {
	    my($dialog) = @_;
	    $dialog->destroy;
				});
	$dialog->show_all;
    }
    unless ($self->{layers}) {
	$self->{open_dialog}->get_widget('open_vector_remove_button')->set_sensitive(0);
	return;
    }
    my $notWFS = !($self->{driver} and $self->{driver} eq 'WFS');
    $self->{open_dialog}->get_widget('open_vector_remove_button')->set_sensitive($notWFS);

    my @columns;
    my $layer = $self->{layers}->[0];
    if ($layer->{Title}) { # Title is preferred for humans
	push @columns, 'Title';
    } elsif ($layer->{Name}) { # Name is required for software
	push @columns, 'Name';
    }
    push @columns, 'Geometry type' if $layer->{'Geometry type'};

    while (my $col = $treeview->get_column(0)) {
	$treeview->remove_column($col);
    }
    my @t;
    for (@columns) {
	push @t, 'Glib::String';
    }
    return unless @t;

    $model = Gtk2::TreeStore->new(@t);
    $treeview->set_model($model);
    $treeview->get_selection->set_mode('multiple');
    my $i = 0;
    for my $column (@columns) {
	my $cell = Gtk2::CellRendererText->new;	    
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$treeview->append_column($col);
    }
    for my $layer (reverse @{$self->{layers}}) {
	my $iter = $model->insert(undef, 0);
	my @row;
	my $i = 0;
	for my $column (@columns) {
	    my $v = $layer->{$column};
	    $v = Glib->filename_to_unicode($v);
	    push @row, $i++;
	    push @row, $v;
	}
	$model->set($iter, @row);
    }
    layer_cursor_changed($treeview, $self);
}

## @ignore
sub on_SQL_entry_changed {
    my($entry, $self) = @_;
    my $sql = $entry->get_text;
    $sql =~ s/^\s+//;
    $sql =~ s/\s+$//;
    $self->{open_dialog}->get_widget('open_vector_layer_name_entry')->set_text('SQL') if $sql;
    $self->{open_dialog}->get_widget('open_vector_layer_treeview')->set_sensitive(!$sql);
    $self->{open_dialog}->get_widget('open_vector_update_checkbutton')->set_sensitive(!$sql);
}

## @ignore
sub layer_cursor_changed {
    my($treeview, $self) = @_;
    my($path, $focus_column) = $treeview->get_cursor;
    if ($path) {
	my $model = $treeview->get_model;
	my $iter = $model->get_iter($path);
	my $layer_name = $model->get($iter, 0);
	$self->{open_dialog}->get_widget('open_vector_layer_name_entry')->set_text($layer_name);
    }
    if ($self->{open_dialog}->get_widget('open_vector_auto_update_schema_checkbutton')->get_active()) {
	describe_layer(undef, $self);
    } else {
	for my $widget (qw/metadata schema/) {
	    my $model = $self->{open_dialog}->get_widget('open_vector_'.$widget.'_treeview')->get_model;
	    $model->clear if $model;
	}
	$self->{open_dialog}->get_widget('open_vector_schema_label')->set_label('');
    }
    $self->{gui}{history}->editing('');
    $self->{open_dialog}->get_widget('open_vector_SQL_entry')->set_text('');
}

## @ignore
sub edit_datasource {
    my($button, $self) = @_;
    my $title;
    my $index;
    my $driver;
    my $format;
    my $template;
    my $help;
    my $datasource;
    my $old_datasource_name;
    my $connection = '';
    if ($button->get_label eq 'gtk-add') {
	$title = 'Add a data source';
	my $combo = $self->{open_dialog}->get_widget('open_vector_driver_combobox');
	$index = $combo->get_active;
    } elsif ($button->get_label eq 'gtk-edit') {
	$title = 'Edit a data source';
	$datasource = get_value_from_combo($self->{open_dialog}, 'open_vector_datasource_combobox');
	return if !$datasource or $datasource eq 'Filesystem';
	($driver, $connection) = @{$self->{gui}{resources}{datasources}{$datasource}};
    } else {
	return;
    }
    my $i = -1;
    for my $d (Geo::OGR::Drivers()) {
	($template, $help) = $d->DataSourceTemplate;
	next if $template eq '<filename>';
	$i++;
	if (defined $index) {
	    next unless $i == $index;
	    $driver = $d->GetName;
	} elsif (defined $driver) {
	    next unless $d->GetName eq $driver;
	}
	$format = $d->FormatName;
	last;
    }
    my @template = split(/[\[\]]/, $template);
    # ask from user the things defined by the template
    my @ask;
    my %required;
    {
	my @tmp;
	for my $c (@template) {
	    next unless ($c and $c ne '');
	    push @tmp, $c;
	    my $r = $template =~ /\[\s*$c/;
	    my @c = $c =~ /\<(\w+)\>/;
	    push @ask, @c;
	    unless ($r) {
		for my $a (@c) {
		    $required{$a} = 1;
		}
	    }
	}
	@template = @tmp;
    }

    my $dialog = Gtk2::Dialog->new($title, 
				   $self->{open_dialog}->get_widget('open_dialog'),
				   'destroy-with-parent',
				   'gtk-cancel' => 'reject',
				   'gtk-ok' => 'ok');
    
    my $vbox = Gtk2::VBox->new(FALSE, 0);
    $vbox->pack_start(Gtk2::Label->new("Edit a connection to a $format data source"), FALSE, FALSE, 0);

    my $table = Gtk2::Table->new(1+@ask, 2, TRUE);
    $table->attach(Gtk2::Label->new("Unique name for the data source *:"), 0, 1, 0, 1, 'fill', 'fill', 0, 0);
    my $e = Gtk2::Entry->new();
    $e->set_name('datasource_name');
    $table->attach($e, 1, 2, 0, 1, 'fill', 'fill', 0, 0);
    $i = 1;
    for my $a (@ask) {
	my $l = $a;
	$l .= ' *' if $required{$a};
	my $label = Gtk2::Label->new($l.":");
	$label->set_justify('left');
	$table->attach($label, 0, 1, $i, $i+1, 'expand', 'fill', 0, 0);
	$e = Gtk2::Entry->new();
	$e->set_visibility(0) if $a eq 'password';
	$e->set_name($a);
	$table->attach($e, 1, 2, $i, $i+1, 'fill', 'fill', 0, 0);
	$i++;
    }
    $vbox->pack_start($table, FALSE, TRUE, 0);

    my $l = Gtk2::Label->new("* denotes a required entry");
    $l->set_justify('left');
    $vbox->pack_start($l, FALSE, TRUE, 0);
    $l = Gtk2::Label->new($help);
    $l->set_justify('left');
    $vbox->pack_start($l, FALSE, TRUE, 0);

    $dialog->get_content_area()->add($vbox);
    $dialog->show_all;
 
    my %input;
    if ($button->get_label eq 'gtk-edit') {
	$old_datasource_name = $datasource;
	my @kv = split(/ /, $connection);
	my $old_style = 0;
	if (@kv) {
	    for my $kv (@kv) {
		my($k,$v) = $kv =~ /^(\w+)=(\S+)$/;
		$old_style = 1, last unless $k;
		$input{$k} = $v;
	    }
	}
	if ($old_style) {
	    my $m = Gtk2::MessageDialog->new
		(undef,'destroy-with-parent','info','ok',
		 "The connection string is\n$connection\nPlease re-enter the data.");
	    $m->run;
	    $m->destroy;
	    %input = ();
	}
	$input{datasource_name} = $datasource;
	set_entries($dialog, \%input);
    }
    while (1) {
	my $response = $dialog->run;
	unless ($response eq 'ok') {
	    $dialog->destroy;
	    return;
	}
	get_entries($dialog, \%input);
	my $ok = 1;
	for (sort keys %input) {
	    if ($required{$_} and not $input{$_}) {
		$ok = 0;
		last;
	    }
	}
	if ($ok) {
	    $dialog->destroy;
	    last;
	}
	my $m = Gtk2::MessageDialog->new
	    (undef,'destroy-with-parent','info','ok',
	     "Please give all required data.");
	$m->run;
	$m->destroy;
    }

    delete $self->{gui}{resources}{datasources}{$old_datasource_name} if $old_datasource_name;
    $datasource = $input{datasource_name};
    delete $input{datasource_name};
    my @input;
    for my $k (keys %input) {
	push @input, "$k=$input{$k}" if $input{$k} ne '';
    }
    $connection = join(' ', @input);
    $self->{gui}{resources}{datasources}{$datasource} = [$driver, $connection];
    fill_datasource_combobox($self, $datasource);
}

## @ignore
sub get_entries {
    my($widget, $entries) = @_;
    if ($widget->isa('Gtk2::Container')) {
	$widget->foreach(\&get_entries, $entries);
    } elsif ($widget->isa('Gtk2::Entry')) {
	my $n = $widget->get_name;
	my $t = $widget->get_text;
	$entries->{$n} = $t if $n;
    }
}

## @ignore
sub set_entries {
    my($widget, $entries) = @_;
    if ($widget->isa('Gtk2::Container')) {
	$widget->foreach(\&set_entries, $entries);
    } elsif ($widget->isa('Gtk2::Entry')) {
	my $n = $widget->get_name;
	#print STDERR "$n -> $entries->{$n}\n" if $n and $entries->{$n};
	$widget->set_text($entries->{$n}) if $n and $entries->{$n};
    }
}

## @ignore
sub select_directory {
    my($self, $treeview) = @_;

    my $combo = $self->{open_dialog}->get_widget('open_vector_driver_combobox');
    $combo->set_active(0) if $combo->get_active;
    $self->{open_dialog}->get_widget('open_vector_layer_treeview')->get_model->clear;

    my($path, $focus_column) = $treeview->get_cursor;
    my $index = $path->to_string if $path;
    if (defined $index) {
	my $dir = $self->{dir_list}->[$index];
	$dir =~ s/^<b>\[//;
	$dir =~ s/\]<\/b>$//;
	my $directory;
	if ($self->{path} eq '') {
	    $self->{volume} = $dir;
	    $directory = File::Spec->rootdir();
	} else {
	    my @directories;
	    for (reverse @{$self->{directory_toolbar}}) {
		push @directories, $_->get_label;
	    }
	    if ($^O eq 'MSWin32') {
		shift @directories; # remove volume
	    }
	    if ($dir eq File::Spec->updir) {
		pop @directories;
	    } else {
		push @directories, $dir;
	    }
	    $directory = File::Spec->catdir(@directories);
	}
	$self->{path} = File::Spec->catpath($self->{volume}, $directory, '');
	fill_directory_treeview($self);
	fill_layer_treeview($self);
    }
}

## @ignore
sub describe_layer {
    my($button, $self) = @_ == 2 ? @_ : (undef, $_[0]);
    my $schema_title = '';
    my %attr = ( driver => $self->{driver}, data_source => $self->{datasource} );
    my $sql = $self->{open_dialog}->get_widget('open_vector_SQL_entry')->get_text;
    my $layer;
    if ($sql) {
	$attr{SQL} = $sql;
	$schema_title = 'Schema of the SQL query';
    } else {
	my $treeview = $self->{open_dialog}->get_widget('open_vector_layer_treeview');
	my($path, $focus_column) = $treeview->get_cursor;
	return unless $path;
	my $model = $treeview->get_model;
	my $iter = $model->get_iter($path);
	my $name = $model->get($iter, 0);
	return unless defined $name;
	$schema_title = "Schema of $name";
	for my $l (@{$self->{layers}}) { # convert title to name
	    if ($l->{Title} and $name eq $l->{Title}) {
		$layer = $l;
		$name = $l->{Name};
		last;
	    } elsif ($name eq $l->{Name}) {
		$layer = $l;
	    }
	}
	$attr{layer} = $name;
    }

    my($metadata, $schema) = Geo::Vector::describe_layer(%attr);
    if ($layer) {
	for my $key (sort keys %$layer) {
	    next if $key eq 'Name';
	    next if $key eq 'Title';
	    next if $key eq 'Geometry type';
	    push @$metadata, [ 0 => $key, 1 => $layer->{$key} ];
	}
    }
    my $model = $self->{open_dialog}->get_widget('open_vector_metadata_treeview')->get_model;
    $model->clear;
    for my $m (reverse @$metadata) {
	my $iter = $model->insert(undef, 0);
	$model->set($iter, @$m);
    }
    $self->{open_dialog}->get_widget('open_vector_schema_label')->set_label($schema_title);
    $model = $self->{open_dialog}->get_widget('open_vector_schema_treeview')->get_model;
    $model->clear;
    for my $s (reverse @$schema) {
	my $iter = $model->insert(undef, 0);
	$model->set($iter, @$s);
    }
}

1;
