#!/usr/bin/perl -w
use strict;
use FindBin;
use lib ("$FindBin::Bin/../lib", "../lib");
use CPAN::WWW::Testers;
use Getopt::Long;
use File::Path;

$| = 1;

our ($opt_d, $opt_t, $opt_h, $opt_w);
GetOptions( 
    'directory|d=s' => \$opt_d, 
    'testers|t=s'   => \$opt_t, 
    'write|w'       => \$opt_w,
    'help|h'        => \$opt_h,
);

if ( $opt_h ) {
    print <<HERE;
Usage: cpan_www_testers_generate [-d directory] [-t directory] [-w] [-h]
  -d directory   main directory location of files
  -t directory   database directory location (*)
  -w             create only output from local testers.db
  -h             this help screen

(*) If the database, testers.db, is located in a directory different from
    where the HTML files are to be created, this option should be used.
HERE
    exit 1;
}

my $t = CPAN::WWW::Testers->new();

my $directory = $opt_d || 'www';
mkpath($directory);
die $!  unless(-d $directory);
$t->directory($directory);

my $database = $opt_t || $directory;
$t->database($database);

if($opt_w)      { $t->write; }
else            { $t->generate; }
