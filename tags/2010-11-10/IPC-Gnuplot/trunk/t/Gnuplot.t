# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gnuplot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 3;
BEGIN { 

# depending for now on Gtk2::Ex::Geo::Raster and Vector
# but putting all linkage code here

    use_ok('IPC::Gnuplot');
};

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

$gnuplot = IPC::Gnuplot->new();

for (0..100) {
    $xy{$_} = $_*$_;
}

eval {
    $gnuplot->plot(\%xy);
};

SKIP: {
    skip "no gnuplot", 1 if $!;
    ok(1, "plot");
}

sleep(2) unless $!;

eval {
    $gnuplot->p(\%xy);
};

SKIP: {
    skip "no gnuplot", 1 if $!;
    ok(1, "print");
}
