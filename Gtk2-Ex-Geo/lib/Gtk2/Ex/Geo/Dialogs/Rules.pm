package Gtk2::Ex::Geo::Dialogs::Rules;
# @brief 

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs qw /:all/;
use Gtk2::Ex::Geo::Layer;

use vars qw/%columns %column_numbers/;

%columns = (0 => 'Name', 
	    1 => 'MinScale', 
	    2 => 'MaxScale',
	    3 => 'Filter',
	    4 => 'Property',
	    5 => 'Cmp',
	    6 => 'Value');
%column_numbers = map { $columns{$_} => $_ } keys %columns;

# rules dialog

sub open {
    my($self, $gui) = @_;

    my($dialog, $boot) = $self->bootstrap_dialog
	($gui, 'rules_dialog', "Rules for ".$self->name,
	 {
	     rules_dialog => [delete_event => \&cancel, [$self, $gui]],
	     rules_add_button => [clicked => \&add, [$self, $gui]],
	     rules_delete_button => [clicked => \&delete, [$self, $gui]],
	     rules_cancel_button => [clicked => \&cancel, [$self, $gui]],
	     rules_ok_button => [clicked => \&ok, [$self, $gui]],
	 },
	 [qw //]
	);
    if ($boot) {

	# a rule has name, type: if/else, 
	# minscale, maxscale (both optional)
	# rules of type: property <|<=|==|=>|> value; property is field name or GeometryType
	my $treeview = $self->{rules_dialog}->get_widget('rules_treeview');
	my $model = Gtk2::TreeStore->new(
	    qw/Glib::String Glib::String Glib::String Glib::String Glib::String Glib::String Glib::String/);
	$treeview->set_model($model);
	my $i = 0;
	for my $attr (sort {$a <=> $b} keys %columns) {
	    my $cell = Gtk2::CellRendererText->new;
	    $cell->set(editable => 1);
	    $cell->signal_connect(edited => \&edit, [$self, $i]);
	    my $column = Gtk2::TreeViewColumn->new_with_attributes($columns{$attr}, $cell, text => $i++);
	    $treeview->append_column($column);
	}

	set_rules($self);

    }

    # back up data, make $self->{SAVED_RULES} a copy of $self->{RULES}
    $self->{SAVED_RULES} = $self->copy_of_rules;

    return $dialog->get_widget('rules_dialog');
}

##@ignore
sub cancel {
    my($self, $gui);
    for (@_) {
	next unless ref CORE::eq 'ARRAY';
	($self, $gui) = @{$_};
    }
    # restore saved temporary rules
    $self->{RULES} = $self->{SAVED_RULES};

    $self->hide_dialog('rules_dialog');
    $gui->{overlay}->render;
    1;
}

##@ignore
sub ok {
    my($self, $gui) = @{$_[1]};
    my $ok = 1;
    # do tests
    # only one Else filter per MinScale/MaxScale pair
    # Scale ranges must not overlap

    # delete saved temporary rules
    delete $self->{SAVED_RULES} if $ok;

    $self->hide_dialog('rules_dialog');
    $gui->set_layer($self);
    $gui->{overlay}->render;
}

sub set_rules {
    my $self = shift;
    my $treeview = $self->{rules_dialog}->get_widget('rules_treeview');
    my $model = $treeview->get_model;

    $self->{RULES} = [
	{ Name => 'rule1',
	  MinScale => 1,
	  MaxScale => 10,
	  Filter => {
	      Property => 'sarake',
	      Cmp => '==',
	      Value => 15
	  } },
	{ Name => 'rule2'
	},
	{ Name => 'rule3',
	  MinScale => undef,
	  MaxScale => undef,
	  Filter => 'Else'
	} ];
    
    for my $rule (@{$self->{RULES}}) {
	my $iter = $model->insert(undef, $#{$self->{RULES}}+1);
	my $i = 0;
	my @set = ($i++, $rule->{Name});
	push @set, ($i++, exists $rule->{MinScale} ? $rule->{MinScale} : undef);
	push @set, ($i++, exists $rule->{MaxScale} ? $rule->{MaxScale} : undef);
	if (not exists $rule->{Filter}) {
	} elsif (not ref $rule->{Filter}) {
	    push @set, ($i++, $rule->{Filter});
	} else {
	    push @set, ($i++, undef);
	    push @set, ($i++, $rule->{Filter}{Property});
	    push @set, ($i++, $rule->{Filter}{Cmp});
	    push @set, ($i++, $rule->{Filter}{Value});
	}
	$model->set($iter, @set);
    }

    my $row = 0;
    while (my $iter = $model->get_iter_from_string($row)) {
	for my $column (0..6) {
	    my $x = $model->get_value($iter, $column) || '.';
	    print STDERR $x.' ';
	}
	print STDERR "\n";
	$row++;
    }
}

sub copy_of_rules {
    my $self = shift;
    my @rules;
    for my $rule (@{$self->{RULES}}) {
	my %copy = ( Name => $rule->{Name} );
	$copy{MinScale} = $rule->{MinScale} if exists $rule->{MinScale};
	$copy{MaxScale} = $rule->{MaxScale} if exists $rule->{MaxScale};
	if (exists $rule->{Filter}) {
	    if (not ref $rule->{Filter}) {
		$copy{Filter} = $rule->{Filter};
	    } else {
		$copy{Filter}{Property} = $rule->{Filter}{Property};
		$copy{Filter}{Cmp} = $rule->{Filter}{Cmp};
		$copy{Filter}{Value} = $rule->{Filter}{Value};
	    }
	}
	push @rules, \%copy;
    }
    return \@rules;
}

sub print_rules {
    my($self, $file) = @_;
    for my $rule (@{$self->{RULES}}) {
	print $file $rule->{Name};
	print $file "\t",(exists $rule->{MinScale} ? $rule->{MinScale} : '');
	print $file "\t",(exists $rule->{MaxScale} ? $rule->{MaxScale} : '');
	if (exists $rule->{Filter}) {
	    if (not ref $rule->{Filter}) {
		print $file "\t",$rule->{Filter};
	    } else {
		print $file "\t";
		print $file "\t",$rule->{Filter}{Property};
		print $file "\t",$rule->{Filter}{Cmp};
		print $file "\t",$rule->{Filter}{Value};
	    }
	}
    }
}

sub read_rules {
    my($self, $file) = @_;
    my @rules = <$file>;
    for (@rules) {
	chomp;
	my() = split
    for my $rule (@{$self->{RULES}}) {
	print $file $rule->{Name};
	print $file "\t",(exists $rule->{MinScale} ? $rule->{MinScale} : '');
	print $file "\t",(exists $rule->{MaxScale} ? $rule->{MaxScale} : '');
	if (exists $rule->{Filter}) {
	    if (not ref $rule->{Filter}) {
		print $file "\t",$rule->{Filter};
	    } else {
		print $file "\t";
		print $file "\t",$rule->{Filter}{Property};
		print $file "\t",$rule->{Filter}{Cmp};
		print $file "\t",$rule->{Filter}{Value};
	    }
	}
    }
}

##@ignore
sub add {
    my($self, $gui) = @{$_[1]};
    # add to the treeview a new blank rule
    # a rule has name, type: if/else, 
    # minscale, maxscale (both optional)
    # rules of type: property <|<=|==|=>|> value; property is field name or GeometryType
    my $treeview = $self->{rules_dialog}->get_widget('rules_treeview');
    my $model = $treeview->get_model;
    my $selection = $treeview->get_selection;
    my($row) = $selection->get_selected_rows;
    my $iter;
    if ($row) {
	$iter = $model->get_iter_from_string($row->to_string);
	$iter = $model->insert_after(undef, $iter);
    } else {
	$iter = $model->insert(undef, 1000);
    }
    # get a unique name suggestion for the new rule
    $model->set($iter, 0 => 'Rule1', 1 => '', 2 => '', 3 => '', 4 => '', 5 => '', 6 => '' );
}

##@ignore
sub delete {
    my($self, $gui) = @{$_[1]};
    # delete the selected rule(s) from the treeview
    my $treeview = $self->{rules_dialog}->get_widget('rules_treeview');
    my $model = $treeview->get_model;
    my $selection = $treeview->get_selection;
    my($row) = $selection->get_selected_rows;
    return unless $row;
    my $iter = $model->get_iter_from_string($row->to_string);
    my $title = $model->get_value($iter, 0) || '';
    print STDERR $row->to_string,", $title\n";
    $model->remove($iter);
}

sub edit {
    my($cell, $path, $new, $data) = @_;
    my($self, $column) = @$data;
    my($r) = $path =~ /^(\w+)/;
    print STDERR "$self, col=$column, cell=$cell, path=$path, new=$new\n";
    my $treeview = $self->{rules_dialog}->get_widget('rules_treeview');
    my $selection = $treeview->get_selection;
    my($row) = $selection->get_selected_rows;
    print STDERR $row->to_string," | $r\n";
    my $model = $treeview->get_model;
    my $iter = $model->get_iter_from_string($row->to_string);
    my $old = $model->get_value($iter, $column) || '';
    my $column_name = $columns{$column};
    my $ok = 1;
    my $msg;
    my $value_ref;
    if ($column_name eq 'Name') {
	# Names must be unique and not empty
	for my $rule (@{$self->{RULES}}) {
	    next if $rule->{Name} eq $old;
	    $ok = 0, last if $rule->{Name} eq $new;
	}
	$msg = "Rule with name '$new' already exists in this layer." unless $ok;
	if ($new eq '') {
	    $msg = "Rule name can't be an empty string.";
	    $ok = 0;
	}
	$value_ref = \$self->{RULES}[$r]{Name};
    } elsif ($column_name eq 'MinScale') {
	# MinScale must be numeric
	$value_ref = \$self->{RULES}[$r]{MinScale};
    } elsif ($column_name eq 'MaxScale') {
	# MaxScale must be numeric
	$value_ref = \$self->{RULES}[$r]{MaxScale};
    } elsif ($column_name eq 'Filter') {
	# Filter is either null or Else
	# setting filter to Else deletes it
	if ($new ne '' and $new ne 'Else') {
	    $msg = "Value in the Filter column must be empty or 'Else'.";
	    $ok = 0;
	}
	if ($new eq 'Else') {
	    delete $self->{RULES}[$r]{Filter};
	    for my $c (qw/Property Cmp Value/) {
		$model->set_value($iter, $column_numbers{$c}, undef);
	    }
	}
	$value_ref = \$self->{RULES}[$r]{Filter};
    } elsif ($column_name eq 'Property') {
	# Property must be a field of the layer
	my @fields = $self->schema->fields;
	my @field_names;
	$ok = 0;
	for my $field (@fields) {
	    $ok = 1 if $new eq $field->{Name};
	    push @field_names, $field->{Name};
	}
	my $properties = join("', '", @field_names);
	$msg = "'$new' is not a property of this layer.\nThe properties are: '$properties'." unless $ok;
	$value_ref = \$self->{RULES}[$r]{Filter}{Property};
    } elsif ($column_name eq 'Cmp') {
	# The comparison operator must be one of <, <=, =, >=, >
	$ok = 0;
	for my $op (qw/< <= = >= >/) {
	    $ok = 1 if $new eq $op;
	}
	$msg = "'$new' is not a valid comparison operator.\n".
	    "The operators are: <, <=, =, >=, and >." unless $ok;
	$value_ref = \$self->{RULES}[$r]{Filter}{Cmp};
    } elsif ($column_name eq 'Value') {
	# The value must be integer if the type of the Property is Integer and number if the type is Real
	$value_ref = \$self->{RULES}[$r]{Filter}{Value};
    }
    if ($ok) {
	$model->set_value($iter, $column, $new);
	$$value_ref = $new;
	my $row = 0;
	while (my $iter = $model->get_iter_from_string($row)) {
	    for my $column (0..6) {
		my $x = $model->get_value($iter, $column) || '.';
		print STDERR $x.' ';
	    }
	    print STDERR "\n";
	    $row++;
	}
    } else {
	my $m = Gtk2::MessageDialog->new(undef,'destroy-with-parent','info','ok',$msg);
	$m->run;
	$m->destroy;
    }
}

1;
