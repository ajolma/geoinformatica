## @class Geo::Raster::Operations
# @brief Adds operations into Geo::Raster and overloads them
package Geo::Raster;

use overload (
	      'fallback' => undef,
	      '""'       => 'as_string',
	      'bool'     => 'bool',
              '='        => 'shallow_copy',
	      'neg'      => 'neg',
	      '+'        => 'plus',
	      '-'        => 'minus',	      
	      '*'        => 'times',
	      '/'        => 'over',
	      '%'        => 'modulo',
	      '**'       => 'power',
	      '+='       => 'add',
	      '-='       => 'subtract',
	      '*='       => 'multiply_by',
	      '/='       => 'divide_by',
	      '%='       => 'modulus_with',
	      '**='      => 'to_power_of',
	      '<'        => 'lt',
	      '>'        => 'gt',
	      '<='       => 'le',
	      '>='       => 'ge',
	      '=='       => 'eq',
	      '!='       => 'ne',
	      '<=>'      => 'cmp',
	      'atan2'    => 'atan2',
	      'cos'      => 'cos',
	      'sin'      => 'sin',
	      'exp'      => 'exp',
	      'abs'      => 'abs',
	      'log'      => 'log',
	      'sqrt'     => 'sqrt',
	      );

sub as_string {
    my $self = shift;
    return $self;
}

## @ignore
sub bool {
    return 1;
}

## @ignore
sub shallow_copy {
    my $self = shift;
    return $self;
}

## @method Geo::Raster neg()
#
# @brief Unary minus.
#
# @return A negated (multiplied by -1) raster.
sub neg {
    my $self = shift;
    my $copy = Geo::Raster->new($self);
    ral_grid_mult_integer($copy->{GRID}, -1);
    return $copy;
}

## @ignore
sub _typeconversion {
    my($self,$other) = @_;
    if (ref($other)) {
	if (isa($other, 'Geo::Raster')) {
	    return $REAL_GRID if 
		$other->{DATATYPE} == $REAL_GRID or 
		$self->{DATATYPE} == $REAL_GRID;
	    return $INTEGER_GRID;
	} else {
	    croak "$other is not a grid\n";
	}
    } else {
	# perlfaq4: is scalar an integer ?
	return $self->{DATATYPE} if $other =~ /^-?\d+$/;
	
	# perlfaq4: is scalar a C float ?
	if ($other =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) {
	    return $REAL_GRID if $self->{DATATYPE} == $INTEGER_GRID;
	    return $self->{DATATYPE};
	}
	croak "$other is not numeric\n";
    }
}


## @method Geo::Raster plus($value)
#
# @brief Adds to returned rasters cells this grids values plus the 
# given number.
#
# If this raster and the number differ in datatypes (other is integer and 
# the other real) then the returned raster will have as datatype real.
# 
# Example of summing
# @code
# $new_grid = $grid + $value;
# @endcode
# is the same as
# @code
# $new_grid = $grid->plus($value); 
# @endcode
#
# @param[in] value A number to add to this objects cell values.
# @return A copy of this raster with the additions from the other grid.
# @note In the case that this raster and the value differ in datatype, the 
# datatype conversion of the returned grid into real type makes it possible not 
# to use rounding.

## @method Geo::Raster plus(Geo::Raster second)
#
# @brief Adds to returned rasters cells this grids values plus the 
# given grids values.
#
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# - If rasters differ in datatypes (other is integer and the other real) 
# then the returned raster will have as datatype real.
# 
# Example of summing
# @code
# $new_grid = $grid + $second_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->plus($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
# @return A copy of this raster with the additions from the other grid.
# @note In the case of the two rasters differ in datatype, the datatype 
# conversion of the returned grid into real type makes it possible not to use 
# rounding (Also note that without the conversion the libral functions will 
# round that grids values that has real datatype).
sub plus {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    my $copy = Geo::Raster->new(datatype=>$datatype, copy=>$self);
    if (ref($second)) {
	ral_grid_add_grid($copy->{GRID}, $second->{GRID});
    } else {
	my $dt = ral_grid_get_datatype($copy->{GRID});
	if ($dt == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_add_integer($copy->{GRID}, $second);
	} else {
	    ral_grid_add_real($copy->{GRID}, $second);
	}
    }
    return $copy;
}

## @method Geo::Raster minus($value, $reversed)
#
# @brief Subtracts the given number from this grids values (or 
# vice versa if reversed is true) and gives those values to the returned grid.
#
# If this raster and the number differ in datatypes (other is integer and 
# the other real) then the returned raster will have as datatype real.
#
# Example of subtraction
# @code
# $new_grid = $grid - $value;
# @endcode
# is the same as
# @code
# $new_grid = $grid->minus($value);
# @endcode
#
# @param[in] value A number to subtract from this objects cell values.
# @param[in] reversed (optional) A boolean which tells in which order the 
# subtraction is done. If true, then the this objects grid cell values are 
# subtracted from the given value, else the the value is subtracted from this 
# grids values.
# @return A copy of this Geo::Raster with the subtractions made.
# @note In the case that this raster and the value differ in datatype, the 
# datatype conversion of the returned grid into real type makes it possible not 
# to use rounding.

## @method Geo::Raster minus(Geo::Raster second, $reversed)
#
# @brief Subtracts the given grids values from this grids values (or 
# vice versa if reversed is true) and gives those values to the returned grid.
#
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# - If rasters differ in datatypes (other is integer and the other real) 
# then the returned raster will have as datatype real.
#
# Example of subtraction
# @code
# $new_grid = $grid - $second_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->minus($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
# @param[in] reversed (optional) A boolean which tells in which order the 
# subtraction is done. If true, then the this objects grid cell values are 
# subtracted from the second grids cells values, else the second grids values 
# are subtracted from this grids values.
# @return A copy of this Geo::Raster with the subtractions made.
# @note In the case of the two rasters differ in datatype, the datatype 
# conversion of the returned grid into real type makes it possible not to use 
# rounding.
sub minus {
    my($self, $second, $reversed) = @_;
    my $datatype = $self->_typeconversion($second);
    my $copy = Geo::Raster->new(datatype=>$datatype, copy=>$self);
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_grid_sub_grid($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    ral_grid_mult_integer($copy->{GRID}, -1);
	} else {
	    $second *= -1;
	}
	
	if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    # Second parameter is an integer.
	    ral_grid_add_integer($copy->{GRID}, $second);
	} else {
	    # Second parameter is a real.
	    ral_grid_add_real($copy->{GRID}, $second);
	}
    }
    return $copy;
}

## @method Geo::Raster times($value)
#
# @brief Multiplies the rasters values with the given number 
# and returns a new grid with the resulting values.
#
# If this raster and the number differ in datatypes (other is integer and 
# the other real) then the returned raster will have as datatype real.
#
# Example of multiplication
# @code
# $new_grid = $grid * $value;
# @endcode
# is the same as
# @code
# $new_grid = $grid->times($value);
# @endcode
#
# @param[in] value A number with which to multiply this objects cell values.
# @return A copy of this Geo::Raster with the multiplication made.
# @note In the case that this raster and the given value differ in datatype, the 
# datatype conversion of the returned grid into real type makes it possible not 
# to use rounding.

## @method Geo::Raster times(Geo::Raster second)
#
# @brief Multiplies the rasters values with the given grids
# values and returns a new grid with the resulting values.
#
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# - If rasters differ in datatypes (other is integer and the other real) 
# then the returned raster will have as datatype real.
#
# Example of multiplication
# @code
# $new_grid = $grid * $second_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->times($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
# @return A copy of this Geo::Raster with the multiplication made.
# @note In the case of the two rasters differ in datatype, the datatype 
# conversion of the returned grid into real type makes it possible not to use 
# rounding.
sub times {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    my $copy = Geo::Raster->new(datatype=>$datatype, copy=>$self);
    if (ref($second)) {
	ral_grid_mult_grid($copy->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_mult_integer($copy->{GRID},$second);
	} else {
	    ral_grid_mult_real($copy->{GRID},$second);
	}
    }
    return $copy;
}

## @method Geo::Raster over($value, $reversed)
#
# @brief Divides the grids values with the number (or vice versa if reversed is 
# true) and returns the resulting values as a new raster.
#
# Example of division
# @code
# $new_grid = $grid / $value;
# @endcode
# is the same as
# @code
# $new_grid = $grid->over($value); 
# @endcode
#
# @param[in] value A number to use for dividing.
# @param[in] reversed (optional) A boolean which tells which one (the raster set 
# or the number) is the denominator. 
# If true then the this grids values are used as denominators, if
# false then the given number is used as denominator (the same thing as if 
# parameter would not be given at all).
# @return A copy of this Geo::Raster with the division made.
# @note The returned raster will always have as datatype real.

## @method Geo::Raster over(Geo::Raster second, $reversed)
#
# @brief Divides the grids values with the other grids values(or 
# vice versa if reversed is true) and returns the resulting values as a new 
# raster.
#
# The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
#
# Example of division
# @code
# $new_grid = $grid / $second_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->over($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
# @param[in] reversed (optional) A boolean which tells which raster set is the 
# denominator. If true then the this grids values are used as denominators, if
# false then given grid values are denominators (the same thing as if parameter
# would not be given at all).
# @return A copy of this Geo::Raster with the division made.
# @note The returned raster will always have as datatype real.
sub over {
    my($self, $second, $reversed) = @_;
    my $copy = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_grid_div_grid($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_integer_div_grid($second, $copy->{GRID});
	    } else {
		ral_real_div_grid($second, $copy->{GRID});
	    }
	} else {
	    if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_div_integer($copy->{GRID}, $second);
	    } else {
		ral_grid_div_real($copy->{GRID}, $second);
	    }
	}
    }
    return $copy;
}



sub over2 {
    my($self, $second, $reversed) = @_;
    my $copy;
    if($reversed) {
        $copy = new Geo::Raster datatype=>$REAL_GRID, copy=>$second;
    } else {
        $copy = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    }
    
    if (ref($second)) {
	# ($copy, $second) = ($second, $copy) if $reversed;
	if($reversed) {
	    ral_grid_div_grid($copy->{GRID}, $self->{GRID});
	} els {
	     ral_grid_div_grid($copy->{GRID}, $second->{GRID});
	}
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_integer_div_grid($second, $copy->{GRID});
	    } else {
		ral_real_div_grid($second, $copy->{GRID});
	    }
	} else {
	    if (ral_grid_get_datatype($copy->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_div_integer($copy->{GRID}, $second);
	    } else {
		ral_grid_div_real($copy->{GRID}, $second);
	    }
	}
    }
    return $copy;
}

## @method Geo::Raster modulo($value, $reversed)
#
# @brief Calculates the modulus gotten by dividing the grids values with 
# the given number (or vice versa if reversed is true) and 
# returns a new grid with result values.
#
# Example of modulus
# @code
# $new_grid = $grid % $value;
# @endcode
# is the same as
# @code
# $new_grid = $grid->modulo($value); 
# @endcode
#
# @param[in] value A integer number used for dividing.
# @param[in] reversed (optional) A boolean which tells which one (the raster set 
# or the number) is the denominator. 
# If true then the this grids values are used as denominators, if
# false then the given number is used as denominator (the same thing as if 
# parameter would not be given at all).
# @return A copy of this Geo::Raster with the division remainders.
# @note This raster has to have integer as datatype and
# the returned raster will always have integer as datatype.

## @method Geo::Raster modulo(Geo::Raster second, $reversed)
#
# @brief Calculates the modulus gotten by dividing the grids values with 
# the given grids values (or vice versa if reversed is true) and 
# returns a new grid with result values.
#
# The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
#
# Example of modulus
# @code
# $new_grid = $grid % $second_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->modulo($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster having integer as datatype.
# @param[in] reversed (optional) A boolean which tells which raster set is the 
# divisor and dividend. If true then the this grids values are used as 
# denominators, if false then given grid values or the number are denominators 
# (the same thing as if parameter would not be given at all).
# @return A copy of this Geo::Raster with the division remainders.
# @note This raster has to have integer as datatype and
# the returned raster will always have integer as datatype.
sub modulo {
    my($self, $second, $reversed) = @_;
    my $copy = new Geo::Raster($self);
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_grid_modulus_grid($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    ral_integer_modulus_grid($second, $copy->{GRID});
	} else {
	    ral_grid_modulus_integer($copy->{GRID}, $second);
	}
    }
    return $copy;
}

## @method Geo::Raster power($value, $reversed)
#
# @brief Calculates the exponential values gotten by using the grids values 
# as bases the given number as exponents (or vice versa if 
# reversed is true) and returns a new grid with the calculated values.
#
# If this raster and the number differ in datatypes (other is integer and 
# the other real) then the returned raster will have as datatype real.
#
# Example of rising to the power defined by the parameter
# @code
# $new_grid = $grid ** $exponent;
# @endcode
# is the same as
# @code
# $new_grid = $grid->power($exponent); 
# @endcode
#
# @param[in] value A number used as exponent (or base, if reversed is true).
# @param[in] reversed (optional) A boolean which tells which one (the raster set 
# or the number) is the exponent, and which as base. 
# If true then the this grids values are used as exponents, if false then the 
# given number is used as exponent (the same thing as if parameter would not be 
# given at all).
# @return A copy of this Geo::Raster with the exponentation done.

## @method Geo::Raster power(Geo::Raster second, $reversed)
#
# @brief Calculates the exponential values gotten by using the grids values 
# as bases the given grids values as exponents (or vice versa if 
# reversed is true) and returns a new grid with the calculated values.
#
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# - If the rasters differ in datatypes (other is integer and the other real) 
# then the returned raster will have as datatype real.
#
# Example of rising to the powers defined the given grid
# @code
# $new_grid = $grid ** $exponent_grid;
# @endcode
# is the same as
# @code
# $new_grid = $grid->power($exponent_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
# @param[in] reversed (optional) A boolean which tells which raster set is the 
# base and which the exponent. If true then the this grids values are used as 
# exponents, if false then given grid values or the number are exponents 
# (the same thing as if parameter would not be given at all).
# @return A copy of this Geo::Raster with the exponentation done.
sub power {
    my($self, $second, $reversed) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    my $copy = Geo::Raster->new(datatype=>$datatype, copy=>$self);
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_grid_power_grid($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    ral_realpower_grid($second, $copy->{GRID});
	} else {
	    ral_grid_power_real($copy->{GRID}, $second);
	}
    }
    return $copy;
}

## @method add($value)
#
# @brief Adds the given number to the cell values.
#
# - The method is almost the same as Geo::Raster::plus(), except that in this 
# method the addition is done directly to this grid, not a new one.
# - If this raster and the number differ in datatypes (other is integer and 
# the other real) then this raster will have as datatype real after the 
# operation.
#
# Example of addition
# @code
# $grid += $value;
# @endcode
# is the same as
# @code
# $grid->add($value); 
# @endcode
#
# @param[in] value The number to add.

## @method Geo::Raster add(Geo::Raster second)
#
# @brief Adds to the cells the respective cell values of the given raster 
#
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# - If rasters differ in datatypes (other is integer and the other real) 
# then the this raster will have as datatype real.
# - The method is almost the same as Geo::Raster::plus(), except that in this 
# method the addition is done directly to this grid, not a new one.
# 
# Example of addition
# @code
# $grid += $second_grid;
# @endcode
# is the same as
# @code
# $grid->add($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster or a number.
sub add {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $datatype)) 
    	if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_grid_add_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_add_integer($self->{GRID}, $second);
	} else {
	    ral_grid_add_real($self->{GRID}, $second);
	}
    }
    return $self;
}

## @method Geo::Raster subtract($value)
#
# @brief Subtracts the given number from the cell values.
#
# - The method is almost the same as Geo::Raster::minus(), except that in this 
# method the subtraction is done directly to this grid, not a new one. And there
# is also no reversed possibility.
# - If this raster and the number differ in datatypes (other is integer and 
# the other real) then this raster will have as datatype real after the 
# operation.
#
# Example of subtraction
# @code
# $grid -= $value;
# @endcode
# is the same as
# @code
# $grid->subtract($value); 
# @endcode
#
# @param[in] value A number that is subtracted from all cells of this grid.

## @method Geo::Raster subtract(Geo::Raster second)
#
# @brief Subtracts from the cell value the respective cell values of the given raster.
#
# - The method is almost the same as Geo::Raster::minus(), except that in this 
# method the subtraction is done directly to this grid, not a new one. And there
# is also no reversed possibility.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# - If rasters differ in datatypes (other is integer and the other real) 
# then this raster will have as datatype real after the method.
#
# Example of subtraction
# @code
# $grid -= $second_grid;
# @endcode
# is the same as
# @code
# $grid->subtract($second_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
sub subtract {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_grid_sub_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_add_integer($self->{GRID}, -$second);
	} else {
	    ral_grid_add_real($self->{GRID}, -$second);
	}
    }
    return $self;
}

## @method Geo::Raster multiply_by($value)
#
# @brief Multiplies the cell values with the given number.
#
# - The method is almost the same as Geo::Raster::times(), except that in this 
# method the multiplication is done directly to this grid, not a new one!
# - If this raster and the number differ in datatypes (other is integer and 
# the other real) then this raster will have as datatype real after the 
# operation.
#
# Example of multiplication
# @code
# $grid *= $multiplier;
# @endcode
# is the same as
# @code
# $grid->multiply_by($multiplier); 
# @endcode
#
# @param[in] value Number used as multiplier.

## @method Geo::Raster multiply_by(Geo::Raster second)
#
# @brief Multiplies the cell values with the respective cell values of the given raster.
#
# - The method is almost the same as Geo::Raster::times(), except that in this 
# method the multiplication is done directly to this grid, not a new one!
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# - If rasters differ in datatypes (other is integer and the other real) 
# then this rasters datatype will be real after the calculation.
#
# Example of multiplication
# @code
# $grid *= $multiplier_grid;
# @endcode
# is the same as
# @code
# $grid->multiply_by($multiplier_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster.
sub multiply_by {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_grid_mult_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_mult_integer($self->{GRID}, $second);
	} else {
	    ral_grid_mult_real($self->{GRID}, $second);
	}
    }
    return $self;
}

## @method Geo::Raster divide_by($value)
#
# @brief Divides the cell values with the given number.
#
# - The method is almost the same as Geo::Raster::over(), except that in this 
# method the division is done directly to this grid, not a new one. And there
# is also no reversed possibility.
#
# Example of division
# @code
# $grid /= $denominator;
# @endcode
# is the same as
# @code
# $grid->divide_by($denominator); 
# @endcode
#
# @param[in] value Number used as denominator.
# @note The returned raster will always have as datatype real.

## @method Geo::Raster divide_by(Geo::Raster second)
#
# @brief Divides the cell values with the respective cell values of the other raster.
#
# - The method is almost the same as Geo::Raster::over(), except that in this 
# method the division is done directly to this grid, not a new one. And there
# is also no reversed possibility.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
#
# Example of division
# @code
# $grid /= $denominator_grid;
# @endcode
# is the same as
# @code
# $grid->divide_by($denominator_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster, which cells values are 
# used as denominators.
# @note The returned raster will always have as datatype real.
sub divide_by {
    my($self, $second) = @_;
    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    if (ref($second)) {
	ral_grid_div_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_div_integer($self->{GRID}, $second);
	} else {
	    ral_grid_div_real($self->{GRID}, $second);
	}
    }
    return $self;
}

## @method Geo::Raster modulus_with($value)
#
# @brief Calculates the modulus gotten by dividing the cell values with 
# the given integer value.
#
# The method is almost the same as Geo::Raster::modulo(), except that in this 
# method the modulus is done directly to this grid, not a new one. And there
# is also no reversed possibility.
#
# Example of calculating the modulus
# @code
# $grid %= $denominator;
# @endcode
# is the same as
# @code
# $grid->modulus_with($denominator); 
# @endcode
#
# @param[in] value Number to use as denominator.
# @note The operation does not affect the datatype.

## @method Geo::Raster modulus_with(Geo::Raster second)
#
# @brief Calculates the modulus gotten by dividing the cell values with 
# the respective cell values of the given integer raster.
#
# - The method is almost the same as Geo::Raster::modulo(), except that in this 
# method the modulus is done directly to this grid, not a new one. And there
# is also no reversed possibility.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
#
# Example of calculating the modulus
# @code
# $grid %= $denominator_grid;
# @endcode
# is the same as
# @code
# $grid->modulus_with($denominator_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster, which values are used
# as denominators.
# @note The operation does not affect the datatype.
sub modulus_with {
    my($self, $second) = @_;
    if (ref($second)) {
	ral_grid_modulus_grid($self->{GRID}, $second->{GRID});
    } else {
	ral_grid_modulus_integer($self->{GRID}, $second);
    }
    return $self;
}

## @method Geo::Raster to_power_of($power)
#
# @brief Raises the cell values to the given power.
# 
# - The method is almost the same as Geo::Raster::power(), except that in this 
# method the power is calculated directly to this grid, not a new one. And there
# is also no reversed possibility.
# - If this raster and the parameter differ in datatypes (other is integer 
# and the other real) then this raster will have as datatype real after the 
# operation.
#
# Example of calculating the power
# @code
# $grid **= $exponent;
# @endcode
# is the same as
# @code
# $grid->to_power_of($exponent); 
# @endcode
#
# @param[in] power Number used as exponent.

## @method Geo::Raster to_power_of(Geo::Raster second)
#
# @brief Raises the cell values to the power of the respective cell values of the given raster.
#
# - The method is almost the same as Geo::Raster::power(), except that in this 
# method the power is calculated directly to this grid, not a new one. And there
# is also no reversed possibility.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# - If the rasters differ in datatypes (other is integer and the other real) 
# then this rasters datatype will have after the operation as datatype real.
#
# Example of calculating the power
# @code
# $grid **= $exponent_grid;
# @endcode
# is the same as
# @code
# $grid->to_power_of($exponent_grid); 
# @endcode
#
# @param[in] second Reference to an another Geo::Raster defining the exponents 
# for each cell.
sub to_power_of {
    my($self, $second) = @_;
    my $datatype = $self->_typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_grid_power_grid($self->{GRID}, $second->{GRID});
    } else {
	ral_grid_power_real($self->{GRID}, $second);
    }
    return $self;
}

## @method Geo::Raster atan2(Geo::Raster second)
#
# @brief Calculates the arctangent between each cells value of the grid and 
# given grids values.
#
# - With the arctangent we get the direction between the two cell values in
# 2-dimemsional Euclidean space.
# - The operation is performed in-place in void context
# - The second rasters real world boundaries must be the same as this
# rasters. The cell sizes and amounts in both directions must also be equal.
#
# @param[in] second Reference to an another Geo::Raster.
# @return A new Geo::Raster having the calculated directions.
# @note The resulting raster will always have as datatype real.
sub atan2 {
    my($self, $second) = @_;
    if (ref($self) and ref($second)) {
	if (defined wantarray) {
	    $self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
	} elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	    $self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
	}
	ral_grid_atan2($self->{GRID}, $second->{GRID});
	return $self;
    } else {
	croak "don't mix scalars and grids in atan2, please";
    }
}

## @method Geo::Raster cos()
#
# @brief Calculates the cosine of the grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated cosine values.
# @note The resulting raster will always have as datatype real.
sub cos {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_cos($self->{GRID});
    return $self;
}

## @method Geo::Raster sin()
#
# @brief Calculates the sine of the grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the sine values.
# @note The resulting raster will always have as datatype real.
sub sin {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_sin($self->{GRID});
    return $self;
}

## @method Geo::Raster exp()
#
# @brief Calculates the exponential function with Euler's number as base of the 
# grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculation results.
# @note The resulting raster will always have as datatype real.
sub exp {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_exp($self->{GRID});
    return $self;
}

## @method Geo::Raster abs()
#
# @brief Calculates the absolute value of the grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having non-negative values.
sub abs {
    my $self = shift;
    if (defined wantarray) {
	my $copy = new Geo::Raster($self);
	ral_grid_abs($copy->{GRID});
	return $copy;
    } else {
	ral_grid_abs($self->{GRID});
    }
}

## @method Geo::Raster sqrt()
#
# @brief Calculates the square root of the grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
# @note The resulting raster will always have as datatype real.
sub sqrt {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_sqrt($self->{GRID});
    return $self;
}

## @method Geo::Raster round()
#
# @brief Rounds grids each value to the nearest integer value.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
# - If the raster has already a as datatype integer, the operation does 
# nothing.
#
# @return A new Geo::Raster having the integer values.
# @note The resulting raster will always have as datatype integer.
sub round {
    my $self = shift;
    if (ref($self)) {
	my $grid = ral_grid_round($self->{GRID});
	return unless $grid;
	if (defined wantarray) {
	    my $new = new Geo::Raster $grid;
	    return $new;
	} else {
	    $self->_new_grid($grid);
	}
    } else {
	return $self < 0 ? POSIX::floor($self - 0.5) : POSIX::floor($self + 0.5);
    }
}

{
    no warnings 'redefine';

## @method Geo::Raster acos()
#
# @brief Calculates the arccosine of the grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
# @note The resulting raster will always have as datatype real.
sub acos {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_acos($self->{GRID});
    return $self;
}

## @method Geo::Raster atan()
#
# @brief Calculates the arctangent of the grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
# @note The resulting raster will always have as datatype real.
sub atan {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_atan($self->{GRID});
    return $self;
}

## @method Geo::Raster ceil()
#
# @brief Calculates the ceiling of the grids each value.
#
# Ceiling is the smallest integer value not less than the grids original value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
sub ceil {
    my $self = shift;
    if (ref($self)) {
	$self = new Geo::Raster($self) if defined wantarray;
	ral_grid_ceil($self->{GRID});
	return $self;
    } else {
	return POSIX::ceil($self);
    }
}

## @method Geo::Raster cosh()
#
# @brief Calculates the hyperbolic cosine of the grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated cosine values.
# @note The resulting raster will always have as datatype real
sub cosh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_cosh($self->{GRID});
    return $self;
}

## @method Geo::Raster floor()
#
# @brief Calculates the ceiling of the grids each value.
#
# Floor is the largest integer value not higher than the grids original value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values
sub floor {
    my $self = shift;
    if (ref($self)) {
	$self = new Geo::Raster($self) if defined wantarray;
	ral_grid_floor($self->{GRID});
	return $self;
    } else {
	return POSIX::floor($self);
    }
}

## @method Geo::Raster log()
#
# @brief Calculates the logarithm of the grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the logarithmic values.
# @note The resulting raster will always have as datatype real.
sub log {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_log($self->{GRID});
    return $self;
}

## @method Geo::Raster log10()
#
# @brief Calculates the base-10 logarithm of the grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the logarithmic values.
# @note The resulting raster will always have as datatype real.
sub log10 {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_log10($self->{GRID});
    return $self;
}

## @fn log_base($base, $value)
#
# @brief Calculates the logarithm with a desired base, for example 2 or 10.
# @param base Desired logarithm base, for example 2 or 10.
# @param value Value for which the logarithm is calculated.
# @return The result of the logarithm function.
sub log_base {
    my ($base, $value) = @_;
    return CORE::log($value)/CORE::log($base);
}

## @method Geo::Raster sinh()
#
# @brief Calculates the hyperbolic sine of the grids each value.
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated hyperbolic sine values.
# @note The resulting raster will always have as datatype real
sub sinh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_sinh($self->{GRID});
    return $self;
}

## @method Geo::Raster tan()
#
# @brief Calculates the tangent of the grids each value.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
# @note The resulting raster will always have as datatype real.
sub tan {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_tan($self->{GRID});
    return $self;
}

## @method Geo::Raster tanh()
#
# @brief Calculates the hyperbolic tangent of the grids each value.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the calculation results is returned.
#
# @return A new Geo::Raster having the calculated values.
# @note The resulting raster will always have as datatype real.
sub tanh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_grid_create_copy($self->{GRID}, $REAL_GRID));
    }
    ral_grid_tanh($self->{GRID});
    return $self;
}
}

## @method Geo::Raster lt($number, $reversed)
#
# @brief The method tells if the rasters cells have smaller values than the 
# given given number. Comparison result is returned if needed.
#
# There are four cases of the use of comparison operations between this grid and a number:
# <center><table border="1">
# <tr><th>Case</th><th>Example</th>     <th>a unchanged</th>  <th>self</th> <th>number</th> <th>reversed</th><th>wantarray defined</th></tr>
# <tr><td>1.</td><td>b = a->lt(n);</td>   <td>yes</td>        <td>a</td>    <td>n</td>       <td>no</td>         <td>yes</td></tr>
# <tr><td>2.</td><td>a->lt(n);</td>       <td>no</td>         <td>a</td>    <td>n</td>       <td>no</td>         <td>no</td></tr>
# <tr><td>3.</td><td>b = a < n;</td>      <td>yes</td>        <td>a</td>    <td>n</td>       <td>no</td>         <td>yes</td></tr>
# <tr><td>4.</td><td>b = n < a;</td>      <td>yes</td>        <td>a</td>    <td>n</td>       <td>yes</td>        <td>yes</td></tr>
# </table></center>
#
# The operation is performed to this raster, if no resulting new raster 
# grid is needed (look at case 2), else a new grid with the comparison results 
# is returned.
# 
# @param[in] number Number used for comparison.
# @param[in] reversed (optional) Tells the comparison order. If true then the 
# method checks if the given parameters value(s) are less than the rasters 
# cells values. If false, then the method acts as no reverse parameter would 
# have given.
# @return Geo::Raster, which has zeros (0) in those cells that are greater or 
# equal and therefor don't fulfil the comparison condition. If the rasters 
# value is less than the comparison value, then the cell gets a value true (1).
# @note If this grids some cells do not have any value, those cells 
# resulting value will also be undef.

## @method Geo::Raster lt(Geo::Raster second)
#
# @brief The method tells if the rasters cells have smaller values than the 
# given rasters cells. Comparison result is returned if needed.
#
# There are three cases of the use of comparison operations between two grids:
# <table border="1">
# <tr><th>Case</th><th>Example</th>     <th>a unchanged</th>  <th>self</th> <th>second</th> <th>wantarray defined</th></tr>
# <tr><td>1.</td><td>c = a->lt(b);</td>   <td>yes</td>        <td>a</td>    <td>b</td>       <td>yes</td></tr>
# <tr><td>2.</td><td>a->lt(b);</td>       <td>no</td>         <td>a</td>    <td>b</td>       <td>no</td></tr>
# <tr><td>3.</td><td>c = a < b;</td>      <td>yes</td>        <td>a</td>    <td>b</td>       <td>yes</td></tr>
# </table>
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed (look at case 2), else a new grid with the comparison results 
# is returned.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster.
# @return Geo::Raster, which has zeros (0) in those cells that are greater or 
# equal and therefor don't fulfil the comparison condition. If the rasters 
# value is less than the comparison value, then the cell gets a value true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
sub lt {
    my($self, $second, $reversed) = @_;    
    $self = Geo::Raster->new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_lt_grid($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_gt_integer($self->{GRID}, $second);
	    } else {
		ral_grid_gt_real($self->{GRID}, $second);
	    }
	} else {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_lt_integer($self->{GRID}, $second);
	    } else {
		ral_grid_lt_real($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster gt($number, $reversed)
#
# @brief The method tells if the rasters cells have greater values than the 
# given number. Comparison result is returned if  needed.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# 
# @param[in] number Number used for comparison.
# @param[in] reversed (optional) Tells the comparison order. If true then the 
# method checks if the given parameters value(s) are greater than the raster 
# grids cells values. If false, then the method acts as no reverse parameter 
# would have been given.
# @return Geo::Raster, which has zeros (0) in those cells that are less or 
# equal and therefor don't fulfil the comparison condition. If the rasters 
# value is greater than the comparison value, then the cell gets a value true 
# (1).
# @note If this grids some cells do not have any value, those cells 
# resulting value will also be undef.

## @method Geo::Raster gt(Geo::Raster second)
#
# @brief The method tells if the rasters cells have greater values than the 
# given rasters cells. Comparison result is returned if needed.
#
# There are three cases of the use of comparison operations between two grids:
# <table border="1">
# <tr><th>Case</th><th>Example</th>     <th>a unchanged</th>  <th>self</th> <th>second</th> <th>wantarray defined</th></tr>
# <tr><td>1.</td><td>c = a->gt(b);</td>   <td>yes</td>        <td>a</td>    <td>b</td>       <td>yes</td></tr>
# <tr><td>2.</td><td>a->gt(b);</td>       <td>no</td>         <td>a</td>    <td>b</td>       <td>no</td></tr>
# <tr><td>3.</td><td>c = a > b;</td>      <td>yes</td>        <td>a</td>    <td>b</td>       <td>yes</td></tr>
# </table>
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed (look at case 2), else a new grid with the comparison results 
# is returned.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster.
# @return Geo::Raster, which has zeros (0) in those cells that are less or 
# equal and therefor don't fulfil the comparison condition. If the rasters 
# value is greater than the comparison value, then the cell gets a value true 
# (1).
sub gt {
    my($self, $second, $reversed) = @_;
    $self = Geo::Raster->new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_gt_grid($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_lt_integer($self->{GRID}, $second);
	    } else {
		ral_grid_lt_real($self->{GRID}, $second);
	    }
	} else {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_gt_integer($self->{GRID}, $second);
	    } else {
		ral_grid_gt_real($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster le($number, $reversed)
#
# @brief The method tells if the rasters cells have smaller or equal values 
# compared to the given number. Comparison result is returned if needed.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# 
# @param[in] number Number used for comparison.
# @param[in] reversed (optional) Tells the comparison order. If true then the 
# method checks if the given parameters value(s) are less or equal than the 
# rasters cells values. If false, then the method acts as no reverse 
# parameter would have given.
# @return Geo::Raster, which has zeros (0) in those cells that are greater 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.

## @method Geo::Raster le(Geo::Raster second)
#
# @brief The method tells if the rasters cells have smaller or equal values 
# compared to the given rasters cells. Comparison result is returned if 
# needed.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster.
# @return Geo::Raster, which has zeros (0) in those cells that are greater 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
sub le {
    my($self, $second, $reversed) = @_;
    $self = Geo::Raster->new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_le_grid($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_ge_integer($self->{GRID}, $second);
	    } else {
		ral_grid_ge_real($self->{GRID}, $second);
	    }
	} else {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_le_integer($self->{GRID}, $second);
	    } else {
		ral_grid_le_real($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster ge($number, $reversed)
#
# @brief The method tells if the rasters cells have greater or equal values 
# compared to the given number. Comparison result is returned if needed.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# 
# @param[in] number Number used for comparison.
# @param[in] reversed (optional) Tells the comparison order. If true then the 
# method checks if the given parameters value(s) are greater or equal than the 
# rasters cells values. If false, then the method acts as no reverse 
# parameter would have given.
# @return Geo::Raster, which has zeros (0) in those cells that are less 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.

## @method Geo::Raster ge(Geo::Raster second)
#
# @brief The method tells if the rasters cells have greater or equal values 
# compared to the given rasters cells. Comparison result is returned if 
# needed.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster.
# @return Geo::Raster, which has zeros (0) in those cells that are less 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
sub ge {
    my($self, $second, $reversed) = @_;
    $self = Geo::Raster->new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_ge_grid($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_le_integer($self->{GRID}, $second);
	    } else {
		ral_grid_le_real($self->{GRID}, $second);
	    }
	} else {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_ge_integer($self->{GRID}, $second);
	    } else {
		ral_grid_ge_real($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster eq($number)
#
# @brief The method tells if the rasters cells have equal values 
# compared to the given number. Comparison result is returned if needed.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# 
# @param[in] number Number used for comparison.
# @return Geo::Raster, which has zeros (0) in those cells that are not equal 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.

## @method Geo::Raster ge(Geo::Raster second)
#
# @brief The method tells if the rasters cells have equal values 
# compared to the given rasters cells. Comparison result is returned if 
# needed.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster.
# @return Geo::Raster, which has zeros (0) in those cells that are not equal 
# and therefor don't fulfil the comparison condition. Else the cell gets a value 
# true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
sub eq {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster->new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_eq_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_eq_integer($self->{GRID}, $second);
	} else {
	    ral_grid_eq_real($self->{GRID}, $second);
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster ne($second)
#
# @brief The method tells if the rasters cells have not equal values 
# compared to the given rasters cells or given number. Comparison result is 
# returned if needed.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# 
# @param[in] second Reference to an another Geo::Raster or a number.
# @return Geo::Raster, which has zeros (0) in those cells that are equal 
# and therefor don't fulfil the comparison condition. An equally valued cell 
# gets a value true (1).
# @note If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
sub ne {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster->new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_ne_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_ne_integer($self->{GRID}, $second);
	} else {
	    ral_grid_ne_real($self->{GRID}, $second);
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster cmp($second, $reversed)
#
# @brief The method tells if the rasters cells have not equal values 
# compared to the given rasters cells or given number. Comparison result is 
# returned if needed.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The second rasters real world boundaries must be the same as this 
# rasters. The cell sizes and amounts in both directions must also be equal.
# - The comparison rasters can differ in datatype.
# - If the given or this grids some cells do not have any value, those cells 
# resulting value will also be undef.
#
# @param[in] second Reference to an another Geo::Raster or a number.
# @param[in] reversed Tells the comparison order. If true then the method does  
# the comparison in reversed order. The returned method then returns as values 
# -1 in those cells that are greater in this raster, 1 in those that are less 
# and 0 in those cells that have equal values (equal case is same and not equal 
# cases just have a reversed sign compared to direct comparison results).
# @return a new raster, which has as values 1 in those cells that are greater in
# this raster, -1 in those that are less and 0 in those cells that have equal 
# values.
sub cmp {
    my($self, $second, $reversed) = @_;
    $self = Geo::Raster->new($self) if defined wantarray;
    if (ref($second)) {
	ral_grid_cmp_grid($self->{GRID}, $second->{GRID});
    } else {
	if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
	    ral_grid_cmp_integer($self->{GRID}, $second);
	} else {
	    ral_grid_cmp_real($self->{GRID}, $second);
	}
	if ($reversed) {
	    if (ral_grid_get_datatype($self->{GRID}) == $INTEGER_GRID and $second =~ /^-?\d+$/) {
		ral_grid_mult_integer($self->{GRID}, -1);
	    } else {
		ral_grid_mult_real($self->{GRID}, -1);
	    }
	}
    }
    $self->{DATATYPE} = ral_grid_get_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

## @method Geo::Raster not()
#
# @brief The operator returns the logical negation of each raster cell value.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The rasters datatype must be integer.
# - The resulting value is 1 if the original raster cell has a value 0, else the
# resulting value is 0.
#
# @return Geo::Raster with results from using the not operator.
# @exception The rasters datatype is not integer.
sub not {
    my $self = shift;
    $self = Geo::Raster->new($self) if defined wantarray;
    ral_grid_not($self->{GRID});
    return $self if defined wantarray;
}

## @method Geo::Raster and(Geo::Raster second)
#
# @brief The operator returns the logical conjuction of this raster and
# given grids cells values.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The rasters must have the same amount of cells in both directions.
# - The rasters datatypes must be integer.
# - The resulting cell value will be 1 if both rasters have in the same 
# cell nonzero values, else the resulting value is 0.
# - If the other or both raster cells have an <I>no data</I> value, then 
# also the resulting cell will have that value.
#
# The (truth) table here shows all possible value combinations (not incl. no 
# data):
#<table>
#<tr><th>Resulting value</th><th>Own value</th><th>Parameter value</th></tr>
#<tr><td>1</td><td>not 0</td><td>not 0</td></tr>
#<tr><td>0</td><td>0</td><td>0</td></tr>
#<tr><td>0</td><td>0</td><td>not 0</td></tr>
#<tr><td>0</td><td>not 0</td><td>0</td></tr>
#</table>
#
# @param[in] second A Geo::Raster, which cell values are used to calculate the 
# logical conjunction.
# @return Geo::Raster with results from using the AND operator.
# @exception The rasters datatype is not integer.
sub and {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster->new($self) if defined wantarray;
    ral_grid_and_grid($self->{GRID}, $second->{GRID});
    return $self if defined wantarray;
}

## @method Geo::Raster or(Geo::Raster second)
#
# @brief The operator returns the logical disjuction of this raster and
# given grids cells values.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The rasters must have the same amount of cells in both directions.
# - The rasters datatypes must be integer.
# - The resulting cell value will be 1 if both rasters don't have in the 
# same cell 0, else the resulting value is 1.
# - If the other or both raster cells have an <I>no data</I> value, then 
# also the resulting cell will have that value.
#
# The (truth) table here shows all possible value combinations (not incl. no 
# data):
#<table>
#<tr><th>Resulting value</th><th>Own value</th><th>Parameter value</th></tr>
#<tr><td>1</td><td>not 0</td><td>not 0</td></tr>
#<tr><td>0</td><td>0</td><td>0</td></tr>
#<tr><td>1</td><td>0</td><td>not 0</td></tr>
#<tr><td>1</td><td>not 0</td><td>0</td></tr>
#</table>
#
# @param[in] second A Geo::Raster, which cell values are used to calculate the 
# logical disjunction.
# @return Geo::Raster with results from using the OR operator.
# @exception The rasters datatype is not integer.
sub or {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster->new($self) if defined wantarray;
    ral_grid_or_grid($self->{GRID}, $second->{GRID});
    return $self if defined wantarray;
}

## @method Geo::Raster nor($second)
#
# @brief The operator returns the inverse of disjunction of this raster 
# grid and given grids cells values.
#
# - The operation is performed to this raster, if no resulting new raster 
# grid is needed, else a new grid with the comparison results is returned.
# - The rasters must have the same amount of cells in both directions.
# - The rasters datatypes must be integer.
# - The resulting cell value will be 1 if both rasters have in the same 
# cell 0, else the resulting value is 1.
# - If the other or both raster cells have an <I>no data</I> value, then 
# also the resulting cell will have that value.
#
# The (truth) table here shows all possible value combinations (not incl. no 
# data):
#<table>
#<tr><th>Resulting value</th><th>Own value</th><th>Parameter value</th></tr>
#<tr><td>0</td><td>not 0</td><td>not 0</td></tr>
#<tr><td>1</td><td>0</td><td>0</td></tr>
#<tr><td>0</td><td>0</td><td>not 0</td></tr>
#<tr><td>0</td><td>not 0</td><td>0</td></tr>
#</table>
#
# @param[in] second A Geo::Raster, which cell values are used to calculate the 
# logical inverse of disjunction.
# @return Geo::Raster with results from using the NOR operator.
# @exception The rasters datatype is not integer.
sub nor {
    my $self = shift;
    my $second = shift;
    $self = Geo::Raster->new($self) if defined wantarray;
    ral_grid_or_grid($self->{GRID}, $second->{GRID});
    $self->not();
    return $self if defined wantarray;
}

1;
