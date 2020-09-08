#! perl

package Data::Properties;

use strict;
use warnings;

# Author          : Johan Vromans
# Created On      : Mon Mar  4 11:51:54 2002
# Last Modified By: Johan Vromans
# Last Modified On: Tue Sep  8 09:43:29 2020
# Update Count    : 370
# Status          : Unknown, Use with caution!

=head1 NAME

Data::Properties -- Flexible properties handling

=head1 SUMMARY

    use Data::Properties;

    my $cfg = new Data::Properties;

    # Preset a property.
    $cfg->set_property("config.version", "1.23");

    # Parse a properties file.
    $cfg->parse_file("config.prp");

    # Get a property value
    $version = $cfg->get_property("config.version");
    # Same, but with a default value.
    $version = $cfg->get_property("config.version", "1.23");

    # Get the list of subkeys for a property, and process them.
    my $aref = $cfg->get_property_keys("item.list");
    foreach my $item ( @$aref ) {
        if ( $cfg->get_property("item.list.$item") ) {
	    ....
	}
    }

=head1 DESCRIPTION

The property mechanism is modelled after the Java implementation of
properties.

In general, a property is a string value that is associated with a
key. A key is a series of names (identifiers) separated with periods.
Names are treated case insensitive. Unlike in Java, the properties are
really hierarchically organized. This means that for a given property
you can fetch the list of its subkeys, and so on. Moreover, the list
of subkeys is returned in the order the properties were defined.

Property lookup can use a preset property context. If a context I<ctx>
has been set using C<set_context('I<ctx>')>,
C<get_property('foo.bar')> will first try C<'I<ctx>.foo.bar'> and
then C<'foo.bar'>. C<get_property('.foo.bar')> (note the leading
period) will only try C<'I<ctx>.foo.bar'> and raise an exception if
no context was set.

Design goals:

=over

=item *

properties must be hierarchical of unlimited depth;

=item *

manual editing of the property files (hence unambiguous syntax and lay out);

=item *

it must be possible to locate all subkeys of a property in the
order they appear in the property file(s);

=item *

lightweight so shell scripts can use it to query properties.

=back

=cut

our $VERSION = "1.0";

use File::LoadLines;
use String::Interpolate::Named;
use Carp;

my $DEBUG = 1;

################ Constructors ################

=over

=item new

I<new> is the standard constructor. I<new> doesn't require any
arguments, but you can pass it a list of initial properties to store
in the resultant properties object.

=cut

sub new {
    unshift(@_, 0);
    &_constructor;
}

=item clone

I<clone> is like I<new>, but it takes an existing properties object as
its invocant and returns a new object with the contents copied.

B<WARNING> This is not a deep copy, so take care.

=cut

sub clone {
    unshift(@_, 1);
    &_constructor;
}

# Internal construction helper.
sub _constructor {
    # Get caller and initial attributes.
    my ($cloning, $invocant, %atts) = @_;

    # If the invocant is an object, get its class.
    my $class = ref($invocant) || $invocant;

    # Initialize and bless the new object.
    my $self = bless({}, $class);

    # Default path.
    $self->{_path} = [ "." ];

    # Initialize.
    $self->{_props} = $cloning ? {%{$invocant->{_props}}} : {};

    # Fill in initial attribute values.
    while ( my ($k, $v) = each(%atts) ) {
	if ( $k eq "_context" ) {
	    $self->{_context} = $v;
	}
	elsif ( $k eq "_debug" ) {
	    $self->{_debug} = 1;
	}
	else {
	    $self->set_property($k, $v);
	}
    }
    $self->{_in_context} = undef;

    # Return.
    $self;
}

################ Methods ################

=item parse_file I<file> [ , I<context> ]

I<parse_file> reads a properties file and adds the contents to the
properties object.

I<file> is the name of the properties file. This file is searched in
all elements of the current search path (see L<set_path()|/"set_path I<paths>">) unless
the name starts with a slash.

I<context> can be used to designate an initial context where all
properties from the file will be subkeys of.

For the detailed format of properties files see L<PROPERTY FILES>.

Reading the file is handled by L<File::LoadLines>. See its
documentation for more power.

=cut

sub parse_file {
    my ($self, $file, $context) = @_;
    $self->_parse_file_internal( $file, $context);

    if ( $self->{_debug} ) {
	use Data::Dumper;
	$Data::Dumper::Indent = 2;
	warn(Data::Dumper->Dump([$self->{_props}],[qw(properties)]), "\n");
    }
    $self;
}

=item parse_lines I<lines> [ , I<filename> [ , I<context> ] ]

As I<parse_file>, but processes an array of lines.

I<filename> is used for diagnostic purposes only.

I<context> can be used to designate an initial context where all
properties from the file will be subkeys of.

=cut

sub parse_lines {
    my ($self, $lines, $file, $context) = @_;
    $self->_parse_lines_internal( $lines, $file, $context);

    if ( $self->{_debug} ) {
	use Data::Dumper;
	$Data::Dumper::Indent = 2;
	warn(Data::Dumper->Dump([$self->{_props}],[qw(properties)]), "\n");
    }
    $self;
}

=item set_path I<paths>

Sets a search path for file lookup.

I<paths> must be reference to an array of paths.

Default I<path> is C<[ '.' ]> (current directory).

=item get_path

Gets the current search path for file lookup.

=cut

sub set_path {
    my ( $self ) = shift;
    my $path = shift;
    if ( @_ > 0 || !UNIVERSAL::isa($path,'ARRAY') ) {
	$path = [ $path, @_ ];
    }
    $self->{_path} = $path;
}

sub get_path {
    my ( $self ) = @_;
    $self->{_path};
}

# internal

sub _parse_file_internal {

    my ($self, $file, $context) = @_;
    my $did = 0;
    my $searchpath = $self->{_path};
    $searchpath = [ '' ] unless $searchpath;

    foreach ( @$searchpath ) {
	my $path = $_;
	$path .= "/" unless $path eq '';

	# Fetch one.
	my $cfg = $file;
	$cfg = $path . $file unless $file =~ m:^/:;
	next unless -e $cfg;

	my $lines = loadlines($cfg);
	$self->parse_lines( $lines, $cfg, $context );
	$did++;

	# We read a file, no need to proceed searching.
	last;
    }

    # Sanity checks.
    croak("No properties $file in " . join(":", @$searchpath)) unless $did;
}

# internal

sub _parse_lines_internal {

    my ( $self, $lines, $filename, $context ) = @_;

    my $stack = $context ? [ $context ] : [];

    # Process its contents.
    foreach ( @$lines ) {

	# Discard empty lines and comment lines/
	next if /^\s*#/;
	next unless /\S/;
	chomp;

	# foo.bar = blech
	# foo.bar = "blech"
	# foo.bar = 'blech'
	# Simple assignment. The value is expanded unless single quotes are used.
	if ( /^\s*([\w.]+)\s*[=:]\s*(.*)/ ) {
	    my $prop = $1;
	    my $value = $2;
	    $value =~ s/\s+$//;

	    # Make a full name.

	    $prop = $stack->[0] . "." . $prop if @$stack;

	    # Handle strings.
	    if ( $value =~ /^'(.*)'\s*$/ ) {
		$value = $1;
	    }
	    elsif ( lc($value) eq "null" ) {
		$value = undef;
	    }
	    else {
		$value = $1 if $value =~ /^"(.*)"\s*$/;
		$value = $self->expand($value, $stack->[0]);
	    }

	    # Set the property.
	    $self->set_property($prop, $value);

	    next;
	}

	# foo.bar {
	# Push a new context.
	if ( /^\s*([\w.]+)\s*{\s*$/ ) {
	    unshift(@$stack, @$stack ? $stack->[0] . "." . $1 : $1);
	    next;
	}

	# include filename
	if ( /^\s*include\s+(.+)/ ) {
	    my $value = $1;
	    # Handle strings.
	    if ( $value =~ /^'(.*)'\s*$/ ) {
		$value = $1;
	    }
	    else {
		$value = $1 if $value =~ /^"(.*)"\s*$/;
		$value = $self->expand($value, $stack->[0]);
	    }
	    $self->_parse_file_internal($value, $stack->[0]);
	    next;
	}

	# }
	# Pop context.
	if ( /^\s*}\s*$/ ) {
	    die("stack underflow at line $.") unless @$stack;
	    shift(@$stack);
	    next;
	}

	# Error.
	croak("?line $.: $_\n");
    }

    # Sanity checks.
    croak("Unfinished properties $filename") if @$stack != ($context ? 1 : 0);
}

=item get_property I<prop> [ , I<default> ]

Get the value for a given property I<prop>.

If a context I<ctx> has been set using C<set_context('I<ctx>')>,
C<get_property('foo.bar')> will first try C<'I<ctx>.foo.bar'> and then
C<'foo.bar'>. C<get_property('.foo.bar')> (note the leading period)
will only try C<'I<ctx>.foo.bar'> and raise an exception if no context
was set.

If no value can be found, I<default> is used.

In either case, the resultant value is examined for references to
other properties or environment variables. See L<PROPERTY FILES> below.

=cut

sub get_property {
    my ($self) = shift;
    $self->expand($self->get_property_noexpand(@_));
}

=item get_property_noexpand I<prop> [ , I<default> ]

This is like I<get_property>, but does not do any expansion.

=cut

sub get_property_noexpand {
    my ($self, $prop, $default) = @_;
    $prop = lc($prop);
    my $ctx = $self->{_context};
    my $context_only;
    if ( ($context_only = $prop =~ s/^\.//) && !$ctx ) {
	croak("get_property: no context for $prop");
    }
    if ( defined($ctx) ) {
	$ctx .= "." if $ctx;
	if ( exists($self->{_props}->{$ctx.$prop}) ) {
	    $self->{_in_context} = $ctx;
	    return $self->{_props}->{$ctx.$prop};
	}
    }
    if ( $context_only ) {
	$self->{_in_context} = undef;
	return $default;
    }
    if ( defined($self->{_props}->{$prop}) && $self->{_props}->{$prop} ne "") {
	$self->{_in_context} = "";
	return $self->{_props}->{$prop};
    }
    $self->{_in_context} = undef;
    $default;
}

=item gps I<prop> [ , I<default> ]

This is like I<get_property>, but raises an exception if no value
could be established.

This is probably the best and safest method to use.

=cut

sub gps {
    my $nargs = @_;
    my ($self, $prop, $default) = @_;
    my $ret = $self->get_property($prop, $default);
    croak("gps: no value for $prop")
      unless defined($ret) || $nargs == 3;
    $ret;
}

=item get_property_keys I<prop>

Returns an array reference with the names of the (sub)keys for the
given property. The names are unqualified, e.g., when properties
C<foo.bar> and C<foo.blech> exist, C<get_property_keys('foo')> would
return C<['bar', 'blech']>.

=cut

sub get_property_keys {
    my ($self, $prop) = @_;
    $prop .= '.' if $prop;
    $prop .= '@';
    $self->get_property_noexpand($prop);
}

=item expand I<value> [ , I<context> ]

Perform the expansion as described with I<get_property>.

=cut

sub expand {
    my ($self, $ret, $ctx) = (@_, "");
    return $ret unless $ret;
    warn("expand($ret,",$ctx//'<undef>',")\n") if $self->{_debug};
    my $props = $self->{_props};
    $ret =~ s:^~(/|$):$ENV{HOME}$1:g;
    return $self->_interpolate( $ret, $ctx );
}

# internal

sub _interpolate {
    my ( $self, $tpl, $ctx ) = @_;
    my $props = $self->{_props};
    return interpolate( { activator => '$',
			  keypattern => qr/\.?\w+[-_\w.]*\??(?::.*)?/,
			  args => sub {
			      my $key = shift;
			      warn("_inter($key,",$ctx//'<undef>',")\n") if $self->{_debug};
			      # Establish the value for this key.
			      my $val = '';

			      my $default = '';
			      ( $key, $default ) = ( $1, $2 )
				if $key =~ /^(.*?):(.*)/;
			      my $checkdef = $key =~ s/\?$//;

			      # If an environment variable exists, take its value.
			      if ( exists($ENV{$key}) ) {
				  $val = $ENV{$key};
				  $val = defined($val) if $checkdef;
			      }
			      else {
				  my $orig = $key;
				  $key = $ctx.$key if ord($key) == ord('.');
				  # For properties, the value should be non-empty.
				  if ( $checkdef ) {
				      $val = defined($props->{lc($key)});
				  }
				  elsif ( defined($props->{lc($key)}) && $props->{lc($key)} ne "" ) {
				      $val = $props->{lc($key)};
				  }
				  else {
				      $val = $default;
				  }
			      }
			      return $val;
			} },
			$tpl );
}

=item set_property I<prop>, I<value>

Set the property to the given value.

=cut

sub set_property {
    my ($self, $prop, $value) = @_;
    my $props = $self->{_props};
    $props->{lc($prop)} = $value;
    my @prop = split(/\./, $prop);
    while ( @prop ) {
	my $last = pop(@prop);
	my $p = lc(join(".", @prop, '@'));
	if ( exists($props->{$p}) ) {
	    push(@{$props->{$p}}, $last)
	      unless index(join("\0","",@{$props->{$p}},""),
			   "\0".$last."\0") >= 0;
	}
	else {
	    $props->{$p} = [ $last ];
	}
    }
}

=item set_properties I<prop1> => I<value1>, ...

Add a hash (key/value pairs) of properties to the set of properties.

=cut

sub set_properties {
    my ($self, %props) = @_;
    foreach ( keys(%props) ) {
	$self->set_property($_, $props{$_});
    }
}

=item set_context I<context>

Set the search context. Without argument, clears the current context.

=cut

sub set_context {
    my ($self, $context) = @_;
    $self->{_context} = lc($context);
    $self->{_in_context} = undef;
    $self;
}

=item get_context

Get the current search context.

=cut

sub get_context {
    my ($self) = @_;
    $self->{_context};
}

=item result_in_context

Get the context status of the last search.

Empty means it was found out of context, a string indicates the
context in which the result was found, and undef indicates search
failure.

=cut

sub result_in_context {
    my ($self) = @_;
    $self->{_in_context};
}

=item dump [ I<start> [ , I<stream> ] ]

Produce a listing of all properties from a given point in the
hierarchy and write it to the I<stream>.

I<stream> defaults to C<*STDOUT>.

=item dumpx [ I<start> [ , I<stream> ] ]

Like dump, but dumps with all values expanded.

=cut

my $dump_expanded;

sub dump {
    my ($self, $start, $fh) = ( @_, '' );
    my $ret = $self->_dump_internal($fh, $start);
    print $fh $ret if $fh;
    $ret;
}

sub dumpx {
    my ($self, $start, $fh) = ( @_, '' );
    $dump_expanded = 1;
    my $ret = $self->dump( $start, $fh );
    $dump_expanded = 0;
    $ret;
}

# internal

sub _dump_internal {
    my ($self, $fh, $cur) = @_;
    $cur .= "." if $cur;
    my $all = $cur;
    $all .= '@';
    my $ret = "";
    if ( my $res = $self->{_props}->{lc($all)} ) {
	$ret .= "# $all = @$res\n" if @$res > 1;
	foreach my $prop ( @$res ) {
	    $ret .= $self->_dump_internal($fh, $cur.$prop);
	    my $val = $self->{_props}->{lc($cur.$prop)};
	    $val = $self->expand($val) if $dump_expanded;
	    next unless defined $val;
	    $val =~ s/(\\\')/\\$1/g;
	    $ret .= "$cur$prop = '$val'\n";
	}
    }
    $ret;
}

################ Package End ################

1;

=back

=head1 PROPERTY FILES

Property files contain definitions for properties. This module uses an
augmented version of the properties as used in e.g. Java.

In general, each line of the file defines one property.

    version: 1
    foo.bar = blech
    foo.xxx = yyy
    foo.xxx = "yyy"
    foo.xxx = 'yyy'

The latter three settings for C<foo.xxx> are equivalent.

Whitespace has no significance. A colon C<:> may be used instead of
C<=>. Lines that are blank or empty, and lines that start with C<#>
are ignored.

Property I<names> consist of one or more identifiers (series of
letters and digits) separated by periods.

Valid values are a plain text (whitespace, but not trailing, allowed),
a single-quoted string, or a double-quoted string (which will allow
escape characters like \n and so in a future version).

B<IMPORTANT:> All values are strings. There is no distinction between

    foo = 1
    foo = "1"
    foo = '1'

and

    foo = Hello World!
    foo = "Hello World!"
    foo = 'Hello World!'

Quotes are required when you want leading and/or trailing whitespace.
Also, the value C<null> is special so if you want to use this as a string
it needs to be quoted.

Single quotes defer expansion, see L</"Expansion"> below.

=head2 Context

When several properties with a common prefix must be set, they can be
grouped in a I<context>:

    foo {
       bar = blech
       xxx = "yyy"
       zzz = 'zyzzy'
    }

Contexts may be nested.

=head2 Includes

Property files can include other property files:

    include "myprops.prp"

All properties that are read from the file are entered in the current
context. E.g.,

    foo {
      include "myprops.prp"
    }

will enter all the properties from the file with an additional C<foo.>
prefix.

=head2 Expansion

Property values can be anything. Unless the value is placed between
single quotes C<''>, the value will be I<expanded> before being assigned
to the property.

Expansion means:

=over

=item *

A tilde C<~> in what looks like a file name will be replaced by the
value of C<${HOME}>.

=item *

If the value contains C<${I<name>}>, I<name> is first looked up in the
current environment. If an environment variable I<name> can be found,
its value is substituted.

If no suitable environment variable exists, I<name> is looked up as a
property and, if it exists and has a non-empty value, this value is
substituted.

Otherwise, the C<${I<name>}> part is removed.

Note that if a property is referred as C<${.I<name>}>, I<name> is
looked up in the current context only.

B<Important:> Property lookup is case insensitive.

=item *

If the value contains C<${I<name>:I<value>}>, I<name> is looked up as
described above. If, however, no suitable value can be found, I<value>
is substituted.

=back

Expansion is delayed if single quotes are used around the value.

    x = 1
    a = ${x}
    b = "${x}"
    c = '${x}'
    x = 2

Now C<a> and C<b> will be C<'1'>, but C<c> will be C<'2'>.

Substitution is handled by String::Interpolate::Named. See its
documentation for more power.

In addition, you can test for a property being defined (not null) by
appending a C<?> to its name.

    result = ${x?|${x|value|empty}|null}

This will yield C<value> if C<x> is not null and not empty, C<empty>
if not null and empty, and C<null> if not defined or defined as null.

=head1 SEE ALSO

L<File::LoadLines>, L<String::Interpolate::Named>.

=head1 BUGS

Although in production for over 25 years, this module is still
slightly experimental and subject to change.

=head1 AUTHOR

Johan Vromans, C<< <JV at cpan.org> >>

=head1 SUPPORT AND DOCUMENTATION

Development of this module takes place on GitHub:
https://github.com/sciurius/perl-Data-Properties.

You can find documentation for this module with the perldoc command.

    perldoc Data::Properties

Please report any bugs or feature requests using the issue tracker on
GitHub.

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2020 Johan Vromans, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Data::Properties
