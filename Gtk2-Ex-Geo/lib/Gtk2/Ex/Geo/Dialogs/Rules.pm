package Gtk2::Ex::Geo::Dialogs::Rules;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw /:all/;
use Gtk2::Ex::Geo::Layer;

use vars qw//;

# rules dialog

sub open {
    my($self, $gui) = @_;

    my($dialog, $boot) = $self->bootstrap_dialog
	($gui, 'rules_dialog', "Rules for ".$self->name,
	 {
	     rules_add_button => [clicked => \&add_rule, [$self, $gui]],
	     rules_delete_button => [clicked => \&delete_rule, [$self, $gui]],
	 },
	 [qw //]
	);
    if ($boot) {
    }

    # back up data
    return $dialog->get_widget('rules_dialog');
}


1;
