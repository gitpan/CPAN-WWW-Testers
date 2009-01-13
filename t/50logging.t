#!perl

use strict;
use warnings;

use Test::More tests => 17;
use File::Path;
use File::Spec;
use Cwd;
use lib 't';
use CWT_Testing;

unlink('50logging.log') if(-f '50logging.log');

{
    ok( my $obj = CWT_Testing::getObj(config => 't/50logging.ini'), "got object" );

    is($obj->logfile, '50logging.log', 'logfile default set');
    is($obj->logclean, 0, 'logclean default set');

    $obj->_log("Hello\n");
    $obj->_log("Goodbye\n");

    ok( -f '50logging.log', '50logging.log created in current dir' );

    my @log = do { open FILE, '<', '50logging.log'; <FILE> };
    chomp @log;

    is_deeply(\@log, [
              $log[0],
              'Hello',
              'Goodbye',
    ], "log written");
}


{
    ok( my $obj = CWT_Testing::getObj(config => 't/50logging.ini'), "got object" );

    is($obj->logfile, '50logging.log', 'logfile default set');
    is($obj->logclean, 0, 'logclean default set');

    $obj->_log("Back Again\n");

    ok( -f '50logging.log', '50logging.log created in current dir' );

    my @log = do { open FILE, '<', '50logging.log'; <FILE> };
    chomp @log;

    is_deeply(\@log, [
              $log[0],
              'Hello',
              'Goodbye',
              $log[0],
              'Back Again',
    ], "log extended");
}

{
    ok( my $obj = CWT_Testing::getObj(config => 't/50logging.ini'), "got object" );

    is($obj->logfile, '50logging.log', 'logfile default set');
    is($obj->logclean, 0, 'logclean default set');
    $obj->logclean(1);
    is($obj->logclean, 1, 'logclean reset');

    $obj->_log("Start Again\n");

    ok( -f '50logging.log', '50logging.log created in current dir' );

    my @log = do { open FILE, '<', '50logging.log'; <FILE> };
    chomp @log;

    is_deeply(\@log, [
              'Start Again',
    ], "log extended");
}

ok( unlink('50logging.log'), 'removed osnames.txt' );
