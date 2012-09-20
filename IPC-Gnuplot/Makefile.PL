use ExtUtils::MakeMaker;

WriteMakefile(
	      NAME              => 'IPC::Gnuplot',
	      VERSION_FROM      => 'lib/IPC/Gnuplot.pm',
	      PREREQ_PM         => {}, # e.g., Module::Name => 1.1
	      (
	       $] >= 5.005 ?     ## Add these new keywords supported since 5.005
	       (
		ABSTRACT_FROM  => 'lib/IPC/Gnuplot.pm', # retrieve abstract from module
		AUTHOR         => 'Ari Jolma <ari.jolma @ aalto.fi>'
		) : 
	       ()
	       ),
	      );
