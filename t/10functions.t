#!/usr/bin/perl -w
use strict;

use Test::More tests => 10;
use CPAN::WWW::Testers;

my $t = CPAN::WWW::Testers->new();
isa_ok($t,'CPAN::WWW::Testers');


# These are really Class::Accessor::Chained::Fast tests, so they should work!

is($t->directory,undef);
$t->directory('./here');
is($t->directory,'./here');

is($t->database,undef);
$t->database('./there');
is($t->database,'./there');

is($t->updates,undef);
$t->updates('./there');
is($t->updates,'./there');


# can we read/update the last id file

$t->directory('.');
is($t->_last_id(),0);
is($t->_last_id(1234567),1234567);
is($t->_last_id(),1234567);
unlink('last_id.txt');

# generate, download & update are not tested as they would instigate a build
# of the website, which would be a bit daft! Maybe can think about splitting
# method down further at some point to test file creation.

# make_rss is not tested, although could be, by just testing files are created.
