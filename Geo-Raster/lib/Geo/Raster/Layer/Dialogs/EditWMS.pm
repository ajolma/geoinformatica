package Geo::Raster::Layer::Dialogs::EditWMS;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw/:all/;
use Geo::Raster::Layer;
use LWP::UserAgent;

## @ignore
sub open {
    my($gui, $title) = @_;
    my $self = { gui => $gui };

    # bootstrap:
    my($dialog, $boot) = Gtk2::Ex::Geo::Layer::bootstrap_dialog
	($self, $gui, 'WMS_edit_dialog', $title,
	 {
	     WMS_edit_test_connection_button => [clicked => \&test_connection, $self],
	 },
	);
    
    if ($boot) {
    }

    return $dialog;
}

##@ignore
sub test_connection {
    my $self = pop;
    my $dialog = $self->{WMS_edit_dialog};
    my $url = $dialog->get_widget('WMS_edit_URL_entry')->get_text();
    my $username = $dialog->get_widget('WMS_edit_username_entry')->get_text();
    my $password = $dialog->get_widget('WMS_edit_password_entry')->get_text();
    
    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(GET => $url);
    $req->authorization_basic($username, $password) if $username;
    my $res = $ua->request($req);
    my $msg;
    if ($res->is_success) {
	$msg = "The connection seems fine.";
    } else {
	$msg = $res->status_line;
    }
    my $msgbox = Gtk2::MessageDialog->new(undef,
					  'destroy-with-parent',
					  'info',
					  'close',
					  $msg);
    $msgbox->run;
    $msgbox->destroy;
}

1;
