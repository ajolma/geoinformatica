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
use Gtk2::Ex::Geo;

our @ISA = qw(Gtk2::Ex::Geo::Layer);

our $VERSION = 0.01;

use vars qw/$NODE_RAY/;

$NODE_RAY = 7;

sub registration {
    my $dialogs;
    my $commands = {
	new => {
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
    my $self = Gtk2::Ex::Geo::Layer->new(%params);
    $self->{graph} = Graph->new;
    return bless $self => $package;
}

sub world {
    return (0, 0, 100, 100);
}

sub render {
    my($self, $pb, $cr, $overlay, $viewport) = @_;

    my $a = $self->alpha/255.0;
    my @color = $self->single_color;
    for (@color) {
	$_ /= 255.0;
	$_ *= $a;
    }

    $cr->set_line_width(1);
    $cr->set_source_rgba(@color);
    
    for my $v ($self->{graph}->vertices) {
	my @p = $overlay->point2surface($v->{point}->{X}, $v->{point}->{Y});
	for (@p) {
	    $_ = bounds($_, -10000, 10000);
	}
	$cr->arc(@p, $NODE_RAY, 0, 2*3.1415927);
	$cr->stroke;
    }
    for my $e ($self->{graph}->edges) {
	my($u, $v) = @$e;
	my @p = $overlay->point2surface($u->{point}->{X}, $u->{point}->{Y});
	my @q = $overlay->point2surface($v->{point}->{X}, $v->{point}->{Y});
	for (@p, @q) {
	    $_ = bounds($_, -10000, 10000);
	}
	$cr->move_to(@p);
	$cr->line_to(@q);
	$cr->stroke;
    }
    
}

sub bounds {
    $_[0] < $_[1] ? $_[1] : ($_[0] > $_[2] ? $_[2] : $_[0]);
}

sub got_focus {
    my($self, $gui) = @_;
    $self->{_tag1} = $gui->{overlay}->signal_connect(drawing_changed => \&drawing_changed, [$self, $gui]);
    $self->{_tag2} = $gui->{overlay}->signal_connect(new_selection => \&new_selection, [$self, $gui]);
    $gui->{overlay}->{rubberband_mode} = 'draw';
    $gui->{overlay}->{rubberband_geometry} = 'line';
}
sub lost_focus {
    my($self, $gui) = @_;
    $gui->{overlay}->signal_handler_disconnect($self->{_tag1}) if $self->{_tag1};
    $gui->{overlay}->signal_handler_disconnect($self->{_tag2}) if $self->{_tag2};
}

sub drawing_changed {
    my($self, $gui) = @{$_[1]};
    my $drawing = $gui->{overlay}->{drawing};
    if ($drawing->isa('Geo::OGC::LineString') and $drawing->NumPoints == 2) {
	my $v1 = $self->find_vertex($gui, $drawing->StartPoint);
	my $v2 = $self->find_vertex($gui, $drawing->EndPoint);
	unless ($v1) {
	    $v1 = { point => $drawing->StartPoint->Clone };
	    $self->{graph}->add_vertex($v1);
	}
	unless ($v2) {
	    $v2 = { point => $drawing->EndPoint->Clone };
	    $self->{graph}->add_vertex($v2);
	}
	$self->{graph}->add_edge($v1, $v2);
    }
    delete $gui->{overlay}->{drawing};
    $gui->{overlay}->render;
}

sub find_vertex {
    my($self, $gui, $point) = @_;
    my $d = -1;
    my $c;
    for my $v ($self->{graph}->vertices) {
	my $e = $point->Distance($v->{point});
	($c, $d) = ($v, $e) if $d < 0 or $e < $d;
    }
    return $c if $d/$gui->{overlay}->{pixel_size} < $NODE_RAY;
}

sub new_selection {
    my($self, $gui) = @{$_[1]};
    my $selection = $gui->{overlay}->{selection};
    delete $gui->{overlay}->{selection};
    $gui->{overlay}->render;
}

sub open_properties_dialog {
    my($self, $gui) = @_;
}

1;
