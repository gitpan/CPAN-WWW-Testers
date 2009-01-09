#!perl

use strict;
use warnings;

use Test::More tests => 8;
use File::Spec;
use lib 't';
use CWT_Testing;

ok( my $obj = CWT_Testing::getObj(), "got object" );

my $f = File::Spec->catfile( $obj->directory, 'last_id.txt' );
ok( ! -f $f, 'last_id.txt absent' );
is( $obj->_last_id, 0, "retrieve from absent file" );
ok( -f $f, 'last_id.txt now exists' );
is( $obj->_last_id, 0, "retrieve 0" );
is( $obj->_last_id(3), 3, "set 3" );
is( $obj->_last_id, 3, "retreive 3" );

ok( unlink($f), 'removed last_id.txt' );


