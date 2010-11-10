#!C:/perl/bin/perl.exe

# Before `make install' is performed this script should be runnable with
# `make test' (or in case of MinGW in Command Prompt with 'dmake test'). 
# After `make install' you can run the tests with `perl t/Gtk2-Ex-Geo.t'

# http://search.cpan.org/~adie/Test-Class-0.24/lib/Test/Class.pm

use Test::More qw(no_plan);
use Cwd;

BEGIN {
    unshift @INC, (getcwd()."/t"); # Absolut path to make the tests work with "make test".
}

ok(1,"dummy");

# Load all the test classes you want to run:
#use Geo::Raster::ConstructorTests;
#use Geo::Raster::BasicTests;
#use Geo::Raster::OperatorTests;
#use Geo::Raster::RasterCalcTests;
#use Geo::Raster::RasterBooleanLogicTests;
#use Geo::Raster::FocalTests;
#use Geo::Raster::ZonalTests;
#use Geo::Raster::FdgTests;
#use Geo::Raster::DemTests;

#Test::Class->runtests;

1; 