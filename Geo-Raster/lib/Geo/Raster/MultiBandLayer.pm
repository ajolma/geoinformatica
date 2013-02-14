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
    for my $band (1..$bands) {
	my $layer = Geo::Raster::Layer->new(dataset => $dataset, filename => $filename, band => $band);
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
