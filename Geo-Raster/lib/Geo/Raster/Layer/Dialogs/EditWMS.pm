package Geo::Raster::Layer::Dialogs::EditWMS;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw/:all/;
use Geo::Raster::Layer;
use WWW::Curl::Easy;

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

    # todo: need only HEAD, not GET
    my $curl = WWW::Curl::Easy->new;
    $curl->setopt($curl->CURLOPT_HEADER, 1);
    if ($username) {
	# http(s)://username:password@domain.ext
	my($protocol) = $url =~ /^(https?:\/\/)/;
	$url =~ s/^(https?:\/\/)//;
	$url = $protocol.$username.':'.$password.'@'.$url;
    }
    $curl->setopt($curl->CURLOPT_URL, $url);
    my $msg;
    $curl->setopt($curl->CURLOPT_WRITEDATA, \$msg);
    my $retcode = $curl->perform;
    
    if ($retcode == 0) {
	my %defs = ( 
	    200 => 'OK',
	    301 => 'Moved Permanently',
	    400 => 'Bad Request',
	    401 => 'Unauthorized',
	    402 => 'Payment Required',
	    403 => 'Forbidden',
	    404 => 'Not Found',
	    500 => 'Internal Server Error',
	    501 => 'Not Implemented',
	    503 => 'Service Unavailable',
	    505 => 'HTTP Version Not Supported'
	    );
	$msg = $defs{$curl->getinfo($curl->CURLINFO_HTTP_CODE)};
    } else {
	$msg = "Error in transfer: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n";
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
