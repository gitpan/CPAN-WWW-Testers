use strict;
use Module::Build;

my $build = Module::Build->new(
  module_name => 'CPAN::WWW::Testers',
  license     => 'perl',
  requires    => {
    'Template'    => '2.08',
    'Test::More'  => '0.01',
    'DB_File'     => '0.01',
    'Net::NNTP'   => '0.01',
    'DBD::SQLite' => '0.01',
    'Email::Simple' => '0.01',
    'Sort::Versions' => '0.01',
    'DateTime' => '0.01',
  },
);
$build->create_build_script;
