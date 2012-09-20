package Geo::OGC::SymbologyEncoding;

use strict;
use warnings;
use Carp;
use XML::Parser;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

# this parser recognzises only these specific elements
# and only specific namespaces, if namespaces are used

# element types are referred to as classes here
# the objects of classes may occur more than once within their parents
# the objects of singletons occur within higher level objects zero or one time
# the objects of attributes are simple valued objects (no attributes)

use vars qw/%se %ogc %classes %singletons %attributes %may_contain/;

# symbology encoding namespace
%se = map {$_=>1} qw/ElseFilter Description ChannelSelection
     GrayChannel ContrastEnhancement Stroke Fill Font Label
     NumericValue FormatNumber Geometry LegendGraphic GraphicFill
     GraphicStroke Graphic AnchorPoint Displacement LabelPlacement
     PointPlacement LinePlacement BaseSymbolizer CoverageStyle Rule
     SvgParameter LineSymbolizer PolygonSymbolizer PointSymbolizer
     TextSymbolizer RasterSymbolizer ExternalGraphic Mark
     ColorReplacement Literal Function SourceChannelName Name
     Normalize Pattern Halo MinScaleDenominator MaxScaleDenominator
     PerpendicularOffset Format WellKnownName MarkIndex Opacity Size
     Rotation AnchorPointX AnchorPointY DisplacementX DisplacementY
     IsRepeated IsAligned GeneralizeLine/;

# OGC namespace (filtering)
%ogc = map {$_=>1} qw/Filter Add Sub Mul Div Literal PropertyName/;

for (qw/MapDescription Description ChannelSelection GrayChannel
     ContrastEnhancement Stroke Fill Font Label NumericValue
     FormatNumber Halo Geometry URL LegendGraphic GraphicFill
     GraphicStroke Graphic AnchorPoint Displacement LabelPlacement
     PointPlacement LinePlacement BaseSymbolizer/)

{
    $singletons{$_} = 1;
}

for (qw/Coverage CoverageStyle Rule SvgParameter LineSymbolizer
     PolygonSymbolizer PointSymbolizer TextSymbolizer RasterSymbolizer
     ExternalGraphic Mark ColorReplacement Add Sub Mul Div Literal
     PropertyName Function/)

{
    $classes{$_} = 1;
}

for (qw/Title SourceChannelName Name Normalize Abstract Pattern
     MinScaleDenominator MaxScaleDenominator PerpendicularOffset
     Format WellKnownName MarkIndex Opacity Size Rotation AnchorPointX
     AnchorPointY DisplacementX DisplacementY IsRepeated IsAligned
     GeneralizeLine/)

{
    $attributes{$_} = 1;
}

$may_contain{MapDescription} = {Coverage=>1, CoverageStyle=>2};

$may_contain{Coverage} = {URL=>1};

$may_contain{CoverageStyle} = {Name=>1, Description=>1,
			       CoverageName=>1,
			       SemanticTypeIdentifier=>1, Rule=>1,
			       OnlineResource=>1};

$may_contain{FeatureStyle} = {Name=>1, Description=>1,
			      FeatureTypeName=>1,
			      SemanticTypeIdentifier=>1, Rule=>1,
			      OnlineResource=>1};

$may_contain{Rule} = {Name=>1, Description=>1, LegendGraphic=>1,
		      Filter=>1, ElseFilter=>1,
		      MinScaleDenominator=>1, MaxScaleDenominator=>1,
		      LineSymbolizer=>1, PolygonSymbolizer=>1,
		      PointSymbolizer=>1, TextSymbolizer=>1,
		      RasterSymbolizer=>1};

$may_contain{Description} = {Title=>1, Abstract=>1};

$may_contain{LineSymbolizer} = {Name=>1, Description=>1,
				BaseSymbolizer=>1, Geometry=>1,
				Stroke=>1, PerpendicularOffset=>1};

$may_contain{PolygonSymbolizer} = {Name=>1, Description=>1,
				   BaseSymbolizer=>1, Geometry=>1,
				   Fill=>1, Stroke=>1,
				   Displacement=>1,
				   PerpendicularOffset=>1};

$may_contain{PointSymbolizer} = {Name=>1, Description=>1,
				 BaseSymbolizer=>1, Geometry=>1,
				 Graphic=>1};

$may_contain{TextSymbolizer} = {Name=>1, Description=>1,
				BaseSymbolizer=>1, Geometry=>1,
				Label=>1, Font=>1, LabelPlacement=>1,
				Halo=>1, Fill=>1};

$may_contain{RasterSymbolizer} = {Name=>1, Description=>1,
				  BaseSymbolizer=>1, Geometry=>1,
				  Opacity=>1, ChannelSelection=>1,
				  OverlapBehavior=>1, ColorMap=>1,
				  ContrastEnhancement=>1,
				  ShadedRelief=>1, ImageOutline=>1};

$may_contain{BaseSymbolizer} = {OnlineResource=>1};

$may_contain{ChannelSelection} = {RedChannel=>1, GreenChannel=>1,
				  BlueChannel=>1, GrayChannel=>1};

{
    my $x = {SourceChannelName=>1, ContrastEnhancement=>1};

    $may_contain{RedChannel} = $may_contain{GreenChannel} =
	$may_contain{BlueChannel} = $may_contain{GrayChannel} = $x;
    
}

$may_contain{ContrastEnhancement} = {Normalize=>1, Histogram=>1, GammaValue=>1};

$may_contain{Geometry} = {PropertyName=>1};

$may_contain{Stroke} = {GraphicFill=>1, GraphicStroke=>1,
			SvgParameter=>1};

$may_contain{Fill} = {GraphicFill=>1, SvgParameter=>1};

$may_contain{LegendGraphic} = {Graphic=>1};

$may_contain{GraphicFill} = {Graphic=>1};

$may_contain{GraphicStroke} = {Graphic=>1, InitialGap=>1, Gap=>1};

$may_contain{Graphic} = {ExternalGraphic=>1, Mark=>1, Opacity=>1,
			 Size=>1, Rotation=>1, AnchorPoint=>1,
			 Displacement=>1};

$may_contain{AnchorPoint} = {AnchorPointX=>1, AnchorPointY=>1};

$may_contain{Displacement} = {DisplacementX=>1, DisplacementY=>1};

$may_contain{Label} = {Add=>1, Sub=>1, Mul=>1, Div=>1,
    PropertyName=>1, Literal=>1, Function=>1};

$may_contain{Font} = {SvgParameter=>1};

$may_contain{LabelPlacement} = {PointPlacement=>1, LinePlacement=>1};

$may_contain{PointPlacement} = {AnchoPoint=>1, Displacement=>1,
				Rotation=>1};

$may_contain{LinePlacement} = {PerpendicularOffset=>1, IsRepeated=>1,
			       InitialGap=>1, Gap=>1, IsAligned=>1,
			       GeneralizeLine=>1};

$may_contain{SvgParameter} = {Add=>1, Sub=>1, Mul=>1, Div=>1,
			      PropertyName=>1, Literal=>1,
			      Function=>1};

$may_contain{ExternalGraphic} = {OnlineResource=>1, InlineContent=>1,
				 Format=>1, ColorReplacement=>1};

$may_contain{ColorReplacement} = {Recode=>1};

$may_contain{Halo} = {Radius=>1, Fill=>1};

$may_contain{Mark} = {WellKnownName=>1, OnlineResource=>1,
    InlineContent=>1, Format=>1, MarkIndex=>1, Fill=>1, Stroke=>1};

{ 
    my $x = {Add=>1, Sub=>1, Mul=>1, Div=>1, PropertyName=>1,
        Literal=>1, Function=>1};

    $may_contain{Add} = $may_contain{Sub} = $may_contain{Mul} =
	$may_contain{Div} = $x;

    $may_contain{FormatNumber} = {%$x, NumericValue=>1, Pattern=>1,
				  NegativePattern=>1};

    $may_contain{NumericValue} = {%$x};

}
 
sub new {
    my($package, %param) = @_;
    my $self = {};
    bless $self, $package;
    if ($param{filename}) {
	$self->{Root} = $self->{object} = {};
	my $p = new XML::Parser
	    ( Handlers => { 
		Start => \&start,
		Char => \&char,
		End => \&end,
	    });
	$p->{self} = $self;
	$p->parsefile($param{filename});
    } elsif ($param{class}) {
	$self->{class} = $param{class};
	if (exists $param{content}) {
	    croak "the content of $param{class} must be a listref, not '$param{content}'"
		if !$attributes{$param{class}} and ref($param{content}) ne 'ARRAY';
	    $self->{content} = $param{content};
	}
	if (exists $param{attributes}) {
	    for my $a (keys %{$param{attributes}}) {
		$self->{$a} = $param{attributes}{$a};
	    }
	}
    } else {
	$self->{Root} = $self->{object} = {};
    }
    return $self;
}

sub get_objects {
    my($self, $class) = @_;
    return unless ref $self;
    return if ref($self) eq 'ARRAY';
    if ($self->{$class}) {
	return $self->{$class} if $singletons{$class};
	return @{$self->{$class}};
    }
    for my $key (keys %$self) {
	next unless $key =~ /^[A-Z]/; # skip class, within etc.
	return get_objects($self->{$key}, $class);
    }
}

sub get_object {
    my($self, $class, $name) = @_;
    return unless ref $self;
    return if ref($self) eq 'ARRAY';
    if ($self->{$class}) {
	return $self->{$class} if $singletons{$class};
	for my $s (@{$self->{$class}}) {
	    return $s if 
		(exists($s->{Name}) and $s->{Name} eq $name) or 
		(exists($s->{name}) and $s->{name} eq $name);
	}
    }
    for my $key (keys %$self) {
	next unless $key =~ /^[A-Z]/; # skip class, within etc.
	return get_object($self->{$key}, $class, $name);
    }
}

sub add_object {
    my($self, $class, $content) = @_;
    unless ($self->{class}) {
	$self = $self->{Root};
    } else {
	croak "can't add a $class to $self->{class}" unless $may_contain{$self->{class}}{$class};
    }
    if ($singletons{$class}) {
	croak "the content of $class must be a listref, not '$content'"
	    if defined($content) and ref($content) ne 'ARRAY';
	carp("overriding existing instance of $class in $self->{class}") if exists $self->{$class};
	my $p = {class => $class, within => $self, content => $content};
	push @{$self->{content}}, $p;
	$self->{$class} = $p;
	return bless $p;
    } elsif ($classes{$class}) {
	croak "the content of $class must be a listref, not '$content'"
	    if defined($content) and ref($content) ne 'ARRAY';
	my $p = {class => $class, within => $self, content => $content};
	push @{$self->{content}}, $p;
	push @{$self->{$class}}, $p;
	return bless $p;
    } elsif ($attributes{$class}) {
	carp("overriding existing value for $class in $self->{class}") if exists $self->{$class};
	push @{$self->{content}}, \$class;
	$self->{$class} = $content;
    } else {
	croak "unknown element: $class";
    }
}

*add = *add_object;

sub set {
    my($self, %attrs) = @_;
    for my $a (keys %attrs) {
	$self->{$a} = $attrs{$a};
    }
}

sub stream {
    my($self, $stream) = @_;
    $stream = \*STDOUT unless $stream;
    unless ($self->{class}) {
	print $stream '<?xml version="1.0" encoding="UTF-8"?>',"\n";
	my @k = keys %{$self->{Root}};
	my $r = $self->{Root}->{$k[0]};
	$r->set('xmlns:se' => "http://www.opengis.net/se",
		'xmlns:ogc' => "http://www.opengis.net/ogc");
	stream($r, $stream);
    } else {
	my $ns = $se{$self->{class}} ? 'se:' : 
	    ($ogc{$self->{class}} ? 'ogc:' : '');
	print $stream "<$ns$self->{class}";
	for my $k (keys %$self) {
	    next if $k =~ /^[A-Z]/;
	    next if $k eq 'class';
	    next if $k eq 'within';
	    next if $k eq 'content';
	    print $stream " $k=\"$self->{$k}\"";
	}
	print $stream ">";
	for my $e (@{$self->{content}}) {
	    unless (ref $e) {
		print $stream $e;
	    } else {
		if (ref($e) eq 'SCALAR') {
		    my $ns2 = $se{$$e} ? 'se:' : ($ogc{$$e} ? 'ogc:' : '');
		    if ($self->{$$e}) {
			print $stream "<$ns2$$e>$self->{$$e}</$ns2$$e>";
		    } else {
			print $stream "<$ns2$$e/>";
		    }
		} else {
		    stream($e, $stream)
		}
	    }
	}
	print $stream "</$ns$self->{class}>";
    }
}

sub start {
    my($p, $element, %av) = @_;
    my $self = $p->{self};
    unless ($self->{nss}) {
	for my $k (keys %av) {
	    # known namespaces
	    if ($k =~ /^xmlns([:\w]*)/) {
		my $ns = $1;
		$ns = 'default' unless $ns;
		$ns =~ s/^://;
		if ($av{$k} eq 'http://www.opengis.net/se') {
		    $self->{nss}->{$ns} = 'se';
		} elsif ($av{$k} eq 'http://www.opengis.net/ogc') {
		    $self->{nss}->{$ns} = 'ogc';
		}
	    }
	}
    } else {
	my $ns = 'default';
	if ($element =~ /^(\w+):(\w+)/) {
	    $ns = $1;
	    $element = $2;
	}
	return unless $self->{nss}->{$ns};
	unless ($classes{$element} or $singletons{$element} or $attributes{$element}) {
	    carp "unknown element $element\n" if $self->{warn_of_unknown_elements};
	    return;
	}
    }
    my $o = $self->{object};
    if ($classes{$element}) {
	my $i = $self->start_object($element, %av);
	push @{$o->{content}}, $i;
    } elsif ($singletons{$element}) {
	my $i = $self->start_singleton($element, %av);
	push @{$o->{content}}, $i;
    } else {
	$self->add_key($element);
	push @{$o->{content}}, \$element;
    }
}
sub char {
    my($p, $string) = @_;
    $p->{self}->add_value($string);
}
sub end {
    my($p, $element) = @_;
    if ($element =~ /^(\w+):(\w+)/) {
	$element = $2;
    }
    $p->{self}->end_object if $singletons{$element};
    $p->{self}->end_object if $classes{$element};
}

sub start_object {
    my($self, $class, %attrs) = @_;
    my $object = {class => $class, within => $self->{object}, %attrs};
    bless $object;
    push @{$self->{object}->{$class}}, $object;
    $self->{object} = $object;
}

sub start_singleton {
    my($self, $class, %attrs) = @_;
    my $object = {class => $class, within => $self->{object}, %attrs};
    bless $object;
    $self->{object}->{$class} = $object;
    $self->{object} = $object;
}

sub end_object {
    my($self) = @_;
    $self->{object} = $self->{object}->{within};
}

sub add_key {
    my($self, $key) = @_;
    #print "add key $key\n";
    return unless ref $self->{object};
    $self->{object}->{$key} = '';
    $self->{key} = $key;
}

sub add_value {
    my($self, $value) = @_;
    $value =~ s/[\n\t]//g;
    if (exists $self->{key}) {
	$self->{object}->{$self->{key}} = $value;
	delete $self->{key};
    } else {
	push @{$self->{object}->{content}}, $value;
    }
}


1;
__END__

=head1 NAME

Geo::OGC::SymbologyEncoding - Perl extension for OGC symbology encoding

=head1 SYNOPSIS

  use Geo::OGC::SymbologyEncoding;
  
  # read symbology encoding from an XML file
  my $s = Geo::OGC::SymbologyEncoding->new(filename => 'se.xml');
  my $r = $s->{Root}->{MapDescription}; # if this is the expected root element
  for ($r->get_objects('CoverageStyle') {
    print "$_ $_->{class} $_->{Name}\n";
  }
  my $style = $s->get_object('CoverageStyle', 'name_of_the_style');
  print "$style->{class} $style->{Name}\n";
  my $rule = $style->get_object('Rule', 'Roads');
  my $sym = $rule->get_object('LineSymbolizer', 'MyLineSymbolizer');
  for ($sym->get_objects('SvgParameter')) {
    print "$_ $_->{class} $_->{name}\n";
  }

  # create a new symbology encoding
  $s = Geo::OGC::SymbologyEncoding->new();
  $m = $s->add('CoverageStyle');
  $m->add('Name', 'style1');
  $r = $m->add('Rule');
  $r->add('Name', 'ChannelSelection');
  
  # lots of more adds ...
   
  $d->add('SvgParameter', ['#0000ff'])->set(name=>'stroke');

  $l = $sym->add('Label', 
	       [
		SymbologyEncoding->new(class=>'PropertyName', content=>['hospital']),
		' (',
		$f,
		')'
		]);

  $s->stream;


=head1 DESCRIPTION

Geo::OGC::SymbologyEncoding defines a class, whose objects store an
open geospatial consortium's symbology encoding
(http://www.opengeospatial.org/standards/symbol). 

A symbology encoding object is a data structure that is an XML tree
but each element is classified according to the standard as an object,
singleton, or a simple object. An object may exist many times within
its parent and they are thus stored in a list. A singleton may exist
only once within its parent and it is therefore stored directly as the
hash value. Objects and singletons are blessed into
Geo::OGC::SymbologyEncoding. A simple object is a element that has
only a name and simple string content. Simple objects are stored in
such as way that the key is the element name and the value is the
content. In content simple objects are stored using references to
scalars (the key).

=head2 METHODS

=over 4

=item new

This is a class method, the constructor for
Geo::OGC::SymbologyEncoding. Options are passed as keyword value
pairs. If no options are given, an empty symbology encoding element is
created.

Recognized options are:

=over 4

=item * filename

The XML file, which contains the symbology encoding.

=item * class

The "subclass", i.e., element name, of the element to be created.

=item * content

The content of the element. The content of non-simple elements is a
list, while it is a string for simple elements.

=item * attributes

Attributes for the new element.

=back

=item get_objects(CLASS)

Return a list of elements that are immediately within the object.

=item get_object(CLASS [, NAME])

Return an element that has the specified class and name and that is
immediately within the object.

=item add_object(CLASS [, CONTENT])

Add a new element within the object.

=item add

An alias to add_object.

=item set(%ATTRIBUTES)

Sets the attributes of this element.

=item stream(STREAM)

Print the XML. The default stream is STDOUT.

=back

=head2 EXPORT

None by default.

=head1 SEE ALSO

XML::Parser

http://www.opengeospatial.org/standards/symbol

http://www.opengeospatial.org/standards/filter

Lists:

http://lists.hut.fi/pipermail/geo-perl
http://lists.osgeo.org/pipermail/standards/

=head1 AUTHOR

Ari Jolma, E<lt>ari.jolma at aalto.fiE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
