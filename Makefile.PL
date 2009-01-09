use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'              => 'CPAN::WWW::Testers',
    'VERSION_FROM'      => 'lib/CPAN/WWW/Testers.pm',
    'PREREQ_PM'         => {
        'Archive::Extract'                  => '0',
        'Class::Accessor::Chained::Fast'    => '0',
        'Config::IniFiles'                  => '0',
        'CPAN::Testers::Common::DBUtils'    => '0.03',
        'DateTime'                          => '0',
        'File::Find::Rule'                  => '0',     # for cpanreps-verify
        'File::Path'                        => '0',
        'File::Slurp'                       => '0.01',
        'FindBin'                           => '0',     # for cpanreps-writepages
        'Getopt::ArgvFile'                  => '0',     # for all scripts
        'Getopt::Long'                      => '0',
        'Image::Imlib2'                     => '0',     # for cpanreps-imlib
        'IO::File'                          => '0',
        'JSON::Syck'                        => '0',
        'LWP::Simple'                       => '0.01',
        'Parse::CPAN::Authors'              => '0',     # for cpanreps-verify
        'Path::Class'                       => '0',
        'OpenThought'                       => '0',     # for src/reports-summary.cgi
        'Sort::Versions'                    => '0',
        'Storable'                          => '0',
        'Template'                          => '2.08',
        'Template::Plugin::Comma'           => '0',
        'Template::Plugin::Cycle'           => '0',
        'Test::More'                        => '0.01',
        'XML::RSS'                          => '1.31',
        'YAML'                              => '0.01',

        'DBD::mysql'                        => '0',
        'DBD::SQLite'                       => '1.00',

        'Test::Differences'                 => '0',     # for testing
        'Archive::Zip'                      => '0',     # for testing
        'File::Spec'                        => '0',     # for testing
        'File::Basename'                    => '0',     # for testing
        'File::Copy'                        => '0',     # for testing

},
    'INSTALLDIRS'       => 'site',
    'PL_FILES'          => {},
    'NO_META'           => 1,

    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT	=> 'CPAN Testers Reports website generation code',
       AUTHOR	=> 'Barbie <barbie@cpan.org>') : ()),
);
