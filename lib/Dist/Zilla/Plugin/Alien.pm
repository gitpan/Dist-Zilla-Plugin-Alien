package Dist::Zilla::Plugin::Alien;
BEGIN {
  $Dist::Zilla::Plugin::Alien::AUTHORITY = 'cpan:GETTY';
}
{
  $Dist::Zilla::Plugin::Alien::VERSION = '0.003';
}
# ABSTRACT: Use Alien::Base with Dist::Zilla

use Moose;
extends 'Dist::Zilla::Plugin::ModuleBuild';
with 'Dist::Zilla::Role::PrereqSource';

use URI;


has name => (
	isa => 'Str',
	is => 'rw',
	lazy_build => 1,
);
sub _build_name {
	my ( $self ) = @_;
	my $name = $self->zilla->name;
	$name =~ s/^Alien-//g;
	return $name;
}

has repo => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

has repo_uri => (
	isa => 'URI',
	is => 'rw',
	lazy_build => 1,
);
sub _build_repo_uri {
	my ( $self ) = @_;
	URI->new($self->repo);
}

has pattern_prefix => (
	isa => 'Str',
	is => 'rw',
	lazy_build => 1,
);
sub _build_pattern_prefix {
	my ( $self ) = @_;
	return $self->name.'-';
}

has pattern_version => (
	isa => 'Str',
	is => 'rw',
	lazy_build => 1,
);
sub _build_pattern_version { '([\d\.]+)' }

has pattern_suffix => (
	isa => 'Str',
	is => 'rw',
	lazy_build => 1,
);
sub _build_pattern_suffix { '\\.tar\\.gz' }

has pattern => (
	isa => 'Str',
	is => 'rw',
	lazy_build => 1,
);
sub _build_pattern {
	my ( $self ) = @_;
	join("",
		$self->pattern_prefix.
		$self->pattern_version.
		$self->pattern_suffix
	);
}

sub register_prereqs {
	my ( $self ) = @_;
	$self->zilla->register_prereqs({
			type  => 'requires',
			phase => 'configure',
		},
		'Alien::Base' => '0.002',
	);
	$self->zilla->register_prereqs({
			type  => 'requires',
			phase => 'runtime',
		},
		'Alien::Base' => '0.002',
	);
}

has "+mb_class" => (
	default => 'Alien::Base::ModuleBuild',
);

around module_build_args => sub {
	my ($orig, $self, @args) = @_;
	my $pattern = $self->pattern;
	return {
		%{ $self->$orig(@args) },
		alien_name => $self->name,
		alien_repository => {
			protocol => $self->repo_uri->scheme,
			host => $self->repo_uri->host_port,
			location => $self->repo_uri->path,
			pattern => qr/^$pattern$/,
		},
	};
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Dist::Zilla::Plugin::Alien - Use Alien::Base with Dist::Zilla

=head1 VERSION

version 0.003

=head1 DESCRIPTION

  name = Alien-myapp

  [Alien]
  repo = http://ffmpeg.org/releases
  name = myapp
  pattern_prefix = myapp-
  pattern_version = ([\d\.]+)
  pattern_suffix = \.tar\.gz
  pattern = myapp-([\d\.]+)\.tar\.gz

=head1 AUTHOR

Torsten Raudssus <torsten@raudss.us>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

