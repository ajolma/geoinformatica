package Geo::Raster::Layer::Dialogs::WMS;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw/:all/;
use Geo::Raster::Layer;

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
	);
    
    if ($boot) {
    }

}

##@ignore
sub connect {
    my $self = pop;
}

##@ignore
sub new {
    my $self = pop;
}

##@ignore
sub edit {
    my $self = pop;
}

##@ignore
sub delete {
    my $self = pop;
}

##@ignore
sub cancel {
    my $self = pop;
    $self->{WMS_dialog}->get_widget('WMS_dialog')->destroy;
}

##@ignore
sub apply {
    my $self = pop;
}

##@ignore
sub ok {
    my $self = pop;
    my $dialog = $self->{WMS_dialog};
    $dialog->get_widget('WMS_dialog')->destroy;
}

1;
