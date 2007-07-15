use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Pod::Manual',
    license             => 'perl',
    dist_author         => 'Yanick Champoux <yanick@cpan.org>',
    dist_version_from   => 'lib/Pod/Manual.pm',
    requires => {
        'Test::More'        => 0,
        'version'           => 0,
        'Object::InsideOut' => 0,
        'XML::XPathScript'  => '1.51',
    },
    add_to_cleanup      => [ 'Pod-Manual-*' ],
);

$builder->create_build_script();
