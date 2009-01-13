#!perl

use strict;
use warnings;
$|=1;

use Test::More tests => 4;
use lib 't';
use CWT_Testing;

ok( my $obj = CWT_Testing::getObj(), "got object" );

is( $obj->perls, undef, "perls got undef" );
my $aref = $obj->_mklist_perls;
is_deeply( $aref, [
          '5.10.0',
          '5.8.9',
          '5.8.8',
          '5.8.3',
          '5.8.1',
          '5.6.2',
          '5.5.5'
], "got perls" );
is( $obj->perls, $aref, "perls attribute matches" );

