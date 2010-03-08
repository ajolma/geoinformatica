package Geo::Vector::Feature;
# @brief A root class for complex features

use strict;
use warnings;
use UNIVERSAL qw(isa);
use Carp;
use Encode;
use Geo::OGC::Geometry;

sub new {
    my $package = shift;
    my %params = @_;
    my $self = {};
    bless $self => (ref($package) or $package);
    %$self = %params;
    $self->{OGRDefn} = Geo::OGR::FeatureDefn->new();
    $self->{OGRFeature} = Geo::OGR::Feature->new($self->{OGRDefn});
    return $self;
}

sub Schema {
    my($self) = @_;
    return {
	Class => $self->{Class},
	Name => '',
	GeometryType => '',
	Fields => [
	    { 
		Name => 'Class',
		Type => 'String'
	    },
	    {
		Name => 'Name',
		Type => 'String'
	    },
	    ],
    }
}

sub Field {
    my($self, $field, $value) = @_;
    $self->{$field} = $value if defined $value;
    $self->{$field};
}
*GetField = *Field;

sub Geometry {
    my($self, $geom) = @_;
    $self->{OGRFeature}->SetGeometry($geom) if $geom;
    $self->{OGRFeature}->GetGeometryRef();
}
*SetGeometry = *Geometry;
*GetGeometryRef = *Geometry;

sub FID {
    my($self, $fid) = @_;
    $self->{FID} = $fid if defined $fid;
    $self->{FID};
}
*GetFID = *FID;

1;
