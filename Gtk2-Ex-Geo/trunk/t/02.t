use Test::More tests => 1;
use Glib qw/TRUE FALSE/;
use Gtk2;

eval {
    require IPC::Gnuplot;
};
my $have_gnuplot = !$@;
BEGIN { 
    use_ok('Gtk2::Ex::Geo');
};

exit unless $ENV{GUI};

Gtk2->init;
#Glib->install_exception_handler(\&Gtk2::Ex::Geo::exception_handler);

{
    package Gtk2::Ex::Geo::Test;
    our @ISA = qw(Gtk2::Ex::Geo::Layer);
    sub new {
	my $self = Gtk2::Ex::Geo::Layer::new(@_);
	return $self;
    }
    sub world {
	return (0, 0, 100, 100);
    }
    sub render {
	my($self, $pb, $cr, $overlay, $viewport) = @_;
    }
    sub got_focus {
	my($self) = @_;
	print STDERR $self->name,"got focus\n";
    }   
}

my($window, $gis) = setup (classes => [qw/Gtk2::Ex::Geo::Layer/] );
#	(classes => [qw/Gtk2::Ex::Geo::Layer Geo::Vector::Layer Geo::Raster::Layer/]);

if ($have_gnuplot) {
    my $gnuplot = IPC::Gnuplot->new();
    $gis->register_function( name => 'plot', object => $gnuplot );
    $gis->register_function( name => 'p', object => $gnuplot );
}

my $layer = Gtk2::Ex::Geo::Test->new(name => 'test 1');
$gis->add_layer($layer);

$layer = Gtk2::Ex::Geo::Test->new(name => 'test 2');
$gis->add_layer($layer);

$gis->{overlay}->signal_connect(update_layers => 
	sub {
	#print STDERR "in callback: @_\n";
	});

$gis->register_commands
    ( 
      {
	  'test' => {
	      nr => 1,
	      text => 'test',
	      pos => -1,
	      sub => sub {
		  my(undef, $gui) = @_;
	      }
	  }
      } );

Gtk2->main;

sub setup{
    my %params = @_;

    my $window = Gtk2::Window->new;
    
    $window->set_title($params{title})
	if $params{title};
    
    $window->set_default_icon_from_file($params{icon}) 
	if $params{icon} and -f $params{icon};
    
    my $gis = Gtk2::Ex::Geo::Glue->new( main_window => $window );
    
    for (@{$params{classes}}) {
	$gis->register_class($_);
    }

    # layer list
    my $list = Gtk2::ScrolledWindow->new();
    $list->set_policy("never", "automatic");
    $list->add($gis->{tree_view});
    
    # layer list and the map
    my $hbox = Gtk2::HBox->new(FALSE, 0);
    $hbox->pack_start($list, FALSE, FALSE, 0);
    $hbox->pack_start($gis->{overlay}, TRUE, TRUE, 0);
    
    # the stack
    my $vbox = Gtk2::VBox->new(FALSE, 0);
    $vbox->pack_start($gis->{toolbar}, FALSE, FALSE, 0);
    #$vbox->add($hbox);
    $vbox->pack_start($hbox, TRUE, TRUE, 0);
    $vbox->pack_start($gis->{entry}, FALSE, FALSE, 0);
    $vbox->pack_start($gis->{statusbar}, FALSE, FALSE, 0);

    $window->add($vbox);
    $window->signal_connect("destroy", \&close_the_app, [$window, $gis]);
    $window->set_default_size(600,600);
    $window->show_all;
    
    return ($window, $gis);

}

sub close_the_app {
    my($window, $gis) = @{$_[1]};
    $gis->close();
    Gtk2->main_quit;
    exit(0);
}
