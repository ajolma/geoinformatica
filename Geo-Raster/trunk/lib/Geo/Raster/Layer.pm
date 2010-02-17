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
use Glib;
use Gtk2;

use vars qw/$dialog_folder/;

require Exporter;

our @ISA = qw(Exporter Geo::Raster Gtk2::Ex::Geo::Layer);
our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );
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
    $items->{'C_lip...'} =
    {
	nr => 12,
	sub => sub {
	    my($self, $gui) = @{$_[1]};
	    $self->open_clip_dialog($gui);
	}
    } if $self->{GDAL};
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

sub open_clip_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{clip_dialog};
    unless ($dialog) {
	$self->{clip_dialog} = $dialog = $gui->get_dialog('clip_dialog');
	croak "clip_dialog for Geo::Raster does not exist" unless $dialog;
	$dialog->get_widget('clip_to_raster_combobox')->signal_connect(changed=>\&clip_to_raster_selected, [$self, $gui]);
	$dialog->get_widget('clip_dialog')->signal_connect(delete_event => \&cancel_clip, [$self, $gui]);
	$dialog->get_widget('clip_compute_button')->signal_connect(clicked => sub {$self->cache_dim});
	$dialog->get_widget('clip_cancel_button')->signal_connect(clicked => \&cancel_clip, [$self, $gui]);
	$dialog->get_widget('clip_ok_button')->signal_connect(clicked => \&apply_clip, [$self, $gui, 1]);
    } elsif (!$dialog->get_widget('clip_dialog')->get('visible')) {
	$dialog->get_widget('clip_dialog')->move(@{$self->{clip_dialog_position}});
    }
    $dialog->get_widget('clip_dialog')->set_title("Create a libral raster from ".$self->name);
	
    my $combo = $dialog->get_widget('clip_to_raster_combobox');
    my $model = $combo->get_model;
    $model->clear;
    $model->set($model->append, 0, '<Current view>');
    $model->set($model->append, 0, '<self>');
    for my $layer (@{$gui->{overlay}->{layers}}) {
	next unless isa($layer, 'Geo::Raster');
	$model->set($model->append, 0, $layer->name());
    }
    $combo->set_active(0);

    clip_to_raster_selected($combo, [$self, $gui]);

    $dialog->get_widget('clip_name_entry')->set_text('gd');

    my @dim = $gui->{overlay}->get_viewport_of_selection;
    @dim = $gui->{overlay}->get_viewport unless @dim;
    push @dim, $self->cell_size( of_GDAL => 1 );
    
    $self->cache_dim(@dim);

    $dialog->get_widget('clip_dialog')->show_all;
    $dialog->get_widget('clip_dialog')->present;
    return $dialog->get_widget('clip_dialog');
}

##@ignore
sub apply_clip {
    my($self, $gui, $close) = @{$_[1]};
    my $dialog = $self->{clip_dialog};

    my $combo = $dialog->get_widget('clip_to_raster_combobox');
    my $model = $combo->get_model;
    my $iter = $combo->get_active_iter;
    my $clip_to = $model->get($iter);
	
    my $new_layer;
	
    if ($clip_to eq '<Current view>') {
	my @dim = $self->cache_dim();
	$new_layer = $self->cache(@dim);
    } elsif ($clip_to eq '<self>') {
	$self->cache();
	delete $self->{GDAL};
    } else {
	my $layer = $gui->{overlay}->get_layer_by_name($clip_to);
	$new_layer = $self->clip_to($layer);  
    }
 
    my $name = $dialog->get_widget('clip_name_entry')->get_text();
    $gui->add_layer($new_layer, $name, 1) unless $name eq '<self>';
    $gui->set_layer($self);

    $self->{clip_dialog_position} = [$dialog->get_widget('clip_dialog')->get_position];
    $dialog->get_widget('clip_dialog')->hide() if $close;
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

##@ignore
sub cancel_clip {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }

    
    my $dialog = $self->{clip_dialog}->get_widget('clip_dialog');
    $self->{clip_dialog_position} = [$dialog->get_position];
    $dialog->hide();
    $gui->set_layer($self);
    $gui->{overlay}->render;
    1;
}


sub clip_to_raster_selected {
    my $combo = $_[0];
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{clip_dialog};
    my $a = $combo->get_active();
    if ($a <= 0) {
	$dialog->get_widget('clip_minx_entry')->set_sensitive(1);
	$dialog->get_widget('clip_miny_entry')->set_sensitive(1);
	$dialog->get_widget('clip_maxx_entry')->set_sensitive(1);
	$dialog->get_widget('clip_maxy_entry')->set_sensitive(1);
	$dialog->get_widget('clip_name_entry')->set_sensitive(1);
    } else {
	$dialog->get_widget('clip_minx_entry')->set_sensitive(0);
	$dialog->get_widget('clip_miny_entry')->set_sensitive(0);
	$dialog->get_widget('clip_maxx_entry')->set_sensitive(0);
	$dialog->get_widget('clip_maxy_entry')->set_sensitive(0);
	my $m = $combo->get_model;
	my $n = $m->get($combo->get_active_iter);
	my $layer;
	my @dim;
	my $cell_size;
	if ($n eq '<self>') {
	    $dialog->get_widget('clip_name_entry')->set_sensitive(0);
	    $dialog->get_widget('clip_name_entry')->set_text($self->name());
	    @dim = $self->world(of_GDAL=>1);
	    $cell_size = $self->cell_size(of_GDAL=>1);
	} else {
	    $layer = $gui->{overlay}->get_layer_by_name($n);
	    @dim = $layer->world;
	    $cell_size = $layer->cell_size;
	}
	$self->cache_dim(@dim, $cell_size);
    }
}

sub cache_dim {
    my $self = shift;

    my $dialog = $self->{clip_dialog};

    my($minx, $miny, $maxx, $maxy, $cellsize);

    if (@_) {

	($minx, $miny, $maxx, $maxy, $cellsize) = @_;

	$dialog->get_widget('clip_minx_entry')->set_text($minx);
	$dialog->get_widget('clip_miny_entry')->set_text($miny);
	$dialog->get_widget('clip_maxx_entry')->set_text($maxx);
	$dialog->get_widget('clip_maxy_entry')->set_text($maxy);
	$dialog->get_widget('clip_cellsize_label')->set_text($cellsize);

    } else {

	$minx = get_number($dialog->get_widget('clip_minx_entry'));
	$miny = get_number($dialog->get_widget('clip_miny_entry'));
	$maxx = get_number($dialog->get_widget('clip_maxx_entry'));
	$maxy = get_number($dialog->get_widget('clip_maxy_entry'));
	$cellsize = get_number($dialog->get_widget('clip_cellsize_label'));
    }

    my $M = int(($maxy - $miny)/$cellsize)+1;
    my $N = int(($maxx - $minx)/$cellsize)+1;
    my $datatype = $self->datatype || '';
    my $bytes =  $datatype eq 'Integer' ? 2 : 4; # should look this up from libral/GDAL
    my $size = $M*$N*$bytes;
    if ($size > 1024) {
	$size = int($size/1024);
	if ($size > 1024) {
	    $size = int($size/1024);
	    $size = "$size MiB";
	} else {
	    $size = "$size KiB";
	}
    } else {
	$size = "$size B";
    }

    $dialog->get_widget('clip_info_label')->set_text("The size of the (~${M}x~${N}) libral raster will be $size.");

    return ($minx, $miny, $maxx, $maxy, $cellsize);

}

sub open_vectorize_dialog {
    my($self, $gui) = @_;

    # bootstrap:
    my $dialog = $self->{vectorize_dialog};
    unless ($dialog) {
	$self->{vectorize_dialog} = $dialog = $gui->get_dialog('vectorize_dialog');
	croak "vectorize_dialog for Geo::Raster does not exist" unless $dialog;
	$dialog->get_widget('vectorize_dialog')->signal_connect(delete_event => \&cancel_vectorize, [$self, $gui]);
	$dialog->get_widget('vectorize_datasource_button')->signal_connect
	    (clicked=>\&select_directory, [$self, $dialog->get_widget('vectorize_datasource_entry')]);
	$dialog->get_widget('vectorize_cancel_button')->signal_connect(clicked => \&cancel_vectorize, [$self, $gui]);
	$dialog->get_widget('vectorize_ok_button')->signal_connect(clicked => \&apply_vectorize, [$self, $gui, 1]);
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
