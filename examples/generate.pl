#!/usr/bin/perl
use strict;
$|++;

my $VERSION = '0.02';

#----------------------------------------------------------------------------

=head1 NAME

generate.pl - script to create the CPAN Testers Reports website.

=head1 SYNOPSIS

  perl generate.pl

=head1 DESCRIPTION

Using the cpanstats database, which should in the local directory, extracts
all the data into the components of each page. Then creates each HTML page for
the site.

=cut

# -------------------------------------
# Library Modules

use FindBin;
use lib ("$FindBin::Bin/../lib", "../lib");
use CPAN::WWW::Testers;
use Getopt::ArgvFile default=>1;
use Getopt::Long;
use File::Path;

# -------------------------------------
# Program

##### INITIALISE #####

our ($opt_d, $opt_t, $opt_h, $opt_u);
GetOptions(
    'directory|d=s' => \$opt_d,
    'testers|t=s'   => \$opt_t,
    'url|u=s'       => \$opt_u,
    'help|h'        => \$opt_h,
);

if ( $opt_h ) {
    print <<HERE;
Usage: $0 [-d directory] [-t database] [-w] [-h]
  -d directory  directory location of build files
  -t database   local database file (*)
  -u url        URL of remote database (*)
  -h            this help screen

(*) If no database is specified, a remote database is used. You may specify
    the URL of the remote database, or use the internal default. Note that the
    URL command line option will take precedence.
HERE
    exit 1;
}

##### MAIN #####

my $t = CPAN::WWW::Testers->new();

my $directory = $opt_d || 'www';
mkpath($directory);
die $!  unless(-d $directory);
$t->directory($directory);

if($opt_u)      { $t->download($opt_u); }
elsif($opt_t)   { $t->database($opt_t); }

$t->generate;

__END__

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties, that is not explained within the POD
documentation, please send bug reports and patches to the RT Queue (see below).

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

RT: http://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-WWW-Testers

=head1 SEE ALSO

L<CPAN::WWW::Testers::Generator>
L<CPAN::Testers::WWW::Statistics>

F<http://www.cpantesters.org/>,
F<http://stats.cpantesters.org/>

=head1 AUTHOR

  Original author:    Leon Brocard <acme@astray.com>   200?-2008
  Current maintainer: Barbie       <barbie@cpan.org>   2008-present

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2002-2008 Leon Brocard <acme@astray.com>
  Copyright (C) 2008      Barbie <barbie@cpan.org>

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

