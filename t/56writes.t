#!perl

use strict;
use warnings;
$|=1;


# NOTE about t/56writes.t & t/expected.zip...
#
# If the write tests fail, due to any change a new expected.zip file is
# required. In order to regenerate the archive enter the following
# commands:
#
# $> prove -Ilib t/50setup_db-*
# $> perl -Ilib t/56writes.t --update-archive
#
# This will assume that any failing tests are actually correct, and
# create a new zip file t/expected-NEW.zip. To commit it, just enter:
#
# $> mv t/expected-NEW.zip t/expected.zip
#

my $UPDATE_ARCHIVE = ($ARGV[0] && $ARGV[0] eq '--update-archive') ? 1 : 0;


use Test::More tests => 308;
use Test::Differences;
use File::Slurp qw( slurp );
use Archive::Zip;
use Archive::Extract;
use File::Spec;
use File::Path;
use File::Copy;
use File::Basename;

use lib 't';
use CWT_Testing;

ok( my $obj = CWT_Testing::getObj(), "got object" );
my $rc;
my @files;
my @expectedFiles;
my $expectedDir;

my $EXPECTEDPATH = File::Spec->catfile( 't', '_EXPECTED' );
my $ae = Archive::Extract->new( archive => File::Spec->catfile('t','expected.zip') );
ok( $ae->extract(to => $EXPECTEDPATH), 'extracted expected files' );



$rc = $obj->_write_recent();
is( $rc, 1, "_write_recent succeeded" );
check_dir_contents(
	"[_write_recent]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_recent'),
);
ok( CWT_Testing::cleanDir($obj), 'directory cleaned' );


$rc = $obj->_write_index();
is( $rc, 1, "_write_index succeeded" );
check_dir_contents(
	"[_write_index]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_index'),
);
ok( CWT_Testing::cleanDir($obj), 'directory cleaned' );


$rc = $obj->_write_stats();
is( $rc, '', "_write_stats succeeded" );
check_dir_contents(
	"[_write_stats]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_stats'),
);
ok( CWT_Testing::cleanDir($obj), 'directory cleaned' );


$rc = $obj->_write_distributions_alphabetic();
is( $rc, '', "_write_distributions_alphabetic succeeded" );
check_dir_contents(
	"[_write_distributions_alphabetic]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_distributions_alphabetic'),
);
ok( CWT_Testing::cleanDir($obj), 'directory cleaned' );



$rc = $obj->_write_authors_alphabetic();
is( $rc, '', "_write_authors_alphabetic succeeded" );
check_dir_contents(
	"[_write_authors_alphabetic]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_authors_alphabetic'),
);
ok( CWT_Testing::cleanDir($obj), 'directory cleaned' );



$rc = $obj->_write_authors();
is( $rc, '', "_write_authors succeeded" );
check_dir_contents(
	"[_write_authors]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_authors'),
);
ok( CWT_Testing::cleanDir($obj), 'directory cleaned' );


$rc = $obj->_write_authors(qw/ JBRYAN LBROCARD INGY /);
is( $rc, '', "_write_authors(<list>) succeeded" );
check_dir_contents(
	"[_write_authors(<list>)]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_authors-list'),
);
ok( CWT_Testing::cleanDir($obj), 'directory cleaned' );


$rc = $obj->_write_distributions();
is( $rc, '', "_write_distributions succeeded" );
check_dir_contents(
	"[_write_distributions]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_distributions'),
);
ok( CWT_Testing::cleanDir($obj), 'directory cleaned' );


$rc = $obj->_write_distributions(qw/ Acme-Buffy AI-NeuralNet-Mesh Acme /);
is( $rc, '', "_write_distributions(<list>) succeeded" );
check_dir_contents(
	"[_write_distributions(<list>)]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_distributions-list'),
);
ok( CWT_Testing::cleanDir($obj), 'directory cleaned' );


#$rc = $obj->generate();
#is( $rc, '', "generate succeeded" );
#check_dir_contents(
#	"[generate]",
#	$obj->directory,
#	File::Spec->catfile($EXPECTEDPATH,'56writes.generate'),
#);
#ok( CWT_Testing::cleanDir($obj), 'directory cleaned' );


if( $UPDATE_ARCHIVE ){
  my $zip = Archive::Zip->new();
  $zip->addTree( $EXPECTEDPATH );
  my $f = File::Spec->catfile( 't', 'expected-NEW.zip' );
  diag "CREATING NEW ZIP FILE: $f";
  unlink $f if -f $f;
  $zip->writeToFileNamed($f) == Archive::Zip::AZ_OK
	or diag "==== ERROR WRITING TO $f ====";
}

##################################################################

ok( CWT_Testing::whackDir($obj), 'directory removed' );
ok( rmtree($EXPECTEDPATH), 'expected dir removed' );


# TODO:
# run $obj->_write_authors( @authors );
# run $obj->_write_distributions( @distributions );

exit;

##################################################################

sub eq_or_diff_files {
  my ($f1, $f2, $desc, $filter) = @_;
  my $s1 = -f $f1 ? slurp($f1) : undef;
  &$filter($s1) if $filter;
  my $s2 = -f $f2 ? slurp($f2) : undef;
  &$filter($s2) if $filter;
  return
	( defined($s1) && defined($s2) )
	? eq_or_diff( $s1, $s2, $desc )
	: ok( 0, "$desc - both files exist")
  ;
}

sub check_dir_contents {
  my ($diz, $dir, $expectedDir) = @_;
  my @files = CWT_Testing::listFiles( $dir );
  my @expectedFiles = CWT_Testing::listFiles( $expectedDir );
  ok( scalar(@files), "got files" );
  ok( scalar(@expectedFiles), "got expectedFiles" );
  eq_or_diff( \@files, \@expectedFiles, "$diz file listings match" );
  foreach my $f ( @files ){
    my $fGot = File::Spec->catfile($dir,$f);
    my $fExpected = File::Spec->catfile($expectedDir, $f);
    my $ok = eq_or_diff_files(
	$fGot,
	$fExpected,
	"$diz diff $f",
	sub {
	  $_[0] =~ s/^(\s*)\d+\.\d+(?:_\d+)? at \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.( Comments and design patches)/$1 ==TIMESTAMP== $2/m;
	}
    );
    next if $ok;
    next unless $UPDATE_ARCHIVE;
    mkpath( dirname($fExpected) ) unless -f $fExpected;
    copy( $fGot, $fExpected );
  }
}

