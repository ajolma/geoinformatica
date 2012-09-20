use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'Geo::OGC::SymbologyEncoding',
    VERSION_FROM      => 'lib/Geo/OGC/SymbologyEncoding.pm', # finds $VERSION
    PREREQ_PM         => { XML::Parser => 0 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Geo/OGC/SymbologyEncoding.pm', # retrieve abstract from module
       AUTHOR         => 'Ari Jolma <ari.jolma at aalto.fi>') : ()),
);
