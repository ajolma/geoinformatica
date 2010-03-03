#!/usr/bin/perl

use Carp;
use Config;
use Cwd;
use Glib qw/TRUE FALSE/;
use Geo::Raster;
use Geo::Vector;
use Gtk2::Ex::Geo;
use Gtk2 '-init';
eval {
    require IPC::Gnuplot;
};
my $have_gnuplot = not $@;
use File::Spec;

my $OS = $Config::Config{'osname'};

require Win32::TieRegistry if $OS eq 'MSWin32';

# the four top level objects
($window, $gis, $log, $icon);

if ($OS eq 'MSWin32') {

    # todo, check gnuplot by splitting path and -f
    $ENV{PATH} = "$ENV{PATH};c:/bin/gnuplot/bin" if $have_gnuplot;

    my $dir = getcwd;
    my($volume,$directories,$file) = File::Spec->splitpath( $dir );
    my @dirs = File::Spec->splitdir( $directories );

    pop @dirs;
    push @dirs, ('share', 'gdal');
    $directories = File::Spec->catfile(@dirs);

    Geo::GDAL::SetConfigOption(
	'GDAL_DATA', File::Spec->catpath( $volume, $directories, '' ));

    pop @dirs;
    pop @dirs;
    push @dirs, ('bin');
    $directories = File::Spec->catfile(@dirs);

    Geo::GDAL::SetConfigOption(
	'PROJSO', File::Spec->catpath( $volume, $directories, 'libproj.dll' ));

    pop @dirs;
    push @dirs, ('share');
    $directories = File::Spec->catfile(@dirs);
    $icon = File::Spec->catpath( $volume, $directories, 'Crop-Circle-5.ico' );

}

# the defaults for layer objects can be adjusted
#$Geo::Vector::Layer::BORDER_COLOR = [255, 255, 255];
#$Gtk2::Ex::Geo::Layer::SINGLE_COLOR = [0, 0, 0, 255];

setup (
    classes => [qw/Gtk2::Ex::Geo::Layer Geo::Vector::Layer Geo::Raster::Layer/],
    title => 'Geoinformatica',
    );

if ($have_gnuplot) {
    my $gnuplot = IPC::Gnuplot->new();
    $gis->register_function( name => 'plot', object => $gnuplot );
    $gis->register_function( name => 'p', object => $gnuplot );
}

Glib->install_exception_handler(\&exception_handler);

Gtk2->main;

sub setup{
    my %params = @_;

    croak "usage: simple(classes => [qw/...layer classes.../])" unless $params{classes};

    my($home, $docs) = homedir();

    $window = Gtk2::Window->new;
    
    $window->set_title($params{title})if $params{title};    
    $window->set_default_icon_from_file($icon) if $icon and -f $icon;
    
    $gis = Gtk2::Ex::Geo::Glue->new
	( 
	  first_file_open_folder => $docs,
	  history => "$home.rash_history", 
	  resources => "$home.rashrc",
	  'overlay:bg_color' => [200, 200, 200, 255],
	  );
    
    for (@{$params{classes}}) {
	$gis->register_class($_);
    }

    # layer list
    my $list = Gtk2::ScrolledWindow->new();
    $list->set_policy("never", "automatic");
    $list->add($gis->{tree_view});
    
    # layer list and the map
    my $hbox = Gtk2::HPaned->new(); #Gtk2::HBox->new(FALSE, 0);
    #$hbox->pack_start($list, FALSE, FALSE, 0);
    #$hbox->pack_start($gis->{overlay}, TRUE, TRUE, 0);
    $hbox->add1($list);
    $hbox->add2($gis->{overlay});
    
    # the stack
    my $vbox = Gtk2::VBox->new(FALSE, 0);
    $vbox->pack_start($gis->{toolbar}, FALSE, FALSE, 0);
    $vbox->pack_start($hbox, TRUE, TRUE, 0);
    $vbox->pack_start($gis->{entry}, FALSE, FALSE, 0);
    $vbox->pack_start($gis->{statusbar}, FALSE, FALSE, 0);

    $window->add($vbox);
    $window->signal_connect("destroy", \&close_the_app);
    $window->set_default_size(600,600);
    $window->show_all;

    # add logger and redirect STDOUT to it
    # thanks to http://www.perlcircus.org/files.shtml

    $log = Gtk2::Window->new;
    $log->set_title($params{title}.' output');
    my $sc = Gtk2::ScrolledWindow->new;
    my $view = Gtk2::TextView->new;
    my $buffer = $view->get_buffer();
    $sc->add($view);
    $log->add($sc);
    $log->signal_connect( delete_event => sub { $log->hide_all; 1; }); 
    $log->set_default_size(600,400);

    {   
	package Buffer;
	sub TIEHANDLE { 
	    my ($class, $self) = @_; 
	    bless $self, $class;
	}
	sub PRINT { 
	    my $self = shift;
	    my $iter = $$self->get_end_iter;
	    $$self->insert($iter, $_) for @_;
	}
    }
    
    tie *STDOUT => "Buffer", \$buffer;

    $gis->register_commands
	( { 1 => { text => 'Output',
		   tip => 'The printout window',
		   pos => 0,
		   sub => sub { $log->show_all } },
	});

}

sub exception_handler {
    
    if ($_[0] =~ /\@INC contains/) {
	$_[0] =~ s/\(\@INC contains.*?\)//;
    }
    $_[0] =~ s/\s+at [\/\w\.]gui\.pl line \d+//;
    my $dialog = Gtk2::MessageDialog->new(undef,
					  'destroy-with-parent',
					  'info',
					  'close',
					  $_[0]);
    $dialog->signal_connect(response => \&destroy_dialog);
    $dialog->show_all;
    
    return 1;
}

sub destroy_dialog {
    my($dialog) = @_;
    $dialog->destroy;
}

sub close_the_app {
    untie *STDOUT;
    $gis->close();
    $log->destroy;
    $window->destroy;
    undef $log;
    undef $gis;
    undef $window;
    Gtk2->main_quit;
    #print STDERR "exiting\n";
    exit(0);
}

sub homedir {

    if ($OS eq 'MSWin32') {

	$Win32::TieRegistry::Registry->Delimiter("/");
	my $drive = $Win32::TieRegistry::Registry->{
	    "HKEY_CURRENT_USER/Volatile Environment//HOMEDRIVE"};
	my $path = $Win32::TieRegistry::Registry->{
	    "HKEY_CURRENT_USER/Volatile Environment//HOMEPATH"};
	my $doc = $Win32::TieRegistry::Registry->{
	    "HKEY_CURRENT_USER/Software/Microsoft/Windows/".
		"CurrentVersion/Explorer/User Shell Folders//Personal"};
	$doc =~ s/\%USERPROFILE\%//;
    
	return ("$drive$path\\", "$drive$path$doc");

    } else {

	return ("$ENV{HOME}/", "$ENV{HOME}/");

    }
    
}
