package Dist::Zilla::Plugin::Alien;
BEGIN {
  $Dist::Zilla::Plugin::Alien::AUTHORITY = 'cpan:GETTY';
}
# ABSTRACT: Use Alien::Base with Dist::Zilla
$Dist::Zilla::Plugin::Alien::VERSION = '0.011';
use Moose;
extends 'Dist::Zilla::Plugin::ModuleBuild';
with 'Dist::Zilla::Role::PrereqSource', 'Dist::Zilla::Role::FileGatherer';


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

has bins => (
	isa => 'Str',
	is => 'rw',
	predicate => 'has_bins',
);

has split_bins => (
	isa => 'ArrayRef',
	is => 'rw',
	lazy_build => 1,
);
sub _build_split_bins { $_[0]->has_bins ? [split(/\s+/,$_[0]->bins)] : [] }

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

has build_command => (
	isa => 'ArrayRef[Str]',
	is => 'rw',
);

has install_command => (
	isa => 'ArrayRef[Str]',
	is => 'rw',
);

has isolate_dynamic => (
	isa => 'Int',
	is => 'rw',
);

has autoconf_with_pic => (
	isa => 'Int',
	is => 'rw',
);

# multiple build/install commands return as an arrayref
around mvp_multivalue_args => sub {
  my ($orig, $self) = @_;
  return ($self->$orig, 'build_command', 'install_command');
};

sub register_prereqs {
	my ( $self ) = @_;

	my $ab_version = '0.002';

	if(defined $self->isolate_dynamic || defined $self->autoconf_with_pic || grep /%c/, @{ $self->build_command || [] }) {
		$ab_version = '0.005';
	}

	$self->zilla->register_prereqs({
			type  => 'requires',
			phase => 'configure',
		},
		'Alien::Base' => $ab_version,
		'File::ShareDir' => '1.03',
		@{ $self->split_bins } > 0 ? ('Path::Class' => '0.013') : (),
	);
	$self->zilla->register_prereqs({
			type  => 'requires',
			phase => 'runtime',
		},
		'Alien::Base' => $ab_version,
		'File::ShareDir' => '1.03',
		@{ $self->split_bins } > 0 ? ('Path::Class' => '0.013') : (),
	);
}

has "+mb_class" => (
	default => 'Alien::Base::ModuleBuild',
);

sub gather_files {
	my ( $self ) = @_;

	my $template = <<'__EOT__';
#!/usr/bin/env perl
# PODNAME: {{ $bin }}
# ABSTRACT: Command {{ $bin }} of {{ $dist->name }}

$|=1;

use strict;
use warnings;
use File::ShareDir ':ALL';
use Path::Class;

my $abs = file(dist_dir('{{ $dist->name }}'),'bin','{{ $bin }}')->cleanup->absolute;

exec($abs, @ARGV) or print STDERR "couldn't exec {{ $bin }}: $!";

__EOT__

	for (@{$self->split_bins}) {
		my $content = $self->fill_in_string(
			$template,
			{
				dist => \($self->zilla),
				bin => $_,
			},
		);

		my $file = Dist::Zilla::File::InMemory->new({
			content => $content,
			name => 'bin/'.$_,
			mode => 0755,
		});

		$self->add_file($file);
	}
}

around module_build_args => sub {
	my ($orig, $self, @args) = @_;
	my $pattern = $self->pattern;
	return {
		%{ $self->$orig(@args) },
		alien_name => $self->name,
		alien_repository => {
			protocol => $self->repo_uri->scheme eq 'file'
				? 'local'
				: $self->repo_uri->scheme,
			host => $self->repo_uri->can('port') # local files do not have port
				? ( $self->repo_uri->default_port == $self->repo_uri->port
					? $self->repo_uri->host
					: $self->repo_uri->host_port )
				: '',
			location => $self->repo_uri->path,
			# NOTE Not using a compiled regex here for serialisation
			# in case it adds flags not in older versions of perl.
			# In particular, the compiled regex was adding the u
			# modifier, but then getting serialised as
			# (?^u:$pattern) which fails to parse under perl less
			# than v5.014.
			pattern => "^$pattern\$",
		},
		(alien_build_commands => $self->build_command)x!! $self->build_command,
		(alien_install_commands => $self->install_command)x!! $self->install_command,
		defined $self->autoconf_with_pic ? (alien_autoconf_with_pic => $self->autoconf_with_pic) : (),
		defined $self->isolate_dynamic ? (alien_isolate_dynamic => $self->isolate_dynamic) : (),
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

version 0.011

=head1 SYNOPSIS

In your I<dist.ini>:

  name = Alien-myapp

  [Alien]
  repo = http://myapp.org/releases
  bins = myapp myapp_helper
  # the following parameters are based on the dist name automatically
  name = myapp
  pattern_prefix = myapp-
  pattern_version = ([\d\.]+)
  pattern_suffix = \.tar\.gz
  pattern = myapp-([\d\.]+)\.tar\.gz

  # commands used to build (optional)
  build_command = %pconfigure --prefix=%s
  # ...

  # commands uses to install (optional)
  install_command = make install

=head1 DESCRIPTION

This is a simple wrapper around Alien::Base, to make it very simple to
generate a distribution that uses it. You only need to make a module like
in this case Alien::myapp which extends Alien::Base and additionally a url
that points to the path where the downloadable .tar.gz of the application
or library can be found. For more informations about the parameter, please
checkout also the L<Alien::Base> documentation. The I<repo> paramter is
automatically taken apart to supply the procotol, host and other parameters
for L<Alien::Base>.

B<Warning>: Please be aware that L<Alien::Base> uses L<Module::Build>, which
means you shouldn't have L<Dist::Zilla::Plugin::MakeMaker> loaded. For our
case, this means, you can't just easily use it together with the common
L<Dist::Zilla::PluginBundle::Basic>, because this includes it. As alternative
you can use L<Dist::Zilla::PluginBundle::Alien> which is also included in this
distribution.

=head1 ATTRIBUTES

=head2 repo

The only required parameter, defines the path for the packages of the product
you want to alienfy. This must not include the filename.

To indicate a local repository use the C<file:> scheme:

   # located in the base directory
   repo = file:.

   # located in the inc/ directory relative to the base
   repo = file:inc

=head2 pattern

The pattern is used to define the filename to be expected from the repo of the
alienfied product. It is set together out of I<pattern_prefix>,
I<pattern_version> and I<pattern_suffix>. I<pattern_prefix> is by default
L</name> together with a dash.

=head2 bins

A space or tab seperated list of all binaries that should be wrapped to be executable
from the perl environment (if you use perlbrew or local::lib this also
guarantees that its available via the PATH).

=head2 name

The name of the Alien package, this is used for the pattern matching filename.
If none is given, then the name of the distribution is used, but the I<Alien->
is cut off.

=head2 build_command

The ordered sequence of commands used to build the distribution (passed to the
C<alien_build_commands> option). This is optional.

  # configure then make
  build_command = %pconfigure --prefix=%s
  build_command = make

=head2 install_command

The ordered sequence of commands used to install the distribution (passed to the
C<alien_install_commands> option). This is optional.

  install_command = make install

=head2 isolate_dynamic

If set to true, then dynamic libraries will be isolated from the static libraries
when C<install_type=share> is used.  This is recommended for XS modules where
static libraries are more reliable.  Dynamic libraries (.dll, .so, etc) are still
available and can easily be used by FFI modules.

  isolate_dynamic = 1

Usage of this attribute will bump the requirement of L<Alien::Base> up to 0.005
for your distribution.

=head2 autoconf_with_pic

If set to true (the default), then C<--with-pic> will be passed to autoconf style
C<configure> scripts.  This usually enables position independent code which is
desirable if you are using static libraries to build XS modules.  Usually, if the
autoconf does not recognize C<--with-pic> it will ignore it, but some C<configure>
scripts which are not managed by autoconf may complain and die with this option.

  ; only if you know configure will die with --with-pic
  autoconf_with_pic = 0

Usage of this attribute will bump the requirement of L<Alien::Base> up to 0.005
for your distribution.

=head1 InstallRelease

The method L<Alien::Base> is using would compile the complete Alien 2 times, if
you use it in combination with L<Dist::Zilla::Plugin::InstallRelease>. One time
at the test, and then again after release. With a small trick, you can avoid
this. You can use L<Dist::Zilla::Plugin::Run> to add an additional test which
installs out of the unpacked distribution for the testing:

  [Run::Test]
  run_if_release = ./Build install

This will do the trick :). Be aware, that you need to add this plugin after
I<[ModuleBuild]>. You can use L<Dist::Zilla::PluginBundle::Author::GETTY>,
which directly use this trick in the right combination.

=head1 AUTHOR

Torsten Raudssus <torsten@raudss.us>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
