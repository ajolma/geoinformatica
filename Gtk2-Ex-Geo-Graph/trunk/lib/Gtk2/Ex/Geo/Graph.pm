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
    $self->{index} = 1;
    return bless $self => $package;
}

sub save {
    my($self, $filename) = @_;
    open(my $fh, '>', $filename) or croak $!;
    for my $v ($self->{graph}->vertices) {
	print $fh "$v->{index}\t$v->{point}->{X}\t$v->{point}->{Y}\n";
    }
    print $fh "edges\n";
    for my $e ($self->{graph}->edges) {
	my($u, $v) = @$e;
	my $w = $self->{graph}->get_edge_weight($u, $v);
	print $fh "$u->{index}\t$v->{index}\t$w\n";
    }
    close $fh;
}

sub open {
    my($self, $filename) = @_;
    open(my $fh, '<', $filename) or croak $!;
    $self->{graph} = Graph->new;
    my $vertex = 1;
    my %vertices;
    while (<$fh>) {
	chomp;
	my @l = split /\t/;
	$vertex = 0, next if $l[0] eq 'edges';
	print STDERR "$vertex, @l\n";
	if ($vertex) {
	    my $v = { index => $l[0],
		      point => Geo::OGC::Point->new($l[1], $l[2]) };
	    $vertices{$l[0]} = $v;
	    $self->{graph}->add_vertex($v);
	} else {
	    my $u = $vertices{$l[0]};
	    my $v = $vertices{$l[1]};
	    $self->{graph}->add_weighted_edge($u, $v, $l[2]);
	}
    }
    close $fh;
}

sub world {
    my $self = shift;
    my($minx, $miny, $maxx, $maxy);
    for my $v ($self->{graph}->vertices) {
	unless (defined $minx) {
	    $maxx = $minx = $v->{point}->{X};
	    $maxy = $miny = $v->{point}->{Y};
	} else {
	    $minx = min($minx, $v->{point}->{X});
	    $miny = min($miny, $v->{point}->{Y});
	    $maxx = max($maxx, $v->{point}->{X});
	    $maxy = max($maxy, $v->{point}->{Y});
	}
    }
    return ($minx, $miny, $maxx, $maxy) if defined $minx;
    return ();
}

sub render {
    my($self, $pb, $cr, $overlay, $viewport) = @_;

    my @s = @{$self->selected_features()};
    my %selected = map { (ref($_) eq 'HASH' ? $_ : $_->[0].$_->[1] ) => 1 } @s;

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
	$cr->fill_preserve if $selected{$v};
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
	$cr->set_line_width(3) if $selected{$u.$v};
	$cr->stroke;
	$cr->set_line_width(1) if $selected{$u.$v};
    }
    
}

sub bounds {
    $_[0] < $_[1] ? $_[1] : ($_[0] > $_[2] ? $_[2] : $_[0]);
}

sub got_focus {
    my($self, $gui) = @_;
    my $o = $gui->{overlay};
    $self->{_tag1} = $o->signal_connect(
	drawing_changed => \&drawing_changed, [$self, $gui]);
    $self->{_tag2} = $o->signal_connect(
	new_selection => \&new_selection, [$self, $gui]);
    $self->{_tag3} = $o->signal_connect(
	key_press_event => \&key_pressed, [$self, $gui]);
    $o->{rubberband_mode} = 'draw';
    $o->{rubberband_geometry} = 'line';
    $o->{show_selection} = 0;
}
sub lost_focus {
    my($self, $gui) = @_;
    $gui->{overlay}->signal_handler_disconnect($self->{_tag1}) if $self->{_tag1};
    $gui->{overlay}->signal_handler_disconnect($self->{_tag2}) if $self->{_tag2};
    $gui->{overlay}->signal_handler_disconnect($self->{_tag3}) if $self->{_tag3};
}

sub drawing_changed {
    my($self, $gui) = @{$_[1]};
    my $drawing = $gui->{overlay}->{drawing};
    if ($drawing->isa('Geo::OGC::LineString') and $drawing->NumPoints == 2) {
	my $v1 = $self->find_vertex($gui, $drawing->StartPoint);
	my $v2 = $self->find_vertex($gui, $drawing->EndPoint);
	unless ($v1) {
	    $v1 = { point => $drawing->StartPoint->Clone };
	    $v1->{index} = $self->{index}++;
	    $self->{graph}->add_vertex($v1);
	}
	unless ($v2) {
	    $v2 = { point => $drawing->EndPoint->Clone };
	    $v2->{index} = $self->{index}++;
	    $self->{graph}->add_vertex($v2);
	}
	my $w = $drawing->Length;
	$self->{graph}->add_weighted_edge($v1, $v2, $w);
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

sub find_edge {
    my($self, $gui, $point) = @_;
    my $d = -1;
    my $c;
    for my $e ($self->{graph}->edges) {
	my $e2 = Geo::OGC::LineString->new;
	$e2->AddPoint($e->[0]->{point});
	$e2->AddPoint($e->[1]->{point});
	my $d2 = $point->Distance($e2);
	($c, $d) = ($e, $d2) if $d < 0 or $d2 < $d;
    }
    return $c if $d/$gui->{overlay}->{pixel_size} < $NODE_RAY;
}

sub new_selection {
    my($self, $gui) = @{$_[1]};
    my $selection = $gui->{overlay}->{selection};
    $self->select();
    $self->_select($gui, $selection);
    $gui->{overlay}->render;
}

sub _select {
    my($self, $gui, $selection) = @_;
    if ($selection->isa('Geo::OGC::GeometryCollection')) {
	for my $g (@{$selection->{Geometries}}) {
	    $self->_select($gui, $g);
	}
    } elsif ($selection->isa('Geo::OGC::Point')) {
	my $v = $self->find_vertex($gui, $selection);
	push @{$self->selected_features}, $v if $v;
	unless ($v) {
	    my $e = $self->find_edge($gui, $selection);
	    push @{$self->selected_features}, $e if $e;
	}
    }
}

sub key_pressed {
    my($overlay, $event, $user) = @_;
    my $key = $event->keyval;
    return unless $key == $Gtk2::Gdk::Keysyms{Delete};
    my($self, $gui) = @{$user};
    my @v;
    my @e;
    for my $v (@{$self->selected_features()}) {
	if (ref $v eq 'HASH') {
	    push @v, $v;
	} else {
	    push @e, ($v->[0], $v->[1]);
	}
    }
    $self->{graph}->delete_vertices(@v);
    $self->{graph}->delete_edges(@e);
    $self->select();
    $gui->{overlay}->render;
}

sub open_properties_dialog {
    my($self, $gui) = @_;
}

sub shortest_path {
    my($self) = @_;
    my($u, $v);
    for my $x (@{$self->selected_features()}) {
	next unless ref $x eq 'HASH';
	$u = $x,next unless $u;
	$v = $x unless $v;
	last;
    }
    $self->select();
    return unless $u and $v;
    print STDERR "sp $u->$v\n";
    my @path = $self->{graph}->SP_Dijkstra($u, $v);
    print STDERR "sp @path\n";
    $self->selected_features(\@path);
    #$gui->{overlay}->render;
}

## @ignore
sub min {
    $_[0] > $_[1] ? $_[1] : $_[0];
}

## @ignore
sub max {
    $_[0] > $_[1] ? $_[0] : $_[1];
}

1;
