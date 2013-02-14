package Geo::Raster::MultiBandLayer;
# @brief A subclass of Gtk2::Ex::Geo::Layer, which constains several Geo::Raster objects
#
# These methods are not documented. For documentation, look at
# Gtk2::Ex::Geo::Layer.

=pod

=head1 NAME

Geo::Raster::MultiBandLayer - A geospatial raster layer class for Gtk2::Ex::Geo

=cut

use strict;
use warnings;
use POSIX;
POSIX::setlocale( &POSIX::LC_NUMERIC, "C" ); # http://www.remotesensing.org/gdal/faq.html nr. 11
use Carp;
use Scalar::Util 'blessed';
use File::Basename; # for fileparse
use File::Spec;
use Glib qw/TRUE FALSE/;
use Gtk2;
use Gtk2::Ex::Geo::Layer qw /:all/;
use Gtk2::Ex::Geo::Dialogs qw /:all/;
use Geo::Raster::Layer::Dialogs;
use Geo::Raster::Layer::Dialogs::Copy;
use Geo::Raster::Layer::Dialogs::Polygonize;
use Geo::Raster::Layer::Dialogs::Properties::GDAL;
use Geo::Raster::Layer::Dialogs::Properties::libral;

require Exporter;

our @ISA = qw(Exporter Gtk2::Ex::Geo::Layer);
our %EXPORT_TAGS = ( 'all' => [ ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = 0.01;

## @ignore
sub new {
    my($package, %params) = @_;
    my $self = Gtk2::Ex::Geo::Layer::new($package, %params);
    my $dataset = $params{dataset};
    my $filename = $params{filename};
    my $bands = $dataset->{RasterCount};
    for my $band (1..$bands) {
	my $layer = Geo::Raster::Layer->new(dataset => $dataset, 
                                            filename => $filename, 
                                            band => $band, 
                                            name => $params{name}.' (Band '.$band.')');
        push @{$self->{layers}}, $layer;
    }
    return $self;
}

## @ignore
sub DESTROY {
    my $self = shift;
    return unless $self;
    Gtk2::Ex::Geo::Layer::DESTROY($self);
}

## @ignore
sub defaults {
    my($self, %params) = @_;
    # set inherited from params:
    $self->SUPER::defaults(%params);
}

## @ignore
sub type {
    my($self, $param) = @_;
    return ($param and $param eq 'long') ? 'Multiband raster' : 'M';
}

## @ignore
sub alpha {
    my($self, $alpha) = @_;
    if (defined $alpha) {
        for my $layer (@{$self->{layers}}) {
            $layer->alpha($alpha);
        }
    } else {
        return $self->{layers}[0]->alpha();
    }
}

## @ignore
sub menu_items {
    my($self) = @_;
    my @symbol_submenus;
    my @colors_submenus;
    my @labeling_submenus;
    my @properties_submenus;
    for my $i (0..$#{$self->{layers}}) {
        my $item = 'Band '.($i+1);
        push @symbol_submenus, $item;
        push @symbol_submenus, sub {
	    my($self, $gui) = @{$_[1]};
	    $self->{layers}[$i]->open_symbols_dialog($gui);
	};
        push @colors_submenus, $item;
        push @colors_submenus, sub {
	    my($self, $gui) = @{$_[1]};
	    $self->{layers}[$i]->open_colors_dialog($gui);
	};
        push @labeling_submenus, $item;
        push @labeling_submenus, sub {
	    my($self, $gui) = @{$_[1]};
	    $self->{layers}[$i]->open_labeling_dialog($gui);
	};
        push @properties_submenus, $item;
        push @properties_submenus, sub {
	    my($self, $gui) = @{$_[1]};
	    $self->{layers}[$i]->open_properties_dialog($gui);
	};
    }
    my @items;
    push @items, (
	'_Unselect all' => sub {
	    my($self, $gui) = @{$_[1]};
	    $self->select;
	    $gui->{overlay}->update_image;
	    $self->open_features_dialog($gui, 1);
	},
	'_Symbol...' => \@symbol_submenus,
	'_Colors...' => \@colors_submenus,
	'_Labeling...' => \@labeling_submenus,
	'_Inspect...' => sub {
	    my($self, $gui) = @{$_[1]};
	    $gui->inspect($self->inspect_data, $self->name);
	},
	'_Properties...' => \@properties_submenus
    );
    return @items;
}

## @ignore
sub world {
    my $self = shift;
    my @bb; # ($min_x, $min_y, $max_x, $max_y);
    for my $layer (@{$self->{layers}}) {
        unless (@bb) {
            @bb = $layer->world;
        } else {
            my @tmp = $layer->world;
            $bb[0] = $tmp[0] if $tmp[0] < $bb[0];
            $bb[1] = $tmp[1] if $tmp[1] < $bb[1];
            $bb[2] = $tmp[2] if $tmp[2] > $bb[2];
            $bb[3] = $tmp[3] if $tmp[3] > $bb[3];
        }
    }
    return @bb;
}

## @ignore
sub render {
    my($self, $pb) = @_;

    return if !$self->visible();
    
    for my $layer (@{$self->{layers}}) {
        $layer->render($pb);
    }
}

1;
