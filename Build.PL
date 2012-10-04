use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Redmine::Chan',
    license             => 'perl',
    dist_author         => 'Yasuhiro Onishi <yasuhiro.onishi@gmail.com>',
    dist_version_from   => 'lib/Redmine/Chan.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
        'Module::Install::AuthorTests' => 0,
        'Module::Install::Repository'  => 0,
        'AnyEvent'      => 0,
        'AnyEvent::IRC' => 0,
        'Class::Accessor::Lite' => 0,
        'WebService::Simple'    => 0,
        'JSON' => 0,
        'URI'  => 0,
    },
    add_to_cleanup      => [ 'Redmine-Chan-*' ],
);

$builder->create_build_script();
