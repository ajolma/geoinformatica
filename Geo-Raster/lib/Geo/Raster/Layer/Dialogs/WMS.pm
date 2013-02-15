package Geo::Raster::Layer::Dialogs::WMS;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw/:all/;
use Geo::Raster::Layer;

## @ignore
# WMS dialog
sub open {
    my($gui) = @_;
    my $self = { gui => $gui };

    # bootstrap:
    my($dialog, $boot) = Gtk2::Ex::Geo::Layer::bootstrap_dialog
	($self, $gui, 'WMS_dialog', "Open from a WMS",
	 {
             WMS_open_dialog => [delete_event => \&cancel, $self],
	     WMS_open_connect_button => [clicked => \&connect, $self],
	     WMS_open_new_button => [clicked => \&new, $self],
	     WMS_open_edit_button => [clicked => \&edit, $self],
	     WMS_open_delete_button => [clicked => \&delete, $self],
	     WMS_open_apply_button => [clicked => \&apply, $self],
	     WMS_open_cancel_button => [clicked => \&cancel, $self],
	     WMS_open_ok_button => [clicked => \&ok, $self],
	 },
	);
    
    if ($boot) {
    }

}

1;
