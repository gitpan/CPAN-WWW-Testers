#!perl

use strict;
use warnings;
$|=1;

use Test::More tests => 7;
use lib 't';
use CWT_Testing;

ok( my $obj = CWT_Testing::getObj(), "got object" );

is( $obj->osnames, undef, "osnames got undef" );
my $href = $obj->_mklist_osnames;
is_deeply( $href, {
	'linux' => 'Linux',
}, "got osnames" );
is( $obj->osnames, $href, "osnames attribute matches" );

is( $obj->perls, undef, "perls got undef" );
my $aref = $obj->_mklist_perls;
is_deeply( $aref, [
          '5.10.0',
          '5.8.8'
], "got perls" );
is( $obj->perls, $aref, "perls attribute matches" );

