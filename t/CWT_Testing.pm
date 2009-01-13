package CWT_Testing;

use strict;
use warnings;

use CPAN::WWW::Testers;
use File::Path;
use File::Temp;
use File::Find;
use File::Spec;

sub getObj {
  my %opts = @_;
  $opts{directory} ||= File::Spec->catfile('t','_TMPDIR');
  $opts{config}    ||= \*DATA;

  _cleanDir( $opts{directory} ) or return;

  my $obj = CPAN::WWW::Testers->new(%opts);

  return $obj;
}

sub _cleanDir {
  my $dir = shift;
  if( -d $dir ){
    rmtree($dir) or return;
  }
  mkpath($dir) or return;
  return 1;
}

sub cleanDir {
  my $obj = shift;
  return _cleanDir( $obj->directory );
}

sub whackDir {
  my $obj = shift;
  my $dir = $obj->directory;
  if( -d $dir ){
    rmtree($dir) or return;
  }
  return 1;
}

sub listFiles {
  my $dir = shift;
  my @files;
  find({ wanted => sub { push @files, File::Spec->abs2rel($File::Find::name,$dir) if -f $_ } }, $dir);
  return sort @files;
}

1;

__DATA__

[MASTER]
database=t/_DBDIR/test.db

[CPANSTATS]
driver=SQLite
database=t/_DBDIR/test.db

[UPLOADS]
driver=SQLite
database=t/_DBDIR/test2.db

[OSNAMES]
aix=AIX
bsdos=BSD/OS
cygwin=Cygwin
darwin=Darwin
dec_osf=Tru64
dragonfly=Dragonfly BSD
mswin32=MSWin32
os2=OS/2
os390=OS/390

[EXCEPTIONS]
LIST=<<IGNORE
Test.php
Net-ITE.pm
CGI.pm
IGNORE
