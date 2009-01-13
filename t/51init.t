#!perl

use strict;
use warnings;
$|=1;

use Test::More tests => 13;
use File::Spec;
use lib 't';
use CWT_Testing;

ok( my $obj = CWT_Testing::getObj(), "got object" );

isa_ok( $obj, 'CPAN::WWW::Testers', "object type" );

#ok( $obj->{config}, 'config' );
#isa_ok( $obj->{config}, 'GLOB', 'config type' );

my $db = File::Spec->catfile('t','_DBDIR','test.db');
isa_ok( $obj->{CPANSTATS},         'CPAN::Testers::Common::DBUtils', 'CPANSTATS' );
is(     $obj->{CPANSTATS}->{database}, $db,                          'CPANSTATS.database' );
is(     $obj->{CPANSTATS}->{driver},   'SQLite',                     'CPANSTATS.database' );
isa_ok( $obj->{CPANSTATS}->{dbh},  'DBI::db',                        'CPANSTATS.dbh' );

isa_ok( $obj->{UPLOADS},         'CPAN::Testers::Common::DBUtils', 'UPLOADS' );

is( $obj->database, $db, 'database' );
ok( -f $obj->database, 'database exists' );

ok( $obj->directory, 'directory' );
is( $obj->directory, File::Spec->catfile('t','_TMPDIR'), 'directory' );
ok( -d $obj->directory, 'directory exists' );

isa_ok( $obj->tt,   'Template', 'tt' );
# TODO: should check attributes

# TODO:  check $CPAN::WWW::Testers::MAX_ID


