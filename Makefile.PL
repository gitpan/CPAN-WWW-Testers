use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'              => 'CPAN::WWW::Testers',
    'VERSION_FROM'      => 'lib/CPAN/WWW/Testers.pm',
    'PREREQ_PM'         => {
        'Archive::Extract'                  => 0,
        'Class::Accessor::Chained::Fast'    => '0',
        'DBD::SQLite'                       => '0.01',
        'DBI'                               => '0.01',
        'DateTime'                          => '0',
        'File::Path'                        => '0',
        'File::Slurp'                       => '0.01',
        'Getopt::ArgvFile'                  => 0,       # for generate.pl only
        'Getopt::Long'                      => '0',
        'JSON::Syck'                        => '0',
        'LWP::Simple'                       => '0.01',
        'Parse::BACKPAN::Packages'          => '0.30',
        'Parse::CPAN::Distributions'        => '0.05',
        'Path::Class'                       => '0',
        'Sort::Versions'                    => '0',
        'Storable'                          => '0',
        'Template'                          => '2.08',
        'Template::Plugin::Comma'           => '0',
        'Template::Plugin::Cycle'           => '0',
        'Test::More'                        => '0.01',
        'XML::RSS'                          => '0.01',
        'YAML'                              => '0.01',
                        },
    'INSTALLDIRS'       => 'site',
    'PL_FILES'          => {},
    'NO_META'           => 1,

    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT	=> 'CPAN Testers Reports website generation code',
       AUTHOR	=> 'Barbie <barbie@cpan.org>') : ()),
);
