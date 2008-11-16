package IPC::Gnuplot;

# @brief A class for managing an IPC to gnuplot
# @author Copyright (c) Ari Jolma
# @author This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.5 or,
# at your option, any later version of Perl 5 you may have available.

=pod

=head1 NAME

IPC::Gnuplot - A class for managing an IPC to gnuplot

The <a href="http://map.hut.fi/doc/Geoinformatica/html/">
documentation of Gtk2::Ex::Geo</a> is written in doxygen format.

=cut

use strict;
use warnings;
use UNIVERSAL qw(isa);
use Carp;
use Term::ReadLine;

BEGIN {
    use Exporter "import";
    our @ISA = qw(Exporter);
    our @EXPORT = qw();
    our @EXPORT_OK = qw();
    our %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
    our $VERSION = 0.02;
}

## @cmethod object new(%params)
# @brief Constructor
#
# @return a new IPC::Gnuplot object
sub new {
    my $class = shift;
    my %params = @_;

    my $self = {};

    bless($self, $class);

    return $self;
}

## @method p(scalar something, hash options)
# Attempts to print data from (references to) hashes and arrays nicely.
# The named parameter 'file' can be used to print to a file.
# The named parameter 'column' can be used to print only that column from
# a two-dimensional array. The column 1 is the first column.
# @param something reference to a hash or an array
# @param options a list of named parameters and key=>value pairs
sub p {
    my($self, $this, %params) = @_;
    $self->output($params{file}) if $params{file};
    if (ref($this) eq 'HASH') {
	my @keys = keys %{$this};
	return unless @keys;
	if ($keys[0] =~ /^[-+\d.]+$/) {
	    foreach (sort {$a<=>$b} @keys) {
		my $v = $$this{$_};
		if (ref($v) eq 'ARRAY') {
		    print "$_ @{$v}\n";
		} else {
		    print "$_ $v\n";
		}
	    }
	} else {
	    foreach (sort @keys) {
		my $v = $$this{$_};
		if (ref($v) eq 'ARRAY') {
		    print "$_ @{$v}\n";
		} else {
		    print "$_ $v\n";
		}
	    }
	}
    } elsif (ref($this) eq 'ARRAY') {
	my $column = defined $params{column} ? $params{column} : 0;
	foreach (@{$this}) {
	    if (ref($_) eq 'ARRAY') {
		print $column ? "$_->[$column-1]\n" : "@$_\n";
	    } else {
		print "$_\n";
	    }
	}
    } else {
	print "$this\n";
    }
    $self->output() if $params{file};
}

## @ignore
sub get_plot_datasets {
    my($this) = @_;
    if (ref($this)) {
	if (ref($this) eq 'ARRAY') {
	    my $index = 0;
	    my @datasets;
	    # elements of this are either well known objects, type, or first element of values
	    while ($index <= $#$this) {
		if (ref($this->[$index]) eq 'HASH') {
		    my $hash = $this->[$index];
		    if ($hash->{function}) {
			push @datasets, ['function', $hash];
		    } elsif ($hash->{xy}) {
			push @datasets, ['data', $hash];
		    } else {
			my @data;
			for my $x (sort {$a<=>$b} keys %$hash) {
			    push @data, [$x, $hash->{$x}];
			}
			push @datasets, ['point_series', \@data];
		    }
		    $index++;
		} elsif (ref($this->[$index])) {
		    croak "expected a well known object or dataset type specifier at $index\n";
		} else {
		    if ($this->[$index] =~ /^p/) { # point dataset or -sets
			$index++;
			if (ref($this->[$index][0][0])) {
			    for my $s (@{$this->[$index]}) {
				push @datasets, ['point_series', $s];
			    }
			} else {
			    push @datasets, ['point_series', $this->[$index]];
			}
			$index++;
		    } elsif ($this->[$index] =~ /^v/) { # value dataset or -sets
			$index++;
			if (ref($this->[$index][0])) {
			    for my $s (@{$this->[$index]}) {
				push @datasets, ['value_series', $s];
			    }
			} else {
			    push @datasets, ['value_series', $this->[$index]];
			}
			$index++;
		    } elsif ($this->[$index] =~ /^d/) { # datafile
			$index++;
			push @datasets, ['datafile', $this->[$index++]];
		    } elsif ($this->[$index] =~ /^f/) { # function
			$index++;
			push @datasets, ['function', $this->[$index++]];
		    } else {
			return [['value_series', $this]];
		    }
		}
	    }
	    return \@datasets;
	} elsif (ref($this) eq 'HASH') {
	    my @data;
	    for my $x (sort {$a<=>$b} keys %$this) {
		push @data, [$x, $this->{$x}];
	    }
	    return [['point_series', \@data]];
	} else {
	    croak "don't know how to plot a " . ref($this) . "\n";
	}
    } elsif (-e $this) {
	return [['datafile', '"'.$this.'"']];
    } else {
	return [['function', $this]];
    }
}

## @method plot(scalar something, hash options)
# An interface to gnuplot. 

# The gnuplot plot parameters 'title', 'with' (default "lines"),
# 'xrange', 'yrange', 'using' (default "using 1:2"), and 'other' can
# be defined via named parameters.  plot() uses p() to print to the
# file 'plot_data' or to one specified with named parameter
# 'datafile'.  The output is to a gnuplot window or to a PNG image
# file if named parameter 'image_file' is given.

# the named parameter 'column' is fed through to p().
# @param something either a filename or a reference to a hash or an array
# @param options a list of named parameters and key=>value pairs for gnuplot or p
sub plot {
    my($self, $this, %params) = @_;
    my $gnuplot = $^O eq 'MSWin32' ? 'pgnuplot' : 'gnuplot';
    open GNUPLOT, "| $gnuplot" or croak "can't open gnuplot: $!\n";
    my $fh = select(GNUPLOT); $| = 1;
    my $datafile = $params{datafile} || 'plot_data';
    if ($params{image_file}) {
	$params{file} = $params{image_file} unless $params{file};
	gnuplot("set terminal png");
	gnuplot("set output \"$params{file}.png\"");
    }
    my $other = $params{other} ? ', ' . $params{other} : '';

    gnuplot("set xdata");
    gnuplot("set format x");

    # an array of [type, dataset]
    my $datasets = get_plot_datasets($this);

    my @range; # $minx, $maxx, $miny, $maxy
    my $scale = $params{scale} ? $params{scale} : 0;
    my @what;
    my @axes;
    my @title;
    my @with;
    my $index = 0;
    my $plot_index = 0;

    for (@$datasets) {
	my($type, $dataset) = @$_;
	#print STDERR "type=$type, dataset=$dataset\n";

	if (ref($dataset) eq 'HASH' and 
	    ($dataset->{function} or $dataset->{xy} or $dataset->{y} or $dataset->{ty})) 
	{
	    if ($scale) {
		if ($dataset->{xy}) {
		    @range = range_from_xy($dataset->{xy}, @range);
		} elsif ($dataset->{y}) {
		    @range = range_from_y($dataset->{y}, @range);
		}
	    }
	    if ($dataset->{function}) {
		$what[$index] = $dataset->{function};
	    } else {
		$self->output($datafile, $index ? (gnuplot_add=>1) : (0=>0));
		$self->p($dataset->{xy}, column=>$dataset->{column});
		$self->output;
		$what[$index] = "\"$datafile\" index $plot_index";
		$plot_index++;
		$what[$index] .= $dataset->{using} ? "using \"$dataset->{using}\"" : ' using 1:2';
	    }
	    $axes[$index] = '';
	    $title[$index] = '';
	    $with[$index] = 'lines';
	    $axes[$index] = "axes $dataset->{axes}" if $dataset->{axes};
	    $title[$index] = "title \"$dataset->{title}\"" if $dataset->{title};
	    $title[$index] = "notitle" if $dataset->{notitle};
	    $with[$index] = "$dataset->{with}" if $dataset->{with};
	    $index++;
	    next;
	}

	if ($type =~ /^f/) {
	    $title[$index] = "title \"$dataset\"";
	} elsif ($type =~ /^d/) {
	    $title[$index] = "title $dataset";
	} else {
	    $title[$index] = "notitle";
	}
	$with[$index] = ref($params{with}) ? $params{with}->[$index] : $params{with};
	if ($type =~ /^p/) {
	    @range = range_from_xy($dataset, @range);
	    $with[$index] = 'impulses' unless $with[$index];
	} elsif ($type =~ /^v/) {
	    @range = range_from_y($dataset, @range);
	    $with[$index] = 'points' unless $with[$index];
	}
	if ($type =~ /^p/ or $type =~ /^v/) {
	    $self->output($datafile, $index ? (gnuplot_add=>1) : (0=>0));
	    $self->p($dataset, column=>$params{column});
	    $self->output;
	    $what[$index] = "\"$datafile\" index $plot_index";
	    $plot_index++;
	    $what[$index] .= ' using 1:2';
	} else {
	    $what[$index] = $dataset;
	}
	$index++;
    }

    my($xrange, $yrange);
    if ($scale) {
	$xrange = defined $range[0] ? "[$range[0]:$range[1]]" : '[]';
	$yrange = "[$range[2]:$range[3]]";
    } else {
	$xrange = $params{xrange} ? $params{xrange} : '[]';
	$yrange = $params{yrange} ? $params{yrange} : '[]';
    }

    my $plot = "plot $xrange $yrange $what[0] $title[0] with $with[0]";
    for $index (1..$#$datasets) {
	$plot .= ", $what[$index] $title[$index] with $with[$index]";
    }
    #print STDERR "$plot\n";
    gnuplot($plot . $other);

    if ($params{image_file}) {
	gnuplot("set terminal x11");
	gnuplot("set output");
    }

    select($fh);
}

sub range_from_xy {
    my $dataset = shift;
    for (@$dataset) {
	$_[0] = min($_->[0], $_[0]);
	$_[1] = max($_->[0], $_[1]);
	$_[2] = min($_->[1], $_[2]);
	$_[3] = max($_->[1], $_[3]);
    }
    return @_;
}

sub range_from_y {
    my $dataset = shift;
    for (@$dataset) {
	$_[2] = min($_, $_[2]);
	$_[3] = max($_, $_[3]);
    }
    return @_;
}

sub min {
    my $min = shift;
    return unless defined $min;
    for (@_) {
	return $min unless defined $_;
	$min = $_ if $_ < $min;
    }
    return $min;
}

sub max {
    my $max = shift;
    return unless defined $max;
    for (@_) {
	return $max unless defined $_;
	$max = $_ if $_ > $max;
    }
    return $max;
}

## @ignore
sub gnuplot {
    my $line = shift;
    $line = '' unless $line;
    print GNUPLOT "$line\n";
}

## @ignore
sub output {
    my($self, $fn, %params) = @_;
    if ($fn and exists $params{gnuplot_add}) {
	open OUTPUT,">>$fn" or croak("can't open $fn: $!\n");
	print OUTPUT "\n\n";
	select OUTPUT;
    } elsif ($fn) {
	open OUTPUT, ">$fn" or croak "can't open $fn: $!\n";
	select OUTPUT;
    } else {
	CORE::close(OUTPUT);
	select STDOUT;
    }
}

1;
