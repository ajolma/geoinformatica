use Test::More qw(no_plan);

BEGIN { 
    use_ok( 'Geo::Raster' );
}

sub diff {
    my ($a1,$a2) = @_;
    return 0 unless defined $a1 and defined $a2;
    my $test = abs($a1 - $a2);
    $test /= $a1 unless $a1 == 0;
    abs($test) < 0.01;
}

# tests here for terrain analysis & hydrological functions
# not tested: route, killoutlets, prune, number_streams, subcatchments

{
    $fdg = Geo::Raster->new(4,1);
    $fdg->set(5);
    $op = Geo::Raster->new(4,1);
    $op->nodata_value(-1);
    $op->set();
    for $i (0..3) {
	next if $i == 1;
	$op->set($i,0,$i);
    }

    $c = $fdg->path(1,0);
    my @test = (undef,1,1,1);
    for $i (0..3) {
	if (defined $test[$i]) {
	    ok($test[$i] == $c->get($i,0),"path at index $i");
	} else {
	    ok(!(defined $c->get($i,0)),"path at index $i");
	}
    }
    $c = $fdg->path_length(undef, $op);
    @test = (2.5,2,1.5,0.5);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"path at index $i");
    }
    $c = $fdg->path_sum(undef, $op);
    @test = (5,5,4,1.5);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"path at index $i");
    }
	
    $c = $fdg->upslope_count(0);
    @test = (0,1,2,3);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope count at index $i");
    }
    $c = $fdg->upslope_count(0,$op);
    @test = (0,1,1,2);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope count with op at index $i");
    }
    $c = $fdg->upslope_count(1);
    @test = (1,2,3,4);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope count including self at index $i");
    }
    $c = $fdg->upslope_count(1,$op);
    @test = (1,1,2,3);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope count including self with op at index $i");
    }
    $c = $fdg->upslope_sum(0,$op);
    @test = (0,0,0,2);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope sum at index $i");
    }
    $c = $fdg->upslope_sum(1,$op);
    @test = (0,0,2,5);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope sum including self at index $i");
    }

    $fdg->set(1);
    $c = $fdg->upslope_count(0);
    @test = (3,2,1,0);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope count at index $i");
    }
    $c = $fdg->upslope_count(0,$op);
    @test = (2,2,1,0);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope count with op at index $i");
    }
    $c = $fdg->upslope_count(1);
    @test = (4,3,2,1);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope count including self at index $i");
    }
    $c = $fdg->upslope_count(1,$op);
    @test = (3,2,2,1);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope count including self with op at index $i");
    }
    $c = $fdg->upslope_sum(0,$op);
    @test = (5,5,3,0);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope sum at index $i");
    }
    $c = $fdg->upslope_sum(1,$op);
    @test = (5,5,5,3);
    for $i (0..3) {
	ok($test[$i] == $c->get($i,0),"upslope sum including self at index $i");
    }
}

{
    my @args; 
    $args[0] = {
	aspect=>[],
	slope=>[],
	fdg=>['method=>"D8"'],
	raise_pits=>['quiet=>1'],
	lower_peaks=>['quiet=>1'],ucg=>[],
	depressions=>['$fdg'],
	fill_depressions=>['fdg=>$fdg'],
	breach=>['fdg=>$fdg']
    };
    $args[1] = {};
    
    my $dem = new Geo::Raster filename=>'data/dem.bil',load=>1;
    @s =  $dem->fit_surface(0.1);
    ok(@s == 9, 'fit_surface');

    my $fdg = $dem->fdg(method=>'D8');

    for my $method (keys %{$args[0]}) {

	#print STDERR "$method\n";
	#next if $method eq 'dag';
	
	for my $cv (0..$#args) {
	    
	    next unless $args[$cv]->{$method};

	    my @as;
	    for my $a (@{$args[$cv]{$method}}) {
		push @as,$a;
	    }
	    my $arg_list = join(',',@as);
	    
	    for (1,0) {
		my $lvalue = '';
		$lvalue = '$lvalue=' if $_;
		my $eval = "$lvalue\$dem->$method($arg_list);";
		#print STDERR "eval: $eval\n";
		eval $eval;
		#print STDERR $@;
		ok(!$@,$method);
	    }
	}
    }
    
    my $streams = new Geo::Raster like=>$fdg;
    $streams->line(10,10,50,50,1);

    $args[0] = {
	drain_flat_areas=>['$dem','method=>"one pour point",quiet=>1'],
	catchment=>[50,50,1],
	distance_to_pit=>['10'],
	distance_to_channel=>['$streams','10'],
    };
    $args[1] = {};

    for my $method (keys %{$args[0]}) {
	
	for my $cv (0..$#args) {

	    $fdg = $dem->fdg(method=>'D8');
	    
	    next unless $args[$cv]->{$method};

	    my @as;
	    for my $a (@{$args[$cv]{$method}}) {
		push @as,$a;
	    }
	    my $arg_list = join(',',@as);
	    
	    for (1,0) {
		my $lvalue = '';
		$lvalue = '$lvalue=' if $_;
		my $eval = "$lvalue\$fdg->$method($arg_list);";
		#print STDERR "eval: $eval\n";
		eval $eval;
		if ($@) {
		    print STDERR "eval: $eval\n";
		    print STDERR $@;
		}
		ok(!$@,$method);
	    }
	}
    }

}
