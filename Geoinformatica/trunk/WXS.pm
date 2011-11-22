package WXS;

use Carp;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw/config header error serve_document xml_elements xml_element/;

use Encode;
use JSON;

sub config {
    my $conf = shift;
    open(my $fh, '<', $conf) or die $!;
    binmode $fh, ":utf8";
    my @json = <$fh>;
    close $fh;
    $config = JSON->new->utf8->decode(encode('UTF-8', "@json"));
}

sub header {
    my %arg = @_;
    if ($arg{length}) {
	print "Content-type: $arg{type}\n";
	print "Content-length: $arg{length}\n\n";
    } else {
	print($arg{cgi}->header(-type => $arg{type}, -charset=>'utf-8'));
    }
    STDOUT->flush;
    return 1;
}

sub error {
    my %arg = @_;
    select(STDOUT);
    header(%arg) unless $arg{header};
    print('<?xml version="1.0" encoding="UTF-8"?>',"\n");
    my($error) = ($arg{msg} =~ /(.*?)\.\#/);
    if ($error) {
	$error =~ s/ $//;
	$error = { code => $error } if $error eq 'LayerNotDefined';
    } else {
	$error = 'Unspecified error: '.$arg{msg};
    }
    xml_element('ServiceExceptionReport',['ServiceException', $error]);
}

sub serve_document {
    my($doc, $type) = @_;
    my $length = (stat($doc))[10];
    croak "Can't stat file to serve" unless $length;    
    open(DOC, '<', $doc) or croak "Couldn't open $doc: $!";
    header(type => $type, length => $length);
    my $data;
    while( sysread(DOC, $data, 10240) ) {
	print $data;
    }
    close DOC;
}

sub xml_elements {
    for my $e (@_) {
	if (ref($e) eq 'ARRAY') {
	    xml_element(@$e);
	} else {
	    xml_element($e->{element}, $e->{attributes}, $e->{content});
	}
    }
}

sub xml_element {
    my $element = shift;
    my $attributes;
    my $content;
    for my $x (@_) {
	$attributes = $x, next if ref($x) eq 'HASH';
	$content = $x;
    }
    #print(encode utf8=>"<$element");
    print("<$element");
    if ($attributes) {
	for my $a (keys %$attributes) {
	    #print(encode utf8=>" $a=\"$attributes->{$a}\"");
	    print(" $a=\"$attributes->{$a}\"");
	}
    }
    unless ($content) {
	print("/>");
    } else {
	if (ref $content) {
	    print(">");
	    if (ref $content->[0]) {
		for my $e (@$content) {
		    xml_element(@$e);
		}
	    } else {
		xml_element(@$content);
	    }
	    #print(encode utf8=>"</$element>");
	    print("</$element>");
	} elsif ($content eq '>' or $content eq '<' or $content eq '<>') {
	    print(">");
	} elsif ($content) {
	    #print(encode utf8=>">$content</$element>");
	    print(">$content</$element>");
	}
    }
}

1;
