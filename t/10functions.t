#!/usr/bin/perl -w
use strict;

use Test::More tests => 5;
use CPAN::WWW::Testers;

my $t = CPAN::WWW::Testers->new();
isa_ok($t,'CPAN::WWW::Testers');

is($t->directory,undef);
$t->directory('./here');
is($t->directory,'./here');

is($t->database,undef);
$t->database('./there');
is($t->database,'./there');


# generate, download & write are not tested
# make_rss is not tested, although could be
