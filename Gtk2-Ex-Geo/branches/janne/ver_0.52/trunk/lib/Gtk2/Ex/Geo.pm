package Gtk2::Ex::Geo;

use 5.005000;
use strict;
use warnings;
use POSIX;
POSIX::setlocale( &POSIX::LC_NUMERIC, "C" ); # http://www.remotesensing.org/gdal/faq.html nr. 11

use Glib qw/TRUE FALSE/;
use Gtk2::Gdk::Keysyms;

# known layer types:
use Geo::Layer qw/:all/;

use Geo::Raster;
use Geo::Vector;

use Gtk2::GladeXML;
use Gtk2::Ex::Geo::DialogMaster;

use Gtk2::Ex::Geo::Renderer;
use Gtk2::Ex::Geo::Overlay;
use Gtk2::Ex::Geo::Glue;

use Gtk2::Ex::Geo::GDALDialog;
use Gtk2::Ex::Geo::OGRDialog;

use Gtk2::Ex::Geo::Layer;
use Gtk2::Ex::Geo::Raster;
use Gtk2::Ex::Geo::Vector;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.50';

1;
__END__

=head1 NAME

Gtk2::Ex::Geo - Perl Gtk2 widgets for GIS

=head1 SYNOPSIS

# the order of these is important:
use Gtk2::Ex::Geo;
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';

my $gis = Gtk2::Ex::Geo::Glue->new( history=>[''] );

$gis->set_event_handler( \&info );
$gis->{overlay}->{rubberbanding} = 'zoom rect';

# the widgets already created and in $gis 
# have to be declared as Custom widgets
# they are installed through this custom_handler

sub get_custom_widget {
    my $name = $_[2];
    if ($name eq 'layer_widget') {
	return $gis->{tree_view};
    } elsif ($name eq 'map_widget') {
	return $gis->{overlay};
    }
}

Gtk2::Glade->set_custom_handler(\&get_custom_widget);

$glade = Gtk2::GladeXML->new("gui.glade");
$glade->signal_autoconnect_from_package('main');

$glade->get_widget('map_widget')->show_all;
$glade->get_widget('layer_widget')->show;

Gtk2->main;

=head1 LAYERS

What is expected of a layer by Gtk2::Ex::Geo?

=head2 Properties

=over

=item name 

string (Gtk2::Ex::Geo takes care)

=item hidden 

boolean (Gtk2::Ex::Geo takes care)

=item alpha 

0..255 (Gtk2::Ex::Geo takes care)

=item ogr_layer 

(for dialogs, todo: change to simple layer)

=item iterator 

(Gtk2::Ex::Geo takes care)

=back

=head2 Methods

=over

=item world(1) 

returns (minX,minY,maxX,maxY)

todo: context menu returns an array

=item nodata_value(nodata_value) 

set or get

=item rasterize() 

(context menu command)


=item cache() 

(context menu command)

=back

todo: type_for_user (for the GUI)
todo: alpha_for_user (for the GUI)

=head1 SEE ALSO

=over

=item Gtk2::Ex::Geo::Glue 

Module for glueing widgets into a GIS.

=item Gtk2::Ex::Geo::Overlay 

A Gtk2 widget for a visual overlay of geospatial data.

=item Gtk2::Ex::Geo::Renderer

A Gtk2::Gdk::Pixbuf made from spatial data

=item Geo::Raster

Perl extension for raster algebra

=item Geo::Vector

Perl extension for geospatial vectors

=item Gtk2::Ex::Geo::Composite

A set of geospatial layers visualized together

=item Gtk2::Ex::Geo::TemporalRaster

A raster timeseries 

=item Gtk2::Ex::Geo::GDALDialog

Dialogs for raster (gdal) layers

=item Gtk2::Ex::Geo::OGRDialog

Dialogs for vector (ogr) layers

=back

This module should be discussed in geo-perl@list.hut.fi.

The homepage of this module is http://libral.sf.net.

=head1 AUTHOR

Ari Jolma, E<lt>ari.jolma _at_ tkk.fiE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
