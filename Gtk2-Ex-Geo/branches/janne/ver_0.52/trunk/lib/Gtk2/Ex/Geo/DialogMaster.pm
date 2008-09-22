package Gtk2::Ex::Geo::DialogMaster;

use strict;
use warnings;
use Carp;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

=pod

=head1 NAME

Gtk2::Ex::Geo::DialogMaster - Something which maintains a set of dialogs

=head1 SYNOPSIS

  use Gtk2::Ex::Geo::DialogMaster;

=head1 DESCRIPTION

=head2 EXPORT

=head1 METHODS

=head2 new

=cut

sub new {
    my($class, %params) = @_;
    my $self = {};
    $self->{path} = $params{add_from_folder};
    $self->{resources} = $params{resources};
    $self->{glue} = $params{glue};
    $self->{overlay} = $params{overlay};
    $self->{main_window} = $params{main_window};
    $self->{buffer} = $params{buffer};
    bless $self => (ref($class) or $class);
    return $self;
}

sub get_dialog {
    my($self, $dialog_name) = @_;
    my @buf = ('<glade-interface>');
    my $push = 0;
    for (@{$self->{buffer}}) {
	$push = 1 if (/^<widget/ and /$dialog_name/);
	push @buf, $_ if $push;
	$push = 0 if /^<\/widget/;
    }
    push @buf, '</glade-interface>';
    my $gladexml = Gtk2::GladeXML->new_from_buffer("@buf");
    my $dialog = $gladexml->get_widget($dialog_name);
    return unless $dialog;
    #$dialog->signal_connect(delete_event => \&hide_dialog);
    return $gladexml;
}

sub hide_dialog {
    my($dialog) = @_;
    $dialog->hide();
}

sub close {
    my $self = shift;
    if (1) { # this is not overkill, problems appear in global destruction without this
	my %w;
	if ($self->{buffer}) {
	    for (@{$self->{buffer}}) {
		my ($a) = /id=\"(\w+)\"/;
		$w{$a} = $self->{glade}->get_widget($a) if $a;
	    }
	}
	for (keys %w) {
	    $w{$_}->destroy if defined $w{$_};
	}
    }
    delete $self->{glade};
}

sub hide_on_delete {
    my($self, $dialog) = @_;
    my $widget = $self->widget($dialog);
    return unless $widget;
    $widget->signal_connect(delete_event => \&close_dialog, [$self, $dialog]);
}

sub hide_on_click {
    my($self, $dialog, $button) = @_;
    my $widget = $self->widget($button);
    return unless $widget;
    $widget->signal_connect(clicked => \&close_dialog, [$self, $dialog]);
}

sub widget {
    my($self, $widget) = @_;
    return unless $self->{glade};
    my $w = $self->{glade}->get_widget($widget);
    croak("error: widget '$widget' not found") unless $w;
    return $w;
}

sub open_dialog {
    my($self, $dialog, $title, $layer, $do_not_show) = @_;
    my $widget = widget($self, $dialog);

    $title .= ' '.$layer->name if $layer;
    $widget->set_title($title) if $title;

    # some X managers don't save the window position
    $widget->move(@{$self->{dialogs}{$dialog}{position}}) 
	if $self->{dialogs}{$dialog}{position} and $self->{dialogs}{$dialog}{hidden};

    $widget->show_all unless $do_not_show;
    $self->{dialogs}{$dialog}{hidden} = 0;
    $self->{dialogs}{$dialog}{dialog} = $widget;
    $self->{dialogs}{$dialog}{layer} = $layer;

    return $widget;
}

sub close_dialog {
    my($self, $dialog);
    for (@_) {
	next unless ref eq 'ARRAY';
	($self, $dialog) = @{$_};
    }
    croak("error: close_dialog called without master") unless $self;
    my $widget = widget($self, $dialog);
    $self->{dialogs}{$dialog}{position} = [$widget->get_position];
    $self->{dialogs}{$dialog}{hidden} = 1;
    $widget->hide();
    return 1;
}

sub get_active_dialog {
    my $self = shift;
    for my $dialog (keys %{$self->{dialogs}}) {
	my $widget = $self->{dialogs}{$dialog}{dialog};
	return $dialog if $widget and $widget->has_toplevel_focus;
    }
}

sub get_active_layer {
    my $self = shift;
    my $dialog = get_active_dialog($self);
    return $self->{dialogs}{$dialog}{layer} if $dialog;
}

sub message {
    my($self, $message) = @_;
    my $parent = $self->{main_window} if $self->{main_window};
    my $dialog = Gtk2::MessageDialog->new(undef,'destroy-with-parent','info','close',$message);
    $dialog->signal_connect(response => \&destroy_dialog);
    $dialog->show_all;
}

sub destroy_dialog {
    my($dialog) = @_;
    $dialog->destroy;
}

sub prepare_simple_combo {
    my($self, $combo) = @_;
    my $c = $self->widget($combo);
    $c->set_model(Gtk2::ListStore->new('Glib::String'));
    my $cell = Gtk2::CellRendererText->new;
    $c->pack_start($cell, 1);
    $c->add_attribute($cell, text => 0);
    return $c;
}

1;
=pod

=head1 SEE ALSO

Gtk2::Ex::Geo

=head1 AUTHOR

Ari Jolma, E<lt>ajolma at tkk.fiE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
