#!/usr/bin/perl -w
use strict;
use lib 'lib';
use CPAN::WWW::Testers;

my $directory = 'www';
mkdir $directory;

my $t = CPAN::WWW::Testers->new();
$t->directory($directory);
$t->generate;
