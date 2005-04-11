use strict;
use Module::Build;

my $build = Module::Build->new(
  module_name => 'CPAN::WWW::Testers',
  create_makefile_pl => 'traditional',
  license     => 'perl',
  requires    => {
    'Template'     => '2.08',
    'Test::More'   => '0.01',
    'DBD::SQLite'  => '0.01',
    'DBI'          => '0.01',
    'File::Slurp'  => '0.01',
    'YAML'         => '0.01',
    'LWP::Simple'  => '0.01',
    'version'      => '0.01',
    'XML::RSS'     => '0.01',
    'Getopt::Long' => '0',
    'File::Path'   => '0',
    'Storable'     => '0',
    'Parse::BACKPAN::Packages' => '0',
  },
);

$build->create_build_script;
