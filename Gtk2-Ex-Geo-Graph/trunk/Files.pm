package Gtk2::Ex::Geo::Graph::Install::Files;

$self = {
          'inc' => '',
          'typemaps' => [],
          'deps' => [
                      'Pango',
                      'Glib',
                      'Gtk2',
                      'Cairo',
                      'Gtk2::Ex::Geo'
                    ],
          'libs' => ''
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
