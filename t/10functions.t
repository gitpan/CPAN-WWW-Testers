#!/usr/bin/perl -w
use strict;

use Test::More tests => 7;
use CPAN::WWW::Testers;

my $t = CPAN::WWW::Testers->new();
isa_ok($t,'CPAN::WWW::Testers');

is($t->directory,undef);
is($t->directory('./here'),'./here');
is($t->directory,'./here');

is($t->database,undef);
is($t->database('./there'),'./there');
is($t->database,'./there');


# generate, download & write are not tested
# make_rss is not tested, although could be
