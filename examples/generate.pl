#!/usr/bin/perl -w
use strict;
use lib 'lib';
use CPAN::WWW::Testers;
$| = 1;

my $directory = 'www';
mkdir $directory || die $!;

my $t = CPAN::WWW::Testers->new();
$t->directory($directory);
$t->generate;
