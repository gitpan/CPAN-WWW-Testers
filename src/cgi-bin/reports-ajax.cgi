#!/usr/bin/perl
use strict;
$|++;

my $VERSION = '0.03';

#----------------------------------------------------------------------------

=head1 NAME

reports-ajax.cgi - program to return information for a CPAN distribution.

=head1 SYNOPSIS

  perl reports-ajax.cgi

=head1 DESCRIPTION

Called in a CGI context, will return either the reporting statistics for a CPAN
named distribution, or will give the date a distribution version was released
to CPAN, depending upon the action requested.

=head1 ACTION MODES

There are two action modes available, 'reports' and 'uploaded', which provide
different data regarding a specific distribution version. For both modes, basic
parameters are required, while additional optional parameters are available for
each mode.

=head2 Common Functionality

In both modes the distribution name and version are required. This can be
derived from the 'distvers' or 'distpath' parameters as described below.

=head3 Required CGI parameters

  act       - action [required] ('reports' or 'uploaded')

  distvers  - distribution name and version
  distpath  - distribution filename or path
  dist      - distribution name
  version   - distribution version

Note that 'dist' and 'version' are required, but will be derived if you pass
'distvers' or 'distpath'

=head2 Reports Functionality

=head3 Optional Reports CGI parameters

  force     - force zeros [optional] (values: 1 only)
  grades    - grades [optional]
  patches   - allow patches [optional] (values: 1 only)
  perlver   - specific perl version required [optional]
  osname    - specific osname required [optional]

The 'grades' parameter is only used with the 'reports' action, and allows the
request to specify which totals are required. If no grades are specified, the
default is to return the grade totals in the following order: ALL PASS FAIL
UNKNOWN NA. Note that if no grade total is available, that grade is not
included in the returned string, unless the 'force' parameter is specified.

=head3 Reports Examples

  > /cgi-bin/reports-ajax.cgi?act=reports&dist=CPAN-WWW-Testers&version=0.35
  <span class="ALL">ALL (2)</span> <span class="PASS">PASS (2)</span>

  > /cgi-bin/reports-ajax.cgi?act=reports&dist=CPAN-WWW-Testers&version=0.35&force=1
  <span class="ALL">ALL (2)</span> <span class="PASS">PASS (2)</span> <span class="FAIL">FAIL (0)</span> <span class="UNKNOWN">UNKNOWN (0)</span> <span class="NA">NA (0)</span>

  > /cgi-bin/reports-ajax.cgi?act=reports&dist=CPAN-WWW-Testers&version=0.35&force=1&grades=fail,na,pass
  <span class="FAIL">FAIL (0)</span> <span class="NA">NA (0)</span> <span class="PASS">PASS (2)</span>

  > /cgi-bin/reports-ajax.cgi?act=reports&distvers=CPAN-WWW-Testers-0.35
  <span class="ALL">ALL (2)</span> <span class="PASS">PASS (2)</span>

  > /cgi-bin/reports-ajax.cgi?act=reports&distpath=CPAN-WWW-Testers-0.35.tar.gz
  <span class="ALL">ALL (2)</span> <span class="PASS">PASS (2)</span>

  > /cgi-bin/reports-ajax.cgi?act=reports&distpath=BARBIE/CPAN-WWW-Testers-0.35.tar.gz
  <span class="ALL">ALL (2)</span> <span class="PASS">PASS (2)</span>

Note that for the 'distpath' example you can provide just the distribution
filename or precede it with the author's PAUSE ID.

If no reports are found a blank string is returned. On error an error string
is returned.

=head2 Uploaded Functionality

=head3 Optional Uploaded CGI parameters

  epoch     - return time since epoch [optional]

When requesting the 'uploaded' action, the date returned is of the form:
"YYYY/MM/DD hh::mm::ss". However, by including the 'epoch' parameter the string
return will be the value of seconds since the server epoch time
("1970/01/01 00:00:00").

=head3 Uploaded Examples

  > /cgi-bin/reports-ajax.cgi?act=uploaded&dist=CPAN-WWW-Testers&version=0.35
  <span class="released">2008/09/28 15:37:50</span>

  > /cgi-bin/reports-ajax.cgi?act=uploaded&dist=CPAN-WWW-Testers&version=0.35&epoch=1
  <span class="released">1222612670</span>

If no entry for the distribution version is found '0' is returned if the epoch
is requested, otherwise '0000/00/00 00:00:00' is returned. On error an error
string is returned.

=head1 AJAX & HTML

The returning text is wrapped in HTML tags, as can be seen in the examples
above. However, to appropriately use the results, you will need to include the
following HTML snippet on the page:

  <div id="report_stats"></div>

It is recommended that you use the OpenThought javascript file, to enable the
communication between the client and server. See the L<OpenThought> module on
CPAN for further details.

=cut

# -------------------------------------
# Library Modules

use OpenThought();
use CGI;
#use CGI::Carp			qw(fatalsToBrowser);
use Config::IniFiles;
use CPAN::Testers::Common::DBUtils;
use CPAN::DistnameInfo;

# -------------------------------------
# Variables

my (%options,%cgiparams,$OT,$cgi);

my %rules = (
    act      => qr/^(reports|uploaded)$/i,
    distvers => qr/^([-\w.]+)$/i,
    distpath => qr/^([-\w.]+)$/i,
    dist     => qr/^([-\w.]+)$/i,
    version  => qr/^([-\w.]+)$/i,
    grades   => qr/^((?:all|pass|fail|unknown|na)(?:,(?:all|pass|fail|unknown|na))*)$/i,
    force    => qr/^(1)$/i,
    epoch    => qr/^(1)$/i,
    patches  => qr/^([0-1])$/i,
    perlver  => qr/^([\w.]+)$/i,
    osname   => qr/^([\w.]+)$/i
);

# -------------------------------------
# Program

init_options();

process_reports()   if($cgiparams{act} eq 'reports');
process_uploaded()  if($cgiparams{act} eq 'uploaded');

# -------------------------------------
# Subroutines

sub init_options {
    $options{config} = 'data/settings.ini';

    error("Must specific the configuration file")              unless($options{config});
    error("Configuration file [$options{config}] not found")   unless(-f $options{config});

    # load configuration
    my $cfg = Config::IniFiles->new( -file => $options{config} );

    # configure upload DB
    for my $db (qw(CPANSTATS UPLOADS)) {
        my %opts = map {$_ => $cfg->val($db,$_);} qw(driver database dbfile dbhost dbport dbuser dbpass);
        $options{$db} = CPAN::Testers::Common::DBUtils->new(%opts);
        error("Cannot configure '$options{$db}' database")    unless($options{$db});
    }

    $OT = OpenThought->new();
    $cgi = CGI->new;

    for my $key (keys %rules) {
        my $val = $cgi->param($key);
        $cgiparams{$key} = $1   if($val =~ $rules{$key});
    }

    #$cgiparams{act} = 'reports';
    #$cgiparams{distvers} = 'CPAN-WWW-Testers-0.39';
    #$cgiparams{distpath} = 'CPAN-WWW-Testers-0.39.tar.gz';

    if($cgiparams{distvers}) {
        $cgiparams{distpath} = $cgiparams{distvers} . '.tar.gz';
    }

    if($cgiparams{distpath}) {
        my $d = CPAN::DistnameInfo->new($cgiparams{distpath});
        $cgiparams{dist}    = $d->dist;
        $cgiparams{version} = $d->version;
    }

    error("Missing variables act=[$cgiparams{act}]","No action given\n")
        unless($cgiparams{act});
    error("Missing variables dist=[$cgiparams{dist}], version=[$cgiparams{version}]","No distribution or version given\n")
        unless($cgiparams{dist} && $cgiparams{version});
}

sub process_reports {
    my $next = $options{CPANSTATS}->iterator(
            'hash',
            "SELECT * FROM cpanstats WHERE dist=? AND version=? AND state!='cpan'",
            $cgiparams{dist},$cgiparams{version});

    my %counts;
    while(my $row = $next->()) {
        next    if(!$cgiparams{patches} && $row->{perl}   =~ /patch/i);
        next    if( $cgiparams{perlver} && $row->{perl}   !~ /$cgiparams{perlver}/i);
        next    if( $cgiparams{osname}  && $row->{osname} !~ /$cgiparams{osname}/i);

        $counts{ALL}++;
        $counts{PASS}++     if($row->{state} eq 'pass');
        $counts{FAIL}++     if($row->{state} eq 'fail');
        $counts{UNKNOWN}++  if($row->{state} eq 'unknown');
        $counts{NA}++       if($row->{state} eq 'na');
    }

    my $str;
    my @grades = $cgiparams{grades} ? split(',',uc $cgiparams{grades}) : qw(ALL PASS FAIL UNKNOWN NA);
    for(@grades) {
        next    unless($cgiparams{force} || $counts{$_});
        $counts{$_} ||= 0;
        $str .= qq!<span class="$_">$_ ($counts{$_})</span> !;
    }


    my $html;
    $html->{'report_stats'} = $str;
    $OT->param( $html );

    print $cgi->header;
    print $OT->response();
}

sub process_uploaded {
    my @rows = $options{UPLOADS}->get_query(
            'hash',
            "SELECT released FROM uploads WHERE dist=? AND version=?",
            $cgiparams{dist},$cgiparams{version});

    my $str;
    if(@rows) {
        if($cgiparams{epoch}) {
            $str = qq!<span class="released">$rows[0]->{released}</span>!;
        } else {
            my @dt = localtime($rows[0]->{released});
            $str = sprintf '<span class="released">%04d/%02d/%02d %02d:%02d:%02d</span>', $dt[5]+1900,$dt[4]+1,$dt[3],$dt[2],$dt[1],$dt[0];
        }
    } else {
        if($cgiparams{epoch}) {
            $str = '0';
        } else {
            $str = '<span class="released">0000/00/00 00:00:00</span>';
        }
    }

    my $html;
    $html->{'report_stats'} = $str;
    $OT->param( $html );

    print $cgi->header;
    print $OT->response();
}

sub error {
    my @mess = @_;
    $mess[1] ||= "Error retrieving data\n";

    print STDERR $mess[0];
    print $cgi->header('text/plain'), $mess[1];
    exit;
}

1;

__END__

=head1 FUTUTE ENHANCEMENTS

Although every attempt has been made to provide as much useful functionality
in these scripts, it is possible that there is further information you would
want it to provide. If you have a suggestion to enhance the capability of this
script, please post it as a wishlist item to the RT queue.

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties, that is not explained within the POD
documentation, please send bug reports and patches to the RT Queue (see below).

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

RT: http://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-WWW-Testers

=head1 SEE ALSO

L<OpenThought>

L<CPAN::WWW::Testers::Generator>,
L<CPAN::Testers::WWW::Statistics>

F<http://www.cpantesters.org/>,
F<http://stats.cpantesters.org/>

=head1 AUTHOR

  Barbie       <barbie@cpan.org>   2008-present

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2008-2009 Barbie <barbie@cpan.org>

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut
