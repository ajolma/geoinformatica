package Geo::Raster::ConstructorTests;

use base qw(Test::Class);
use strict;

#use Geo::Raster;
use UNIVERSAL qw(isa);

use Test::More;

# The very first test will verify that Geo::Raster is available.
# and load the module.
BEGIN {
    use_ok('Geo::Raster');
    use_ok('Geo::Raster qw/$INTEGER_GRID $REAL_GRID/');
}

# Creating a new real raster grid.
#
# Positive test case.
sub new_real_raster : Test(7) {
    my $gd = Geo::Raster->new( 'real', 5, 10 );
    ok( defined($gd), "New real grid" );
    isa_ok( $gd, 'Geo::Raster' );

    $gd = Geo::Raster->new( 'float', 1000, 500);
    ok( defined($gd), "New real grid" );
    isa_ok( $gd, 'Geo::Raster' );

    $gd = Geo::Raster->new($Geo::Raster::REAL_GRID, 100, 50);
    ok( defined($gd), "New real grid" );
    isa_ok( $gd, 'Geo::Raster' );
    
    for ('data/dem.bil') {
        $gd = Geo::Raster->new($_);
        ok( defined($gd), "Opening DEM test file" );
    }
}

# Creating a new integer raster grid.
#
# Positive test case.
sub new_integer_raster : Test(12) {
    my $gd = Geo::Raster->new( 5, 10 );
    ok( defined($gd), "New integer grid" );
    isa_ok( $gd, 'Geo::Raster' );
    
    $gd = Geo::Raster->new( '', 5, 10 );
    ok( defined($gd), "New integer grid" );
    isa_ok( $gd, 'Geo::Raster' );
    
    $gd = Geo::Raster->new( 'i', 5, 10 );
    ok( defined($gd), "New integer grid" );
    isa_ok( $gd, 'Geo::Raster' );

    $gd = Geo::Raster->new( 'int', 1000, 500);
    ok( defined($gd), "New integer grid" );
    isa_ok( $gd, 'Geo::Raster' );

    $gd = Geo::Raster->new( 'integer', 1, 1);
    ok( defined($gd), "New integer grid" );
    isa_ok( $gd, 'Geo::Raster' );

    $gd = Geo::Raster->new($Geo::Raster::INTEGER_GRID, 10, 20);
    ok( defined($gd), "New integer grid" );
    isa_ok( $gd, 'Geo::Raster' );
}

# Testing the copy constructor.
#
# Positive test case.
sub copy_constructor_with_diff_types : Test(16) {
    for my $datatype1 ( 'int', 'real' ) {
        my $gd1 = new Geo::Raster( $datatype1, 5, 10 );
        $gd1->set(5);
        ok( diff( $gd1->cell( 3, 3 ), 5 ), 'Set & get' );
        
        # Copy constructor with datatype
        for my $datatype2 ( undef, 'int', 'real' ) {
            my $gd2 = new Geo::Raster copy => $gd1, datatype => $datatype2;
            isa_ok( $gd2, 'Geo::Raster' );
            ok( diff( $gd1->cell( 3, 3 ), $gd2->cell( 3, 3 ) ),
                'New with copy constructor' );
        }
        
        # Copy constructor without datatype
        my $gd2 = Geo::Raster::new($gd1);
        isa_ok( $gd2, 'Geo::Raster' );
    }
}

# Testing the like constructor.
#
# Positive test case.
sub like_constructor_with_diff_types : Test(12) {
    my %dm = ( '' => 'Integer', int => 'Integer', real => 'Real' );
    for my $datatype1 ( '', 'int', 'real' ) {
        my $gd1 = new Geo::Raster( $datatype1, 5, 10 );
        my $dt1 = $gd1->data_type();
        ok( $dt1 eq $dm{$datatype1}, "Datatype: $dt1 eq $dm{$datatype1}" );
        for my $datatype2 ( '', 'int', 'real' ) {
            my $gd2 = new Geo::Raster like => $gd1, datatype => $datatype2;
            my $dt2 = $gd2->data_type();
            my $cmp = $dm{$datatype2};
            $cmp = $dm{$datatype1} if $datatype2 eq '';
            ok( $dt2 eq $cmp, "New like: $datatype2->$dt2 eq $cmp" );
        }
    }
}

# Creating a new raster with the world.
# In this test case the the world is defined
# using three min/max values and cell counts.
#
# Positive test case.
sub new_with_world_boundaries : Test {  

    my $gd = new Geo::Raster(
        datatype => 'integer',
        M        => 5,
        N        => 15,
        world    => { minx => 5, miny => 5, maxy => 10, maxx => 20}
        );
            
    my @world = $gd->world();
    ok(( $world[0] == 5 and $world[1] == 5 and
        $world[2] == 20 and $world[3] == 10), "New with world" );
}

# Creating a new raster with the world and grid size.
# In this test case the the world is defined using three min/max 
# values or two and the cell size (lenght of one side) of the 
# world.
#
# Positive test case.
sub new_with_world : Test(8) {
    use Switch;
    
    for (my $i=0; $i<4; $i++) {
        my $gd;
        switch($i) {
            case 0 {
                $gd = new Geo::Raster(
                    datatype => 'integer',
                    M        => 5,
                    N        => 15,
                    world    => { minx => 5, miny => 5, maxy => 10 });}
            case 1 {
                $gd = new Geo::Raster(
                    datatype => 'integer',
                    M        => 5,
                    N        => 15,
                    world    => { minx => 5, miny => 5, maxx => 20 });}
            case 2 {
                $gd = new Geo::Raster(
                    datatype => 'integer',
                    M        => 5,
                    N        => 15,
                    world    => { minx => 5, maxx => 20, maxy => 10 });}
            case 3 {
                $gd = new Geo::Raster(
                    datatype => 'integer',
                    M        => 5,
                    N        => 15,
                    world    => { miny => 5, maxx => 20, maxy => 10 });}
        }
        my @world = $gd->world();
        ok(( $world[0] == 5 and $world[1] == 5 and 
            $world[2] == 20 and $world[3] == 10 ), "New with world" );
    }
         
    my $gd = new Geo::Raster(
        datatype => 'integer',
        M        => 3,
        N        => 4,
        world    => { minx => 5, miny => 5, cellsize => 2 });
    my @world = $gd->world();
    ok(( $world[0] == 5 and $world[1] == 5 and 
        $world[2] == 13 and $world[3] == 11 ), "New with world" );
        
    $gd = new Geo::Raster(
        datatype => 'integer',
        M        => 5,
        N        => 2,
        world    => { minx => 5, maxy => 18, cellsize => 3 });
    @world = $gd->world();
    ok(( $world[0] == 5 and $world[1] == 3 and 
        $world[2] == 11 and $world[3] == 18 ), "New with world" );

    $gd = new Geo::Raster(
        datatype => 'integer',
        M        => 10,
        N        => 1,
        world    => { miny => 5, maxx => 20, cellsize => 1 });
    @world = $gd->world();
    ok(( $world[0] == 19 and $world[1] == 5 and 
        $world[2] == 20 and $world[3] == 15 ), "New with world" );

    $gd = new Geo::Raster(
        datatype => 'integer',
        M        => 10,
        N        => 100,
        world    => { maxy => 1000, maxx => 10000, cellsize => 100 });
    @world = $gd->world();
    ok(( $world[0] == 0 and $world[1] == 0 and 
        $world[2] == 10000 and $world[3] == 1000 ), "New with world" );
}

# Help routine.
sub diff {
    my ( $a1, $a2 ) = @_;
    
    return 0 unless defined $a1 and defined $a2;
    my $test = abs( $a1 - $a2 );
    $test /= $a1 unless $a1 == 0;
    abs($test) < 0.01;
}

1;
