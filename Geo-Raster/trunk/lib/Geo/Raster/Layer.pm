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
use Glib qw/TRUE FALSE/;
use Gtk2;
use Gtk2::Ex::Geo::Layer qw /:all/;
use Geo::Raster::Layer::Dialogs;
use Geo::Raster::Layer::Dialogs::Copy;
use Geo::Raster::Layer::Dialogs::Vectorize;
use Geo::Raster::Layer::Dialogs::Properties::GDAL;
use Geo::Raster::Layer::Dialogs::Properties::libral;

require Exporter;

our @ISA = qw(Exporter Geo::Raster Gtk2::Ex::Geo::Layer);
our %EXPORT_TAGS = ( 'all' => [ qw( %EPSG ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = 0.03;

use vars qw/%EPSG/;

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

		my $uri = file_chooser('Save all rasters into folder', 'select_folder');
		
		if ($uri) {
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
    if (isa($object, 'Geo::Raster') and !isa($object, 'Geo::Raster::Layer')) {
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

sub DESTROY {
    my $self = shift;
    return unless $self;
    Geo::Raster::DESTROY($self);
    Gtk2::Ex::Geo::Layer::DESTROY($self);
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
    $self->color_field('Cell value');
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

sub open_properties_dialog {
    my($self, $gui) = @_;
    if ($self->{GDAL}) {
	Geo::Raster::Layer::Dialogs::Properties::GDAL::open($self, $gui);
    } else {
	Geo::Raster::Layer::Dialogs::Properties::libral::open($self, $gui);
    }
}

sub menu_items {
    my($self, $items) = @_;
    $items = $self->SUPER::menu_items($items);
    push @$items, ( 1 => 0 );
    push @$items, ( 'S_ave...' => sub {
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
	}}) unless $self->{GDAL};
    push @$items, ( 'C_opy...' => sub {
	my($self, $gui) = @{$_[1]};
	$self->open_copy_dialog($gui);
		    },
		    'V_ectorize...' => sub {
			my($self, $gui) = @{$_[1]};
			$self->open_vectorize_dialog($gui);
		    });
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

sub open_copy_dialog {
    Geo::Raster::Layer::Dialogs::Copy::open(@_);
}

sub open_vectorize_dialog {
    Geo::Raster::Layer::Dialogs::Vectorize::open(@_);
}

##@ignore
sub update_srs_labels {
    my($self, $gui) = @{$_[1]};
    my $dialog = $self->{copy_raster_dialog};
    my $from = $dialog->get_widget('from_EPSG_entry')->get_text;
    my $to = $dialog->get_widget('to_EPSG_entry')->get_text;

    unless (defined $EPSG{2000}) {
	my $dir = Geo::GDAL::GetConfigOption('GDAL_DATA');
	$dir = '/usr/local/share/gdal' unless $dir;

	#for my $f ("$dir/gcs.csv","$dir/gcs.override.csv","$dir/pcs.csv","$dir/pcs.override.csv") {
	for my $d ("gcs.csv","gcs.override.csv","pcs.csv","pcs.override.csv") {
	    my $f = Geo::GDAL::FindFile('gdal', $d);
	    if (CORE::open(EPSG, $f)) {
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

1;
