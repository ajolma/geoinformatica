package Geo::Raster::BasicTests;

use base qw(Test::Class);
use strict;

#use Geo::Raster;
use UNIVERSAL qw(isa);

use Test::More;

# The very first test will verify that Geo::Raster is available.
# and load the module.
BEGIN {
    use_ok('Geo::Raster');
}

# Testing a too high integer value as no data value.
#
# Negative test case.
sub too_large_nodata_value : Test {
    my $gd = Geo::Raster->new( 5, 10 );
    eval { $gd->nodata_value(999999999); };
    ok( $@ =~ /out of bounds/,
        'Set too large int as nodata to int grid is an error' );
}

# Testing all the outside areas of the grid.
#
#     x  |  x  |  x
#    ____|_____|____
#        |     |
#     x  |GRID |  x
#    ____|_____|____
#        |     |
#     x  |  x  |  x
#
# Negative test cases.
sub set_outside_grid : Test(8) {
    my @grid_i_coords = ( -1, -2, -3, 2,  6,  3,  -1, -2 );
    my @grid_j_coords = ( -1, 2,  11, 12, 13, 14, 15, 9 );
    my $data_value    = 0;

    for ( my $i = 0 ; $i < 8 ; $i++ ) {
        my $gd = Geo::Raster->new( 5, 10 );
        eval {
            $gd->set( $grid_i_coords[$i], $grid_j_coords[$i], $data_value );
        };
        ok( $@ =~ /not on grid/, 'Set outside the grid' );
    }
}

# Testing that inserting inside the grid does not throw any exceptions.
#
# Positive test case.
sub set_inside_grid : Test {
    my $data_value = 0;
    my $gd = Geo::Raster->new( 5, 10 );
    eval { $gd->set( 3, 5, $data_value ); };
    is( $@, '' ); # $@ contains the exception that was thrown
}

# Testing that inserting inside the grid a nodata value works.
#
# Positive test case.
sub set_inside_of_grid_nodata : Test {
    my $gd = Geo::Raster->new( 5, 10 );
    $gd->nodata_value(-1);
    eval { $gd->set( 3, 5 ); };
    is( $@, '' ); # $@ contains the exception that was thrown
}

# Testing getting an array from a grid.
#
# Positive test case.
sub array : Test(2) {
    for my $datatype ( 'int', 'real' ) {
        my $gd = new Geo::Raster( $datatype, 5, 10 );
        # Set all values in the grid.
        $gd->set(5);
        # Change one single value.
        $gd->set( 4, 3, 2 );
        my ($points) = $gd->array();
        my $j = 0;
        my @p;
        for (@$points) {
            $p[$j] = "$_->[0],$_->[1] = $_->[2]";
            $j++;
        }
        ok( ( $p[17] eq '1,7 = 5' and $p[43] eq '4,3 = 2' ),
            "Array from grid" );
    }
}

# Testing dump and restore.
#
# Positive test case.
sub dump_and_restore : Test(14) {
    for my $datatype ( 'int', 'real' ) {
        my $gd = new Geo::Raster( $datatype, 5, 10 );
        $gd->set(5);
        $a   = new Geo::Raster( like => $gd );
        my @sgd = $gd->size();
        my @sa  = $a->size();
        for ( 0 .. 1 ) {
            ok( diff( $sgd[0], $sa[0] ), "New with like constructor" );
        }
        my $dump = 'dumptest';
        $gd->dump($dump);
        $a->restore($dump);
        ok( diff( $gd->cell( 3, 3 ), $a->cell( 3, 3 ) ), "Dump and restore" );

        $a = $gd == $a;
        my @nx = $a->value_range();
        ok( diff( $nx[0], $nx[1] ), "Value range after dump and restore" );
        ok( diff( $nx[1], 1 ), "Value range after dump and restore" );

        my $min = $a->min();
        my $max = $a->max();
        ok( diff( $min, $nx[0] ), "Min from min() after dump and restore" );
        ok( diff( $max, $nx[1] ), "Max from max() after dump and restore" );
    }
}

# Saving the raster to a file and loading the data from the file.
#
# Positive test case.
sub saving_and_loading_to_file : Test(2) {
    my $test_grid = 'test_grid.bil';

    for my $datatype ( 'int', 'real' ) {
        my $gd1 = new Geo::Raster( $datatype, 5, 10 );
        $gd1->set(5);
        $gd1->save($test_grid);
        my $gd2 = new Geo::Raster filename => $test_grid, load => 1;
        ok( diff( $gd1->cell( 3, 3 ), $gd2->cell( 3, 3 ) ),
            "Save/open grid to/from file" );
    }
    for ( '.hdr', '.bil' ) { unlink( $test_grid . $_ ) }
}

# Positive test case.
sub dump_and_restore_to_file : Test(2) {
    my $test_grid = 'test_grid.bil';

    for my $datatype ( 'int', 'real' ) {
        my $gd = new Geo::Raster( $datatype, 5, 10 );
        $gd->set( 1, 1, 1 );
        $gd->dump($test_grid);
        $gd->restore($test_grid);
        unlink($test_grid);
        ok( diff( $gd->cell( 1, 1 ), 1 ),
            'Dump to file and restore from file' );
    }
}

# Positive test case.
sub setting_world : Test(30) {
    my $gd1 = new Geo::Raster( 'i', 5, 10 );
    my %bm = (
        1 => 'cell_size',
        2 => 'minX',
        3 => 'minY',
        4 => 'maxX',
        5 => 'maxY'
    );

    #valid bounds:
    my %bounds = (
        cell_size => 1.5,
        minX      => 3.5,
        minY      => 2.5,
        maxX      => 18.5,
        maxY      => 10
    );
    for my $b (
        [ 1, 2, 3 ],
        [ 1, 2, 5 ],
        [ 1, 3, 4 ],
        [ 2, 3, 4 ],
        [ 2, 3, 5 ],
        [ 3, 4, 5 ]
      )
    {
        my %o;
        for ( 0 .. 2 ) {
            my $bm = $bm{ $b->[$_] };
            $o{$bm} = ( $bounds{$bm} );
        }

        #for (keys %o) {
        #    print STDERR "bo: $_ $o{$_}\n";
        #}
        $gd1->world(%o);
        my @attrib = $gd1->attributes();
        for ( 1 .. 5 ) {
            ok( diff( $bounds{ $bm{$_} }, $attrib[ 2 + $_ ] ),
                "Setting world to grid" );
        }
    }
}

# Positive test case.
sub copying_world_between_grids : Test(30) {
    my $gd1 = new Geo::Raster( 'i', 5, 10 );
    my %bm = (
        1 => 'cell_size',
        2 => 'minX',
        3 => 'minY',
        4 => 'maxX',
        5 => 'maxY'
    );
    my %bounds = (
        cell_size => 1.5,
        minX      => 3.5,
        minY      => 2.5,
        maxX      => 18.5,
        maxY      => 10
    );

    for my $b (
        [ 1, 2, 3 ],
        [ 1, 2, 5 ],
        [ 1, 3, 4 ],
        [ 2, 3, 4 ],
        [ 2, 3, 5 ],
        [ 3, 4, 5 ]
      )
    {
        my %o;
        for ( 0 .. 2 ) {
            my $bm = $bm{ $b->[$_] };
            $o{$bm} = ( $bounds{$bm} );
        }
        $gd1->world(%o);
        my $gd2 = new Geo::Raster( 5, 10 );
        $gd1->copy_world_to($gd2);
        my @attrib1 = $gd1->attributes();
        my @attrib2 = $gd2->attributes();
        for ( 1 .. 5 ) {
            ok( diff( $attrib1[ 2 + $_ ], $attrib2[ 2 + $_ ] ),
                "Setting world to grid" );
        }
    }
}

# Converting grid coordinates to world coordinates and vice versa.
#
# Positive test case.
sub converting_between_world_and_grid_coords : Test {
    my $gd = new Geo::Raster(100, 100);
    $gd->world( cell_size => 1.4, minX => 1.2, minY => 2.4 );

    my @point = $gd->g2w(3, 7);
    my @cell = $gd->w2g(@point);
    ok(( $cell[0] == 3 and $cell[1] == 7 ), 
    "World coordinates <-> grid coordinates");
}

# Trying to convert grid coordinates that are outside the grid
# to world coordinates.
#
# Positive test case.
#sub not_existing_grid_coords_to_world : Test {
#    my $gd = new Geo::Raster(100, 100);
#    $gd->world( cell_size => 1.4, minX => 1.2, minY => 2.4 );
#
#    eval { my @point = $gd->g2w(102, 50); };
#    ok($ ~= '', 'Not existing grid coordinates to world coordinates');
#}



# Converting the a grids boundaries to a bounding box in world coordinates.
#
#  0,0_________j      y
#    |                 |
#    |                 |
#    |           =>    |
#    |                 |_________
#   i                0,0         x
#
# Positive test case.
sub grid_boundaries_to_world_coords : Test(3)
{
    my $gd = new Geo::Raster(5, 5);
    $gd->world(minX => 10, minY => 10, maxX=>60, maxY=>60 );
    my @boundary_grid = (1, 1, 3, 3); # Min i, min j, max i, max j
    my @rectangle = $gd->ga2wa(@boundary_grid);
    ok(($rectangle[0] == 45 and $rectangle[1] == 45 and
        $rectangle[2] == 25 and $rectangle[3] == 25), 
        "Grid boundaries to world coordinates");

    $gd = new Geo::Raster(10, 10);
    $gd->world(minX => -10, minY => -10, maxX=>10, maxY=>10 );
    @boundary_grid = (0, 0, 9, 9); # Min i, min j, max i, max j
    @rectangle = $gd->ga2wa(@boundary_grid);

    ok(($rectangle[0] == 9 and $rectangle[1] == 9 and
        $rectangle[2] == -9 and $rectangle[3] == -9), 
        "Grid boundaries to world coordinates");

    $gd = new Geo::Raster(10, 10);
    $gd->world(minX => -10, minY => 10, maxX=>20, maxY=>20 );
    @boundary_grid = (0, 0, 9, 9); # Min i, min j, max i, max j
    @rectangle = $gd->ga2wa(@boundary_grid);
    
    ok(($rectangle[0] == 18.5 and $rectangle[1] == 38.5 and
        $rectangle[2] == -8.5 and $rectangle[3] == 11.5), 
        "Grid boundaries to world coordinates");
}

# Converting the a bounding box in world coordinates to grid boundaries.
#
#   y               0,0_________j
#    |                |
#    |                |
#    |           =>   |
#    |_________       |
#  0,0         x     i
#
# Positive test case.
sub world_coords_to_grid_boundaries : Test(3)
{
    # Testing on a small grid.
    my $gd = new Geo::Raster(5, 5);
    $gd->world(minX => 10, minY => 10, maxX=>60, maxY=>60 );
    my @rectangle = (25, 25, 45, 45); # Min x, min y, max y, max y
    my @boundary_grid = $gd->wa2ga(@rectangle);
    
    ok(($boundary_grid[0] == 1 and $boundary_grid[1] == 1 and
        $boundary_grid[2] == 3 and $boundary_grid[3] == 3), 
        "World coordinates to grid boundaries");

    $gd = new Geo::Raster(10, 10);
    $gd->world(minX => -10, minY => -10, maxX=>10, maxY=>10 );
    @rectangle = (-9, -9, 9, 9); # Min x, min y, max y, max y
    @boundary_grid = $gd->wa2ga(@rectangle);
    ok(($boundary_grid[0] == 0 and $boundary_grid[1] == 0 and
        $boundary_grid[2] == 9 and $boundary_grid[3] == 9), 
        "World coordinates to grid boundaries");
    
    $gd = new Geo::Raster(10, 10);
    $gd->world(minX => -10, minY => 10, maxX=>20, maxY=>20 );
    @rectangle = (-8.5, 11.5, 18.5, 38.5); # Min x, min y, max y, max y
    @boundary_grid = $gd->wa2ga(@rectangle);
     ok(($boundary_grid[0] == 0 and $boundary_grid[1] == 0 and
        $boundary_grid[2] == 9 and $boundary_grid[3] == 9), 
        "World coordinates to grid boundaries");
}

# Testing that getting zeros works.
#
# Positive test case.
sub point_from_zero_grid : Test(2)
{
    # Grid size is 100 * 50.
    my $gd = new Geo::Raster(100, 50);
    # Same value for all grid cells.
    $gd->set(0);
    # Note maxY is actually not used to define the world!
    $gd->world(minX => 3000000, minY => 55000000, maxX => 4000000, maxY => 57000000);

    ok((defined($gd->point(3000001, 55000001)) and 
        defined($gd->point(3999999, 56999999)) and 
        defined($gd->point(3999999, 55000001)) and 
        defined($gd->point(3000001, 56999999)) and 
        defined($gd->point(3500000, 56000000))), 
        'Point value from grid of zeros defined');
    
    ok(($gd->point(3500001, 55500001) == 0 and 
        $gd->point(3999999, 56999999) == 0 and 
        $gd->point(3999999, 55000001) == 0 and 
        $gd->point(3000001, 56999999) == 0 and 
        $gd->point(3500000, 56000000) == 0), 
        'Point value from grid of zeros');
    
#    ok(defined($gd->point(3000000, 55000000)), 'Point value from grid of zeros defined');
#    ok($gd->point(3000000, 55000000)==0, 'Point value from grid of zeros');
}

# Testing that getting nodata values works.
#
# Positive test case.
#sub point_from_nodata_grid : Test(8)
sub point_from_nodata_grid
{
    local $TODO = "Check if nodata value should even be gotten from a grid!";
    
    my $gd = new Geo::Raster(100, 50);
    # Note maxY is actually not used to define the world!
    $gd->world(minX => 3000000, minY => 55000000, maxX => 4000000, maxY => 57000000);
    
    for(my $i=0; $i<4; $i++) {
        # Define the nodata value.
        if($i == 0) {
            $gd->nodata_value(-1);
        } elsif($i == 1){
            $gd->nodata_value(255);
        } elsif($i == 1){
            $gd->nodata_value(0);
        } else {
            $gd->nodata_value(9999);
        }
        
        # Set to all cells a nodata value.
        if($i % 2 == 0) {
            $gd->set();
        } else {
            $gd->set('nodata');
        }
        
        ok((defined($gd->point(3000001, 55000001)) and 
            defined($gd->point(3999999, 56999999)) and 
            defined($gd->point(3999999, 55000001)) and 
            defined($gd->point(3000001, 56999999)) and 
            defined($gd->point(3500000, 56000000))), 
            'Point value from grid of nodata values defined'); 
    
        ok(($gd->point(3500001, 55500001) == -1 and 
            $gd->point(3999999, 56999999) == -1 and 
            $gd->point(3999999, 55000001) == -1 and 
            $gd->point(3000001, 56999999) == -1 and 
            $gd->point(3500000, 56000000) == -1), 
            'Point value from grid of nodata values');
    }
}

#
#
# Negative test case.
sub point_from_ouside_grid : Test
{
    my $gd = new Geo::Raster(100, 50);
    # Note maxY is actually not used to define the world!
    $gd->world(minX => 3000000, minY => 55000000, maxX => 4000000, maxY => 56000000); 
    
    ok((!defined($gd->point(-1, 0)) and
        !defined($gd->point(0, -1)) and
        !defined($gd->point(100, 0)) and
        !defined($gd->point(0, 50))), 
        'Point value from outside the grid is undefined');
}

# Testing if set field names are found.
#
# Positive test case.
sub check_for_field : Test(8)
{
    my @field_names = ("Continent", "Country", "State",  "Province", "Municipality", 
        "City", "Postal code", "Street");
    my @field_types = ("String", "String", "String",  "String", "String", "String", 
        "Integer", "String");
    my $gd = new Geo::Raster(100, 100);
    my @table = (\@field_names, \@field_types);
    
    $gd->table(\@table);
    
    for(my $i=0; $i < 8; $i++) {
        ok($gd->has_field($field_names[$i]), "Field name exists");
    }
}

# Testing if field names that do not exist are also not reported as existing.
#
# Negative test case.
sub check_for_not_existing_field : Test(8)
{
    my @field_names = ("Continent", "Country", "State",  "Province", "Municipality", 
        "City", "Postal code", "Street");
    my @field_types = ("String", "String", "String",  "String", "String", "String", 
        "Integer", "String");
    my @field_names_to_search = ("Continen", "ountry", "tat",  "Pprovince", "Municipalityy", 
        "", "P o s t a l c o d e", "STREET");
    my $gd = new Geo::Raster(100, 100);
    my @table = (\@field_names, \@field_types);
    
    $gd->table(\@table);
    
    for(my $i=0; $i<8; $i++) {
        ok(!$gd->has_field($field_names_to_search[$i]), "Field name does not exists");
    }
}

# Testing if the existing cells are reported existing trough their co-ordinates.
#
# Positive test case.
sub cell_in : Test
{
    my $gd = new Geo::Raster(100, 50);
    ok(($gd->cell_in(0, 0) and
        $gd->cell_in(0, 49) and
        $gd->cell_in(99, 0) and
        $gd->cell_in(99, 49)), 'Cell in');
}

# Testing if the non-existing cells are reported existing trough their 
# grid co-ordinates in all the outside areas of the grid.
#
#     x  |  x  |  x
#    ____|_____|____
#        |     |
#     x  |GRID |  x
#    ____|_____|____
#        |     |
#     x  |  x  |  x
#
# Negative test case.
sub cell_not_in : Test(8)
{
    my $gd = new Geo::Raster(100, 50);
    my @grid_i_coords = ( -1, -2, -3, 2, 99,  50,  -1, -2 );
    my @grid_j_coords = ( -1, 2,  25, 51, 50, 52, 50, 25 );
    
    for ( my $i = 0 ; $i < 8 ; $i++ ) {
        ok(!$gd->cell_in($grid_i_coords[$i], $grid_j_coords[$i]), 'Cell not in');
    }
}

# Testing if the existing real world points are reported existing 
# trough their real world co-ordinates.
#
# Positive test case.
sub point_in : Test
{
    my $gd = new Geo::Raster(
        datatype => 'integer',
        M        => 5,
        N        => 5,
        world    => { minx => 10, miny => 10, maxy => 20, maxx => 20});
        
    ok(($gd->point_in(10, 10) and
        $gd->point_in(10, 20) and 
        $gd->point_in(20, 10) and
        $gd->point_in(20, 20)), 'Point in');
}

# Testing if non-existing points are reported existing trough their 
# real world co-ordinates in all the outside areas of the real world bounding box.
#
#     x  |  x  |  x
#    ____|_____|____
#        |     |
#     x  |World|  x
#    ____|_____|____
#        |     |
#     x  |  x  |  x
#
# Negative test case.
sub point_not_in : Test(8)
{
    my $gd = new Geo::Raster(
        datatype => 'integer',
        M        => 5,
        N        => 5,
        world    => { minx => -10, miny => -10, maxy => 20, maxx => 20});
    my @x_coords = ( -11, -12, -13, 2, 20, 10,  -11, -12 );
    my @y_coords = ( -11, 2,  10, 21, 22, 23, 21, 10 );
    
    for ( my $i = 0 ; $i < 8 ; $i++ ) {
        ok(!$gd->point_in($x_coords[$i], $y_coords[$i]), 'Point not in');
    }
}

# $field_name and $field_name ne 'Cell value'

# Testing that the range works when the smallest value
# is the default value (0) and the highest value is a
# non-negative integer.
#
# Positive test case.
sub value_range_with_non_negative_integer : Test(18) {
    my $tolerance = 0;    # With integers the tolerance has to be zero.
    my @grid_i_coords = ( 0, 99, 0, 99, 50, 25 );
    my @grid_j_coords = ( 0, 99, 99, 0, 50, 75 );
    my @values        = ( 0, 1, 9999 );

    for ( my $i = 0 ; $i < 6 ; $i++ ) {
        for ( my $val = 0 ; $val < 3 ; $val++ ) {
            my $gd = new Geo::Raster( 100, 100 );
            $gd->set( $grid_i_coords[$i], $grid_j_coords[$i], $values[$val] );
            my $check = $gd->cell( $grid_i_coords[$i], $grid_j_coords[$i] );
            my ( $min, $max ) = $gd->value_range();
            ok((abs( $min - 0 ) <= $tolerance
                and abs( $max - $values[$val] ) <= $tolerance),
                "Value range after setting non-negative integers"
            );
        }
    }
}

# Testing that the range works when the smallest value
# is the default value (0) and the highest value is a
# positive double.
#
# Positive test case.
sub value_range_with_positive_double : Test(18) {
    my $tolerance     = 0.0001;
    my @grid_i_coords = ( 0, 99, 0, 99, 50, 25 );
    my @grid_j_coords = ( 0, 99, 99, 0, 50, 75 );
    my @values        = ( 0.00001, 0.99999, 1.23456 );

    for ( my $i = 0 ; $i < 6 ; $i++ ) {
        for ( my $val = 0 ; $val < 3 ; $val++ ) {
            my $gd = new Geo::Raster( 'real', 100, 100 );
            $gd->set( $grid_i_coords[$i], $grid_j_coords[$i], $values[$val] );
            my $check = $gd->cell( $grid_i_coords[$i], $grid_j_coords[$i] );
            my ( $min, $max ) = $gd->value_range();
            ok((abs( $min - 0 ) < $tolerance
                and abs( $max - $values[$val] ) < $tolerance
                ), "Value range after setting positive doubles");
        }
    }
}

# Testing that the range works when the highest value
# is the default value (0) and the smallest value is a
# negative integer.
#
# Positive test case.
sub value_range_with_negative_integer : Test(12) {
    my $tolerance = 0;    # With integers the tolerance has to be zero.
    my @grid_i_coords = ( 0, 99, 0, 99, 50, 25 );
    my @grid_j_coords = ( 0, 99, 99, 0, 50, 75 );
    my @values        = ( -1, -9999 );

    for ( my $i = 0 ; $i < 6 ; $i++ ) {
        for ( my $val = 0 ; $val < 2 ; $val++ ) {
            my $gd = new Geo::Raster( 100, 100 );
            $gd->set( $grid_i_coords[$i], $grid_j_coords[$i], $values[$val] );
            my $check = $gd->cell( $grid_i_coords[$i], $grid_j_coords[$i] );
            my ( $min, $max ) = $gd->value_range();
            ok((abs( $min - $values[$val] ) <= $tolerance
                and abs( $max - 0 ) <= $tolerance),
                "Value range after setting negative integers"
            );
        }
    }
}

# Testing that the range works when the highest value
# is the default value (0) and the smallest value is a
# negative double.
#
# Positive test case.
sub value_range_with_negative_double : Test(18) {
    my $tolerance     = 0.0001;
    my @grid_i_coords = ( 0, 99, 0, 99, 50, 25 );
    my @grid_j_coords = ( 0, 99, 99, 0, 50, 75 );
    my @values        = ( -0.00001, -0.99999, -9999.9999 );

    for ( my $i = 0 ; $i < 6 ; $i++ ) {
        for ( my $val = 0 ; $val < 3 ; $val++ ) {
            my $gd = new Geo::Raster( 'real', 100, 100 );
            $gd->set( $grid_i_coords[$i], $grid_j_coords[$i], $values[$val] );
            my $check = $gd->cell( $grid_i_coords[$i], $grid_j_coords[$i] );
            my ( $min, $max ) = $gd->value_range();
            ok((abs( $min - $values[$val] ) <= $tolerance
                and abs( $max - 0 ) <= $tolerance),
                "Value range after setting negative integers"
            );
        }
    }
}

# Testing that the set method returns the same value that has been put into the grid.
#
# Positive test case.
sub set_and_get_integer : Test(30) {
    my $tolerance = 0;

    my @grid_i_coords = ( 0, 99, 0,  99, 50, 25 );
    my @grid_j_coords = ( 0, 99, 99, 0,  50, 75 );
    my @values = ( -9999, -1, 0, 1, 9999 );

    for ( my $i = 0 ; $i < 6 ; $i++ ) {
        for ( my $val = 0 ; $val < 5 ; $val++ ) {
            my $gd = new Geo::Raster( 'integer', 100, 100 );
            $gd->set( $grid_i_coords[$i], $grid_j_coords[$i], $values[$val] );
            my $check = $gd->cell( $grid_i_coords[$i], $grid_j_coords[$i] );
            ok( ( abs( $values[$val] - $check ) <= $tolerance ),
                "Set and get integer" );
        }
    }
}

# Testing that the set method returns the same value that has been put into the grid.
#
# Positive test case.
sub set_and_get_double : Test(30) {
    my $tolerance = 0.0001;

    my @grid_i_coords = ( 0, 99, 0,  99, 50, 25 );
    my @grid_j_coords = ( 0, 99, 99, 0,  50, 75 );
    my @values = ( -9999.9999, -0.9999, 0.00001, 0.99999, 9999.9999 );

    for ( my $i = 0 ; $i < 6 ; $i++ ) {
        for ( my $val = 0 ; $val < 5 ; $val++ ) {
            my $gd = new Geo::Raster( 'real', 100, 100 );
            $gd->set( $grid_i_coords[$i], $grid_j_coords[$i], $values[$val] );
            my $check = $gd->cell( $grid_i_coords[$i], $grid_j_coords[$i] );
            ok( ( abs( $values[$val] - $check ) < $tolerance ),
                "Set and get double" );
        }
    }
}

#
# Positive test case.
sub mapping : Test(6)
{
    for my $datatype ('int','real') {
	my $g = new Geo::Raster($datatype, 5, 5);
	for my $i (0..4) {
	    for my $j (0..4) {
		$g->set($i,$j,$i+$j);
	    }
	}

	$g->map('*'=>12, [1,3]=>13, [5,7.1]=>56);

	ok($g->get(0,0) == 12, "default map $datatype");
	ok($g->get(0,1) == 13, "map $datatype 1");
	ok($g->get(1,4) == 56, "map $datatype 2");
    }
}

# Testing data function with zeros for nodata and ones for data.
#
# Positive test case.
sub data_with_zeros_and_ones : Test
{
    my $gd =  Geo::Raster->new( 15, 41 );
    # Set a nodata value to all cells.
    $gd->nodata_value(0);
    $gd->set();
    # Put a random amount of same values to a grid.
    my $values = random_value_amount($gd, 1);
    $gd->data();
    
    ok(value_count($gd, 1) == $values, 'Data function with zeros for nodata and ones for data.');
    # ok(value_count2($gd, 0) == 615 - $values, 'Data function with zeros for nodata and ones for data.');
}

# Testing data function with 10000 for nodata and random numbers 
# between -9999 and 9999 for data.
#
# Positive test case.
sub data_with_random_numbers : Test(4)
{
    my @nodata_values = (-10000, 10000);
    
    foreach my $nodata_value (@nodata_values) {
        my $gd =  Geo::Raster->new( 100, 100 );
        # Set a nodata value to all cells.
        $gd->nodata_value($nodata_value);
        $gd->set();
        # Put a random amount of same values to a grid.
        my $values = random_value_amount_of_random_numbers($gd, -9999, 9999);
        $gd->data();
        
        # print "VALUES: ".$values."\n";
        # print "VALUE_COUNT2: ".value_count_skipping_certain_value($gd, 0)."\n";
        
        ok($values == value_count_skipping_certain_value($gd, 0), 
            "Data function with random numbers for data.");
        ok($values == value_count($gd, 1), 
            "Data function with random numbers for data.");
    }
}

# Testing that the cell size is returned correctly.
#
sub cell_size_with_grid : Test(4)
{
    # By default the grid size is 1, else its calculated: (maxX-minX)/gd->N;
    my $gd = Geo::Raster->new('i', 100, 100);
    ok($gd->cell_size()==1, "Cell size");
    
    $gd = Geo::Raster->new(datatype=>'i', M=>100, N=>100);
    $gd->world(minx => 0, miny => 0, maxx=>100 );
    ok($gd->cell_size()==1, "Cell size");
   
    $gd =  Geo::Raster->new('integer', 50, 50);
    $gd->world(minx => -50, miny => -50, maxx=>50 );
    ok($gd->cell_size()==2, "Cell size");
    
    $gd =  Geo::Raster->new('integer', 10, 10);
    $gd->world( cell_size => 1.4, minX => 1.2, minY => 2.4 );
    ok($gd->cell_size()==1.4, "Cell size");
}

# Testing cloning with an integer grid.
#
# Positive test case.
sub cloning_integer_grid : Test(2)
{
    my $gd = Geo::Raster->new('int', 100, 100);
    
    #Setting values that are easily checked.
    for(my $i=0; $i<100; $i++) {
        for(my $j=0; $j<100; $j++) {
            $gd->set($i, $j, $i*$j);
        }
    }
    
    # Creating a clone.
    my $clone = $gd->clone();
    my $same_values = 1;
    
    # Checking values. 
    for(my $i=0; $i<100; $i++) {
        for(my $j=0; $j<100; $j++) {
            if($clone->get($i, $j) != $i*$j) {
                $same_values = 0;
            }
        }
    }
    ok($same_values, "Clone has same values as original grid");
    
    # Checking that the clone really is a clone and not the same object.
    $clone->set(50, 50, -100);
    ok(($clone->get(50, 50) == -100 and $gd->get(50, 50) != -100), 
        "Clone is really a clone and not the same object");
}

# Testing cloning with an real grid.
#
# Positive test case.
sub cloning_real_grid : Test(2)
{
    my $gd = Geo::Raster->new('real', 100, 100);
    my $tolerance = 0.0001;
    
    #Setting values that are easily checked.
    for(my $i=0; $i<100; $i++) {
        for(my $j=0; $j<100; $j++) {
            $gd->set($i, $j, $i*$j/10000);
        }
    }
    
    # Creating a clone.
    my $clone = $gd->clone();
    my $same_values = 1;
    
    # Checking values. 
    for(my $i=0; $i<100; $i++) {
        for(my $j=0; $j<100; $j++) {
            if(abs($clone->get($i, $j) - $i*$j/10000)>$tolerance) {
                
                print "Clone value: ".$clone->get($i, $j)." Orig value: ".$gd->get($i, $j)."\n";
         
                $same_values = 0;
            }
        }
    }
    ok($same_values, "Clone has same values as original grid");
    
    # Checking that the clone really is a clone and not the same object.
    $clone->set(50, 50, 1234.1234);
    ok((abs($clone->get(50, 50) - 1234.1234) < $tolerance and
        abs($gd->get(50, 50) - 1234.1234) > $tolerance), 
        "Clone is really a clone and not the same object");
}

# Testing the schema.
#
sub real_schema : Test(2)
{
    my $gd = Geo::Raster->new('real', 100, 100);
    my @field_names = ("Alfisols", "Andisols", "Aridisols", "Gelisol", "Histosols", "Spodosols", "Oxisols",
	"Vertisols", "Ultisols", "Mollisols", 
	"Inceptisols", "Entisols");
    my @field_types = ("Real", "Real", "Real", "Real", "Real", "Real", "Real", 
    "Real", "Real", "Real", "Real", "Real", "Real");
    my @table = (\@field_names, \@field_types);
    $gd->table(\@table);
    my $schema = $gd->schema();
    
    my $i=0;
    my @numbers;
    my $types_ok=1;
    foreach my $key (sort(keys %$schema)) {
        push @numbers, $schema->{$key}{Number};
        if($key eq 'cell value') {
            ok($schema->{$key}{TypeName} eq 'Real', "Schema type");
        } else {
            if($schema->{$key}{TypeName} ne "Real") {
               $types_ok = 0; 
            }
            $i++;
        }
    }
    
    ok($types_ok, "Schema types");
    
    $i = 0;
    my $numbers_ok = 1;
    foreach my $number (sort(@numbers)) {
        if($number !=$i) {
            $numbers_ok = 0;
        }
    }
    
    ok($types_ok, "Schema numbers");  
}

###############################
# Help subroutines - no tests #
###############################

sub diff {
    my ( $a1, $a2 ) = @_;

    #print "$a1 == $a2?\n";
    return 0 unless defined $a1 and defined $a2;
    my $test = abs( $a1 - $a2 );
    $test /= $a1 unless $a1 == 0;
    abs($test) < 0.01;
}

# Sets to the array cells randomly the given number 
# and returns the amount of set values.
sub random_value_amount {
    my ($gd, $value) = @_;
    my @gd_size = $gd->size();
    my $value_count=0;
    
    for(my $i=0; $i<$gd_size[0]; $i++) {
        for(my $j=0; $j<$gd_size[1]; $j++) {            
            my $random = rand(100);
            if($random > 50) {
                $gd->set($i, $j, $value);
                $value_count++;
            }
        }
    }
    return $value_count;
}

# Sets to the array cells randomly a number between the two
# given numbers and returns the amount of set values.
sub random_value_amount_of_random_numbers {
    my ($gd, $min_value, $max_value) = @_;
    my @gd_size = $gd->size();
    my $value_count=0;
    
    for(my $i=0; $i<$gd_size[0]; $i++) {
        for(my $j=0; $j<$gd_size[1]; $j++) {
            if(rand(100) > 50) {
                my $random_value = int(rand($max_value)) + $min_value;
                $gd->set($i, $j, $random_value);
                $value_count++;
            }
        }
    }
    return $value_count;
}

# Returns the amount of certain values in the grid.
# Uses the array function.
sub value_count_using_array {
    my ($gd, $value) = @_;
    my ($cells) = $gd->array();
    my $value_count = 0; 
    
    for (@$cells) {
        if($_->[2] == $value) {
            $value_count++;
        }
    }
    return $value_count;
}

# Returns the amount of certain values or any defined
# values (if no specific value is given) in the grid.
# Uses two for-loops.
sub value_count {
    my ($gd, $search_value) = @_;
    my @gd_size = $gd->size();
    my $value_count=0;
    
    if(defined($search_value)) {
        for(my $i=0; $i<$gd_size[0]; $i++) {
            for(my $j=0; $j<$gd_size[1]; $j++) {
                if(defined($gd->cell( $i, $j ))) {
                    if( $gd->cell( $i, $j ) == $search_value) {
                        $value_count++;
                    }
                }
            }
        }
    } else {
        for(my $i=0; $i<$gd_size[0]; $i++) {
            for(my $j=0; $j<$gd_size[1]; $j++) {
                if(defined($gd->cell( $i, $j ))) {
                    $value_count++;
                }
            }
        }
    }
    return $value_count;
}

# Returns the amount of certain values or any nodata 
# values (if no specific value is given) in the grid.
# Uses two for-loops.
sub value_count_skipping_certain_value {
    my ($gd, $skip_value) = @_;
    my @gd_size = $gd->size();
    my $value_count=0;
    
    if(defined($skip_value)) {
        for(my $i=0; $i<$gd_size[0]; $i++) {
            for(my $j=0; $j<$gd_size[1]; $j++) {
                if(defined($gd->cell( $i, $j ))) {
                    if($gd->cell( $i, $j ) != $skip_value) {
                        # print $gd->cell( $i, $j );
                        $value_count++;
                    }
                }
            }
        }
    }
    return $value_count;
}




#{
#    my $gd = new Geo::Raster('real',10,10);
#    $gd->nodata_value(-9999);
#    $gd->lt(1);
#    my $test = diff(-9999,$gd->nodata_value());
#    ok($test, "nodata in lt");
#}

1;
