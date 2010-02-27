package Geo::Raster::Layer;
# @brief A subclass of Gtk2::Ex::Geo::Layer and Geo::Raster
#
# These methods are not documented. For documentation, look at
# Gtk2::Ex::Geo::Layer.

=pod

=head1 NAME

Geo::Raster::Layer - A geospatial raster layer class for Gtk2::Ex::Geo

=cut

use strict;
use warnings;
use UNIVERSAL qw(isa);
use POSIX;
POSIX::setlocale( &POSIX::LC_NUMERIC, "C" ); # http://www.remotesensing.org/gdal/faq.html nr. 11
use FileHandle;
use Carp;
use File::Spec;
use File::Basename;
use Gtk2::Ex::Geo::Layer qw /:all/;
use Geo::Raster::Layer::Dialogs;
use Glib qw/TRUE FALSE/;
use Gtk2;

use vars qw/$dialog_folder %EPSG/;

require Exporter;

our @ISA = qw(Exporter Geo::Raster Gtk2::Ex::Geo::Layer);
our %EXPORT_TAGS = ( 'all' => [ qw( %EPSG ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = 0.03;

sub registration {
    my $dialogs = Geo::Raster::Layer::Dialogs->new();
    my $commands = {
	open => {
	    nr => 2,
	    text => 'Open raster',
	    tip => 'Add a new raster layer.',
	    pos => 0,
	    sub => sub {
		my(undef, $gui) = @_;
		my $file_chooser =
		    Gtk2::FileChooserDialog->new ('Select a raster file',
						  undef, 'open',
						  'gtk-cancel' => 'cancel',
						  'gtk-ok' => 'ok');

		$file_chooser->set_select_multiple(1);
		$file_chooser->set_current_folder($gui->{folder}) if $gui->{folder};
    
		my @filenames = $file_chooser->get_filenames if $file_chooser->run eq 'ok';

		$gui->{folder} = $file_chooser->get_current_folder();
    
		$file_chooser->destroy;

		return unless @filenames;

		for my $filename (@filenames) {
		    my $dataset = Geo::GDAL::Open($filename);
		    croak "$filename is not recognized by GDAL" unless $dataset;
		    my $bands = $dataset->{RasterCount};
	
		    for my $band (1..$bands) {
	    
			my $layer = Geo::Raster::Layer->new(filename => $filename, band => $band);
			
			my $name = fileparse($filename);
			$name =~ s/\.\w+$//;
			$name .= "_$band" if $bands > 1;
			$gui->add_layer($layer, $name, 1);
			$gui->{overlay}->render;
			
		    }
		}
		$gui->{tree_view}->set_cursor(Gtk2::TreePath->new(0));
	    }
	},
	save_all => {
	    nr => 1,
	    text => 'Save rasters',
	    tip => 'Save all libral raster layers.',
	    pos => 0,
	    sub => sub {
		my(undef, $gui) = @_;
		my @rasters;
		if ($gui->{overlay}->{layers}) {
		    for my $layer (@{$gui->{overlay}->{layers}}) {
			if (isa($layer, 'Geo::Raster')) {
			    next if $layer->{GDAL};
			    push @rasters, $layer;
			}
		    }
		}
		
		croak('No libral layers to save.') unless @rasters;

		my $file_chooser =
		    Gtk2::FileChooserDialog->new ("Save all rasters into folder",
						  undef, 'select_folder',
						  'gtk-cancel' => 'cancel',
						  'gtk-ok' => 'ok');
		
		my $folder = $file_chooser->get_current_folder();
		$folder = $gui->{folder} if $gui->{folder};
		$file_chooser->set_current_folder($folder);
		my $uri;
		if ($file_chooser->run eq 'ok') {
		    $uri = $file_chooser->get_uri;
		    $gui->{folder} = $file_chooser->get_current_folder();
		}
		$file_chooser->destroy;
		
		if ($uri) {
		    
		    #$uri =~ s/^file:\/\///;	
		    
		    for my $layer (@rasters) {
			
			#my $filename = File::Spec->catfile($uri, $layer->name);
			my $filename = File::Spec->catfile($gui->{folder}, $layer->name);
			
			my $save = 1;
			if ($layer->exists($filename)) {
			    my $dialog = Gtk2::MessageDialog->new(undef,'destroy-with-parent',
								  'question',
								  'yes_no',
								  "Overwrite existing $filename?");
			    my $ret = $dialog->run;
			    $save = 0 if $ret eq 'no';
			    $dialog->destroy;
			}
			$layer->save($filename) if $save;
		    }
		}
	    }
	}
    };
    return { dialogs => $dialogs, commands => $commands };
}

sub upgrade {
    my($object) = @_;
    if (ref($object) eq 'Geo::Raster') {
	bless($object, 'Geo::Raster::Layer');
	$object->defaults();
	return 1;
    }
    return 0;
}

sub new {
    my($package, %params) = @_;
    my $self = Geo::Raster::new($package, %params);
    Gtk2::Ex::Geo::Layer::new($package, self => $self, %params);
    return $self;
}

sub defaults {
    my($self, %params) = @_;

    if ($self->{GDAL}) {
	my $band = $self->band();
	my $color_table = $band->GetRasterColorTable;
	my $color_interpretation = $band->GetRasterColorInterpretation;
	if ($color_table) {
	    $self->color_table($color_table);
	    $self->palette_type('Color table');
	} elsif ($color_interpretation == $Geo::GDAL::Const::GCI_RedBand) {
	    $self->palette_type('Red channel');
	    #$self->color_scale($b->GetMinimum, $b->GetMaximum);
	    $self->color_scale(0, 255);
	} elsif ($color_interpretation == $Geo::GDAL::Const::GCI_GreenBand) {
	    $self->palette_type('Green channel');
	    $self->color_scale(0, 255);
	} elsif ($color_interpretation == $Geo::GDAL::Const::GCI_BlueBand) {
	    $self->palette_type('Blue channel');
	    $self->color_scale(0, 255);
	} else {
	    $self->palette_type('Grayscale');
	}
    } else {
	$self->palette_type('Grayscale');
    }
    $self->SUPER::defaults(%params);
}

sub save {
    my($self, $filename, $format) = @_;
    $self->SUPER::save($filename, $format);
    if ($self->{COLOR_TABLE} and @{$self->{COLOR_TABLE}}) {
	my $fh = new FileHandle;
	croak "can't write to $filename.clr: $!\n" unless $fh->open(">$filename.clr");
	for my $color (@{$self->{COLOR_TABLE}}) {
	    next if $color->[0] < 0 or $color->[0] > 255;
	    # skimming out data because this format does not support all
	    print $fh "@$color[0..3]\n";
	}
	$fh->close;
	eval {
	    $self->save_color_table("$filename.color_table");
	};
	print STDERR "warning: $@" if $@;
    }
    if ($self->{COLOR_BINS} and @{$self->{COLOR_BINS}}) {
	eval {
	    $self->save_color_bins("$filename.color_bins");
	};
	print STDERR "warning: $@" if $@;
    }
}

sub type {
    my($self, $format) = @_;
    my $type = $self->data_type;
    my $tooltip = ($format and ($format eq 'long' or $format eq 'tooltip'));
    if ($type) {
	if ($tooltip) {
	    $type = $type eq 'Integer' ? 'integer-valued raster' : 'real-valued raster';
	} else {
	    $type = $type eq 'Integer' ? 'int' : 'real';
	}
    } else {
	$type = '';
    }
    if ($self->{GDAL}) {
	$type = $tooltip ? "GDAL $type" : "G $type";
    }
    return $type;
}

sub supported_palette_types {
    my($self) = @_;
    return ('Single color') unless $self->{GRID}; # may happen if not cached
    if ($self->datatype eq 'Integer') {
	return ('Single color','Grayscale','Rainbow','Color table','Color bins','Red channel','Green channel','Blue channel');
    } else {
	return ('Single color','Grayscale','Rainbow','Color bins','Red channel','Green channel','Blue channel');

    }
}

sub supported_symbol_types {
    my($self) = @_;
    return ('No symbol') unless $self->{GRID}; # may happen if not cached
    if ($self->datatype eq 'Integer') {
	return ('No symbol', 'Flow_direction', 'Square', 'Dot', 'Cross');
    } else {
	return ('No symbol', 'Flow_direction', 'Square', 'Dot', 'Cross');
    }
}

sub properties_dialog {
    my($self, $gui) = @_;
    if ($self->{GDAL}) {
	$self->open_gdal_properties_dialog($gui);
    } else {
	$self->open_libral_properties_dialog($gui);
    }
}

sub menu_items {
    my($self, $items) = @_;
    $items = $self->SUPER::menu_items($items);
    $items->{x10} =
    {
	nr => 10,
    };
    $items->{'S_ave...'} = 
    {
	nr => 11,
	sub => sub {
	    my($self, $gui) = @{$_[1]};
	    my $file_chooser =
		Gtk2::FileChooserDialog->new( "Save raster '".$self->name."' as:",
					      undef, 'save',
					      'gtk-cancel' => 'cancel',
					      'gtk-ok' => 'ok' );
	    
	    my $folder = $file_chooser->get_current_folder();
	    $folder = $gui->{folder} if $gui->{folder};
	    $file_chooser->set_current_folder($folder);
	    $file_chooser->set_current_name($self->name);
	    my $filename;
	    if ($file_chooser->run eq 'ok') {
		$filename = $file_chooser->get_filename;
		$gui->{folder} = $file_chooser->get_current_folder();
	    }
	    $file_chooser->destroy;

	    if ($filename) {
		if ($self->exists($filename)) {
		    my $dialog = Gtk2::MessageDialog->new(undef, 'destroy-with-parent',
							  'question',
							  'yes_no',
							  "Overwrite existing $filename?");
		    my $ret = $dialog->run;
		    $dialog->destroy;
		    return if $ret eq 'no';
		}
		$self->save($filename);
	    }
	}
    } unless $self->{GDAL};
    $items->{'C_opy...'} =
    {
	nr => 12,
	sub => sub {
	    my($self, $gui) = @{$_[1]};
	    $self->open_copy_dialog($gui);
	}
    };
    $items->{'V_ectorize...'} =
    {
	nr => 13,
	sub => sub {
	    my($self, $gui) = @{$_[1]};
	    $self->open_vectorize_dialog($gui);
	}
    };
    return $items;
}

sub render {
    my($self, $pb) = @_;

    return if !$self->visible();

    $self->{PALETTE_VALUE} = $PALETTE_TYPE{$self->{PALETTE_TYPE}};
    $self->{SYMBOL_VALUE} = $SYMBOL_TYPE{$self->{SYMBOL_TYPE}};
    if ($self->{SYMBOL_FIELD} eq 'Fixed size') {
		$self->{SYMBOL_SCALE_MIN} = 0; # similar to grayscale scale
		$self->{SYMBOL_SCALE_MAX} = 0;
    }

    #this will need to be done when there's support in the layer for attributes
    #my $schema = $self->schema();
    #$self->{COLOR_FIELD_VALUE} = $schema->{$self->{COLOR_FIELD}}{Number};

    my $tmp = Gtk2::Ex::Geo::gtk2_ex_geo_pixbuf_get_world($pb);
    my($minX,$minY,$maxX,$maxY) = @$tmp;
    $tmp = Gtk2::Ex::Geo::gtk2_ex_geo_pixbuf_get_size($pb);
    my($w,$h) = @$tmp;
    my $pixel_size = Gtk2::Ex::Geo::gtk2_ex_geo_pixbuf_get_pixel_size($pb);

    my $gdal = $self->{GDAL};

    if ($gdal) {
	$self->cache($minX,$minY,$maxX,$maxY,$pixel_size);
	return unless $self->{GRID} and Geo::Raster::ral_grid_get_height($self->{GRID});
    }

    if ($self->datatype eq 'Integer') {	    

	my $layer = Geo::Raster::ral_make_integer_grid_layer($self);
	if ($layer) {
	    Geo::Raster::ral_render_igrid($pb, $self->{GRID}, $layer);
	    Geo::Raster::ral_destroy_integer_grid_layer($layer);
	}

    } elsif ($self->datatype eq 'Real') {
	
	my $layer = Geo::Raster::ral_make_real_grid_layer($self);
	if ($layer) {
	    Geo::Raster::ral_render_rgrid($pb, $self->{GRID}, $layer);
	    Geo::Raster::ral_destroy_real_grid_layer($layer);
	}

    } else {
	croak("bad Geo::Raster::Layer");
    }
}

sub open_gdal_properties_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{gdal_properties_dialog};
    unless ($dialog) {
	$self->{gdal_properties_dialog} = $dialog = $gui->get_dialog('gdal_properties_dialog');
	croak "gdal_properties_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('gdal_properties_dialog')->signal_connect(delete_event => \&cancel_gdal_properties, [$self, $gui]);
	$dialog->get_widget('gdal_properties_apply_button')->signal_connect(clicked => \&apply_gdal_properties, [$self, $gui, 0]);
	$dialog->get_widget('gdal_properties_cancel_button')->signal_connect(clicked => \&cancel_gdal_properties, [$self, $gui]);
	$dialog->get_widget('gdal_properties_ok_button')->signal_connect(clicked => \&apply_gdal_properties, [$self, $gui, 1]);
    } elsif (!$dialog->get_widget('gdal_properties_dialog')->get('visible')) {
	$dialog->get_widget('gdal_properties_dialog')->move(@{$self->{gdal_properties_dialog_position}});
    }
    $dialog->get_widget('gdal_properties_dialog')->set_title("Properties of ".$self->name);
	
    $self->{backup}->{name} = $self->name;
    $self->{backup}->{alpha} = $self->alpha;
    $self->{backup}->{nodata_value} = $self->nodata_value;

    $dialog->get_widget('gdal_name_entry')->set_text($self->name);
    $dialog->get_widget('gdal_alpha_spinbutton')->set_value($self->alpha);

    my @size = $self->size(of_GDAL=>1);
    $dialog->get_widget('gdal_size_label')->set_text("@size");

    @size = $self->world(of_GDAL=>1);
    $dialog->get_widget('gdal_min_x_label')->set_text($size[0]);
    $dialog->get_widget('gdal_min_y_label')->set_text($size[1]);
    $dialog->get_widget('gdal_max_x_label')->set_text($size[2]);
    $dialog->get_widget('gdal_max_y_label')->set_text($size[3]);

    @size = $self->cell_size(of_GDAL=>1);
    $dialog->get_widget('gdal_cellsize_label')->set_text("@size");

    my $nodata = $self->nodata_value();
    $nodata = '' unless defined $nodata;
    $dialog->get_widget('gdal_nodata_entry')->set_text($nodata);

    @size = $self->value_range(of_GDAL=>1);
    my $text = defined $size[0] ? "@size" : "not available";
    $dialog->get_widget('gdal_minmax_label')->set_text($text);
    
    $dialog->get_widget('gdal_properties_dialog')->show_all;
    $dialog->get_widget('gdal_properties_dialog')->present;
    
    return $dialog->get_widget('gdal_properties_dialog');
}

##@ignore
sub apply_gdal_properties {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{gdal_properties_dialog};

    eval {
	my $name = $dialog->get_widget('gdal_name_entry')->get_text;
	$self->name($name);
	my $alpha = $dialog->get_widget('gdal_alpha_spinbutton')->get_value_as_int;
	$self->alpha($alpha);
	
	my $nodata = get_number($dialog->get_widget('gdal_nodata_entry'));
	my $band = $self->band();
	$band->SetNoDataValue($nodata) if $nodata ne '';
    };
    $gui->message("$@") if $@;

    $self->{gdal_properties_dialog_position} = [$dialog->get_widget('gdal_properties_dialog')->get_position];
    $dialog->get_widget('gdal_properties_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

##@ignore
sub cancel_gdal_properties {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }

    eval {
	$self->alpha($self->{backup}->{alpha});
	$self->name($self->{backup}->{name});
	my $band = $self->band();
	$band->SetNoDataValue($self->{backup}->{nodata}) if $self->{backup}->{nodata} and $self->{backup}->{nodata} ne '';
    };
    $gui->message("$@") if $@;

    my $dialog = $self->{gdal_properties_dialog}->get_widget('gdal_properties_dialog');
    $self->{gdal_properties_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

sub open_libral_properties_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{libral_properties_dialog};
    unless ($dialog) {
	$self->{libral_properties_dialog} = $dialog = $gui->get_dialog('libral_properties_dialog');
	croak "libral_properties_dialog for Geo::Vector does not exist" unless $dialog;
	$dialog->get_widget('libral_properties_dialog')->signal_connect(delete_event => \&cancel_libral_properties, [$self, $gui]);
	$dialog->get_widget('libral_properties_apply_button')->signal_connect(clicked => \&apply_libral_properties, [$self, $gui, 0]);
	$dialog->get_widget('libral_properties_cancel_button')->signal_connect(clicked => \&cancel_libral_properties, [$self, $gui]);
	$dialog->get_widget('libral_properties_ok_button')->signal_connect(clicked => \&apply_libral_properties, [$self, $gui, 1]);
    } elsif (!$dialog->get_widget('libral_properties_dialog')->get('visible')) {
	$dialog->get_widget('libral_properties_dialog')->move(@{$self->{libral_properties_dialog_position}});
    }
    $dialog->get_widget('libral_properties_dialog')->set_title("Properties of ".$self->name);
	
    $self->{backup}->{name} = $self->name;
    $self->{backup}->{alpha} = $self->alpha;
    $self->{backup}->{nodata_value} = $self->nodata_value;
    my @world = $self->world();
    $self->{backup}->{world} = \@world;
    $self->{backup}->{cell_size} = $self->cell_size();

    $dialog->get_widget('libral_name_entry')->set_text($self->name);
    $dialog->get_widget('libral_alpha_spinbutton')->set_value($self->alpha);

    my @size = $self->size();
    $dialog->get_widget('libral_size_label')->set_text("@size");

    $dialog->get_widget('libral_min_x_entry')->set_text($world[0]);
    $dialog->get_widget('libral_min_y_entry')->set_text($world[1]);
    $dialog->get_widget('libral_max_x_entry')->set_text($world[2]);
    $dialog->get_widget('libral_max_y_entry')->set_text($world[3]);

    $dialog->get_widget('libral_cellsize_entry')->set_text($self->cell_size());

    my $nodata = $self->nodata_value();
    $nodata = '' unless defined $nodata;
    $dialog->get_widget('libral_nodata_entry')->set_text($nodata);

    @size = $self->value_range();
    my $text = defined $size[0] ? "@size" : "not available";
    $dialog->get_widget('libral_minmax_label')->set_text($text);
    
    $dialog->get_widget('libral_properties_dialog')->show_all;
    $dialog->get_widget('libral_properties_dialog')->present;
}

##@ignore
sub apply_libral_properties {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{libral_properties_dialog};

    eval {
	my $name = $dialog->get_widget('libral_name_entry')->get_text;
	$self->name($name);
	my $alpha = $dialog->get_widget('libral_alpha_spinbutton')->get_value_as_int;
	$self->alpha($alpha);

	my @world;
	$world[0] = get_number($dialog->get_widget('libral_min_x_entry'));
	$world[1] = get_number($dialog->get_widget('libral_min_y_entry'));
	$world[2] = get_number($dialog->get_widget('libral_max_x_entry'));
	$world[3] = get_number($dialog->get_widget('libral_max_y_entry'));
	my $cell_size = get_number($dialog->get_widget('libral_cellsize_entry'));
    
	my ($minX,$minY) = ($world[0], $world[1]);
	my ($maxX,$maxY) = ($world[2], $world[3]);
    
	for ($minX,$minY,$maxX,$maxY,$cell_size) {
	    $_ = undef if /^\s*$/;
	}
    
	$self->world(minX=>$minX, minY=>$minY, maxX=>$maxX, maxY=>$maxY, cell_size=>$cell_size);
	
	my $nodata = get_number($dialog->get_widget('libral_nodata_entry'));
	$self->nodata_value($nodata);
    };
    $gui->message("$@") if $@;

    $self->{libral_properties_dialog_position} = [$dialog->get_widget('libral_properties_dialog')->get_position];
    $dialog->get_widget('libral_properties_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

##@ignore
sub cancel_libral_properties {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }

    $self->alpha($self->{backup}->{alpha});
    $self->name($self->{backup}->{name});
    $self->world( minX => $self->{backup}->{world}->[0], 
		  minY => $self->{backup}->{world}->[1],
		  cell_size => $self->{backup}->{cell_size} );
    $self->nodata_value($self->{backup}->{nodata});
    
    my $dialog = $self->{libral_properties_dialog}->get_widget('libral_properties_dialog');
    $self->{libral_properties_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

sub open_copy_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{copy_dialog};
    unless ($dialog) {
	$self->{copy_dialog} = $dialog = $gui->get_dialog('copy_dialog');
	croak "copy_dialog for Geo::Raster does not exist" unless $dialog;

	my $combo = $dialog->get_widget('copy_driver_combobox');
	my $renderer = Gtk2::CellRendererText->new;
	$combo->pack_start ($renderer, TRUE);
	$combo->add_attribute ($renderer, text => 0);
	$combo->signal_connect(changed=>\&copy_driver_selected, [$self, $gui]);

	$dialog->get_widget('copy_folder_button')
	    ->signal_connect(clicked => \&copy_select_folder, [$self, $gui]);
	
	$combo = $dialog->get_widget('copy_region_combobox');
	$renderer = Gtk2::CellRendererText->new;
	$combo->pack_start ($renderer, TRUE);
	$combo->add_attribute ($renderer, text => 0);
	$combo->signal_connect(changed=>\&copy_region_selected, [$self, $gui]);

	$dialog->get_widget('copy_dialog')
	    ->signal_connect(delete_event => \&cancel_copy, [$self, $gui]);
	$dialog->get_widget('copy_cancel_button')
	    ->signal_connect(clicked => \&cancel_copy, [$self, $gui]);
	$dialog->get_widget('copy_ok_button')
	    ->signal_connect(clicked => \&do_copy, [$self, $gui, 1]);

	for ('minx','miny','maxx','maxy','cellsize') {
	    $dialog->get_widget('copy_'.$_.'_entry')->signal_connect(
		changed => 
		sub {
		    my(undef, $self) = @_;
		    return if $self->{_ignore_copy_entry_change};
		    $self->{copy_dialog}->get_widget('copy_region_combobox')->set_active(0);
		    copy_info($self);
		}, $self);
	}

	$dialog->get_widget('from_EPSG_entry')
	    ->signal_connect(changed => \&update_srs_labels, [$self, $gui]);
	$dialog->get_widget('to_EPSG_entry')
	    ->signal_connect(changed => \&update_srs_labels, [$self, $gui]);

    } elsif (!$dialog->get_widget('copy_dialog')->get('visible')) {
	$dialog->get_widget('copy_dialog')->move(@{$self->{copy_dialog_position}});
    }
    $dialog->get_widget('copy_dialog')->set_title("Copy ".$self->name);
    $dialog->get_widget('copy_progressbar')->set_fraction(0);
	
    my $model = Gtk2::ListStore->new('Glib::String');
    $model->set($model->append, 0, 'libral');
    my @drivers;
    for my $driver (Geo::GDAL::Drivers) {
	next unless $driver->TestCapability('Create');
	my $name = $driver->{ShortName};
	push @drivers, $name;
    }
    for my $driver (sort @drivers) {
	$model->set($model->append, 0, $driver);
    }
    my $combo = $dialog->get_widget('copy_driver_combobox');
    $combo->set_model($model);
    $combo->set_active(0);

    $model = Gtk2::ListStore->new('Glib::String');
    $model->set($model->append, 0, '');
    $model->set($model->append, 0, '<Current view>');
    $model->set($model->append, 0, '<self>');
    my %names;
    for my $layer (@{$gui->{overlay}->{layers}}) {
	my $n = $layer->name();
	$names{$n} = 1;
	next unless isa($layer, 'Geo::Raster');
	next if $n eq $self->name();
	$model->set($model->append, 0, $n);
    }
    $combo = $dialog->get_widget('copy_region_combobox');
    $combo->set_model($model);
    $combo->set_active(2);

    copy_region_selected($combo, [$self, $gui]);

    my $i = ord('a'); 
    while ($names{chr($i)}) {$i++}
    my $name = chr($i);
	
    $dialog->get_widget('copy_name_entry')->set_text($name);

    $dialog->get_widget('copy_dialog')->show_all;
    $dialog->get_widget('copy_dialog')->present;
    return $dialog->get_widget('copy_dialog');
}

##@ignore
sub do_copy {
    my($self, $gui, $close) = @{$_[1]};

    my $dialog = $self->{copy_dialog};

    my $minx = get_number($dialog->get_widget('copy_minx_entry'));
    my $miny = get_number($dialog->get_widget('copy_miny_entry'));
    my $maxx = get_number($dialog->get_widget('copy_maxx_entry'));
    my $maxy = get_number($dialog->get_widget('copy_maxy_entry'));
    my $cellsize = get_number($dialog->get_widget('copy_cellsize_entry'));
    if ($minx eq '' or $miny eq '' or $maxx eq '' or $maxy eq '' or $cellsize eq '') {
	return;
    }

    my($src, $dst);
    my $project = $dialog->get_widget('copy_projection_checkbutton')->get_active;
    my @bounds;
    if ($project) {
	my $from = $dialog->get_widget('from_EPSG_entry')->get_text;
	my $to = $dialog->get_widget('to_EPSG_entry')->get_text;
	return unless $EPSG{$from} and $EPSG{$to};

	$src = Geo::OSR::SpatialReference->create( EPSG => $from );
	$dst = Geo::OSR::SpatialReference->create( EPSG => $to );
	return unless $src and $dst;

	# compute corner points in new srs
	my $ct;
	eval {
	    $ct = Geo::OSR::CoordinateTransformation->new($src, $dst);
	};
	if ($@ or !$ct) {
	    $@ = '' unless $@;
	    $@ = ": $@" if $@;
	    $gui->message("Can't create coordinate transformation$@.");
	    return;
	}
	my $points = [[$minx,$miny],[$minx,$maxy],[$maxx,$miny],[$maxx,$maxy]];
	$ct->TransformPoints($points);
	for (@$points) {
	    $bounds[0] = $_->[0] if (!defined($bounds[0]) or ($_->[0] < $bounds[0]));
	    $bounds[1] = $_->[1] if (!defined($bounds[1]) or ($_->[1] < $bounds[1]));
	    $bounds[2] = $_->[0] if (!defined($bounds[2]) or ($_->[0] > $bounds[2]));
	    $bounds[3] = $_->[1] if (!defined($bounds[3]) or ($_->[1] > $bounds[3]));
	}

	$src = $src->ExportToPrettyWkt;
	$dst = $dst->ExportToPrettyWkt;
    }

    my $name = $dialog->get_widget('copy_name_entry')->get_text();
    my $folder = $dialog->get_widget('copy_folder_entry')->get_text();
    $folder .= '/' if $folder;

    my $combo = $dialog->get_widget('copy_driver_combobox');
    my $iter = $combo->get_active_iter;
    my $driver = $combo->get_model->get($iter);
    $combo = $dialog->get_widget('copy_region_combobox');
    $iter = $combo->get_active_iter;
    my $region = $combo->get_model->get($iter);

    my($new_layer, $src_dataset, $dst_dataset);
    
    # src_dataset
    if ($driver eq 'libral' and !$project) {
	if ($self->{GDAL}) {
	    $new_layer = $self->cache($minx, $miny, $maxx, $maxy, $cellsize);
	} else {
	    $new_layer = $self * 1;
	}
    } else {
	$src_dataset = $self->dataset;

	if ($project) {
	    #my($w, $h) = $src_dataset->Size;
	    #my @transform = $src_dataset->GeoTransform;
	    #my $w = int(($maxx-$minx)/$transform[1]);
	    #my $h = int(($miny-$maxy)/$transform[5]);
	    my $w = int(($bounds[2]-$bounds[0])/$cellsize+1);
	    my $h = int(($bounds[3]-$bounds[1])/$cellsize+1);
	    my $bands = $src_dataset->Bands;
	    my $type = $src_dataset->Band(1)->DataType;
	    my $d = $driver eq 'libral' ? 'MEM' : $driver;
	    $dst_dataset = Geo::GDAL::Driver($d)->Create($folder.$name, $w, $h, $bands, $type);
	    my @transform = ($bounds[0], $cellsize, 0, 
			     $bounds[1], 0, $cellsize);
	    $dst_dataset->GeoTransform(@transform);
	    my $alg = 'NearestNeighbour';
	    my $bar = $dialog->get_widget('copy_progressbar');

	    eval {
		Geo::GDAL::ReprojectImage($src_dataset, $dst_dataset, $src, $dst, $alg, 0, 0.0, 
					  \&progress, $bar);
	    };
	    if ($@) {
		$gui->message("Error in reprojection: $@.");
		return;
	    }
	} else {
	    $dst_dataset = Geo::GDAL::Driver($driver)->Copy($folder.$name, $src_dataset);
	}

	$new_layer = {};
	$new_layer->{GDAL}->{dataset} = $dst_dataset;
	$new_layer->{GDAL}->{band} = 1;
	if ($driver eq 'libral') {
	    Geo::Raster::cache($new_layer);
	    delete $new_layer->{GDAL};
	}
	bless $new_layer => 'Geo::Raster';
    }
    
    $gui->add_layer($new_layer, $name, 1);
    $gui->set_layer($new_layer);
    $gui->select_layer($name);
    $gui->{overlay}->zoom_to($new_layer);

    $self->{copy_dialog_position} = [$dialog->get_widget('copy_dialog')->get_position];
    $dialog->get_widget('copy_dialog')->hide() if $close;
    $gui->{overlay}->render;
}

sub progress {
    my($progress, $msg, $bar) = @_;
    $progress = 1 if $progress > 1;
    $bar->set_fraction($progress);
    Gtk2->main_iteration while Gtk2->events_pending;
    return 1;
}

##@ignore
sub cancel_copy {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    
    my $dialog = $self->{copy_dialog}->get_widget('copy_dialog');
    $self->{copy_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

sub copy_select_folder {
    my($self, $gui) = @{$_[1]};
    my $file_chooser =
	Gtk2::FileChooserDialog->new ("Select a folder",
				      undef, 'select_folder',
				      'gtk-cancel' => 'cancel',
				      'gtk-ok' => 'ok');
    #$file_chooser->set_current_folder($dialog_folder) if $dialog_folder;
    my $uri;
    if ($file_chooser->run eq 'ok') {
	$dialog_folder = $file_chooser->get_current_folder();
	$uri = $file_chooser->get_uri;
	#print "$uri\n";
	#print "$dialog_folder\n";
	$uri =~ s/^file:\/\///;
	$uri =~ s/^\/// if $uri =~ /^\/\w:/; # hack for windows
	$self->{copy_dialog}->get_widget('copy_folder_entry')->set_text($uri);
    }
    $file_chooser->destroy;
}

sub copy_driver_selected {
    my $combo = $_[0];
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{copy_dialog};
    my $model = $combo->get_model;
    my $iter = $combo->get_active_iter;
    my $driver = $model->get($iter);
    my $a = ($driver eq 'libral' or $driver eq 'MEM');
    for ('copy_folder_button','copy_folder_entry') {
	$dialog->get_widget($_)->set_sensitive(not $a);
    }
}

sub copy_region_selected {
    my $combo = $_[0];
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{copy_dialog};
    my $model = $combo->get_model;
    my $iter = $combo->get_active_iter;
    my $region = $model->get($iter);
    my @region;
    if ($region eq '') {
    } elsif ($region eq '<Current view>') {
	@region = $gui->{overlay}->get_viewport();
	push @region, $self->cell_size( of_GDAL => 1 );
    } else {
	$region = $self->name if $region eq '<self>';
	my $layer = $gui->{overlay}->get_layer_by_name($region);
	@region = $layer->world( of_GDAL => 1 );
	push @region, $layer->cell_size( of_GDAL => 1 );
    }
    $self->copy_define_region(@region);
}

sub copy_define_region {
    my $self = shift;

    my $dialog = $self->{copy_dialog};
    $dialog->get_widget('copy_size_label')->set_text('?');
    $dialog->get_widget('copy_memory_size_label')->set_text('?');

    my($minx, $miny, $maxx, $maxy, $cellsize);

    if (@_) {

	($minx, $miny, $maxx, $maxy, $cellsize) = @_;
	
    } else {

	$minx = get_number($dialog->get_widget('copy_minx_entry'));
	$miny = get_number($dialog->get_widget('copy_miny_entry'));
	$maxx = get_number($dialog->get_widget('copy_maxx_entry'));
	$maxy = get_number($dialog->get_widget('copy_maxy_entry'));
	$cellsize = get_number($dialog->get_widget('copy_cellsize_entry'));

	$cellsize = $self->cell_size( of_GDAL => 1 ) if $cellsize eq '';
	my @world = $self->world( of_GDAL => 1 ); # $min_x, $min_y, $max_x, $max_y

	$minx = $world[0] if $minx eq '';
	$miny = $world[1] if $miny eq '';
	$maxx = $world[2] if $maxx eq '';
	$maxy = $world[3] if $maxy eq '';

    }

    $self->{_ignore_copy_entry_change} = 1; 
    $dialog->get_widget('copy_minx_entry')->set_text($minx);
    $dialog->get_widget('copy_miny_entry')->set_text($miny);
    $dialog->get_widget('copy_maxx_entry')->set_text($maxx);
    $dialog->get_widget('copy_maxy_entry')->set_text($maxy);
    $dialog->get_widget('copy_cellsize_entry')->set_text($cellsize);
    $self->{_ignore_copy_entry_change} = 0;
    
    copy_info($self);

    return ($minx, $miny, $maxx, $maxy, $cellsize);

}

sub copy_info {
    my($self) = @_;
    my $dialog = $self->{copy_dialog};
    my $minx = get_number($dialog->get_widget('copy_minx_entry'));
    my $miny = get_number($dialog->get_widget('copy_miny_entry'));
    my $maxx = get_number($dialog->get_widget('copy_maxx_entry'));
    my $maxy = get_number($dialog->get_widget('copy_maxy_entry'));
    my $cellsize = get_number($dialog->get_widget('copy_cellsize_entry'));
    if ($minx eq '' or $miny eq '' or $maxx eq '' or $maxy eq '' or $cellsize eq '') { 
	$dialog->get_widget('copy_size_label')->set_text('?');
	$dialog->get_widget('copy_memory_size_label')->set_text('?');
    } else {
	my $M = int(($maxy - $miny)/$cellsize)+1;
	my $N = int(($maxx - $minx)/$cellsize)+1;
	my $datatype = $self->datatype || '';
	my $bytes =  $datatype eq 'Integer' ? 2 : 4; # should look this up from libral/GDAL
	my $size = $M*$N*$bytes;
	if ($size > 1024) {
	    $size = int($size/1024);
	    if ($size > 1024) {
		$size = int($size/1024);
		if ($size > 1024) {
		    $size = int($size/1024);
		    $size = "$size GiB";
		} else {
		    $size = "$size MiB";
		}
	    } else {
		$size = "$size KiB";
	    }
	} else {
	    $size = "$size B";
	}
	$dialog->get_widget('copy_size_label')->set_text("~${M} x ~${N}");
	$dialog->get_widget('copy_memory_size_label')->set_text($size);
    }
}

##@ignore
sub update_srs_labels {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{copy_dialog};
    my $from = $dialog->get_widget('from_EPSG_entry')->get_text;
    my $to = $dialog->get_widget('to_EPSG_entry')->get_text;

    unless (defined $EPSG{2000}) {
	my $dir = Geo::GDAL::GetConfigOption('GDAL_DATA');
	$dir = '/usr/local/share/gdal' unless $dir;

	#for my $f ("$dir/gcs.csv","$dir/gcs.override.csv","$dir/pcs.csv","$dir/pcs.override.csv") {
	for my $d ("gcs.csv","gcs.override.csv","pcs.csv","pcs.override.csv") {
	    my $f = Geo::GDAL::FindFile('gdal', $d);
	    if (open(EPSG, $f)) {
		while (<EPSG>) {
		    next unless /^\d/;
		    my @t = split/,/;
		    $t[1] =~ s/^"//;
		    $t[1] =~ s/"$//;
		    $EPSG{$t[0]} = $t[1];
		}
		close EPSG;
	    }
	}
    }

    $from = $EPSG{$from};
    $from = 'srs not found' unless $from;
    $to = $EPSG{$to};
    $to = 'srs not found' unless $to;

    $dialog->get_widget('from_srs_label')->set_text($from);
    $dialog->get_widget('to_srs_label')->set_text($to);
    $dialog->get_widget('copy_projection_checkbutton')->set_active(1);
}

sub open_vectorize_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{vectorize_dialog};
    unless ($dialog) {
	$self->{vectorize_dialog} = $dialog = $gui->get_dialog('vectorize_dialog');
	croak "vectorize_dialog for Geo::Raster does not exist" unless $dialog;
	$dialog->get_widget('vectorize_dialog')
	    ->signal_connect(delete_event => \&cancel_vectorize, [$self, $gui]);
	$dialog->get_widget('vectorize_datasource_button')->signal_connect
	    (clicked=>\&select_directory, [$self, $dialog->get_widget('vectorize_datasource_entry')]);
	$dialog->get_widget('vectorize_cancel_button')
	    ->signal_connect(clicked => \&cancel_vectorize, [$self, $gui]);
	$dialog->get_widget('vectorize_ok_button')
	    ->signal_connect(clicked => \&apply_vectorize, [$self, $gui, 1]);
    } elsif (!$dialog->get_widget('vectorize_dialog')->get('visible')) {
	$dialog->get_widget('vectorize_dialog')->move(@{$self->{vectorize_dialog_position}});
    }
    $dialog->get_widget('vectorize_dialog')->set_title("Create a vector layer from ".$self->name);
	
    my $combo = $dialog->get_widget('vectorize_driver_combobox');
    my $model = $combo->get_model;
    $model->clear;
    $model->set($model->append, 0, "");
    for my $driver (Geo::OGR::Drivers) {
	next unless $driver->TestCapability('CreateDataSource');
	$model->set($model->append, 0, $driver->GetName);
    }

    $dialog->get_widget('vectorize_name_entry')->set_text('vector');
    $dialog->get_widget('vectorize_datasource_entry')->set_text('.');

    $dialog->get_widget('vectorize_dialog')->show_all;
    $dialog->get_widget('vectorize_dialog')->present;
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

    $self->{vectorize_dialog_position} = [$dialog->get_widget('vectorize_dialog')->get_position];
    $dialog->get_widget('vectorize_dialog')->hide() if $close;
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

    
    my $dialog = $self->{vectorize_dialog}->get_widget('vectorize_dialog');
    $self->{vectorize_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}

sub select_directory {
    my $button = shift;
    my($self, $entry) = @{$_[0]};
    my $file_chooser =
	Gtk2::FileChooserDialog->new ("Select a folder",
				      undef, 'select_folder',
				      'gtk-cancel' => 'cancel',
				      'gtk-ok' => 'ok');
    $file_chooser->set_current_folder($dialog_folder) if $dialog_folder;
    my $uri;
    if ($file_chooser->run eq 'ok') {
	$dialog_folder = $file_chooser->get_current_folder();
	$uri = $file_chooser->get_uri;
	#print "$uri\n";
	#print "$dialog_folder\n";
	$uri =~ s/^file:\/\///;
	$uri =~ s/^\/// if $uri =~ /^\/\w:/; # hack for windows
	$entry->set_text($uri);
    }

    $file_chooser->destroy;
}

##@ignore
sub get_number {
    my($entry) = @_;
    my $text = $entry->get_text;
    $text =~ s/\s//g;
    $text =~ s/,/./;
    $text;
}

1;
