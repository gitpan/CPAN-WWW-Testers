#!/usr/bin/perl
use strict;
$|++;

my $VERSION = '0.02';

#----------------------------------------------------------------------------

=head1 NAME

reports-summary.pl - program to return graphical status of a CPAN distribution

=head1 SYNOPSIS

  perl reports-summary.pl

=head1 DESCRIPTION

Called in a CGI context, returns the current reporting statistics for a CPAN
distribution, depending upon the POST parameters provided.

=cut

# -------------------------------------
# Library Modules

use OpenThought();
use CGI;
use Config::IniFiles;
use CPAN::Testers::Common::DBUtils;
use Template;

# -------------------------------------
# Variables

my (%options,%cgiparams,$OT,$cgi,$tt);

my %rules = (
    dist    => qr/^([-\w.]+)$/i,
    author  => qr/^([a-z0-9]+)$/i,
    version => qr/^([-\w.]+)$/i,
    grade   => qr/^([0-4])$/i,
    oncpan  => qr/^([0-2])$/i,
    distmat => qr/^([0-2])$/i,
    perlmat => qr/^([0-2])$/i,
    patches => qr/^([0-2])$/i,
    perlver => qr/^([\w.]+)$/i,
    osname  => qr/^([\w.]+)$/i
);

my $EXCEPTIONS = 'Test.php|Net-ITE.pm|CGI.pm';

# -------------------------------------
# Program

init_options();
process_dist()      if($cgiparams{dist});
process_author()    if($cgiparams{author});

print $cgi->header;
print $OT->response();
print "\n";

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
        error("Cannot configure '$options{database}' database")    unless($options{$db});
    }

    $OT = OpenThought->new();
    $cgi = CGI->new;

    for my $key (keys %rules) {
        my $val = $cgi->param("${key}_pref");
        $cgiparams{$key} = $1   if($val =~ $rules{$key});
    }

    # set up API to Template Toolkit
    $tt = Template->new(
        {
            #    POST_CHOMP => 1,
            #    PRE_CHOMP => 1,
            #    TRIM => 1,
            EVAL_PERL    => 1,
            INCLUDE_PATH => [ 'templates' ],
        }
    );

    #$cgiparams{dist} = 'Acme-Beatnik';

}

sub process_dist {
    my $next = $options{CPANSTATS}->iterator(
        'hash',
        "SELECT id, state, version, perl, osname, osvers, platform FROM cpanstats WHERE dist = ? AND state != 'cpan' ORDER BY version, id",
        $cgiparams{dist} );

    my ( $summary );
    while ( my $row = $next->() ) {
        next unless $row->{version};
        $row->{perl} = "5.004_05" if $row->{perl} eq "5.4.4"; # RT 15162
        next    if($cgiparams{patches} && $cgiparams{patches} == 1     && $row->{perl}     =~ /patch/i);
        next    if($cgiparams{patches} && $cgiparams{patches} == 2     && $row->{perl}     !~ /patch/i);
        next    if($cgiparams{distmat} && $cgiparams{distmat} == 1     && $row->{version}  =~ /_/i);
        next    if($cgiparams{distmat} && $cgiparams{distmat} == 2     && $row->{version}  !~ /_/i);
        next    if($cgiparams{perlmat} && $cgiparams{perlmat} == 1     && $row->{perl}     =~ /^5.(7|9|11)/);
        next    if($cgiparams{perlmat} && $cgiparams{perlmat} == 2     && $row->{perl}     !~ /^5.(7|9|11)/);
        next    if($cgiparams{perlver} && $cgiparams{perlver} ne 'ALL' && $row->{perl}     !~ /$cgiparams{perlver}/i);
        next    if($cgiparams{osname}  && $cgiparams{osname}  ne 'ALL' && $row->{osname}   !~ /$cgiparams{osname}/i);

        $summary->{ $row->{version} }->{ uc $row->{state} }++;
        $summary->{ $row->{version} }->{ 'ALL' }++;
    }

    my $oncpan = q!'cpan','upload','backpan'!;
    $oncpan = q!'cpan','upload'!    if($cgiparams{oncpan} && $cgiparams{oncpan} == 1);
    $oncpan = q!'backpan'!          if($cgiparams{oncpan} && $cgiparams{oncpan} == 2);

    # ensure we cover all known versions
    my @rows = $options{UPLOADS}->get_query(
                    'array',
                    "SELECT DISTINCT(version) FROM uploads WHERE dist = ? AND type IN ($oncpan) ORDER BY released DESC",
                    $cgiparams{dist} );
    my @versions;
    for(@rows) { push @versions, $_->[0]; }
    my %versions = map {my $v = $_; $v =~ s/[^\w\.\-]/X/g; $_ => $v} @versions;

    my $parms = {
        versions        => \@versions,
        versions_tag    => \%versions,
        summary         => $summary,
    };

    my $str;
    $tt->process( 'dist_summary.html', $parms, \$str )
            || error( $tt->error );

    my $html;
    $html->{'reportsummary'} = $str;
    $OT->param( $html );
}

sub process_author {
    my $dists = _get_distvers($cgiparams{author});
    my @dists;

    for my $dist (sort keys %$dists) {
        my $next = $options{CPANSTATS}->iterator(
                        'hash',
                        "SELECT state,perl,version,osname FROM cpanstats WHERE dist=? AND version=? AND state!='cpan'",
                        $dist, $dists->{$dist} );

        my ($summary);
        while ( my $row = $next->() ) {
            $row->{perl} = "5.004_05" if $row->{perl} eq "5.4.4"; # RT 15162
            next    if($cgiparams{patches} && $cgiparams{patches} == 1     && $row->{perl}     =~ /patch/i);
            next    if($cgiparams{patches} && $cgiparams{patches} == 2     && $row->{perl}     !~ /patch/i);
            next    if($cgiparams{distmat} && $cgiparams{distmat} == 1     && $row->{version}  =~ /_/i);
            next    if($cgiparams{distmat} && $cgiparams{distmat} == 2     && $row->{version}  !~ /_/i);
            next    if($cgiparams{perlmat} && $cgiparams{perlmat} == 1     && $row->{perl}     =~ /^5.(7|9|11)/);
            next    if($cgiparams{perlmat} && $cgiparams{perlmat} == 2     && $row->{perl}     !~ /^5.(7|9|11)/);
            next    if($cgiparams{perlver} && $cgiparams{perlver} ne 'ALL' && $row->{perl}     !~ /$cgiparams{perlver}/i);
            next    if($cgiparams{osname}  && $cgiparams{osname}  ne 'ALL' && $row->{osname}   !~ /$cgiparams{osname}/i);

            $summary->{ uc $row->{state} }++;
            $summary->{ 'ALL' }++;
        }

        push @dists,
            {
                distribution => $dist,
                summary      => $summary,
            };
    }

    my $parms = {
        distributions   => \@dists,
    };

    my $str;
    $tt->process( 'author_summary.html', $parms, \$str )
            || error( $tt->error );

    my $html;
    $html->{'reportsummary'} = $str;
    $OT->param( $html );
}

sub _get_distvers {
    my $author    = shift;
    my $dbx       = $options{UPLOADS};
    my ($dist,@dists,%dists);

    my $oncpan = q!'cpan','upload','backpan'!;
    $oncpan = q!'cpan','upload'!    if($cgiparams{oncpan} && $cgiparams{oncpan} == 1);
    $oncpan = q!'backpan'!          if($cgiparams{oncpan} && $cgiparams{oncpan} == 2);

    # What distributions have been released by this author?
    my @rows = $dbx->get_query(
                'array',
                "SELECT DISTINCT(dist) FROM uploads WHERE author = ? AND type IN ($oncpan)",
                $author );
    for(@rows) { push @dists, $_->[0] }

    for my $distribution (@dists ) {
        next    unless($distribution =~ /^[A-Za-z0-9][A-Za-z0-9\-_]*$/
                    || $distribution =~ /$EXCEPTIONS/);
        next    if(defined $dists{$distribution});
        #print "... dist $distribution\n";

        # Find the latest version
        my @vers = $dbx->get_query(
            'array',
            "SELECT version FROM uploads WHERE author = ? AND dist = ? ORDER BY released DESC LIMIT 1",
            $author,$distribution );
        $dists{$distribution} = @vers ? $vers[0]->[0] : 0;
    }

    return \%dists;
}

sub error {
    print STDERR @_;
    print $cgi->header('text/plain'), "Error retrieving data\n";
    exit;
}

1;

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

  Barbie       <barbie@cpan.org>   2008-present

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2008      Barbie <barbie@cpan.org>

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut
