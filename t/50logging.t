#!perl

use strict;
use warnings;

use Test::More tests => 26;
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

    $obj->_log("Hello");
    $obj->_log("Goodbye");

    ok( -f '50logging.log', '50logging.log created in current dir' );

    my @log = do { open FILE, '<', '50logging.log'; <FILE> };
    chomp @log;

    is(scalar(@log),3, 'log written');
    like($log[0], qr!\d{4}/\d\d/\d\d \d\d:\d\d:\d\d MAX!,        'line 1 of log');
    like($log[1], qr!\d{4}/\d\d/\d\d \d\d:\d\d:\d\d Hello!,      'line 2 of log');
    like($log[2], qr!\d{4}/\d\d/\d\d \d\d:\d\d:\d\d Goodbye!,    'line 3 of log');
}


{
    ok( my $obj = CWT_Testing::getObj(config => 't/50logging.ini'), "got object" );

    is($obj->logfile, '50logging.log', 'logfile default set');
    is($obj->logclean, 0, 'logclean default set');

    $obj->_log("Back Again");

    ok( -f '50logging.log', '50logging.log created in current dir' );

    my @log = do { open FILE, '<', '50logging.log'; <FILE> };
    chomp @log;

    is(scalar(@log),5, 'log written');
    like($log[0], qr!\d{4}/\d\d/\d\d \d\d:\d\d:\d\d MAX!,        'line 1 of log');
    like($log[1], qr!\d{4}/\d\d/\d\d \d\d:\d\d:\d\d Hello!,      'line 2 of log');
    like($log[2], qr!\d{4}/\d\d/\d\d \d\d:\d\d:\d\d Goodbye!,    'line 3 of log');
    like($log[3], qr!\d{4}/\d\d/\d\d \d\d:\d\d:\d\d MAX!,        'line 4 of log');
    like($log[4], qr!\d{4}/\d\d/\d\d \d\d:\d\d:\d\d Back Again!, 'line 5 of log');
}

{
    ok( my $obj = CWT_Testing::getObj(config => 't/50logging.ini'), "got object" );

    is($obj->logfile, '50logging.log', 'logfile default set');
    is($obj->logclean, 0, 'logclean default set');
    $obj->logclean(1);
    is($obj->logclean, 1, 'logclean reset');

    $obj->_log("Start Again");

    ok( -f '50logging.log', '50logging.log created in current dir' );

    my @log = do { open FILE, '<', '50logging.log'; <FILE> };
    chomp @log;

    is(scalar(@log),1, 'log written');
    like($log[0], qr!\d{4}/\d\d/\d\d \d\d:\d\d:\d\d Start Again!, 'line 1 of log');
}

ok( unlink('50logging.log'), 'removed 50logging.log' );
