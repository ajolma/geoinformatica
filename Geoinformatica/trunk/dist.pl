# run this program to create a distribution tree
# before running this make sure
# - sources (see below) exist
# - GDAL is compiled and works (both GDAL and Geo::GDAL modules)
# - libral is compiled and works
# - other Geo:: modules are compiled and work
# - GDAL docs are made (make docs)
# - libral docs are made (doxygen in libral)
# - Geoinformatica docs are made (doxygen in Geo-Raster)

use strict;
use Cwd;
use File::Spec;

my $DIST = getcwd() . "/Geoinformatica";

# sources:
my $PERL = "c:/Geoinformatica"; # Perl with needed modules
my $GTK_RUNTIME = "c:/GTK-runtime"; # GTK runtime
my $GTK = "c:/GTK";
my $MINGW = "c:/MinGW";
my $EXPAT = "c:/Program Files/Expat 2.0.1";
my $LOCAL = "c:/msys/1.0/local";
my $GNUPLOT = "c:/Program Files/gnuplot";
my $GDAL = "c:/dev/gdal";
my $LIBRAL = "c:/dev/geoinformatica/libral/trunk";
my $PERL_MOD_DOC = "c:/dev/geoinformatica/Geo-Raster/trunk/html";
my $LIBRAL_DOC = "$LIBRAL/html";
my $PERL_GDAL_DOC = "$GDAL/swig/perl/html";

#system "rmdir \"$DIST\" /s /q";

my %dist;
tree($DIST, \%dist);

my %copy;
my %to;

copy('G-shell.bat', "$DIST/G-shell.bat");
copy('README', "$DIST/README");
#copy('LICENCE', "$DIST/LICENCE");

copy($GDAL."/html", "$DIST/doc/GDAL");
copy($PERL_MOD_DOC, "$DIST/doc/Perl modules");
copy($LIBRAL_DOC, "$DIST/doc/libral");
copy($PERL_GDAL_DOC, "$DIST/doc/Perl GDAL");

for (glob("$PERL/bin/*perl*.exe"), glob("$PERL/bin/*perl*.dll")) {
    my($vol,$dirs,$file) = File::Spec->splitpath( $_ );
    copy($_, "$DIST/bin/$file");
}
copy("$PERL/html", "$DIST/html");
copy("$PERL/lib", "$DIST/lib");
copy("$PERL/share", "$DIST/share");
copy("$PERL/site", "$DIST/site");

copy($GTK_RUNTIME, $DIST);
delete $copy{"$GTK_RUNTIME/uninst.exe"};
delete $to{"$DIST/uninst.exe"};
delete $copy{"$GTK_RUNTIME/license.txt"};
delete $to{"$DIST/license.txt"};
copy("$GTK_RUNTIME/license.txt", "$DIST/share/doc/GTK_RUNTIME/license.txt") if -f "$GTK_RUNTIME/license.txt";

for (glob("'$GNUPLOT/bin/?gnuplot.*'")) {
    my($vol,$dirs,$file) = File::Spec->splitpath( $_ );
    copy($_, "$DIST/bin/$file");
}
copy("$GNUPLOT/bin/share", "$DIST/bin/share");

for (qw/BUGS ChangeLog Copyright INSTALL NEWS README 
        README.1ST README.Windows docs/) 
{
    copy("$GNUPLOT/$_", "$DIST/share/doc/gnuplot/$_");
}
copy("$MINGW/bin/mingwm10.dll", "$DIST/bin");
for (qw/libpq.dll/) 
{ 
    copy("$LOCAL/pgsql/lib/$_", "$DIST/bin/$_");
}
for (glob("'$EXPAT/bin/*.dll'")) {
    my($vol,$dirs,$file) = File::Spec->splitpath( $_ );
    copy($_, "$DIST/bin/$file");
}
# here must have '
for (glob("'$EXPAT/*.*'")) {
    my($vol,$dirs,$file) = File::Spec->splitpath( $_ );
    copy($_, "$DIST/share/doc/expat/$file");
}
# here can't have '
for (glob("$LOCAL/bin/*.dll")) {
    my($vol,$dirs,$file) = File::Spec->splitpath( $_ );
    copy($_, "$DIST/bin/$file");
}
copy("$LOCAL/share/gdal", "$DIST/share/gdal");
copy("$GDAL/LICENSE.TXT", "$DIST/share/doc/gdal/LICENSE.TXT");
for (qw/README lesser.txt/) 
{ 
    copy("$LIBRAL/$_", "$DIST/share/doc/libral/$_");
}
copy("c:/dev/geoinformatica/Geoinformatica/trunk/gui.pl", "$DIST/bin/gui.pl");

# devel

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime(time);
$year += 1900;
$mon++;
$mon = "0$mon" if $mon < 10;
$mday = "0$mday" if $mday < 10;

my $devel = "devel"; # -$year-$mon-$mday";

for (glob("$LOCAL/bin/*.exe")) {
    next if /swig.exe/;
    my($vol,$dirs,$file) = File::Spec->splitpath( $_ );
    next if $file =~ /^[A-Z]/;
    copy($_, "$DIST/bin/$file");
}

for (glob("$LOCAL/bin/*config")) {
    my($vol,$dirs,$file) = File::Spec->splitpath( $_ );
    copy($_, "$DIST-$devel/bin/$file");
}
copy("$LOCAL/include", "$DIST-$devel/include");
for (glob("$LOCAL/lib/*.dll.a")) {
    my($vol,$dirs,$file) = File::Spec->splitpath( $_ );
    copy($_, "$DIST-devel/lib/$file");
}

for (glob("$GTK/bin/*.exe"), glob("$GTK/bin/*.bat")) {
    my($vol,$dirs,$file) = File::Spec->splitpath( $_ );
    copy($_, "$DIST-devel/bin/$file");
}
#copy("$LOCAL/pgsql/bin/psql.exe", "$DIST-utilities/bin/psql.exe");


for (keys %dist) {
    next if $to{$_};
    my $f = dossify($_);
    if (-d $f) {
	opendir DIR, $f;
	my @dir = readdir(DIR);
	closedir DIR;
	my $count = 0;
	for (@dir) {
	    $count++ unless /^\.+$/;
	}
	unless ($count) {
	    print "delete $f\n";
	    system "rmdir \"$f\" /q";
	}
    } else {
	print "delete $f\n";
	system "del \"$f\"";
    }
}

for (keys %copy) {
    #print "$_, $copy{$_}\n";
    simple_copy($_, $copy{$_});
}

sub copy {
    my($from, $to) = @_;
    if (-d $from) {
	return if $from eq '.svn';
	$to{$to} = 1;
	opendir DIR, $from;
	my @dir = readdir(DIR);
	closedir DIR;
	for (@dir) {
	    copy("$from/$_", "$to/$_") unless /^\.+$/;
	}
    } else {
	$copy{$from} = $to;
	$to{$to} = 1;
    }
}

sub tree {
    my($file, $tree) = @_;
    if (-d $file) {
	$tree->{$file} = 1;
	my @dir;
	opendir DIR, $file;
	@dir = readdir(DIR);
	closedir DIR;
	for (@dir) {
	    tree("$file/$_", $tree) unless /^\.+$/;
	}
    } else {
	my @f = stat($file);
	my $age = $f[9];
	$tree->{$file} = $age;
    }
}

sub simple_copy {
    my($from, $to) = @_;
    
    my($vol,$dirs,$file) = File::Spec->splitpath( $to );
    my @dirs = File::Spec->splitdir( $dirs );

    for (0..$#dirs) {
	my @d = @dirs[0..$_];
	$dirs = File::Spec->catfile(@d);
	my $p = File::Spec->catpath( $vol, $dirs, '' );
	dos_mkdir($p);
    }

    $from = dossify($from);
    $to = dossify($to);
    my $complete_to = $to;
    
    if (-r $to) {
	my @f = stat($from);
	my $age_from = $f[9];
	
	my @t = stat($to);
	my $age_to = $t[9];

	return if $age_from <= $age_to;
    }

    $to = File::Spec->catpath( $vol, $dirs, '' );
    $to = dossify($to);
    
    my $x = "xcopy \"$from\" \"$to\" /H /Y";
    print "$x\n";
    system $x;

    $to = $complete_to;
    if ($to=~/\.dll$/ and ($to=~/libgdal/ or $to=~/libgeos/ or $to=~/libxerces/)) {
	print "strip $to\n";
	system "strip --strip-debug $to";
    }
}

sub dos_mkdir {
    my($dir) = @_;
    $dir = dossify($dir);
    return if -d $dir;
    my $x = "mkdir \"$dir\"";
    print "$x\n";
    system $x;
}

sub dossify {
    my $x = shift;
    $x =~ s/\//\\/g;
    $x;
}
