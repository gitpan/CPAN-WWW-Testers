use strict;
use Module::Build;

my $build = Module::Build->new(
  module_name => 'CPAN::WWW::Testers',
  license     => 'perl',
  requires    => {
    'Template'    => '2.08',
    'Test::More'  => '0.01',
    'DBD::SQLite' => '0.01',
    'DBI'         => '0.01',
    'File::Slurp' => '0.01',
    'YAML'        => '0.01',
    'LWP::Simple' => '0.01',
    'version'     => '0.01',
  },
);

$build->create_build_script;
