use 5.008003; # support use Exporter 'import';
use Config;
use ExtUtils::MakeMaker;

my %missing_modules;

$missing_modules{chk_module('ExtUtils::Depends')} = 1;
$missing_modules{chk_module('ExtUtils::PkgConfig')} = 1;

delete $missing_modules{''};

my @missing_modules = keys %missing_modules;
print "Following required/optional modules are missing: @missing_modules\n" if @missing_modules;
exit 0 if @missing_modules;

require ExtUtils::Depends;
require ExtUtils::PkgConfig;

my($inc,$libs,$cflags) = ('','','');

my @packages = ('gdk-pixbuf-2.0');

for $package (@packages) {
    print "Checking for $package: ";
    my($c,$l);
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
    # hack to circumwent the fact that ExtUtils::MakeMaker does not find .dll.a libraries
    if ($^O eq "MSWin32") {
	my @a = split /\s+/,$l;
	for (@a) {
	    if (/^-l/ and !(/.dll/) and !(/-lm/) and !(/^-lws2/) and !(/^-lgdi/)) {
		$_ .= '.dll';
	    }
	}
	$l = join(' ',@a);
    }
    $libs .= " $l";
    print "ok\n";
}

our $deps = ExtUtils::Depends->new('Gtk2::Ex::Geo', 'Gtk2');

our %pm_files = (
		 'lib/Gtk2/Ex/Geo/Dialogs/Colors.pm'  => '$(INST_LIBDIR)/Geo/Dialogs/Colors.pm',
		 'lib/Gtk2/Ex/Geo/Dialogs/Labeling.pm'=> '$(INST_LIBDIR)/Geo/Dialogs/Labeling.pm',
		 'lib/Gtk2/Ex/Geo/Dialogs/Symbols.pm' => '$(INST_LIBDIR)/Geo/Dialogs/Symbols.pm',
		 'lib/Gtk2/Ex/Geo/Overlay.pm'      => '$(INST_LIBDIR)/Geo/Overlay.pm',
		 'lib/Gtk2/Ex/Geo/Glue.pm'         => '$(INST_LIBDIR)/Geo/Glue.pm',
		 'lib/Gtk2/Ex/Geo/TreeDumper.pm'   => '$(INST_LIBDIR)/Geo/TreeDumper.pm',
		 'lib/Gtk2/Ex/Geo/DialogMaster.pm' => '$(INST_LIBDIR)/Geo/DialogMaster.pm',
		 'lib/Gtk2/Ex/Geo/Layer.pm'        => '$(INST_LIBDIR)/Geo/Layer.pm',
		 'lib/Gtk2/Ex/Geo/Dialogs.pm'      => '$(INST_LIBDIR)/Geo/Dialogs.pm',
		 'lib/Gtk2/Ex/Geo.pm'              => '$(INST_LIBDIR)/Geo.pm',
);

$deps->add_pm (%pm_files);
$deps->add_xs('lib/Gtk2/Ex/Geo.xs');
$deps->set_libs($libs);

@for_windows = ();
if ($^O eq 'MSWin32') {
    $lddlflags = $Config{lddlflags};
    $lddlflags =~ s/-mdll/-shared/;
    @for_windows = (LDDLFLAGS => $lddlflags,
		    dynamic_lib=>{OTHERLDFLAGS=>"-Wl,--out-implib=blib\\arch\\auto\\Gtk2\\Ex\\Geo.dll.a "});
}

$deps->install (qw(lib/Gtk2/Ex/gtk2-ex-geo.h));
$deps->save_config ('Files.pm');

WriteMakefile(
	      NAME              => 'Gtk2::Ex::Geo',
	      VERSION_FROM      => 'lib/Gtk2/Ex/Geo.pm',
	      ABSTRACT_FROM   => 'lib/Gtk2/Ex/Geo.pm', # retrieve abstract from module
	      AUTHOR          => 'Ari Jolma <ari.jolma @ tkk.fi>',
	      PREREQ_PM         => {
		  'ExtUtils::Depends' => 0,
		  'ExtUtils::PkgConfig' => 0,
		  'Gtk2::GladeXML' => 0,
		  'Graphics::ColorUtils' => 0,
		  'Geo::OGC::Geometry' => 0
		  },
	      CCFLAGS => $cflags,
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
    my $lib = 'lib/Gtk2/Ex/Geo/';
    $lib = "lib/Gtk2/Ex/Geo/";
    for ('Glue', 'Dialogs') {
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
