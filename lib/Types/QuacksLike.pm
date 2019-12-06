package Types::QuacksLike;
use strict;
use warnings;

our $VERSION = '0.001000';
$VERSION =~ tr/_//d;

use Type::Library -base;
use Types::Standard qw(ClassName Object);
BEGIN {
  if ("$]" >= 5.010_000) {
    require mro;
  } else {
    require MRO::Compat;
  }
  local $@;
  if (eval { require Sub::Util; defined &Sub::Util::subname }) {
    *_stash_name = sub {
      my $name = Sub::Util::subname($_[0]);
      $name =~ s{::[^:]+\z}{};
      $name;
    };
  }
  else {
    require B;
    *_stash_name = sub {
      my ($coderef) = @_;
      ref $coderef or return;
      my $cv = B::svref_2object($coderef);
      $cv->isa('B::CV') or return;
      $cv->GV->isa('B::SPECIAL') and return;
      $cv->GV->STASH->NAME;
    };
  }
}

my $meta = __PACKAGE__->meta;

sub _get_methods {
  my $package = shift;
  my $meta;
  if ($INC{'Moo/Role.pm'} && Moo::Role->is_role($package)) {
    return Moo::Role->methods_provided_by($package);
  }
  elsif ($INC{'Role/Tiny.pm'} && Role::Tiny->is_role($package)) {
    return Role::Tiny->methods_provided_by($package);
  }
  elsif ($INC{'Class/MOP.pm'} and $meta = Class::MOP::class_of($package)) {
    if ($meta->can('get_all_method_names')) {
      return $meta->get_all_method_names;
    }
    elsif ($meta->can('get_method_list')) {
      return $meta->get_method_list;
    }
    elsif ($meta->can('list_all_symbols')) {
      return $meta->list_all_symbols('CODE');
    }
  }
  else {
    my @methods;
    my %s;
    my $moo_method;
    if ($INC{'Moo.pm'}) {
      $moo_method = Moo->can('is_class') ? 'is_class' : '_accessor_maker_for';
    }

    for my $isa (@{mro::get_linear_isa($package)}) {
      if ($moo_method && Moo->$moo_method($isa)) {
        push @methods, keys %{ Moo->_concrete_methods_of($isa) };
      }
      else {
        no strict 'refs';
        my $does
          = $isa->can('does') ? 'does'
          : $isa->can('DOES') ? 'DOES'
          : undef;
        my $stash = \%{"${isa}::"};
        my @subs = grep {
          my $entry = $stash->{$_};
          defined $entry && !(ref $entry ne 'HASH');
        } keys %$stash;
        for my $name (@subs) {
          my $code_stash;
          if (
            $name =~ /\A\(/
            or (
              $code_stash = _stash_name(\&{"${isa}::${name}"})
              and (
                $code_stash eq $isa
                or $code_stash eq 'constant'
                or $does && $isa->$does($code_stash)
              )
            )
          ) {
            push @methods, $name;
          }
        };
      }
    }
    return @methods;
  }
  return ();
}

my $class_name = ClassName;

$meta->add_type({
  name    => "QuacksLike",
  parent  => Object,
  constraint_generator => sub {
    my @packages = @_;
    return Object unless @_;
    $class_name->($_) for @_;
    my %s;
    my @methods = sort grep !$s{$_}++, map _get_methods($_), @_;

    require Type::Tiny::Duck;
    return Type::Tiny::Duck->new(
      methods      => \@methods,
      display_name => sprintf('QuacksLike[%s]', join q[,], map qq{"$_"}, @packages),
    );
  },
});

1;
__END__

=head1 NAME

Types::QuacksLike - Check for object providing all methods from a class or role

=head1 SYNOPSIS

  use Types::QuacksLike -all;

=head1 DESCRIPTION

Check for object providing all methods from a class or role.

=head1 AUTHOR

haarg - Graham Knop (cpan:HAARG) <haarg@haarg.org>

=head1 CONTRIBUTORS

None so far.

=head1 COPYRIGHT

Copyright (c) 2019 the Types::QuacksLike L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself. See L<https://dev.perl.org/licenses/>.

=cut
