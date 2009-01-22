#!perl

use strict;
use warnings;

use Test::More tests => 5;
use File::Spec;

use lib 't';
use CWT_Testing;

ok( my $obj = CWT_Testing::getObj(), "got object" );

is( $obj->_copy_files, '1', '_copy_files()' );
my @files = CWT_Testing::listFiles( $obj->directory );
is_deeply( \@files, [
          'background.png',
          'blank.js',
          'cgi-bin/reports-ajax.cgi',
          'cgi-bin/reports-summary.cgi',
          'cgi-bin/reports-text.cgi',
          'cgi-bin/templates/author_summary.html',
          'cgi-bin/templates/dist_summary.html',
          'cpan-testers-author.js',
          'cpan-testers-dist.js',
          'cpan-testers.css',
          'cssrules.js',
          'green.png',
          'headings/blank.png',
          'loader-orange.gif',
          'red.png',
          'style.css',
          'yellow.png',
        ],
	'file listings match' );
my $d = File::Spec->catfile( $obj->directory, 'stats', 'dist' );
ok( -d $d, '{directory}/stats/dist/ exists' );

ok( CWT_Testing::whackDir($obj), 'directory removed' );

