use 5.005;
use Carp;
use Config;
use ExtUtils::MakeMaker;

my %missing_modules;

$missing_modules{chk_module('ExtUtils::Depends')} = 1;
$missing_modules{chk_module('ExtUtils::PkgConfig')} = 1;
delete $missing_modules{''};
my @missing_modules = keys %missing_modules;
die "Following required modules are missing: @missing_modules\n" if @missing_modules;

require ExtUtils::Depends;
require ExtUtils::PkgConfig;

$missing_modules{chk_module('Statistics::Descriptive')} = 1;
$missing_modules{chk_module('Geo::GDAL')} = 1; # should this be optional?
$missing_modules{chk_module('Gtk2::Ex::Geo')} = 1;
delete $missing_modules{''};
my @missing_modules = keys %missing_modules;
warn "Following required modules are missing: @missing_modules\n" if @missing_modules;

my($inc,$libs,$cflags) = ('','','');

for $package ('gdal','gdk-pixbuf-2.0','libral') {
    print "Checking for $package: ";
    my($c, $l);
    if ($package eq 'gdal' and $^O ne 'MSWin32') {
	$c = `gdal-config --cflags`;
	chomp $c;
	$l = `gdal-config --libs`;
	chomp $l;
    } else {
	%pkg_info = ExtUtils::PkgConfig->find ($package);
	$c = $pkg_info{cflags};
	$l = $pkg_info{libs};
    }
    $cflags .= " $c";
    # this code is for MinGW in fact
    if ($^O eq "MSWin32") {
	my @a = split /\s+/,$l;
	for (@a) {
	    if (/^-l/ and !(/.dll/)) {
		$_ .= '.dll.a';
	    }
	}
	$l = join(' ',@a);
    }
    $libs .= " $l";
    print "ok\n";
}

our $deps = ExtUtils::Depends->new('Geo::Raster', 'Gtk2::Ex::Geo');

$deps->set_inc($inc);
$deps->set_libs($libs);

@for_windows = ();
if ($^O eq 'MSWin32') {
    $lddlflags = $Config{lddlflags};
    $lddlflags =~ s/-mdll/-shared/;
    @for_windows = 
	(
	 LDDLFLAGS => $lddlflags,
	 dynamic_lib=>
	 {OTHERLDFLAGS=>"-Wl,--out-implib=blib\\arch\\auto\\Geo\\Raster\\Raster.dll.a "});
}

our %pm_files = 
    (
     'lib/Geo/Raster.pm'                  => '$(INST_LIBDIR)/Raster.pm',
     'lib/Geo/Raster/IO.pm'               => '$(INST_LIBDIR)/Raster/IO.pm',
     'lib/Geo/Raster/Image.pm'            => '$(INST_LIBDIR)/Raster/Image.pm',
     'lib/Geo/Raster/Algorithms.pm'       => '$(INST_LIBDIR)/Raster/Algorithms.pm',
     'lib/Geo/Raster/TerrainAnalysis.pm'  => '$(INST_LIBDIR)/Raster/TerrainAnalysis.pm',
     'lib/Geo/Raster/Geostatistics.pm'    => '$(INST_LIBDIR)/Raster/Geostatistics.pm',
     'lib/Geo/Raster/Layer.pm'            => '$(INST_LIBDIR)/Raster/Layer.pm',
     'lib/Geo/Raster/Layer/Dialogs.pm'    => '$(INST_LIBDIR)/Raster/Layer/Dialogs.pm',
     );

$deps->add_pm(%pm_files);
$deps->add_xs('lib/Geo/Raster.xs');

$deps->save_config("Files.pm");

WriteMakefile(NAME                        => 'Geo::Raster',
	      VERSION_FROM                => 'lib/Geo/Raster.pm',
	      ABSTRACT_FROM               => 'lib/Geo/Raster.pm',
	      AUTHOR                      => 'Ari Jolma <ari.jolma @ tkk.fi>',
	      $deps->get_makefile_vars(),
	      #'EXE_FILES'                => [ 'rash' ],
	      CCFLAGS                     => "-O2 -fno-builtin $cflags $inc",
	      $deps->get_makefile_vars,
	      @for_windows
	      );

sub chk_module {
    my $pkg = shift;
    print "Checking for $pkg:";
    eval { 
	my $p; 
	($p = $pkg . ".pm") =~ s#::#/#g; 
	require $p; 
    };
    if ($@) {
	print " failed\n";
	return $pkg;
    } else {
	print " ok\n";
	return '';
    }
}

# -o on the compiler command line...
package MY;
use Cwd;
sub const_cccmd {
    my $inherited = shift->SUPER::const_cccmd(@_);
    $inherited .= ' -o $@';
    $inherited;
}

sub postamble {
    my $ret = '';
    my $lib = 'lib/Geo/Raster/Layer/';
    for ('Dialogs') {
	$ret .= "\n$lib$_.pm: $lib$_.pm.in $lib$_.glade\n";
	if ($^O eq 'MSWin32') {
	} else {
	    $ret .= "\tif [ -f $lib$_.pm ]; then chmod u+w $lib$_.pm; fi\n\n";
	}
	my $l = $lib;
	if ($^O eq 'MSWin32') {
	    $l =~ s/\//\\/g;
	    $ret .= "\tcopy $l$_.pm.in+$l$_.glade $l$_.pm\n";
	} else {
	    $ret .= "\tcat $l$_.pm.in $l$_.glade >$l$_.pm\n";
	    $ret .= "\tchmod a-w $lib$_.pm\n\n"; # to remember to edit .pm.in :)
	}
    }
    return $ret;
}
