# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Geo-OGC-SymbologyEncoding.t'

#########################

use Test::More tests => 3;
BEGIN { use_ok('Geo::OGC::SymbologyEncoding') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $s0 = Geo::OGC::SymbologyEncoding->new(filename => 't/test.xml');

my $s = Geo::OGC::SymbologyEncoding->new();
$m = $s->add_object('MapDescription');

$m->{'version'} = "1.1.0";
$m->{'xsi:schemaLocation'} = "http://www.opengis.net/se/1.1.0/FeatureStyle.xsd";
$m->{'xmlns'} = "http://www.opengis.net/se";
$m->{'xmlns:ogc'} = "http://www.opengis.net/ogc";
$m->{'xmlns:xlink'} = "http://www.w3.org/1999/xlink";
$m->{'xmlns:xsi'} = "http://www.w3.org/2001/XMLSchema-instance";

$t = $m->add_object('Coverage');
$t->{style} = 'style1';
$t->add('URL', ['file://c:/data/corine/clc_fi25m.tif']);

$t = $m->add_object('CoverageStyle');
$t->add_object('Name', 'style1');
$r = $t->add_object('Rule');
$r->add_object('Name', 'ChannelSelection');
$r->add_object('Description')->add_object('Title', 'Gray channel mapping');
$sym = $r->add_object('RasterSymbolizer');
$sym->add('ChannelSelection')->add('GrayChannel')->add('SourceChannelName', 'Band.band1');
$sym->add_object('ContrastEnhancement')->add_object('Normalize');
$t = $m->add('CoverageStyle');
$t->add('Name', 'style2');
$r = $t->add('Rule');
$r->add('Name', 'Roads');
$r->add('Description')->add('Title', 'Gray channel mapping');
$sym = $r->add('LineSymbolizer');
$sym->add('Name', 'MyLineSymbolizer');
$d = $sym->add('Description');
$d->add('Title', 'Example Symbol');
$d->add('Abstract', 'This is just a simple example of a line symbolizer.');
$d = $sym->add('Stroke');
$d->add('SvgParameter', ['#0000ff'])->set(name=>'stroke');
$p = $d->add('SvgParameter');
$p->set(name=>'stroke-width');
$a = $p->add('Add');
$a->add('PropertyName', ['A']);
$a->add('Literal', [2]);
$sym = $r->add('TextSymbolizer');
$sym->add('Name', 'MyTextSymbolizer');
$d = $sym->add('Description');
$d->add('Title', 'Example TextSymbolizer');
$d->add('Abstract', 'This is just an example of a text symbolizer using the FormatNumber function.');
$sym->add('Geometry')->add('PropertyName', ['locatedAt']);
$f = Geo::OGC::SymbologyEncoding->new(class=>'FormatNumber', 
				      attributes=>{fallbackValue=>''});
$f->add('NumericValue')->add('PropertyName', ['numberOfBeds']);
$f->add('Pattern', '#####');
$l = $sym->add('Label', 
	       [
		Geo::OGC::SymbologyEncoding->new(class=>'PropertyName', content=>['hospitalName']),
		' (',
		$f,
		')  '
		]);
$l = 1;
$f = $sym->add('Font');
$f->add('SvgParameter', ['Arial'])->set(name=>'font-family');
$f->add('SvgParameter', ['Sans-Serif'])->set(name=>'font-family');
$f->add('SvgParameter', ['italic'])->set(name=>'font-style');
$f->add('SvgParameter', [10])->set(name=>'font-size');
$sym->add('Halo');
$sym->add('Fill')->add('SvgParameter', ['#000000'])->set(name=>'fill');

open TEST, ">test-a.xml" or die "$!: test-a.xml";
$s0->stream(\*TEST);
close TEST;
open TEST, ">test-b.xml" or die "$!: test-b.xml";
$s->stream(\*TEST);
close TEST;

open TEST, "test-a.xml" or die "$!: test-a.xml";
@a = <TEST>;
close TEST;
open TEST, "test-b.xml" or die "$!: test-a.xml";
@b = <TEST>;
close TEST;

for (0..length($a[1])) {
    my $a = substr($a[1],$_,1);
    my $b = substr($b[1],$_,1);
    #print STDERR "$a $b\n";
    last if $a ne $b;
}

ok(is_deeply(\@a, \@b), "comparison of opened and created");
