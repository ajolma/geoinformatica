package Gtk2::Ex::Geo::Overlay;

use strict;
use POSIX;
use Carp;
use Glib qw/TRUE FALSE/;

=pod

=head1 NAME

Gtk2::Ex::Geo::Overlay - A Gtk2 widget for a visual overlay of geospatial data

=head1 SYNOPSIS

my $overlay = Gtk2::Ex::Geo::Overlay->new;

$overlay->my_inits;

=head1 DESCRIPTION

Gtk2::Ex::Geo::Overlay is a subclass of Gtk2::ScrolledWindow

=head1 ATTRIBUTES

public:

bg_color = ($red, $green, $blue) # a color for the background for the overlay

rubberbanding = FALSE, /line/, /rect/, /ellipse/ 

private:

image
event_box
zoom_factor
step

=head1 METHODS

=cut

my %visual_keys = ($Gtk2::Gdk::Keysyms{plus}=>1,
		   $Gtk2::Gdk::Keysyms{minus}=>1,
		   $Gtk2::Gdk::Keysyms{Right}=>1,
		   $Gtk2::Gdk::Keysyms{Left}=>1,
		   $Gtk2::Gdk::Keysyms{Up}=>1,
		   $Gtk2::Gdk::Keysyms{Down}=>1);


use Glib::Object::Subclass
    Gtk2::ScrolledWindow::,
    signals => {
	features_selected => {},
	zoomed_in => {},
	extent_widened => {},
    },
    properties => 
    [
     Glib::ParamSpec->double 
     (
      'zoom_factor', 'Zoom factor', 
      'Zoom multiplier when user presses + or -',
      0.1, 1000, 1.2, [qw/readable writable/]
      ),
     Glib::ParamSpec->double 
     (
      'step', 'Step', 
      'One step when scrolling is window width/height divided by step',
      1, 100, 8, [qw/readable writable/]
      ),
     ]
    ;

sub INIT_INSTANCE {

    my $self = shift;

    $self->{image} = Gtk2::Image->new;
    $self->{image}->set_size_request(0, 0);
    $self->{image}->signal_connect(size_allocate => \&size_allocate, $self);

    $self->{event_box} = Gtk2::EventBox->new;

    $self->{event_box}->add($self->{image});

    $self->{event_box}->signal_connect(button_press_event => \&button_press_event, $self);
    $self->{event_box}->signal_connect(button_release_event => \&button_release_event, $self);

    $self->{event_box}->add_events('pointer-motion-mask');
    $self->{event_box}->signal_connect(motion_notify_event => \&motion_notify, $self);

    $self->signal_connect(key_press_event => \&key_press_event, $self);
    $self->signal_connect(key_release_event => \&key_release_event, $self);
        
    # why do I need to set these?
    $self->{zoom_factor} = 1.2;
    $self->{step} = 8;

    $self->{offset} = [0, 0];
    @{$self->{bg_color}} = (0, 0, 0);

    @{$self->{menu}} = ('Zoom _in', 
			'Zoom _out',
			'Zoom to pre_vious',
			'',
			'_Zoom', 
			'_Pan', 
			'_Select', 
			'_Measure',
			'',
			'_Line',
			'Path',
			'_Rectangle',
			'_Ellipse',
			'Polygon',
			'',
			'Reselect',
			'_Clear selection',
			'',
			'Select within',
			'Select intersecting',
			'',
			'Set _background color..',
			'_Export as PNG',
			'Res_tore');

    %{$self->{menu_action}} = 
	('Zoom _in' => 
	 sub { 
	     my ($item, $self) = @_;
	     $self->delete_rubberband;
	     $self->zoom_in(); 
	 },
	 'Zoom _out' => 
	 sub { 
	     my ($item, $self) = @_; 
	     $self->delete_rubberband;
	     $self->zoom_out(); 
	 },
	 'Zoom to pre_vious' => 
	 sub { 
	     my ($item, $self) = @_; 
	     $self->delete_rubberband;
	     $self->zoom_to(@{$self->{previous_zoom}});
	 },
	 '_Zoom' => 
	 sub { 
	     my ($item, $self) = @_; 
	     $self->delete_rubberband;
	     $self->{rubberbanding} = 'zoom rect';
	 },
	 '_Pan' => 
	 sub { my ($item, $self) = @_; 
	       $self->delete_rubberband;
	       $self->{rubberbanding} = 'pan line';
	   },
	 '_Select' => 
	 sub { 
	     my ($item, $self) = @_; 
	     $self->delete_rubberband;
	     $self->{rubberbanding} = 'select rect';
	 },
	 '_Clear selection' => 
	 sub { my ($item, $self) = @_;
	       $self->delete_rubberband;
	       if ($self->{selection}) {
		   delete $self->{selection};
		   $self->restore_pixmap;
	       }
	   },
	 'Reselect' =>
	 sub { my ($item, $self) = @_;
	       my $layer = $self->selected_layer();
	       if ($layer and $self->{selection}) {
		   $layer->select() unless $self->{_control_down};
		   $layer->select($self->{_selecting} => $self->{selection});
		   $self->signal_emit('features_selected');
	       }
	   },
	 'Select within' => 
	 sub { 
	     my ($item, $self) = @_;
	     $self->{_selecting} = 'that_are_within';
	 },
	 'Select intersecting' => 
	 sub { 
	     my ($item, $self) = @_;
	     $self->{_selecting} = 'that_intersect';
	 },
	 '_Measure' => 
	 sub { 
	     my ($item, $self) = @_; 
	     $self->delete_rubberband;
	     $self->{rubberbanding} = 'measure line';
	 },
	 '_Line' => 
	 sub { 
	     my ($item, $self) = @_;
	     $self->delete_rubberband;
	     $self->{rubberbanding} = 'measure line';
	 },
	 'Path' => 
	 sub { 
	     my ($item, $self) = @_; 
	     $self->delete_rubberband;
	     $self->{rubberbanding} = 'measure path';
	 },
	 '_Rectangle' => 
	 sub { 
	     my ($item, $self) = @_; 
	     $self->delete_rubberband;
	     for ($self->{rubberbanding}) {
		 /zoom/ && do { 
		     $self->{rubberbanding} = 'zoom rect';
		 };
		 /select/ && do { 
		     $self->{rubberbanding} = 'select rect';
		 };
		 /measure/ && do { 
		     $self->{rubberbanding} = 'measure rect';
		 };
	     }
	 },
	 '_Ellipse' => 
	 sub { 
	     my ($item, $self) = @_; 
	     $self->delete_rubberband;
	     $self->{rubberbanding} = 'measure ellipse';
	 },
	 'Polygon' => 
	 sub { 
	     my ($item, $self) = @_; 
	     $self->delete_rubberband;
	     for ($self->{rubberbanding}) {
		 /select/ && do { 
		     $self->{rubberbanding} = 'select polygon';
		 };
		 /measure/ && do { 
		     $self->{rubberbanding} = 'measure polygon';
		 };
	     }
	 },
	 'Set _background color..' => 
	 sub { my ($item, $self) = @_;
	       $self->delete_rubberband;
	       my $color = $self->{bg_color};
	       my $d = Gtk2::ColorSelectionDialog->new('Color for the background');
	       my $c = new Gtk2::Gdk::Color ($color ? $color->[0]*257 : 0,
					     $color ? $color->[1]*257 : 0,
					     $color ? $color->[2]*257 : 0);
	       $d->colorsel->set_current_color($c);
	       
	       if ($d->run eq 'ok') {
		   $c = $d->colorsel->get_current_color;
		   $d->destroy;
		   $self->{bg_color} = 
		       [int($c->red/257),int($c->green/257),int($c->blue/257)];
		   $self->render;
	       } else {
		   $d->destroy};
	   },
	 '_Export as PNG' =>
	 sub { my ($item, $self) = @_;
	       $self->delete_rubberband;
	       my $filename;
	       my $type = 'png';
	       my $file_chooser =
		   Gtk2::FileChooserDialog->new ('Export as a PNG image',
						 undef, 'save',
						 'gtk-cancel' => 'cancel',
						 'gtk-ok' => 'ok');
	       
	       my $folder = $file_chooser->get_current_folder;
	       
	       $file_chooser->set_current_folder($self->{folder}) if $self->{folder};
	       
	       if ('ok' eq $file_chooser->run) {
		   # you can get the user's selection as a filename or a uri.
		   $self->{folder} = $file_chooser->get_current_folder;
		   $filename = $file_chooser->get_filename;
	       }
	       
	       $file_chooser->set_current_folder($folder);	       
	       $file_chooser->destroy;
	       $self->render(filename=>$filename, type=>$type) if $filename;
	   },
	 'Res_tore' => 
	 sub { 
	     my ($item, $self) = @_;
	     $self->delete_rubberband;
	     $self->restore_pixmap;
	 });
    $self->{rubberbanding} = 'zoom rect';
    $self->{_selecting} = 'that_are_within';
}

sub close {
    my $self = shift;
    delete $self->{image};
    delete $self->{event_box};
    delete $self->{pixmap};
    delete $self->{pixmap_backup};
    delete $self->{pixbuf};
    delete $self->{old_hadj};
    delete $self->{old_vadj};
}

sub size_allocate {
    my($image, $allocation, $self) = @_;
    my @old_v = (0, 0);
    @old_v = @{$self->{viewport_size}} if $self->{viewport_size};
    my @v = $allocation->values;
    @{$self->{viewport_size}} = @v[2..3];
    $self->render() if $v[2] != $old_v[0] or $v[3] != $old_v[1];
    return 0;
}

=pod

=head2 my_inits

some initializations which cannot be done automagically (for some reason unknown to me...)

=cut

sub my_inits {
    my($self) = @_;
    $self->{inited} = 1;
    
    my $hs = $self->get_hscrollbar();
    my $vs = $self->get_vscrollbar();

    $hs->signal_connect("value-changed" => \&value_changed, $self);
    $vs->signal_connect("value-changed" => \&value_changed, $self);
    
    $self->add_with_viewport($self->{event_box});
}

=pod

=head2 add_layer($layer, $do_not_zoom_to);

adds a spatial data layer to the top of the overlay, the default
behavior is to zoom to the new layer

=cut

sub add_layer {
    my($self, $layer, $do_not_zoom_to) = @_;

    my $ref = ref($layer);
    return unless $ref =~ /Geo::/;
    push @{$self->{layers}}, $layer;

    # MUST zoom to if this is the first layer
    $do_not_zoom_to = 0 unless $self->{first_added};

    $self->my_inits unless $self->{inited};
    unless ($do_not_zoom_to) {
	$self->zoom_to($layer) if $self->{viewport_size};
    }
    $self->{first_added} = 1;
    return $#{$self->{layers}};
}

sub selected_layer {
    my($self, $index) = @_;
    if (defined $index) {
	$self->{_selected} = $self->get_layer_by_index($index);
    }
    return $self->{_selected};
}

=pod

=head2 layer_count

=head2 get_layer_by_index($index)

=head2 get_layer_by_name($name)

returns a layer by its index (top = 0) or name

=cut

sub layer_count {
    my($self) = @_;
    my $count = @{$self->{layers}};
    return $count;
}

sub has_layer {
    my($self, $layer) = @_;
    for (@{$self->{layers}}) {
	next unless ref($_) eq ref($layer);
	return 1 if ref($_) eq ref($layer);
    }
    return 0;
}

sub index_of_layer {
    my($self, $name) = @_;
    my $i = $#{$self->{layers}};
    for my $layer (@{$self->{layers}}) {
	return $i if $layer->name() eq $name;
	$i--;
    }
    return undef;
}

sub get_layer_by_index {
    my($self, $index) = @_;
    return unless $index >= 0 and $index <= $#{$self->{layers}};
    return $self->{layers}->[$#{$self->{layers}} - $index];
}

sub get_layer_by_name {
    my($self, $name) = @_;
    for my $layer (@{$self->{layers}}) {
	return $layer if $layer->name() eq $name;
    }
}

sub remove_layer_by_index {
    my($self, $index) = @_;
    my $n = $#{$self->{layers}};
    return 0 unless $index >= 0 and $index <= $n;
    splice(@{$self->{layers}}, $n-$index, 1);
    delete $self->{_selected} unless $self->has_layer($self->{_selected});
    return 1;
}

sub remove_layer_by_name {
    my($self, $name) = @_;
    for my $index (0..$#{$self->{layers}}) {
	if ($self->{layers}->[$index]->name() eq $name) {
	    splice(@{$self->{layers}}, $index, 1);
	    delete $self->{_selected} unless $self->has_layer($self->{_selected});
	    return 1;
	}
    }    
    return 0;
}

=pod

=head2 zoom_to($layer) or zoom_to($minx, $miny, $maxx, $maxy)

sets the given bounding box as the world

=cut

sub zoom_to {
    # usage: ->zoom_to(layer) or ->zoom_to(minX, minY, maxX, maxY)

    my $self = shift;

    # up left (minX, maxY) is fixed, adjust maxX or minY

    my @bounds; # minX, minY, maxX, maxY

    if (@_ == 1) {
	my $layer = shift;
	return unless $self->{layers} and @{$self->{layers}};
	@bounds = $layer->world(of_GDAL=>1);
	$self->{offset} = [0, 0];
    } elsif (@_ == 5) {
	my($minX, $maxY, $pixel_size, @offset) = @_;
	$pixel_size = 1 if $pixel_size <= 0;
	$self->{pixel_size} = $pixel_size;
	@bounds = ($minX,
		   $maxY-$pixel_size*$self->{viewport_size}->[1],
		   $minX+$pixel_size*$self->{viewport_size}->[0],
		   $maxY);
	$self->{offset} = [@offset];
    } else {
	@bounds = @_;
	$self->{offset} = [0, 0];
    }

    # sanity check
    $bounds[2] = $bounds[0]+1 if $bounds[2] <= $bounds[0];
    $bounds[3] = $bounds[1]+1 if $bounds[3] <= $bounds[1];

    my($w, $h) = @{$self->{viewport_size}};
    @{$self->{canvas_size}} = @{$self->{viewport_size}};
    $self->{pixel_size} = max(($bounds[2]-$bounds[0])/$w,($bounds[3]-$bounds[1])/$h);

    $self->{minX} = $bounds[0];
    $self->{maxY} = $bounds[3];
    $self->{maxX} = $bounds[0]+$self->{pixel_size}*$w;
    $self->{minY} = $bounds[3]-$self->{pixel_size}*$h;

    $self->render() if $self->{first_added};
    $self->signal_emit ('extent-widened');
}

sub world { # used in vector::rasterize
    my $self = shift;
    return $self->get_focus;
}

sub size { # similar to Geo::Raster (M, N) i.e. )height, width)
    my $self = shift;
    return ($self->{viewport_size}->[1], $self->{viewport_size}->[0]);
}

=pod

=head2 zoom_to_all

sets the bounding box which bounds all layers as the world

=cut

sub zoom_to_all {
    my($self) = @_;
    return unless $self->{layers} and @{$self->{layers}};
    my @size;
    for my $layer (@{$self->{layers}}) {
	my @s;
	if (ref($layer) eq 'Geo::Raster' or ref($layer) eq 'Geo::Vector') {
	    @s = $layer->world(of_GDAL=>1);
	}
	if (@size) {
	    $size[0] = min($size[0], $s[0]);
	    $size[1] = min($size[1], $s[1]);
	    $size[2] = max($size[2], $s[2]);
	    $size[3] = max($size[3], $s[3]);
	} else {
	    @size = @s;
	}
    }
    $self->zoom_to(@size) if @size;
}

=pod

=head2 set_event_handler($event_handler, $user_param)

sets a subroutine which gets called when something happens in the
widget, the sub is called like this:
$event_handler->($user_param, $event, @xy);

=cut

sub set_event_handler {
    my($self, $event_handler, $user_param) = @_;
    $self->{event_handler} = $event_handler;
    $self->{event_handler_user_param} = $user_param;
}

=pod

=head2 set_draw_on($draw_on, $user_param)

sets a subroutine which gets called whenever a new pixmap is drawn for
the widget, the sub is called like this:
$draw_on->($user_param, $pixmap);

=cut

sub set_draw_on {
    my($self, $draw_on, $user_param) = @_;
    $self->{draw_on} = $draw_on;
    $self->{draw_on_user_param} = $user_param;
}

sub value_changed {
    my($scrollbar, $self) = @_;
    $self->{offset} = [$self->get_hadjustment()->value(), $self->get_vadjustment()->value()];
    $self->render();
    return 1;
}

=pod

=head2 get_focus

Returns the visible area or the selection, if one exists,
as ($minx, $miny, $maxx, $maxy).

=cut

sub get_focus {
    my($self) = @_;
    if ($self->{selection} and 
	($self->{selection}->GetGeometryType == $Geo::OGR::wkbPolygon or
	 $self->{selection}->GetGeometryType == $Geo::OGR::wkbPolygon25D)) {
	my $e = $self->{selection}->GetEnvelope;
	return ($e->[0], $e->[2], $e->[1], $e->[3]);
    } else {
	my $minX = $self->{minX}+$self->{offset}[0]*$self->{pixel_size};
	my $maxY = $self->{maxY}-$self->{offset}[1]*$self->{pixel_size};
	return ($minX, $maxY-$self->{viewport_size}->[1]*$self->{pixel_size},
		$minX+$self->{viewport_size}->[0]*$self->{pixel_size}, $maxY);
    }
}

=pod

=head2 render(key=>value,..)

Does the actual rendering by calling (creating) a new
Gtk2::Ex::Geo::Renderer object. Creates the pixmap for the
image. Deletes the backup pixmap if one exists. Currently used
parameters:

filename=>filename, type=>type

    if filename is set, calls pixbuf->save with given options

=cut

sub render {
    my $self = shift;
    my %opt = @_;

    return unless $self->{layers} and @{$self->{layers}} and $self->{viewport_size}->[0];

    my @tmp = ($self->{minX}, $self->{maxY}, $self->{pixel_size}, @{$self->{offset}});
    $self->{previous_zoom} = $self->{current_zoom} ? [@{$self->{current_zoom}}] : [@tmp];
    $self->{current_zoom} = [@tmp];

    $self->{pixbuf} = Gtk2::Ex::Geo::Renderer->new($self->{layers}, @tmp, 
						   @{$self->{viewport_size}},
						   @{$self->{bg_color}}, $self);
    return unless $self->{pixbuf};

    if ($opt{filename}) {
	my $filename = $opt{filename};
	delete $opt{filename};
	my $type = $opt{type};
	delete $opt{type};
	# other options...
	$self->{pixbuf}->save($filename, $type);
    }

    $self->{image}->set_from_pixbuf(undef);
    
    $self->{pixmap} = $self->{pixbuf}->render_pixmap_and_mask(0);
    delete $self->{pixmap_backup};

    $self->{image}->set_from_pixmap($self->{pixmap}, undef);

    $self->{old_hadj} = $self->get_hscrollbar->get_adjustment; # prevents a warning
    $self->get_hscrollbar->set_adjustment
	(Gtk2::Adjustment->new($self->{offset}[0], 0, $self->{canvas_size}[0], $self->{viewport_size}[0]/20,
			       $self->{viewport_size}[0], $self->{viewport_size}[0]));

    $self->{old_vadj} = $self->get_vscrollbar->get_adjustment; # prevents a warning
    $self->get_vscrollbar->set_adjustment
	(Gtk2::Adjustment->new($self->{offset}[1], 0, $self->{canvas_size}[1], $self->{viewport_size}[1]/20,
			       $self->{viewport_size}[1], $self->{viewport_size}[1]));
    
    $self->{draw_on}->($self->{draw_on_user_param}, $self->{pixmap}) if $self->{draw_on};

    $self->draw_selection; # if $self->{selection};
}

## @method
# Render a Geo::OGR::Geometry on the pixmap of the overlay using a given graphics context.
# Call update_image after you are finished with drawing on the pixmap.
sub render_geometry {
    my($self, $gc, $geom) = @_;
    my $n = $geom->GetGeometryCount;
    if ($n) {
	for my $i (0..$n-1) {
	    my $g = $geom->GetGeometryRef($i);
	    $self->render_geometry($gc, $g);
	}
    } else {
	my $type = $geom->GetGeometryType;
      SWITCH: {
	  if ($type == $Geo::OGR::wkbPoint or
	      $type == $Geo::OGR::wkbMultiPoint or
	      $type == $Geo::OGR::wkbPoint25D or
	      $type == $Geo::OGR::wkbMultiPoint25D) {

	      for my $i (0..$geom->GetPointCount-1) {
		  my @p = ($geom->GetX($i), $geom->GetY($i));
		  @p = $self->point2pixmap_pixel(@p);
		  $self->{pixmap}->draw_line($gc, $p[0]-4, $p[1], $p[0]+4, $p[1]);
		  $self->{pixmap}->draw_line($gc, $p[0], $p[1]-4, $p[0], $p[1]+4);
	      }

	      last SWITCH; 
	  }
	  if ($type == $Geo::OGR::wkbLineString or
	      $type == $Geo::OGR::wkbPolygon or
	      $type == $Geo::OGR::wkbMultiLineString or
	      $type == $Geo::OGR::wkbMultiPolygon or
	      $type == $Geo::OGR::wkbLineString25D or
	      $type == $Geo::OGR::wkbPolygon25D or
	      $type == $Geo::OGR::wkbMultiLineString25D or
	      $type == $Geo::OGR::wkbMultiPolygon25D) { 
	      
	      my @points;
	      for my $i (0..$geom->GetPointCount-1) {
		  my @p = ($geom->GetX($i), $geom->GetY($i));
		  my @q = $self->point2pixmap_pixel(@p);
		  push @points, @q;
	      }
	      $self->{pixmap}->draw_lines($gc, @points);

	      last SWITCH; 
	  }
      }
    }
}

=pod

=head2 create_backup_pixmap

Creates a backup pixmap unless one already exists.

=cut

sub create_backup_pixmap {
    my($self) = @_;
    return if $self->{pixmap_backup};
    $self->{pixmap_backup} = Gtk2::Gdk::Pixmap->new($self->{pixmap}, @{$self->{viewport_size}}, -1);
    my $gc = Gtk2::Gdk::GC->new($self->{pixmap_backup});
    $self->{pixmap_backup}->draw_drawable($gc, $self->{pixmap}, 0, 0, 0, 0, -1, -1);
}

=pod

=head2 restore_pixmap

Restores the pixmap to the state it was right after last call to
create_backup_pixmap that actually had an effect.

=cut

sub restore_pixmap {
    my($self) = @_;
    return unless $self->{pixmap_backup};
    my $gc = Gtk2::Gdk::GC->new($self->{pixmap});
    $self->{pixmap}->draw_drawable($gc, $self->{pixmap_backup}, 0, 0, 0, 0, -1, -1);
    $self->update_image;
}

=pod

=head2 update_image

Updates the image on the screen to show the changes in pixmap.

=cut

sub update_image {
    my($self) = @_;
    $self->draw_selection if $self->{selection};
    $self->{image}->set_from_pixbuf(undef);
    $self->{image}->set_from_pixmap($self->{pixmap}, undef);
}

sub draw_selection {
    my($self) = @_;

    $self->create_backup_pixmap;
	
    my $gc = Gtk2::Gdk::GC->new($self->{pixmap});
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535,0,0));
    
    my $layer = $self->selected_layer;
    $layer->render_selection($gc, $self) if $layer;

    if ($self->{selection}) {
	my $type = $self->{selection}->GetGeometryType;
	unless ($type == $Geo::OGR::wkbPoint or $type == $Geo::OGR::wkbPoint25D) {
	    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535, 65535, 0));
	    $gc->set_line_attributes(2,'GDK_LINE_ON_OFF_DASH','GDK_CAP_NOT_LAST','GDK_JOIN_MITER');
	    $self->render_geometry($gc, $self->{selection});
	}
    }
}

=pod

=head2 zoom($w_offset, $h_offset, $pixel_size)

select a part of the world into the visible area

=cut

sub zoom {
    my($self, $w_offset, $h_offset, $pixel_size, $zoomed_in) = @_;

    $self->{offset} = [$w_offset, $h_offset];
    
    # sanity check
    $pixel_size = 1 if $pixel_size <= 0;
    $self->{pixel_size} = $pixel_size;

    my $w = ($self->{maxX}-$self->{minX})/$self->{pixel_size};
    my $h = ($self->{maxY}-$self->{minY})/$self->{pixel_size};

    $self->{canvas_size} = [$w, $h];

    $self->render();
    if ($zoomed_in) {
	$self->signal_emit ('zoomed-in');
    } else {
	$self->signal_emit ('extent-widened');
    }
}

sub _zoom { 
    my($self, $in, $event, $center_x, $center_y, $zoomed_in) = @_;

    return unless $self->{layers} and @{$self->{layers}};

    my @old_offset = @{$self->{offset}};

    # the center point should stay where it is unless center is defined
    $center_x = $self->{minX} + 
	($self->{offset}[0]+$self->{viewport_size}->[0]/2)*$self->{pixel_size} unless defined $center_x;
    $center_y = $self->{maxY} - 
	($self->{offset}[1]+$self->{viewport_size}->[1]/2)*$self->{pixel_size} unless defined $center_y;

    $self->{pixel_size} = $in ? 
	$self->{pixel_size} / $self->{zoom_factor} : 
	$self->{pixel_size} * $self->{zoom_factor};

    $self->{offset} = 
	[int(($center_x - $self->{minX})/$self->{pixel_size} - $self->{viewport_size}->[0]/2),
	 int(($self->{maxY} - $center_y)/$self->{pixel_size} - $self->{viewport_size}->[1]/2)];

    $self->zoom(@{$self->{offset}}, $self->{pixel_size}, $zoomed_in);

    for (0, 1) {
	$self->{event_coordinates}->[$_] += $self->{offset}[$_] - $old_offset[$_];
    }
    $self->event_handler($event) if $event;
}

=pod

=head2 zoom_in($event, $center_x, $center_y)

zooms in a zoom_factor amount

=cut

sub zoom_in { 
    my($self, $event, $center_x, $center_y) = @_;
    $self->_zoom(1, $event, $center_x, $center_y, 1);
}

=pod

=head2 zoom_out($event, $center_x, $center_y)

zooms out a zoom_factor amount

note: may enlarge the world

=cut

sub zoom_out { 
    my($self, $event, $center_x, $center_y) = @_;
    if ($self->{offset}[0] == 0 and $self->{offset}[1] == 0) {
	my $dx = ($self->{maxX}-$self->{minX})*$self->{zoom_factor}/6.0;
	my $dy = ($self->{maxY}-$self->{minY})*$self->{zoom_factor}/6.0;
	$self->zoom_to($self->{minX}-$dx, $self->{minY}-$dy, $self->{maxX}+$dx, $self->{maxY}+$dy);
    } else {
	$self->_zoom(0, $event, $center_x, $center_y);
    }
}

=pod

=head2 pan($w_move, $h_move, $event)

pans the viewport

=cut

sub pan {
    my($self, $w_move, $h_move, $event) = @_;

    $w_move = floor($w_move);
    $h_move = floor($h_move);
    
    $self->{event_coordinates}[0] += $w_move;
    $self->{event_coordinates}[1] += $h_move;

    $self->{offset} = [$self->{offset}[0] + $w_move, $self->{offset}[1] + $h_move];
	
    $self->render();
    
    $self->event_handler($event) if $event;
    $self->signal_emit ('extent-widened');
}

=pod

=head2 internal handling of key and button events

+ => zoom_in
- => zoom_out
arrow keys => pan 

the attribute rubberbanding defines what is done with button press,
move and release

=cut

sub key_press_event {
    my($self, $event) = @_;

    return 0 unless $self->{layers} and @{$self->{layers}};
    
    # if this were an event box handler like button press
#    my(undef, $event, $self) = @_;

    my $key = $event->keyval;
    if ($key == $Gtk2::Gdk::Keysyms{plus}) {
	$self->zoom_in($event); # , $self->event_pixel2point());
    } elsif ($key == $Gtk2::Gdk::Keysyms{minus}) {
	$self->zoom_out($event); # , $self->event_pixel2point());
    } elsif ($key == $Gtk2::Gdk::Keysyms{Right}) {
	$self->pan($self->{viewport_size}->[0]/$self->{step}, 0, $event);
    } elsif ($key == $Gtk2::Gdk::Keysyms{Left}) {
	$self->pan(-$self->{viewport_size}->[0]/$self->{step}, 0, $event);
    } elsif ($key == $Gtk2::Gdk::Keysyms{Up}) {
	$self->pan(0, -$self->{viewport_size}->[1]/$self->{step}, $event);
    } elsif ($key == $Gtk2::Gdk::Keysyms{Down}) {
	$self->pan(0, $self->{viewport_size}->[1]/$self->{step}, $event);
    } elsif ($key == $Gtk2::Gdk::Keysyms{Escape}) {
	if ($self->{rubberbanding} =~ /select/) {
	    my $layer = $self->selected_layer();
	    if ($layer) {
		$layer->select() unless $self->{_control_down};
		delete $self->{selection};
		my $polygon = new Geo::OGR::Geometry($Geo::OGR::wkbPolygon);
		$polygon->ACQUIRE;
		my $r = new Geo::OGR::Geometry($Geo::OGR::wkbLinearRing);
		my @p = @{$self->{path}};
		if (@p > 2) {
		    for my $p (0..$#p) {
			$r->AddPoint($self->event_pixel2point(@{$p[$p]}));
		    }
		    $r->AddPoint($self->event_pixel2point(@{$p[0]}));
		    $polygon->AddGeometry($r);
		    $self->{selection} = $polygon;
		    $layer->select($self->{_selecting} => $polygon);
		    $self->signal_emit('features_selected');
		}
	    }
	}
    } elsif ($key == $Gtk2::Gdk::Keysyms{Control_L} or $key == $Gtk2::Gdk::Keysyms{Control_R}) {
	$self->{_control_down} = 1;
	return 0;
    } else {
	$self->event_handler($event);
    }
    $self->delete_rubberband;
    return 0;
}

sub key_release_event {
    my($self, $event) = @_;
    my $key = $event->keyval;
    $self->{_control_down} = 0 if $Gtk2::Gdk::Keysyms{Control_L} or $Gtk2::Gdk::Keysyms{Control_R};
}

# rubberbanding yes/no?
# if rubberbanding, what to draw when motion? line/rect/ellipse
# if rubberbanding, what to do when button release? (how to cancel?) pan/zoom/select

sub delete_rubberband {
    my $self = shift;
    delete $self->{rubberband};
    delete $self->{rubberband_gc};
    delete $self->{path};
    my $gc = Gtk2::Gdk::GC->new ($self->{pixmap});
    $self->{pixmap}->draw_pixbuf($gc, $self->{pixbuf}, 0, 0, 0, 0, -1, -1, 'GDK_RGB_DITHER_NONE', 0, 0);
    $self->{image}->set_from_pixbuf(undef);
    $self->{image}->set_from_pixmap($self->{pixmap}, undef);
    $self->draw_selection;
	
}

sub button_press_event {
    my(undef, $event, $self) = @_;

    return 0 unless $self->{layers} and @{$self->{layers}};
    $self->grab_focus;

    my $handled = 0;

    if ($event->button == 3) {

	my $menu = Gtk2::Menu->new;
	my $i = 0;
	for (@{$self->{menu}}) {
	    my $menu_item = $_;
	    if ($menu_item eq '') {
		my $item = Gtk2::SeparatorMenuItem->new();
		$item->show;
		$menu->append ($item);
		next;
	    } 
	    my $action = $self->{menu_action}->{$menu_item};
	    for ($menu_item) {
		$_ .= ' x', last if /within/ and $self->{_selecting} =~ /within/;
		$_ .= ' x', last if /intersect/ and $self->{_selecting} =~ /intersect/;
		$_ .= ' x', last if /_Zoom/ and $self->{rubberbanding} =~ /zoom/;
		$_ .= ' x', last if /Pan/ and $self->{rubberbanding} =~ /pan/;
		$_ .= ' x' if /_Select/ and $self->{rubberbanding} =~ /select/;
		$_ .= ' x' if /Measure/ and $self->{rubberbanding} =~ /measure/;
		$_ .= ' x' if /Line/ and $self->{rubberbanding} =~ /line/;
		$_ .= ' x' if /Path/ and $self->{rubberbanding} =~ /path/;
		$_ .= ' x' if /Rect/ and $self->{rubberbanding} =~ /rect/;
		$_ .= ' x' if /Ellipse/ and $self->{rubberbanding} =~ /ellipse/;
		$_ .= ' x' if /Polygon/ and $self->{rubberbanding} =~ /polygon/;
	    }
	    my $item = Gtk2::MenuItem->new($menu_item);
	    $item->show;
	    $menu->append ($item);
	    $item->{index} = $i++;
	    $item->{text} = $menu_item;
	    $item->signal_connect(activate => $action, $self);
	}
	$menu->popup(undef, undef, undef, undef, $event->button, $event->time);
	$handled = 1;

    } elsif ($event->button == 1) {

	@{$self->{event_coordinates}} = ($event->x, $event->y);

	if ($self->{rubberbanding}) {
	    @{$self->{rubberband_begin}} = @{$self->{event_coordinates}};
	    $self->{rubberband} = [];
	    $self->{rubberband_gc} = Gtk2::Gdk::GC->new ($self->{pixmap});
	    $self->{rubberband_gc}->copy($self->style->fg_gc($self->state));
	    $self->{rubberband_gc}->set_function('invert');
	    
	    if ($self->{selection} and $self->{rubberbanding} =~ /select/) {
		delete $self->{selection};
		$self->restore_pixmap;
	    }

	    if ($self->{rubberbanding} =~ /path/ or $self->{rubberbanding} =~ /polygon/) {
		push @{$self->{path}}, [@{$self->{rubberband_begin}}];
		delete $self->{rubberband_begin};
	    }

	    $handled = 1;
	}

    }

    $self->event_handler($event);
    return $handled;
}

sub button_release_event {
    my(undef, $event, $self) = @_;
    
    return 0 unless $self->{layers} and @{$self->{layers}};
    
    @{$self->{event_coordinates}} = ($event->x, $event->y);

    my $handled = 0;
    if ($self->{rubberbanding} and $self->{rubberband_begin}) {

	my $pm = $self->{pixmap};
	my @rb = @{$self->{rubberband}};
	my $rgc = $self->{rubberband_gc};
	my @begin = @{$self->{rubberband_begin}};
	my @end = @{$self->{event_coordinates}};

	# erase & do pan or zoom 

	for ($self->{rubberbanding}) {

	    #$handled = 1;

	    #last if $begin[0] == $end[0] and $begin[1] == $end[1];
	    my $click = ($begin[0] == $end[0] and $begin[1] == $end[1]);

	    /line/ && do { 
		$pm->draw_line($rgc, @rb) if @rb;
	    };
	    /rect/ && do {
		$pm->draw_rectangle($rgc, FALSE, @rb) if @rb;
	    };
	    /ellipse/ && do {
		$pm->draw_arc($rgc, FALSE, @rb, 0, 64*360) if @rb;
	    };

	    $self->{image}->set_from_pixbuf(undef);
	    $self->{image}->set_from_pixmap($pm, undef);

	    my @wbegin = $self->event_pixel2point(@begin);
	    my @wend = $self->event_pixel2point(@end);

	    /pan/ && do {
		$self->pan($begin[0] - $end[0], $begin[1] - $end[1]);
	    };
	    /zoom/ && !$click && do {		
		my $w_offset = min($begin[0], $end[0]);
		my $h_offset = min($begin[1], $end[1]);
		
		my $pixel_size = max(abs($wbegin[0]-$wend[0])/$self->{viewport_size}->[0],
				     abs($wbegin[1]-$wend[1])/$self->{viewport_size}->[1]);
		
		$w_offset = int((min($wbegin[0], $wend[0])-$self->{minX})/$pixel_size);
		$h_offset = int(($self->{maxY}-max($wbegin[1], $wend[1]))/$pixel_size);
		
		$self->zoom($w_offset, $h_offset, $pixel_size, 1);
	    };
	    /select/ && do {

		my $layer = $self->selected_layer();
		if ($layer) {
		    $layer->select() unless $self->{_control_down};
		    delete $self->{selection};
		    if ($click) {
			my $point = new Geo::OGR::Geometry($Geo::OGR::wkbPoint);
			$point->ACQUIRE;
			$point->AddPoint($wbegin[0], $wbegin[1]);
			$self->{selection} = $point;
			$layer->select(that_contain => $point);
			my $f = $layer->selected_features();
			my @f, values(%$f);
		    } elsif (/rect/) {
			my @rect = (min($wbegin[0], $wend[0]), min($wbegin[1], $wend[1]),
				    max($wbegin[0], $wend[0]), max($wbegin[1], $wend[1]));
			my $rect = new Geo::OGR::Geometry($Geo::OGR::wkbPolygon);
			$rect->ACQUIRE;
			my $r = new Geo::OGR::Geometry($Geo::OGR::wkbLinearRing);
			$r->AddPoint($rect[0], $rect[1]);
			$r->AddPoint($rect[0], $rect[3]);
			$r->AddPoint($rect[2], $rect[3]);
			$r->AddPoint($rect[2], $rect[1]);
			$rect->AddGeometry($r);
			$rect->CloseRings;
			$self->{selection} = $rect;
			$layer->select($self->{_selecting} => $rect);
		    }
		    $self->signal_emit('features_selected');
		    $self->draw_selection;
		}
	    }
	}
	$self->delete_rubberband;

	$self->event_handler($event);

    } elsif ($self->{rubberbanding} =~ /path/ or $self->{rubberbanding} =~ /polygon/) {

	#$handled = 1;

    } else {

	$self->event_handler($event);
    }
    return $handled;
}

sub motion_notify {
    my(undef, $event, $self) = @_;

    return 0 unless $self->{layers} and @{$self->{layers}};

    @{$self->{event_coordinates}} = ($event->x, $event->y);

    my $handled = 0;
    if ($self->{rubberbanding} and $self->{rubberband}) {

	my $pm = $self->{pixmap};
	my @rb = @{$self->{rubberband}};
	my $rgc = $self->{rubberband_gc};
	my @end = @{$self->{event_coordinates}};
	my @begin;
	my ($w, $h);
	if ($self->{rubberband_begin}) {
	    @begin = @{$self->{rubberband_begin}};
	    $w = $end[0] - $begin[0];
	    $h = $end[1] - $begin[1];
	}

	# erase & draw

	for ($self->{rubberbanding}) {
	    /line/ && do {
		if (/pan/) {
		    my $gc = new Gtk2::Gdk::GC $pm;
		    $pm->draw_rectangle($gc, 1, 0, 0, @{$self->{viewport_size}});
		    $pm->draw_pixbuf($gc, $self->{pixbuf}, 0, 0, $w, $h, -1, -1, 'GDK_RGB_DITHER_NONE', 0, 0);
		} else {
		    $pm->draw_line($rgc, @rb) if @rb;
		    @rb = (@begin, @end);
		    $pm->draw_line($rgc, @rb);
		}
	    };
	    /path/ && do {
		my @p = @{$self->{path}}; 
		for my $p (0..$#p-1) {
		    $pm->draw_line($rgc, @{$p[$p]}, @{$p[$p+1]});
		}
		$pm->draw_line($rgc, @rb) if @rb;
		@rb = (@{$p[$#p]}, @end);
		for my $p (0..$#p-1) {
		    $pm->draw_line($rgc, @{$p[$p]}, @{$p[$p+1]});
		}
		$pm->draw_line($rgc, @rb);
	    };
	    /rect/ && do {
		$pm->draw_rectangle($rgc, FALSE, @rb) if @rb;
		@rb = (min($begin[0], $end[0]), min($begin[1], $end[1]), abs($w), abs($h));
		$pm->draw_rectangle($rgc, FALSE, @rb);
	    };
	    /ellipse/ && do {
		$pm->draw_arc($rgc, FALSE, @rb, 0, 64*360) if @rb;
		my $a = abs(floor($w * sqrt(2)));
		my $b = abs(floor($h * sqrt(2)));
		@rb = ($begin[0] - $a, $begin[1] - $b, 2*$a, 2*$b);
		$pm->draw_arc($rgc, FALSE, @rb, 0, 64*360);
	    };
	    /polygon/ && do {
		my @p = @{$self->{path}};
		my @points;
		for my $p (@p) {
		    push @points, @$p;
		}
		push @points, @rb if @rb;
		$pm->draw_polygon($rgc, 1, @points);
		@rb = @end;
		pop @points;
		pop @points;
		push @points, @rb;
		$pm->draw_polygon($rgc, 1, @points);
	    }
	}

	@{$self->{rubberband}} = @rb;
	
	$self->{image}->set_from_pixbuf(undef);
	$self->{image}->set_from_pixmap($pm, undef);
	$handled = 1;
    }
    
    $self->event_handler($event);
    return $handled;
}

sub rubberband_value {
    my($self) = @_;

    if ($self->{rubberbanding} and $self->{rubberband}) {

	my @p0 = $self->event_pixel2point(@{$self->{rubberband_begin}}) if $self->{rubberband_begin};
	my @p1 = $self->event_pixel2point(@{$self->{event_coordinates}});

	for ($self->{rubberbanding}) {
	    /line/ && do {
		return sprintf("length = %.4f", sqrt(($p1[0]-$p0[0])**2+($p1[1]-$p0[1])**2));
	    };
	    /path/ && do {
		my @p = @{$self->{path}}; 
		my $l = 0;
		@p0 = @{$p[0]};
		for my $i (1..$#p) {
		    $l += sqrt(($p[$i]->[0] - $p0[0])**2+($p[$i]->[1] - $p0[1])**2);
		    @p0 = @{$p[$i]};
		}
		$l += sqrt(($p1[0]-$p0[0])**2+($p1[1]-$p0[1])**2);
		return sprintf("length = %.4f", $l);
	    };
	    /rect/ && do {
		return sprintf("area = %.4f", abs(($p1[0]-$p0[0])*($p1[1]-$p0[1])));
	    };
	    /ellipse/ && do {
		my $a = ($p1[0]-$p0[0]) * sqrt(2);
		my $b = ($p1[1]-$p0[1]) * sqrt(2);
		return sprintf("area = %.4f", abs(3.14159266*$a*$b));
	    };
	    /polygon/ && do {
		my @p = @{$self->{path}};
		my @points;
		for my $p (@p) {
		    push @points, [$self->event_pixel2point(@$p)];
		}
		push @points, [@p1];
		push @points, [@{$points[0]}];
		my @edges;
		for my $i (0..$#points-1) {
		    push @edges, [$points[$i], $points[$i+1]];
		}
		# test for simplicity
		my $simple = 1;
		for my $i (0..$#edges) {
		    for my $j ($i+2..$#edges) {
			next if $i == 0 and $j == $#edges;
			$simple = 0 if intersect($edges[$i], $edges[$j]);
			last unless $simple;
		    }
		    last unless $simple;
		}
		return "not a simple polygon" unless $simple;
		
		pop @points; # remove the duplicate

		@points = reverse @points unless ccw_simple_polygon(\@points) == 1;
		
		my $area = 0;
		my $j = 0;
		for my $i (0..$#points) {
		    $j++;
		    $j = 0 if $j > $#points;
		    $area += $points[$i]->[0] * $points[$j]->[1];
		}
		$j = 0;
		for my $i (0..$#points) {
		    $j++;
		    $j = 0 if $j > $#points;
		    $area -= $points[$i]->[1] * $points[$j]->[0];
		}
		return sprintf("area = %.4f", $area/2);
	    };
	}
    }
    return '';
}

sub ccw {
    my($p0, $p1, $p2) = @_;
    my $dx1 = $p1->[0] - $p0->[0]; my $dy1 = $p1->[1] - $p0->[1];
    my $dx2 = $p2->[0] - $p0->[0]; my $dy2 = $p2->[1] - $p0->[1];
    return 1 if $dx1*$dy2 > $dy1*$dx2;
    return -1 if $dx1*$dy2 < $dy1*$dx2;
    return -1 if (($dx1*$dx2 < 0) or ($dy1*$dy2 < 0));
    return +1 if (($dx1*$dx1+$dy1*$dy1) < ($dx2*$dx2+$dy2*$dy2));
    return 0;
}

sub intersect {
    my($l1, $l2) = @_;
    return ((ccw($l1->[0], $l1->[1], $l2->[0])
	     *ccw($l1->[0], $l1->[1], $l2->[1])) <= 0)
	&& ((ccw($l2->[0], $l2->[1], $l1->[0])
	     *ccw($l2->[0], $l2->[1], $l1->[1])) <= 0);
}

sub ccw_simple_polygon {
    my($points) = @_;
    # find the northernmost point
    my $t = 0;
    return 0 if @$points < 3;
    for my $i (1..$#$points) {
	$t = $i if $points->[$i][1] > $points->[$t][1];
    }
    my $p = $t-1;
    $p = $#$points if $p < 0;
    my $n = $t+1;
    $n = 0 if $n > $#$points;
    return ccw($points->[$p], $points->[$t], $points->[$n]);
}

=pod

=head2 coordinate transforms

event_pixel2point => returns event coordinates as world coordinates

point2pixmap_pixel => returns world coordinates as pixmap pixel
coordinates

=cut

# from event coordinates to world coordinates
sub event_pixel2point {
    my($self, @pixel) = @_;
    return unless $self->{layers} and @{$self->{layers}};
    @pixel = @{$self->{event_coordinates}} unless @pixel;
    return ($self->{minX} + $self->{pixel_size} * ($self->{offset}[0] + $pixel[0] + 0.5),
	    $self->{maxY} - $self->{pixel_size} * ($self->{offset}[1] + $pixel[1] + 0.5));
}

# from world coordinates to the coordinates of the drawable
sub point2pixmap_pixel {
    my($self, @p) = @_;
    return (round(($p[0] - $self->{minX})/$self->{pixel_size} - 0.5 - $self->{offset}[0]),
	    round(($self->{maxY} - $p[1])/$self->{pixel_size} - 0.5 - $self->{offset}[1]));
}

sub event_handler {
    my($self, $event) = @_;
    return unless $self->{event_handler};
    my @xy 
	= $self->event_pixel2point if $self->{event_coordinates};
    my @xy0 
	= $self->event_pixel2point(@{$self->{rubberband_begin}}) if $self->{rubberband_begin};
    $self->{event_handler}->($self->{event_handler_user_param}, $event, @xy, @xy0);
}

sub min {
    $_[0] > $_[1] ? $_[1] : $_[0];
}

sub max {
    $_[0] > $_[1] ? $_[0] : $_[1];
}

sub round {
    return int($_[0] + .5 * ($_[0] <=> 0));
}

1;
=pod

=head1 SEE ALSO

Gtk2::Ex::Geo

=head1 AUTHOR

Ari Jolma, E<lt>ajolma at tkk.fiE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
