# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gtk2-Ex-Geo.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;
BEGIN { use_ok('Gtk2::Ex::Geo') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# run as "make test GUI=1" to bring up the GUI

use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2;

exit unless $ENV{GUI};

Gtk2->init;

Glib->install_exception_handler(\&exception_handler);

my $home = homedir();

# make the GUI:

my $window = Gtk2::Window->new;

$window->set_title('Geoinformatica');
my $icon = $0;
$icon =~ s/Gtk2-Ex-Geo.t/..\/Crop-Circle-5.ico/;
$window->set_default_icon_from_file($icon) if -f $icon;

my $gis = new Gtk2::Ex::Geo::Glue 
	history => "$home.rash_history", 
	resources => "$home.rashrc", 
	main_window => $window;

my $vbox = Gtk2::VBox->new (FALSE, 0);

$vbox->pack_start ($gis->{toolbar}, FALSE, FALSE, 0);

my $hbox = Gtk2::HBox->new (FALSE, 0);

$hbox->pack_start ($gis->{tree_view}, FALSE, FALSE, 0);
$hbox->pack_start ($gis->{overlay}, TRUE, TRUE, 0);

$vbox->add ($hbox);

$vbox->pack_start ($gis->{entry}, FALSE, FALSE, 0);
$vbox->pack_start ($gis->{statusbar}, FALSE, FALSE, 0);

$window->add ($vbox);

# connect callbacks:

$window->signal_connect("destroy", \&close_the_app);

$window->set_default_size(600,600);
$window->show_all;

$gis->{overlay}->{rubberbanding} = 'zoom rect';

Gtk2->main;

# these are the callbacks:

sub exception_handler {
    
    if ($_[0] =~ /\@INC contains/) {
	$_[0] =~ s/\(\@INC contains.*?\)//;
    }
    my $dialog = Gtk2::MessageDialog->new(undef,'destroy-with-parent','info','close',$_[0]);
    $dialog->signal_connect(response => \&destroy_dialog);
    $dialog->show_all;
    
    return 1;
}

sub destroy_dialog {
    my($dialog) = @_;
    $dialog->destroy;
}

sub close_the_app {
    # The order is important! (I think...)
    for (qw/toolbar entry statusbar/) {
	$vbox->remove($gis->{$_});
    }
    for (qw/tree_view overlay/) {
	$hbox->remove($gis->{$_});
    }
    $gis->close();
    Gtk2->main_quit;
    exit(0);
}

sub homedir {

    require Config;
    my $OS = $Config::Config{'osname'};

    if ($OS eq 'MSWin32') {

	require Win32::Registry;
    
	my $Register = "Volatile Environment";
	my $hkey = $HKEY_CURRENT_USER; # assignment is just to get rid of a "used only once" warning
    
	$HKEY_CURRENT_USER->Open($Register,$hkey);
    
	$hkey->GetValues(\%values);
    
	$hkey->Close;

	return "$values{HOMEDRIVE}->[2]$values{HOMEPATH}->[2]\\";

    } else {

	return "$ENV{HOME}/";

    }

}
