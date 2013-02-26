package Dist::Zilla::PluginBundle::Alien;
BEGIN {
  $Dist::Zilla::PluginBundle::Alien::AUTHORITY = 'cpan:GETTY';
}
{
  $Dist::Zilla::PluginBundle::Alien::VERSION = '0.004';
}
# ABSTRACT: Dist::Zilla::PluginBundle::Basic for Alien

use Moose;
use Moose::Autobox;
use Dist::Zilla;
with 'Dist::Zilla::Role::PluginBundle::Easy';


use Dist::Zilla::PluginBundle::Basic;

sub configure {
  my ($self) = @_;

  $self->add_bundle('Filter' => {
    -bundle => '@Basic',
    -remove => ['MakeMaker'],
  });

  $self->add_plugins([ 'Alien' => {
    map { $_ => $self->payload->{$_} } keys %{$self->payload},
  }]);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Dist::Zilla::PluginBundle::Alien - Dist::Zilla::PluginBundle::Basic for Alien

=head1 VERSION

version 0.004

=head1 SYNOPSIS

In your B<dist.ini>:

  name = Alien-ffmpeg

  [@Alien]
  repo = http://ffmpeg.org/releases

=head1 DESCRIPTION

This plugin bundle allows to use L<Dist::Zilla::Plugin::Alien> together
with L<Dist::Zilla::PluginBundle::Basic>.

=head1 AUTHOR

Torsten Raudssus <torsten@raudss.us>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

