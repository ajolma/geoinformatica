package Gtk2::Ex::Geo::Graph;

=pod

=head1 NAME

Gtk2::Ex::Geo::Graph - Geospatial graphs for Gtk2::Ex::Geo

=cut

use strict;
use warnings;
use Carp;
use Graph;
use Glib qw/TRUE FALSE/;
use Gtk2;

our @ISA = qw(Exporter Gtk2::Ex::Geo::Layer);

our $VERSION = 0.01;

sub registration {
    my $dialogs;
    my $commands = {
	new => {
	    nr => 1,
	    text => 'New graph',
	    tip => 'Create a new graph',
	    pos => 0,
	    sub => sub {
		my(undef, $gui) = @_;
		my $layer = Gtk2::Ex::Geo::Graph->new( name => 'graph' );
		$gui->add_layer($layer);
	    }
	}
    };
    return { dialogs => $dialogs, commands => $commands };
}

sub new {
    my($package, %params) = @_;
    my $self = { Graph => Graph::new($package) };
    Gtk2::Ex::Geo::Layer::new($package, self => $self, %params);
    return $self;
}

sub world {
    return (0, 0, 100, 100);
}

sub render {
    my($self, $pb, $cr, $overlay, $viewport) = @_;
}

sub open_properties_dialog {
    my($self, $gui) = @_;
}

1;
