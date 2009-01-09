#!perl

use strict;
use warnings;

use Test::More tests => 6;
use File::Path;
use File::Spec;
use Cwd;
use lib 't';
use CWT_Testing;

ok( my $obj = CWT_Testing::getObj(), "got object" );

my $cwd = getcwd;
my $subdir = File::Spec->catfile( $obj->directory, '.subdir' );
mkpath $subdir;
chdir $subdir;
is( $obj->_write_osnames, '1', '_write_osnames()' );
ok( -f 'osnames.txt', 'osnames.txt created in current dir' );

my @osnames = do { open FILE, '<', 'osnames.txt'; <FILE> };
chomp @osnames;

is_deeply(\@osnames, [
          'aix,AIX',
          'bsdos,BSD/OS',
          'cygwin,Cygwin',
          'darwin,Darwin',
          'dec_osf,Tru64',
          'dragonfly,Dragonfly BSD',
          'freebsd,FreeBSD',
          'gnu,GNU',
          'hpux,HP-UX',
          'irix,IRIX',
          'linux,Linux',
          'macos,MacOS',
          'mirbsd,MirBSD',
          'mswin32,MSWin32',
          'netbsd,NetBSD',
          'openbsd,OpenBSD',
          'os2,OS/2',
          'os390,OS/390',
          'sco,SCO',
          'solaris,Solaris',
          'vms,VMS'
], "osnames match");

ok( unlink('osnames.txt'), 'removed osnames.txt' );
chdir $cwd;
ok( CWT_Testing::cleanDir($obj), 'cleaned directory' );

