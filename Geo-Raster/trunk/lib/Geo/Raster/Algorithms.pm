## @class Geo::Raster::Algorithms
# @brief Adds various algorithmic methods to Geo::Raster
package Geo::Raster;

## @method Geo::Raster interpolate(%params)
#
# @brief Interpolate values for nodata cells.
#
# @param[in] params Named parameters:
# - <i>method</i> => string. At moment only 'nearest neighbor' is
# supported.
# @return a new raster. In void context changes this raster.
# @exception A unsupported method is specified.
# @todo Add more interpolation methods.
sub interpolate {
    my($self, %param) = @_;
    $param{method} = 'nearest neighbor' unless defined $param{method};
    $param{method} = 'nearest neighbor' if $param{method} eq 'nn';
    my $new;
    if ($param{method} eq 'nearest neighbor') {
	$new = ral_grid_nn($self->{GRID});
    } else {
	croak "interpolation method '$param{method}' not implemented\n";
    }
    if (defined wantarray) {
	return Geo::Raster->new($new);
    } else {
	ral_grid_destroy($self->{GRID});
	$self->{GRID} = $new;
	$self->_attributes;
    }
}

## @method Geo::Raster dijkstra(@cell)
#
# @brief Computes a cost-to-go raster for a given cost raster and a
# target cell.
#
# When this method is applied to a cost raster, the method computes
# the cost to travel to the target cell from each cell in the
# raster. If the cost at a cell is less than one, the cell cannot be
# a part of the optimal route to the target.
# @param[in] cell The target cell.
# @return a new raster. In void context changes this raster.
sub dijkstra {
    my($self, $i, $j) = @_;
    my $new = ral_grid_dijkstra($self->{GRID}, $i, $j);
    if (defined wantarray) {
	return Geo::Raster->new($new);
    } else {
	ral_grid_destroy($self->{GRID});
	$self->{GRID} = $new;
	$self->_attributes;
    }
}

## @method Geo::Raster colored_map()
#
# @brief Attempts to use the smallest possible number of integers for
# the zones in the raster.
# @return a new raster. In void context changes this raster.
sub colored_map {
    my $self = shift;
    my $n = $self->neighbors();
    my %map;
    $map{0} = 0;
    my $base;
    my %nn;
    foreach $base (sort {$a<=>$b} keys %{$n}) {
    	# Going trough each value (zone)
	next if $base == 0; # Zero values are already the smallest.
	my $m = 1;
	$map{$base} = $m unless defined($map{$base}); # The first gets a value 1.
	my $skip = $map{$base};
	# Going trough each neighbor of the value.
	foreach (@{$$n{$base}}) {
	    # Checking if the neighbor does not already exist in the map hash.
	    if (!defined($map{$_})) {
		$m++;
		$m++ if $m == $skip;
		$map{$_} = $m; # Giving the neighbor a higher value.
	    } elsif ($map{$_} == $skip) {
		# Redefining:
		$m++;
		$m++ if $m == $skip;
		my $m2 = $m;
		while ($nn{$m2}{$_}) {
		    # Some base -> $m2 and $_ is already a neighbor of $m2
		    $m2++;
		    $m2++ if $m2 == $skip;
		}
		$map{$_} = $m2;
	    }
	    $nn{$skip}{$_} = 1;
	}
    }
    if (defined wantarray) {
	return $self->map(\%map);
    } else {
	$self->map(\%map);
    }
}

## @method Geo::Raster applytempl(listref templ, $new_val)
#
# @brief Apply a modifying template on the raster.
#
# The "apply template" method is a generic method which is, e.g., used
# in the thinning algorithm.
#
# @code
# $a->applytempl(\@templ, $new_val);
# @endcode
#
# @param[in] templ The structuring template (or mask) to use
# A structuring template is an integer array [0..8] where 0
# and 1 mean a binary value and -1 is don't care.  The array is the 3x3
# neighborhood:<BR>
# 0 1 2<BR>
# 3 4 5<BR>
# 6 7 8
#
# The cell 4 is the center of the template. If the template matches a
# cell's neighborhood, the cell will get the given new value after all
# cells are tested. 
# @param[in] new_val (optional). New value to give to the center cell if the 
# template rules match the cell and its 8 neighbours. If not given, then 1 is 
# used to inform about match success.
# @return a new raster. In void context changes this raster.
sub applytempl {
    my($self, $templ, $new_val) = @_;
    croak "applytempl: too few values in the template" if $#$templ < 8;
    $new_val = 1 unless $new_val;
    $self = Geo::Raster->new($self) if defined wantarray;
    ral_grid_apply_templ($self->{GRID}, $templ, $new_val);
    return $self if defined wantarray;
}

## @method hashref polygonize($connectivity)
#
# @brief Returns a reference of to a hash, where each polygon has its own key 
# (a number), value and the left and right endings of each single connected 
# piece on every row.
#
# @param[in] connectivity (optional). Connectivity between cells as a number:4 
# or 8. If connectivity is not given then 8-connectivity is used.
# @return a reference to a hash including each polygon.
# The hash has named parameters, which have as keys the keys of the polygons (unigue 
# numbers) that have as values a reference to a hash having two named parameters:
# - <I>value</I>=>number. The polygons value.
# - <I>lines</I>=>array. A two dimensional array having the left and right 
# endings of each single connected piece on every row [[left, right], 
# [left, right], ...].
sub polygonize {
    my($self, $connectivity) = @_;
    $connectivity = 8 unless defined $connectivity and $connectivity == 4;
    my $grid = $self->{GRID};

    my %polygons;
    my $key = 1;

	# Going trough each row.
    for my $i (0..$self->{M}-1) {
	
	my $left = 0;
	my $value = ral_grid_get($grid, $i, $left);
	
	# Going trough each cell in the row.
	for my $j (1..$self->{N}-1) {
	    
	    my $d = ral_grid_get($grid, $i, $j);
	    
	    if ((!defined $d and defined $value) or 
		(defined $d and !defined $value) or 
		($d != $value)) {
		
		# we have a piece		
		$key = add_piece(\%polygons, $key, $value, $i, $left, $j-1, $connectivity) if defined $value;
		$left = $j;
		$value = $d;
	
	    }
	    
	}
	$key = add_piece(\%polygons, $key, $value, $i, $left, $self->{N}-1, $connectivity) if defined $value;
    }
    return \%polygons;
}

## @fn $add_piece(hashref polygons, $key, $value, $line, $left, $right, $connectivity)
#
# @brief Adds a piece to the polygons in the given hash.
# (of some already existing or new)
#
# @param[in, out] polygons Reference to an hash including each polygon.
# The hash has named parameters, which have as keys the keys of the polygons (unigue 
# numbers) that have as values a reference to a hash having two named parameters:
# - <I>value</I>=>number. The polygons value.
# - <I>lines</I>=>array. A two dimensional array having the left and right 
# endings of each single connected piece on every row [[left, right], 
# [left, right], ...].
# @param[in, out] key Key (a number) of the last polygon added to the polygon hash.
# @param[in] value Value of the piece to add to the polygon. 
# @param[in] line Number of the column where the piece is located (a 
# number between 0-(N-1).
# @param[in] left The most left j-coordinate of the piece to add.
# @param[in] right The most right j-coordinate of the piece to add.
# @param[in] connectivity (optional). Connectivity between cells as a number:4 
# or 8. If connectivity is not given then 8-connectivity is used.
# @return Returns the count of polygons in the hash.
sub add_piece {
    my($polygons, $key, $value, $line, $left, $right, $connectivity) = @_;
    my @piece_belongs_to_these_polygons;
    my $d = $connectivity == 8 ? 1 : 0;
    for my $k (keys %$polygons) {
	# see if this piece belongs to this polygon
	next unless $value == $polygons->{$k}->{value};
	my $from_line_above = $polygons->{$k}->{lines}->{$line-1};
	if ($from_line_above) {
	    my $belongs = 0;
	    for my $piece (@$from_line_above) { # $piece is [left,right]
		# does not belong if
		next if $left > $piece->[1]+$d;
		next if $right < $piece->[0]-$d;
		$belongs = 1;
		last;
	    }
	    push @piece_belongs_to_these_polygons,$k if $belongs;
	}
    }
    if (@piece_belongs_to_these_polygons > 1) {
	# Joining the piece to more than just one polygon.
	my $k = join_polygons($polygons, @piece_belongs_to_these_polygons);
	push @{$polygons->{$k}->{lines}->{$line}},[$left,$right];
    } elsif (@piece_belongs_to_these_polygons == 1) {
	# Joining a single polygon piece to that single polygon to which it 
	# belongs to.
	my $k = shift @piece_belongs_to_these_polygons;
	push @{$polygons->{$k}->{lines}->{$line}},[$left,$right];	
    } else {
    	# The piece did not belong to any polygon, so it creates it's own polygon.
	$polygons->{$key} = { value => $value,
			      lines => {
				  $line => [[$left,$right]],
			      },
			  };
	$key++;
    }
    return $key;
}

## @fn $join_polygons(hashref polygons, @k)
#
# @brief Jois the given polygons and removes all other except one from the 
# polygon hashref.
# @param[in, out] polygons Reference to an hash containing the polygons.
# The hash has named parameters, which have as keys the keys of the polygons (unigue 
# numbers) that have as values a reference to a hash having two named parameters:
# - <I>value</I>=>number. The polygons value.
# - <I>lines</I>=>array. A two dimensional array having the left and right 
# endings of each single connected piece on every row [[left, right], 
# [left, right], ...].
# @param[in] k Keys of the polygons in the polygon hashref, which should be joined.
sub join_polygons {
    my $polygons = shift;
    my $k = shift;
    # join polygons @_ to polygon $k
    for my $l (@_) {
	for my $line (keys %{$polygons->{$l}->{lines}}) {
	    push @{$polygons->{$k}->{lines}->{$line}},@{$polygons->{$l}->{lines}->{$line}};
	}
	delete $polygons->{$l};
    }
    return $k;
}

## @ignore 
sub the_border_of_a_polygon {
    my ($p) = @_;
    my $faces = the_border_of_a_polygon_as_faces($p);
    my @path;

    my($i2p,$j2p) = (-1,-1);
    for my $face (@$faces) {
	my($f,$i,$j) = @$face;
	my($i1,$j1,$i2,$j2);
	
	if ($f eq 'T') {
	    ($i1,$j1) = ($i,$j);
	    ($i2,$j2) = ($i,$j+1);
	}
	elsif ($f eq 'R') {
	    ($i1,$j1) = ($i,$j+1);
	    ($i2,$j2) = ($i+1,$j+1);
	}
	elsif ($f eq 'B') {
	    ($i1,$j1) = ($i+1,$j+1);
	    ($i2,$j2) = ($i+1,$j);
	}
	elsif ($f eq 'L') {
	    ($i1,$j1) = ($i+1,$j);
	    ($i2,$j2) = ($i,$j);
	}
	
	push @path,[$i1, $j1] unless $i1 == $i2p and $j1 == $j2p;
	push @path,[$i2, $j2];
	
	($i2p,$j2p) = ($i2,$j2);
    }

    return \@path;
}

## @ignore
sub the_border_of_a_polygon_as_faces {
    my ($p) = @_;
    my @path = ();

    # search for leftmost pixel on the upmost line
    my @lines = sort {$a<=>$b} keys %$p;
    my $pieces = $p->{$lines[0]};
    my @start = ($lines[0]);
    for my $piece (@$pieces) {
	$start[1] = $piece->[0] if !defined $start[1] or $start[1] > $piece->[0];
    }
    
    # the pixel in direction 1 (up) is definitely not on the polygon
    # search for the first direction clockwise which goes to a polygon cell
    my $d = 1;
    while (!in_polygon($p, movecell(0,@start,$d))) {
	$d++; $d = 1 if $d > 8;
	last if $d == 1;
    }
    if ($d == 1) {
	# one cell
	push @path, ['T', @start];
	push @path, ['R', @start];
	push @path, ['B', @start];
	push @path, ['L', @start];
	return \@path;
    }
    
    push @path, ['T', @start];
    my $d_prev = 3;

    my @mover = @start;
    my $d_first = 0;
    my @c1;
    my @c2;
    my @c3;
    while (1) {
	
	# the direction where to go
	while (!in_polygon($p, movecell(0,@mover,$d))) {
	    $d++; $d = 1 if $d > 8;
	}
	
	# we prefer to move to dir 1,3,5,or 7
	if ($d % 2 == 0) {
	    my $d2 = $d+1; $d2 = 1 if $d2 > 8;
	    if (in_polygon($p, movecell(0,@mover,$d2))) {
				$d = $d2;
			    }
	}
	
	# are we done?
	if ($mover[0] == $start[0] and $mover[1] == $start[1]) {
	    if (!$d_first) {
		$d_first = $d;
	    } elsif ($d == $d_first) {
		add_face_to_path(\@path, ['B', @start]) if $d_prev == 7;
		add_face_to_path(\@path, ['L', @start]) if $d_prev >= 7 or $d_prev == 1;
		return \@path;
	    }
	}
	
	# move
	@c1 = @c2;
	@c2 = @mover;
	@mover = movecell(0,@mover,$d);
	@c3 = @mover;
	
	# add faces to the path, we are sloppy and add some more than once
	# but we'll later filter the extra out
	
	for my $set ([1,'L','T','R','B'],[3,'T','R','B','L'],[5,'R','B','L','T'],[7,'B','L','T','R']) {
	    my($p,$L,$T,$R,$B) = @$set;
	    if ($d_prev == $p and $d == dirsum($p, 6)) {
		add_face_to_path(\@path, [$L, @c1]);
	    }
	    elsif ($d_prev == $p and $d == dirsum($p, 7)) {
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$B, @c3]);
	    }
	    elsif ($d_prev == $p and $d == $p) {
		add_face_to_path(\@path, [$L, @c2]);
	    }
	    elsif ($d_prev == $p and $d == dirsum($p, 1)) {
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$T, @c2]);
		add_face_to_path(\@path, [$L, @c3]);
	    }
	    elsif ($d_prev == $p and $d == dirsum($p, 2)) {
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$T, @c2]);
	    }
	    elsif ($d_prev == $p and $d == dirsum($p, 3)) {
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$T, @c2]);
		add_face_to_path(\@path, [$R, @c2]);
	    }
	    elsif ($d_prev == $p and $d == dirsum($p, 4)) {
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$T, @c2]);
		add_face_to_path(\@path, [$R, @c2]);
	    }
	}
	
	for my $set ([2,"L","T","R","B"],[4,"T","R","B","L"],[6,"R","B","L","T"],[8,"B","L","T","R"]) {
	    my($p,$L,$T,$R,$B) = @$set;
	    if ($d_prev == $p and $d == dirsum($p, 6)) {
		add_face_to_path(\@path, [$T, @c1]);
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$B, @c3]);
	    }
	    elsif ($d_prev == $p and $d == dirsum($p, 7)) {
		add_face_to_path(\@path, [$T, @c1]);
		add_face_to_path(\@path, [$L, @c2]);
	    }
	    elsif ($d_prev == $p and $d == $p) {
		add_face_to_path(\@path, [$T, @c1]);
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$T, @c2]);
		add_face_to_path(\@path, [$L, @c3]);
	    }
	    elsif ($d_prev == $p and $d == dirsum($p, 1)) {
		add_face_to_path(\@path, [$T, @c1]);
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$T, @c2]);
	    }
	    elsif ($d_prev == $p and $d == dirsum($p, 2)) {
		add_face_to_path(\@path, [$T, @c1]);
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$T, @c2]);
		add_face_to_path(\@path, [$R, @c2]);
		add_face_to_path(\@path, [$T, @c3]);
	    }
	    elsif ($d_prev == $p and $d == dirsum($p, 3)) {
		add_face_to_path(\@path, [$T, @c1]);
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$T, @c2]);
		add_face_to_path(\@path, [$R, @c2]);
	    }
	    elsif ($d_prev == $p and $d == dirsum($p, 4)) {
		add_face_to_path(\@path, [$T, @c1]);
		add_face_to_path(\@path, [$L, @c2]);
		add_face_to_path(\@path, [$T, @c2]);
		add_face_to_path(\@path, [$R, @c2]);
		add_face_to_path(\@path, [$B, @c2]);
		add_face_to_path(\@path, [$R, @c3]);
	    }
	}
	
	$d_prev = $d;
	
	# seed for where to go next
	$d = dirsum($d, 6);
    }
}

## @ignore
sub add_face_to_path {
    my($path, $face) = @_;
    return unless @$face == 3;
    # our system may try to add the same face twice,
    # or even two faces twice
    if (@$path) {
	return if 
	    $path->[$#$path]->[0] eq $face->[0] and
	    $path->[$#$path]->[1] == $face->[1] and
	    $path->[$#$path]->[2] == $face->[2];
	if ($#$path >= 0) {
	    return if 
		$path->[$#$path-1]->[0] eq $face->[0] and
		$path->[$#$path-1]->[1] == $face->[1] and
		$path->[$#$path-1]->[2] == $face->[2];
	}
    }
    push @$path, $face;
}

## @fn $in_polygon(hashref polygon, $line, $j)
#
# @brief Checks if the given coordinates are inside some polygon.
# @param[in] polygon Reference to an hash having as values references to each of the
# lines included in the polygon as hashes, whose keys are the line number and 
# values is a two dimensional array having the left and right 
# endings of each single connected piece on every row [[left, right], 
# [left, right], ...].
# @param[in] line The number of the row to check for the polygon.
# @param[in] j The number of the column to check for the polygon..
# @return true if the polygon includes the given coordinates, else false.
sub in_polygon {
    my($polygon, $line, $j) = @_;
    return 0 unless exists $polygon->{$line};
    for my $piece (@{$polygon->{$line}}) {
	return 1 if ($piece->[0] <= $j and $j <= $piece->[1]);
    }
    return 0;
}

## @method Geo::Vector vectorize(%param)
#
# @brief Polygonizes the raster and saves it as a polygon layer.
# @param[in] param is a hash having named parameters, which are given to the 
# constructor of the new Geo::Vector. The
# named parameter 'connectivity' (default 8) can be used to set the
# connectivity by which the polygons are delineated.
# @return a new vector layer.
sub vectorize {
    my ($self, %param) = @_;

    my $cell_size = $self->cell_size();

    my ($minX,$minY,$maxX,$maxY) = $self->world();

    my $vector = Geo::Vector->new(%param, geometry_type => 'Polygon', update => 1);
    $vector->schema({value=>{TypeName=>Integer}});

    croak "layer with name: '$param{layer}' already exists" if $vector->geometry_type ne 'Polygon' or $vector->feature_count() > 0;

    my $schema = $vector->{OGR}->{Layer}->GetLayerDefn();

    my $polygons = $self->polygonize($param{connectivity});

    for my $k (keys %$polygons) {

	my $value = $polygons->{$k}->{value};
	
	my $f = new Geo::OGR::Feature($schema);
	$f->SetField('value', $value);
	my $g = new Geo::OGR::Geometry($Geo::OGR::wkbPolygon);
	my $r = new Geo::OGR::Geometry($Geo::OGR::wkbLinearRing);
	
	my $path = the_border_of_a_polygon($polygons->{$k}->{lines});
	
	for my $point (@$path) {
	    $r->AddPoint($minX + $point->[1] * $cell_size, $maxY - $point->[0] * $cell_size);
	}
	
	$g->AddGeometry($r);
	$g->CloseRings;
	$f->SetGeometry($g);
	$vector->add_feature($f);
	
    }

    return $vector;
}

## @method Geo::Raster ca_step(@k)
#
# @brief Perform a cellular automata step.
#
# @param[in] k Array defining the cellular automaton defining the
# values with which the cell neighbor and the cell is multiplied. The
# indexes of the array for the neighbors are:<BR>
# 8 1 2<BR>
# 7 0 3<BR>
# 6 5 4
#
# The new value for the cell is a k weighted sum of the neighborhood
# cell values.
#
# @return a new raster. In void context changes this raster.
sub ca_step {
    my($self, @k) = @_;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_ca_step($self->{GRID}, \@k));
	return $g;
    } else {
	$self->_new_grid(ral_ca_step($self->{GRID}, \@k));
    }
}

1;
