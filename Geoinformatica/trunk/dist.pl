# run this program to create a distribution tree

use strict;
use Cwd;
use File::Spec;

my $DIST = getcwd() . "/Geoinformatica";
my $PERL = "c:/Geoinformatica"; # Perl with needed modules
my $GTK = "c:/GTK-rt"; # GTK runtime
my $MINGW = "c:/MinGW";
my $EXPAT = "c:/Program Files/Expat 2.0.1";
my $LOCAL = "c:/msys/1.0/local";
my $POSTGIS = "c:/Program Files/PostgreSQL/8.2";
my $GNUPLOT = "c:/Program Files/gnuplot";
my $GDAL = "c:/dev/gdal";
my $LIBRAL = "c:/dev/hoslab/libral/trunk";

my $PERL_MOD_DOC = "c:/dev/hoslab/Geo-Raster/trunk/html";
my $LIBRAL_DOC = "$LIBRAL/html";
my $PERL_GDAL_DOC = "$GDAL/swig/perl/html";

#system "rmdir \"$DIST\" /s /q";

my %dist;
tree($DIST, \%dist);

my %copy;
my %to;

copy($PERL_MOD_DOC, "$DIST/doc/Perl modules");
copy($LIBRAL_DOC, "$DIST/doc/libral");
copy($PERL_GDAL_DOC, "$DIST/doc/Perl GDAL");

copy($PERL, $DIST);
copy($GTK, $DIST);
delete $copy{"$GTK/uninst.exe"};
delete $to{"$DIST/uninst.exe"};
delete $copy{"$GTK/license.txt"};
delete $to{"$DIST/license.txt"};
copy("$GTK/license.txt", "$DIST/share/doc/GTK/license.txt") if -f "$GTK/license.txt";
copy("$GNUPLOT/bin", "$DIST/bin");
for (qw/BUGS ChangeLog Copyright INSTALL NEWS README 
        README.1ST README.Windows docs/) 
{
    copy("$GNUPLOT/$_", "$DIST/share/doc/gnuplot/$_");
}
copy("$MINGW/bin/mingwm10.dll", "$DIST/bin");
copy("$POSTGIS/OpenSSL Licence.txt", "$DIST");
for (qw/comerr32.dll krb5_32.dll libeay32.dll libiconv-2.dll
    libintl-2.dll libpq.dll libproj.dll ssleay32.dll/) 
{ 
    copy("$POSTGIS/bin/$_", "$DIST/bin/$_");
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
copy("gui.pl", "$DIST/bin/gui.pl");

# devel

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime(time);
$year += 1900;
$mon++;
$mon = "0$mon" if $mon < 10;
$mday = "0$mday" if $mday < 10;

my $devel = "devel"; # -$year-$mon-$mday";

for (glob("'$LOCAL/bin/*config'")) {
    my($vol,$dirs,$file) = File::Spec->splitpath( $_ );
    copy($_, "$DIST-$devel/bin/$file");
}
copy("$LOCAL/include", "$DIST-$devel/include");
copy("$LOCAL/lib", "$DIST-$devel/lib");


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
    
    if (-r $to) {
	my @f = stat($from);
	my $age_from = $f[9];
	
	my @t = stat($to);
	my $age_to = $t[9];

	return if $age_from <= $age_to;
    }
    
    my $x = "copy \"$from\" \"$to\"";
    print "$x\n";
    system $x;
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
