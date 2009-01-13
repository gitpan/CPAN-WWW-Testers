#!perl

use strict;
use warnings;

use Test::More tests => 7;
use File::Spec;

use CPAN::WWW::Testers;

use lib 't';
use CWT_Testing;

# defaults
is_deeply( \%CPAN::WWW::Testers::RSS_LIMIT, {
    'RECENT' => 200,
    'AUTHOR' => 100
}, "RSS_LIMIT default hash" );

{
    ok( my $obj = CWT_Testing::getObj(), "got object" );
    is( $obj->_rss_limit('RECENT'), 200, "rss_limit => RECENT uses correct default" );
    is( $obj->_rss_limit('AUTHOR'), 100, "rss_limit => AUTHOR uses correct default" );
}

{
    ok( my $obj = CWT_Testing::getObj(config => 't/52functions-rss_limit.ini'), "got object" );
    is( $obj->_rss_limit('RECENT'), 1965, "rss_limit => RECENT loads correct config setting" );
    is( $obj->_rss_limit('AUTHOR'), 42,   "rss_limit => AUTHOR loads correct config setting" );
}

