package Gtk2::Ex::Geo::Graph::Install::Files;

$self = {
          'deps' => [
                      'Cairo',
                      'Glib',
                      'Gtk2',
                      'Pango',
                      'Gtk2::Ex::Geo'
                    ],
          'inc' => '',
          'libs' => '',
          'typemaps' => []
        };


# this is for backwards compatiblity
@deps = @{ $self->{deps} };
@typemaps = @{ $self->{typemaps} };
$libs = $self->{libs};
$inc = $self->{inc};

	$CORE = undef;
	foreach (@INC) {
		if ( -f $_ . "/Gtk2/Ex/Geo/Graph/Install/Files.pm") {
			$CORE = $_ . "/Gtk2/Ex/Geo/Graph/Install/";
			last;
		}
	}

1;
