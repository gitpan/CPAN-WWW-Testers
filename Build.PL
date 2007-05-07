use strict;
use Module::Build;

my $build = Module::Build->new(
    module_name        => 'CPAN::WWW::Testers',
    create_makefile_pl => 'traditional',
    license            => 'perl',
    requires           => {
        'Class::Accessor::Chained::Fast' => '0',
        'Path::Class'                    => '0',
        'Template'                       => '2.08',
        'Template::Plugin::Comma'        => '0',
        'Template::Plugin::Cycle'        => '0',
        'Test::More'                     => '0.01',
        'DBD::SQLite'                    => '0.01',
        'DBI'                            => '0.01',
        'File::Slurp'                    => '0.01',
        'YAML'                           => '0.01',
        'LWP::Simple'                    => '0.01',
        'version'                        => '0.01',
        'XML::RSS'                       => '0.01',
        'Getopt::Long'                   => '0',
        'File::Path'                     => '0',
        'Storable'                       => '0',
        'Parse::BACKPAN::Packages'       => '0.30',
        'JSON::Syck'                     => '0',
        'DateTime'                       => '0',
    },
);

$build->create_build_script;

