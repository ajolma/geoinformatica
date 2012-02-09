package Scale;
our @ISA = qw(Gtk2::Ex::Geo::Layer);
sub new {
    my($package, %param) = @_;
    my $self = Gtk2::Ex::Geo::Layer::new($package);
    $self->{dx} = $param{dx};
    $self->{dy} = $param{dy};
    return $self;
}
sub name {
    'scale';
}
sub world {
    return (3470000, 6670000, 347000, 6670000);
}
sub render {
    my($self, $pb, $cr, $overlay, $viewport) = @_;
    my $px = $overlay->{pixel_size};
    my $box = 20;
    my $layout = Gtk2::Pango::Cairo::create_layout($cr);
    my $font_desc = Gtk2::Pango::FontDescription->from_string("sans 10");
    $layout->set_font_description($font_desc);    
    my $w = ($viewport->[2]-$viewport->[0])/$px;
    my $h = ($viewport->[3]-$viewport->[1])/$px;
    $w -= 0.5;
    $h -= 0.5;
    my $dx = $self->{dx} || 0;
    my $dy = $self->{dy} || 0;
    
    my $x = 100*$px;
    my $i = 0;
    while ($x > 10) {
	$i++;
	$x /= 10;
    }
    if ($x < 1.5) {
	$x = 1;
	} elsif ($x < 3.5) {
	    $x = 2;
	} elsif ($x < 7.5) {
	    $x = 5;
	} else {
	    $x = 1;
	    $i++;
	}
    my $u;
    my $s = $x;
    $x = int($x*10**$i / $px);
    if ($i < 3) {
	$u = ' m';
    } else {
	$i -= 3;
	$u = ' km';
    }
    $s .= ('0' x $i) . $u;
    
    $cr->set_line_width(1);
    $cr->set_source_rgba(0, 0, 0, 1);
    $cr->move_to($w-$dx-20, $h-$dy-6);
    $cr->rel_line_to(0, -5);
    $cr->rel_move_to(0, 5);
    $cr->rel_line_to(-$x, 0);
    $cr->rel_line_to(0, -5);
    $cr->stroke();
    
    $layout->set_text($s);
    my ($w2, $h2) = $layout->get_pixel_size;
    $cr->move_to($w-$dx-20-$x/2-$w2/2, $h-$dy-8-$h2);
    
    Gtk2::Pango::Cairo::show_layout($cr, $layout);

}

1;
