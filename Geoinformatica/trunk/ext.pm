# load with require ext
# before reloading issue delete $INC{ext.pm}

package ext;

remove();
$main::gis->register_command('ext', \&ext);

#my @buffer = <ext::DATA>;
my @buffer = `cat /home/ajolma/dev/geoinformatica/Geoinformatica/trunk/ext.glade`;
pop @buffer unless $buffer[$#buffer] =~ /^\</; # remove the extra content
shift @buffer if $buffer[0] =~ /^\s*$/;
$main::gis->register_dialogs(Gtk2::Ex::Geo::DialogMaster->new(buffer => \@buffer));

sub remove {
    $main::gis->de_register_command('ext');
}

sub ext {

    my $self = {};
    my($dialog, $boot) = Gtk2::Ex::Geo::Layer::bootstrap_dialog
	($self, $main::gis, 'overlay_dialog', "Overlay",
	 {}, []);
    return;
    

    print "your vector layers:\n";
    my @layers;
    for my $l ($main::gis->layers) {
	next unless UNIVERSAL::isa($l, 'Geo::Vector');
	print $l->name,"\n";
	push @layers, $l;
    }
    unless (@layers > 1) {
	$main::gis->message("Overlay needs at least two vector layers.");
	return;
    }

    # the schema for the overlay
    my $schema = { Fields => [
				 { Name => 'risk', Type => 'Real', Width => 14, Precision => 6 },
#				 { Name => '', Type => '', Width => 8, Precision => 0 },
#				 { Name => '', Type => '', Width => 8, Precision => 0 },
			     ] };
    my $overlay = Geo::Vector->new( schema => $schema );
    my $s = $overlay->schema;
    my @s = $s->field_names;
    print "fields: @s\n";
    # intersect all in @overlay
    my @f;
    my @g;
    my $defn = Geo::OGR::FeatureDefn->new();
    $defn->Schema(%$schema);

    overlay($overlay, $defn, undef, undef, undef, 0, \@layers);

    $main::gis->add_layer($overlay, 'overlay', 1);
}

sub overlay {
    my($overlay, $defn, $g0, $attr, $e, $i, $layers) = @_;
    my %options = ( filter_rect => [$e->[0], $e->[2], $e->[1], $e->[3]] ) if $e;
    my $name = $layers->[$i]->name;
    $layers->[$i]->init_iterate(%options);
    while (my $f = $layers->[$i]->next_feature) {
	my $row = $f->Row;
	$attr = {} unless $attr;
	for (keys %$row) {
	    next if /^Geometry/;
	    next if /^FID/;
	    $attr->{"$name.$_"} = $row->{$_}; # assuming scalar values
	}
	my $g = $row->{Geometry};
	my $e = $g->GetEnvelope;
	unless ($g0) {
	    overlay($overlay, $defn, $g, $attr, $e, $i+1, $layers);
	    next;
	}
	next unless Geo::Vector::_intersect($g0, $g);
	my $gx = $g0->Buffer(0)->Intersection($g->Buffer(0));
	if ($i < $#$layers) {
	    overlay($overlay, $defn, $gx, $attr, $e, $i+1, $layers);
	} else {
	    # gx is a final intersection and $attr has final attributes
	    my $result = compute_overlay($attr);
	    my $fx = Geo::OGR::Feature->new($defn);
	    $fx->SetGeometry($gx);
	    $fx->Row(%$result);
	    $overlay->feature($fx);
	}
    }
}

sub compute_overlay {
    my($attr) = @_;
    my $risk = $attr->{'p.Day_2'} * $attr->{'hab.v'};
    print "$risk = $attr->{'p.Day_1'} * $attr->{'hab.v'}\n";
    # the result should be ref to a hash containing values for the overlay feature
    return { risk => $risk };
}

1;
__DATA__
