use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Pod::Manual',
    license             => 'perl',
    dist_author         => 'Yanick Champoux <yanick@cpan.org>',
    dist_version_from   => 'lib/Pod/Manual.pm',
    requires => {
        'XML::LibXML'       => 0,
        'Test::More'        => 0,
        'version'           => 0,
        'Object::InsideOut' => 0,
        'Pod::XML'          => 0,
        'Pod::Usage'        => 0,  # for podmanual
        'Pod::2::DocBook'   => '0.02',
        'Params::Validate'  => 0,
    },
    recommends => {
        'XML::XPathScript'  => '1.54',
    },
    script_files        => [ 'script/podmanual' ],
    add_to_cleanup      => [ 'Pod-Manual-*' ],
    create_makefile_pl  => 'passthrough',
    sign                => 1,
    meta_merge => {
        resources => {
            repository => 'git://github.com/yanick/pod-manual.git',
            bugtracker =>
            'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Pod-Manual',
        },
    },
);

$builder->create_build_script();
