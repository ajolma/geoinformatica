package Geo::Raster::OperatorTests;

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

# Tests include at the moment: 
# min, max, neg, plus, minus, times.
#
# Tests to be added to this file: 
# over, modulo, power, add, subtract, multiply_by, divide_by, modulus_with, to_power_of, 
# exp, abs, log, log10, sqrt, round, ceil, floor.
#
# Tests to be added to a another file:
# lt, gt, le, ge, eq, ne, cmp, not, and, or.
#
# Tests to be added to a third file:
# atan2, cos, sin, acos, atan, cosh, sinh, tan, tanh.

sub initialization_of_all_test_cases : Test(startup) {

};

# Creating two grids - a real and integer grid. 
# 
# 
sub create_grids : Test(setup) {
    my $self = shift;
    $self->{real_grid} = new Geo::Raster('real', 10, 10);
    $self->{integer_grid} = new Geo::Raster('int', 10, 10);
    $self->{datatypes}->[0] = 'int';#('int', 'real');
    $self->{datatypes}->[1] = 'real';
    
    $self->{real_tol} = 0.00001; # tolerance. 
    
    for(my $i=0; $i<10; $i++) {
        for(my $j=0; $j<10; $j++) {
            $self->{real_grid}->set($i, $j, 10*$i + $j - 50); # Values are from -50 to 49.
            $self->{integer_grid}->set($i, $j, 10*$i + $j - 50); # Values are from -50 to 49.
        }
    }
};

# Testing the max-operator.
sub max_operator : Test(4)
{
    my $self = shift;
    
    ok(abs($self->{real_grid}->max() - 49) < $self->{real_tol}, "Max operator on real grid");
    ok($self->{integer_grid}->max() == 49, "Max operator on integer grid");
    
    foreach my $u(0 .. 1){
         my $gd = new Geo::Raster($self->{datatypes}[$u], 10, 10);
        $gd->set(0);
        
        # Running the max operator using an another grid.
        my $real_gd = $self->{real_grid}->max($gd);
        my $int_gd = $self->{integer_grid}->max($gd); # Note can also be real :), int just refers to the original datatype.
    
        # Running the max operator using a threshold value.
        my $int_gd2;
        my $real_gd2;
        if($self->{datatypes}[$u] eq 'int') {
            $real_gd2 = $self->{real_grid}->max(0);
            $int_gd2 = $self->{integer_grid}->max(0); # Note can also be real :), int just refers to the original datatype.
        } else {
            $real_gd2 = $self->{real_grid}->max(0.0);
            $int_gd2 = $self->{integer_grid}->max(0.0); # Note can also be real :), int just refers to the original datatype.
        }

        my $error_count=0; # Boolean/count telling if the maximum values are correct.

        # Going trough the cells originally having smaller values.
        for(my $i=0; $i<5; $i++) {
            for(my $j=0; $j<10; $j++) {
                if($self->{datatypes}[$u] eq 'int') {
                    # The resulting grid is an integer grid if the other has also integer as datatype.
                    if(($int_gd2->get($i, $j) != 0) or ($int_gd->get($i, $j) != 0)) {
                        $error_count++;
                    } elsif(($real_gd2->get($i, $j) > $self->{real_tol}) or
                            ($real_gd->get($i, $j) > $self->{real_tol})) {
                        $error_count++;
                    }
                } elsif(($int_gd2->get($i, $j) > $self->{real_tol}) or 
                            ($int_gd->get($i, $j) != 0) or
                            ($real_gd2->get($i, $j) > $self->{real_tol}) or
                            ($real_gd->get($i, $j) > $self->{real_tol})) {
                    # The resulting grid always real.
                    $error_count++;
                }
            }
        }
        # Going trough the cells originally having equal or higher values.
        for(my $i=5; $i<10; $i++) {
            for(my $j=0; $j<10; $j++) {
                if($self->{datatypes}[$u] eq 'int') {
                    # The resulting grid is an integer grid if the other has also integer as datatype.
                    if(($int_gd->get($i, $j) - $self->{integer_grid}->get($i, $j) != 0) or
                            ($int_gd2->get($i, $j) - $self->{integer_grid}->get($i, $j) != 0)) {
                        $error_count++;
                    } elsif((abs($real_gd->get($i, $j) - $self->{real_grid}->get($i, $j)) > $self->{real_tol}) or
                            (abs($real_gd2->get($i, $j) - $self->{real_grid}->get($i, $j)) > $self->{real_tol})) {
                        $error_count++;
                    }
                } elsif((abs($int_gd->get($i, $j) - $self->{integer_grid}->get($i, $j)) > $self->{real_tol}) or
                        (abs($real_gd->get($i, $j) - $self->{real_grid}->get($i, $j)) > $self->{real_tol}) or
                        (abs($int_gd2->get($i, $j) - $self->{integer_grid}->get($i, $j)) > $self->{real_tol}) or
                        (abs($real_gd2->get($i, $j) - $self->{real_grid}->get($i, $j)) > $self->{real_tol})) {
                    $error_count++;
                }
            }
        }
        if($error_count > 0) {
            ok(0, "Max operator with second grid / value. Total error count: ".$error_count);
        } else {
            ok(1, "Max operator with second grid / value.");
        }
    }
}

# Testing the min-operator.
sub min_operator : Test(4)
{
    my $self = shift;
    ok(abs($self->{real_grid}->min() + 50) < $self->{real_tol}, "Min operator on real grid");
    ok($self->{integer_grid}->min() == -50, "Min operator on integer grid");
    
    # Going trough both datatypes (integer & real).
    foreach my $u(0 .. 1){
         my $gd = new Geo::Raster($self->{datatypes}[$u], 10, 10);
        $gd->set(0);
        
        # Running the min operator using a second grid.
        my $real_gd = $self->{real_grid}->min($gd);
        my $int_gd = $self->{integer_grid}->min($gd);

        # Running the min operator using a threshold value.
        my $real_gd2;
        my $int_gd2;
        if($self->{datatypes}[$u] eq 'int') {
            $real_gd2 = $self->{real_grid}->min(0);
            $int_gd2 = $self->{integer_grid}->min(0);
        } else {
            $real_gd2 = $self->{real_grid}->min(0.0);
            $int_gd2 = $self->{integer_grid}->min(0.0);
        }

        my $error_count=0; # Boolean/count telling if the minimum values are correct.
        
        # Going trough the cells originally having equal or higher values.
        for(my $i=5; $i<10; $i++) {
            for(my $j=0; $j<10; $j++) {
                if($self->{datatypes}[$u] eq 'int') {
                    # The resulting grid is an integer grid if the other has also integer as datatype.
                    if(($int_gd2->get($i, $j) != 0) or ($int_gd->get($i, $j) != 0)) {
                        $error_count++;
                    } elsif(($real_gd2->get($i, $j) > $self->{real_tol}) or
                            ($real_gd->get($i, $j) > $self->{real_tol})) {
                        $error_count++;
                    }
                } elsif(($int_gd2->get($i, $j) > $self->{real_tol}) or 
                            ($int_gd->get($i, $j) != 0) or
                            ($real_gd2->get($i, $j) > $self->{real_tol}) or
                            ($real_gd->get($i, $j) > $self->{real_tol})) {
                    # The resulting grid always real.
                    $error_count++;
                }
            }
        }   
        
        # Going trough the cells originally having smaller values.
        for(my $i=0; $i<5; $i++) {
            for(my $j=0; $j<10; $j++) {
                if($self->{datatypes}[$u] eq 'int') {
                    # The resulting grid is an integer grid if the other has also integer as datatype.
                    if(($int_gd->get($i, $j) - $self->{integer_grid}->get($i, $j) != 0) or
                            ($int_gd2->get($i, $j) - $self->{integer_grid}->get($i, $j) != 0)) {
                        $error_count++;
                    } elsif((abs($real_gd->get($i, $j) - $self->{real_grid}->get($i, $j)) > $self->{real_tol}) or
                            (abs($real_gd2->get($i, $j) - $self->{real_grid}->get($i, $j)) > $self->{real_tol})) {
                        $error_count++;
                    }
                } elsif((abs($int_gd->get($i, $j) - $self->{integer_grid}->get($i, $j)) > $self->{real_tol}) or
                        (abs($real_gd->get($i, $j) - $self->{real_grid}->get($i, $j)) > $self->{real_tol}) or
                        (abs($int_gd2->get($i, $j) - $self->{integer_grid}->get($i, $j)) > $self->{real_tol}) or
                        (abs($real_gd2->get($i, $j) - $self->{real_grid}->get($i, $j)) > $self->{real_tol})) {
                    $error_count++;
                }
            }
        }
        if($error_count > 0) {
            ok(0, "Min operator with second grid / value. Total error count: ".$error_count);
        } else {
            ok(1, "Min operator with second grid / value.");
        }
    }
}

# Testing negation.
sub neg : Test {
    my $self = shift;
    
    my $real_gd = $self->{real_grid}->neg();
    my $integer_gd = $self->{integer_grid}->neg();
    
    my $neg_result = 1;
    for(my $i=0; $i<10; $i++) {
        for(my $j=0; $j<10; $j++) {
            if((abs($real_gd->get($i, $j) + $self->{real_grid}->get($i, $j)) > $self->{real_tol}) or
                  ($integer_gd->get($i, $j) + $self->{integer_grid}->get($i, $j) != 0)) {
                $neg_result = 0;
                $i=10; $j=10;
            }
        }
    }   
    ok($neg_result, "Neg operator");
}

# Testing adding another grids values or a static value.
sub plus_operator : Test(2) {
    my $self = shift;

    # Going trough both datatypes (integer & real).
    foreach my $u(0 .. 1){
         my $gd = new Geo::Raster($self->{datatypes}[$u], 10, 10);
        $gd->set(2);
        
        # Running the plus operator using a second grid.
        my $real_gd = $self->{real_grid}->plus($gd);
        my $int_gd = $self->{integer_grid}->plus($gd);

        # Running the plus operator using a static value and overloading.
        my $real_gd2;
        my $int_gd2;
        if($self->{datatypes}[$u] eq 'int') {
            $real_gd2 = $self->{real_grid} + 2;
            $int_gd2 = $self->{integer_grid}->plus(2);
        } else {
            $real_gd2 = $self->{real_grid}->plus(2.0);
            $int_gd2 = $self->{integer_grid} + 2.0;
        }

        my $error_count=0; # Boolean/count telling if the values are correct.
        
        # Going trough the cells.
        for(my $i=0; $i<10; $i++) {
            for(my $j=0; $j<10; $j++) {
                if($self->{datatypes}[$u] eq 'int') {
                    # The resulting grid should be of type integer.
                    if(($int_gd2->get($i, $j) - $self->{integer_grid}->get($i, $j) != 2) or
                            ($int_gd->get($i, $j) - $self->{integer_grid}->get($i, $j) != 2)) {
                        $error_count++;
                    }
                    # The resulting grid should be of type real.
                    if((abs($real_gd2->get($i, $j) - $self->{real_grid}->get($i, $j) - 2) > $self->{real_tol}) or
                            (abs($real_gd->get($i, $j) - $self->{real_grid}->get($i, $j) - 2) > $self->{real_tol})) {
                        $error_count++;
                    }
                } elsif((abs($real_gd2->get($i, $j) - $self->{real_grid}->get($i, $j) - 2) > $self->{real_tol}) or
                            (abs($int_gd2->get($i, $j) - $self->{integer_grid}->get($i, $j) - 2) > $self->{real_tol}) or
                            (abs($real_gd->get($i, $j) - $self->{real_grid}->get($i, $j) - 2) > $self->{real_tol}) or 
                            (abs($int_gd->get($i, $j) - $self->{integer_grid}->get($i, $j) - 2) > $self->{real_tol})) {
                    # The resulting grid should be of type real.
                    $error_count++;
                }
            }
        }
        if($error_count > 0) {
            ok(0, "Plus operator with second grid / value. Total error count: ".$error_count);
        } else {
            ok(1, "Plus operator with second grid / value.");
        }
    }
}

# Testing subtracting another grids values or a static value.
sub minus_operator : Test(2) {
    my $self = shift;

    # Going trough both datatypes (integer & real).
    foreach my $u(0 .. 1){
         my $gd = new Geo::Raster($self->{datatypes}[$u], 10, 10);
        $gd->set(2);
        
        # Running the minus operator using a second grid.
        my $real_gd = $self->{real_grid}->minus($gd);
        my $int_gd = $self->{integer_grid}->minus($gd);

        # Running the minus operator using a static value and overloading.
        my $real_gd2;
        my $int_gd2;
        if($self->{datatypes}[$u] eq 'int') {
            $real_gd2 = $self->{real_grid} - 2;
            $int_gd2 = $self->{integer_grid}->minus(2);
        } else {
            $real_gd2 = $self->{real_grid}->minus(2.0);
            $int_gd2 = $self->{integer_grid} - 2.0;
        }

        my $error_count=0; # Boolean/count telling if the values are correct.
        
        # Going trough the cells.
        for(my $i=0; $i<10; $i++) {
            for(my $j=0; $j<10; $j++) {
                if($self->{datatypes}[$u] eq 'int') {
                    # The resulting grid should be of type integer.
                    if(($int_gd2->get($i, $j) - $self->{integer_grid}->get($i, $j) != -2) or
                            ($int_gd->get($i, $j) - $self->{integer_grid}->get($i, $j) != -2)) {
                        $error_count++;
                    }
                    # The resulting grid should be of type real.
                    if((abs($real_gd2->get($i, $j) - $self->{real_grid}->get($i, $j) + 2) > $self->{real_tol}) or
                            (abs($real_gd->get($i, $j) - $self->{real_grid}->get($i, $j) + 2) > $self->{real_tol})) {
                        $error_count++;
                    }
                } elsif((abs($real_gd2->get($i, $j) - $self->{real_grid}->get($i, $j) + 2) > $self->{real_tol}) or
                            (abs($int_gd2->get($i, $j) - $self->{integer_grid}->get($i, $j) + 2) > $self->{real_tol}) or
                            (abs($real_gd->get($i, $j) - $self->{real_grid}->get($i, $j) + 2) > $self->{real_tol}) or 
                            (abs($int_gd->get($i, $j) - $self->{integer_grid}->get($i, $j) + 2) > $self->{real_tol})) {
                    # The resulting grid should be of type real.
                    $error_count++;
                }
            }
        }
        if($error_count > 0) {
            ok(0, "Minus operator with second grid / value. Total error count: ".$error_count);
        } else {
            ok(1, "Minus operator with second grid / value.");
        }
    }
}

# Testing multiplying another grids values or by a static value.
sub times_operator : Test(2) {
   my $self = shift;

    # Going trough both datatypes (integer & real).
    foreach my $u(0 .. 1){
         my $gd = new Geo::Raster($self->{datatypes}[$u], 10, 10);
        $gd->set(2);
        
        # Running the times operator using a second grid.
        my $real_gd = $self->{real_grid}->times($gd);
        my $int_gd = $self->{integer_grid}->times($gd);

        # Running the times operator using a static value and overloading.
        my $real_gd2;
        my $int_gd2;
        if($self->{datatypes}[$u] eq 'int') {
            $real_gd2 = $self->{real_grid} * 2;
            $int_gd2 = $self->{integer_grid}->times(2);
        } else {
            $real_gd2 = $self->{real_grid}->times(2.0);
            $int_gd2 = $self->{integer_grid} * 2.0;
        }

        my $error_count=0; # Boolean/count telling if the values are correct.
        
        # Going trough the cells.
        for(my $i=0; $i<10; $i++) {
            for(my $j=0; $j<10; $j++) {
                if($self->{datatypes}[$u] eq 'int') {
                    # The resulting grid should be of type integer.
                    if(($int_gd2->get($i, $j) != $self->{integer_grid}->get($i, $j) * 2) or
                            ($int_gd->get($i, $j) != $self->{integer_grid}->get($i, $j) * 2)) {
                        $error_count++;
                    }
                    # The resulting grid should be of type real.
                    if((abs($real_gd2->get($i, $j) - $self->{real_grid}->get($i, $j) * 2) > $self->{real_tol}) or
                            (abs($real_gd->get($i, $j) - $self->{real_grid}->get($i, $j) * 2) > $self->{real_tol})) {
                        $error_count++;
                    }
                } elsif((abs($real_gd2->get($i, $j) - $self->{real_grid}->get($i, $j) * 2) > $self->{real_tol}) or
                            (abs($int_gd2->get($i, $j) - $self->{integer_grid}->get($i, $j) * 2) > $self->{real_tol}) or
                            (abs($real_gd->get($i, $j) - $self->{real_grid}->get($i, $j) * 2) > $self->{real_tol}) or 
                            (abs($int_gd->get($i, $j) - $self->{integer_grid}->get($i, $j) * 2) > $self->{real_tol})) {
                    # The resulting grid should be of type real.
                    $error_count++;
                }
            }
        }
        if($error_count > 0) {
            ok(0, "Times operator with second grid / value. Total error count: ".$error_count);
        } else {
            ok(1, "Times operator with second grid / value.");
        }
    }
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

sub round {
    my $number = shift;
    return int($number + 0.5);
}

sub min {
    my $a = shift;
    my $b = shift;
    return $a < $b ? $a : $b;
}

sub max {
    my $a = shift;
    my $b = shift;
    return $a > $b ? $a : $b;
}

1;
