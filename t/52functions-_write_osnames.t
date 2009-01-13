#!perl

use strict;
use warnings;

use Test::More tests => 16;
use File::Path;
use File::Spec;
use Cwd;
use lib 't';
use CWT_Testing;

{
    ok( my $obj = CWT_Testing::getObj(), "got object" );

    is_deeply( $obj->osnames, {
        'aix'       => 'AIX',
        'bsdos'     => 'BSD/OS',
        'cygwin'    => 'Cygwin',
        'dec_osf'   => 'Tru64',
        'dragonfly' => 'Dragonfly BSD',
        'darwin'    => 'Darwin',
        'mswin32'   => 'MSWin32',
        'os2'       => 'OS/2',
        'os390'     => 'OS/390',
    }, "osnames with default loaded attributes" );

    my $cwd = getcwd;
    my $subdir = File::Spec->catfile( $obj->directory, '.subdir' );
    mkpath $subdir;
    chdir $subdir;
    is( $obj->_write_osnames, '1', '_write_osnames()' );
    ok( -f 'osnames.txt', 'osnames.txt created in current dir' );

    is_deeply( $obj->osnames, {
        'aix'       => 'AIX',
        'bsdos'     => 'BSD/OS',
        'cygwin'    => 'Cygwin',
        'dec_osf'   => 'Tru64',
        'dragonfly' => 'Dragonfly BSD',
        'darwin'    => 'Darwin',
        'freebsd'   => 'FREEBSD',
        'linux'     => 'LINUX',
        'mswin32'   => 'MSWin32',
        'solaris'   => 'SOLARIS',
        'openbsd'   => 'OPENBSD',
        'os2'       => 'OS/2',
        'os390'     => 'OS/390',
    }, "osnames attribute matches" );

    my @osnames = do { open FILE, '<', 'osnames.txt'; <FILE> };
    chomp @osnames;

    is_deeply(\@osnames, [
              'aix,AIX',
              'bsdos,BSD/OS',
              'cygwin,Cygwin',
              'darwin,Darwin',
              'dec_osf,Tru64',
              'dragonfly,Dragonfly BSD',
              'freebsd,FREEBSD',
              'linux,LINUX',
              'mswin32,MSWin32',
              'openbsd,OPENBSD',
              'os2,OS/2',
              'os390,OS/390',
              'solaris,SOLARIS'
    ], "osnames match");

    ok( unlink('osnames.txt'), 'removed osnames.txt' );
    chdir $cwd;
    ok( CWT_Testing::cleanDir($obj), 'cleaned directory' );
}


{
    ok( my $obj = CWT_Testing::getObj(config => 't/52functions-rss_limit.ini'), "got object" );
    is_deeply( $obj->osnames, undef, "osnames with no defaults" );

    my $cwd = getcwd;
    my $subdir = File::Spec->catfile( $obj->directory, '.subdir' );
    mkpath $subdir;
    chdir $subdir;
    is( $obj->_write_osnames, '1', '_write_osnames()' );
    ok( -f 'osnames.txt', 'osnames.txt created in current dir' );

    is_deeply( $obj->osnames, {
        'darwin'    => 'DARWIN',
        'freebsd'   => 'FREEBSD',
        'linux'     => 'LINUX',
        'mswin32'   => 'MSWIN32',
        'solaris'   => 'SOLARIS',
        'openbsd'   => 'OPENBSD',
    }, "osnames attribute matches" );

    my @osnames = do { open FILE, '<', 'osnames.txt'; <FILE> };
    chomp @osnames;

    is_deeply(\@osnames, [
              'darwin,DARWIN',
              'freebsd,FREEBSD',
              'linux,LINUX',
              'mswin32,MSWIN32',
              'openbsd,OPENBSD',
              'solaris,SOLARIS'
    ], "osnames match");

    ok( unlink('osnames.txt'), 'removed osnames.txt' );
    chdir $cwd;
    ok( CWT_Testing::cleanDir($obj), 'cleaned directory' );
}
