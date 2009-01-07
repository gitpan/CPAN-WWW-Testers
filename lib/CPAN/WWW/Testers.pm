package CPAN::WWW::Testers;

use strict;
use vars qw($VERSION);

$VERSION = '0.41';

#----------------------------------------------------------------------------
# Library Modules

use Archive::Extract;
use Config::IniFiles;
use CPAN::Testers::Common::DBUtils;
use DateTime;
use File::Basename;
use File::Copy;
use File::Path;
use File::stat;
use File::Slurp;
use JSON::Syck;
use LWP::Simple;
use Path::Class;
use Template;
use Sort::Versions;
use Storable qw(dclone);
use XML::RSS;
use YAML;

use base qw(Class::Accessor::Chained::Fast);

#----------------------------------------------------------------------------
# Variables

use constant RSS_LIMIT_RECENT => 200;
use constant RSS_LIMIT_AUTHOR => 100;

# The following distributions are considered exceptions from the norm and
# are to be added on a case by case basis.
my $EXCEPTIONS = 'Test.php|Net-ITE.pm|CGI.pm';

my %OSNAMES = (
    'aix'       => 'AIX',
    'bsdos'     => 'BSD/OS',
    'cygwin'    => 'Cygwin',
    'darwin'    => 'Darwin',
    'dec_osf'   => 'Tru64',
    'dragonfly' => 'Dragonfly BSD',
    'freebsd'   => 'FreeBSD',
    'gnu'       => 'GNU',
    'hpux'      => 'HP-UX',
    'irix'      => 'IRIX',
    'linux'     => 'Linux',
    'macos'     => 'MacOS',
    'mirbsd'    => 'MirBSD',
    'mswin32'   => 'MSWin32',
    'netbsd'    => 'NetBSD',
    'openbsd'   => 'OpenBSD',
    'os2'       => 'OS/2',
    'os390'     => 'OS/390',
    'sco'       => 'SCO',
    'solaris'   => 'Solaris',
    'vms'       => 'VMS'
);

my $MAX_ID;
my $UPDATE_ID = 0;

#----------------------------------------------------------------------------
# The Application Programming Interface

__PACKAGE__->mk_accessors(
    qw( directory database config updates tt ttjs authors osnames perls ));

sub generate {
    my $self = shift;

    $self->_init();
    $UPDATE_ID = 1;

    # generate pages
    $self->_copy_files;
    $self->_write_distributions_alphabetic;
    $self->_write_distributions;
    $self->_write_authors_alphabetic;
    $self->_write_authors;
    $self->_write_recent;
    $self->_write_stats;
    $self->_write_index;
    $self->_write_osnames;
}

sub update {
    my $self = shift;

    $self->_init();

    my (@dists,@authors);
    my $updates = $self->updates;
    my $fh = IO::File->new($updates,'r') or die "Cannot open updates file [$updates]: $!\n";
    while(<$fh>) {
        my ($name,$value) = split(':');
        $value =~ s/\s+$//;
        push @dists,   $value   if($name eq 'dist');
        push @authors, $value   if($name eq 'author');
    }

    # generate pages
    $self->_copy_files;
    if(@dists) {
        $self->_write_distributions_alphabetic;
        $self->_write_distributions(@dists);
    }
    if(@authors) {
        $self->_write_authors_alphabetic;
        $self->_write_authors(@authors);
    }
    $self->_write_recent;
    $self->_write_stats;
    $self->_write_index;
    $self->_write_osnames;
}

sub _init {
    my $self = shift;

    # ensure we have a configuration file
    die "Must specify the configuration file\n"                 unless($self->{config});
    die "Configuration file [".$self->{config}."] not found\n"  unless(-f $self->{config});

    # load configuration
    my $cfg = Config::IniFiles->new( -file => $self->{config} );

    # configure databases
    for my $db (qw(CPANSTATS UPLOADS)) {
        die "No configuration for $db database\n"   unless($cfg->SectionExists($db));
        my %opts = map {$_ => $cfg->val($db,$_);} qw(driver database dbfile dbhost dbport dbuser dbpass);
        $self->{$db} = CPAN::Testers::Common::DBUtils->new(%opts);
        die "Cannot configure $db database\n"   unless($self->{$db});
    }

    $self->database($cfg->val('MASTER','database'));

    my $directory = $self->directory || $cfg->val('MASTER','directory');
    die "No output directory specified\n"       unless(-d $directory);
    $self->directory($directory);
    mkpath($directory);

    # set up API to Template Toolkit
    my $tt = Template->new(
        {
            #    POST_CHOMP => 1,
            #    PRE_CHOMP => 1,
            #    TRIM => 1,
            EVAL_PERL    => 1,
            INCLUDE_PATH => [ 'src', "$directory/templates" ],
            PROCESS      => 'layout',
            FILTERS      => {
                'striphtml' => sub {
                    my $text = shift;
                    $text =~ s/<.+?>//g;
                    return $text;
                },
            },
        }
    );
    $self->tt($tt);
    my $ttjs = Template->new(
        {
            #    POST_CHOMP => 1,
            #    PRE_CHOMP => 1,
            #    TRIM => 1,
            EVAL_PERL    => 1,
            INCLUDE_PATH => [ 'src', "$directory/templates" ],
            PROCESS      => 'layout.js',
        }
    );
    $self->ttjs($ttjs);

    # Get the current max id
    my @rows = $self->{CPANSTATS}->get_query('array',"SELECT max(id) FROM cpanstats");
    $MAX_ID = @rows ? $rows[0]->[0] : 0;

    # we store the max id at the beginning so that if the processing
    # takes too long, in the next run we can include any reports we
    # may have missed during the earlier parts of file generation.
    print "MAX_ID = $MAX_ID\n";

}

sub _last_id {
    my ( $self, $id ) = @_;
    my $filename = file( $self->directory, "last_id.txt" )->stringify;

    overwrite_file( $filename, 0 ) unless -f $filename;

    if (defined $id) {
        overwrite_file( $filename, $id );
    } else {
        $id = read_file($filename);
    }

    print "last_id = $id\n";
    return $id;
}

sub _copy_files {
    my $self      = shift;
    my $directory = $self->directory;

    for my $filename (
        'style.css', 'cpan-testers.css',

        'cssrules.js', 'cpan-testers-author.js', 'cpan-testers-dist.js',
        'blank.js', 'OpenThought.js',

        'red.png', 'yellow.png', 'green.png', 'background.png',
        'headings/blank.png', 'loader-orange.gif',

        'cgi-bin/reports-summary.cgi',
        'cgi-bin/templates/author_summary.html',
        'cgi-bin/templates/dist_summary.html',
        )
    {
        my $src  = "src/$filename";
        my $dest = "$directory/$filename";
        mkpath(dirname($dest));
        copy( $src, $dest );
    }


    my $dir = dir( $directory, 'stats', 'dist' );
    mkpath("$dir");
    die $!  unless(-d "$dir");
}

sub _write_distributions_alphabetic {
    my $self      = shift;
    my $dbh       = $self->{CPANSTATS};
    my $directory = $self->directory;
    my $now       = DateTime->now;
    my $tt        = $self->tt;

    my $dir = dir( $directory, 'letter' );
    mkpath("$dir");
    die $!  unless(-d "$dir");

    for my $letter ( 'A' .. 'Z' ) {
        my ($dist,@dists);
        my $next = $dbh->iterator('array',"SELECT DISTINCT(dist) FROM cpanstats WHERE dist LIKE '$letter%'");
        while( my $row = $next->() ) {
            next unless $row->[0] =~ /^[A-Za-z0-9][A-Za-z0-9-_]+$/;
            push @dists, $row->[0];
        }
        my $parms = {
            letter         => $letter,
            dists          => \@dists,
            now            => $now,
            testersversion => $VERSION,
        };
        my $destfile = file( $directory, 'letter', $letter . ".html" );
        print "Writing $destfile\n";
        $tt->process( 'letter', $parms, $destfile->stringify )
            || die $tt->error;
    }
}

sub _write_authors_alphabetic {
    my $self      = shift;
    my $directory = $self->directory;
    my $now       = DateTime->now;
    my $tt        = $self->tt;

    my $dir = dir( $directory, 'lettera' );
    mkpath("$dir");
    die $!  unless(-d "$dir");

    my $authors = $self->_mklist_authors;

    for my $letter ( 'A' .. 'Z' ) {
        my @authors = grep {/^$letter/} @$authors;
        my $parms = {
            letter         => $letter,
            authors        => \@authors,
            now            => $now,
            testersversion => $VERSION,
        };
        my $destfile = file( $directory, 'lettera', $letter . ".html" );
        print "Writing $destfile\n";
        $tt->process( 'lettera', $parms, $destfile->stringify )
            || die $tt->error;
    }
}

sub _write_authors {
    my $self      = shift;
    my $dbh       = $self->{CPANSTATS};
    my $directory = $self->directory;
    my $last_id   = $self->_last_id;
    my $now       = DateTime->now;
    my $tt        = $self->tt;
    my $ttjs      = $self->ttjs;
    my $count     = 0;

    my $dir = dir( $directory, 'letter' );
    mkpath("$dir");
    die $!  unless(-d "$dir");

    my @authors;
    if(@_) {
        @authors = @_;

    } else {
        my @rows = $dbh->get_query('array',"SELECT count(id) FROM cpanstats WHERE id > $last_id");
        $count = $rows[0]->[0]  if(@rows);
        if($count > 500000) {
            # rebuild for all authors if we're looking at a large number
            # of reports, as checking backpan for distributions is EXTREMELY
            # time consuming! There are less than 7000 authors in total and
            # roughly 3600 active authors.
            my $authors = $self->_mklist_authors;
            @authors = @$authors;
        } else {
            # if only updating for a smaller selection of reports, only update
            # for those authors that have had reports since our last update
            my %authors;
            my $next = $dbh->iterator('hash',"SELECT dist,version FROM cpanstats WHERE id > $last_id GROUP BY dist,version");
            while ( my $row = $next->() ) {
                my $author = $self->_author_of($row->{dist},$row->{version});
                $authors{$author}++;
            }
            @authors = keys %authors;
        }
    }

    print "Updating ".(scalar(@authors))." authors, from $count entries\n";

    for my $author (sort @authors) {
        print "Processing $author\n";
        my $distributions = $self->_get_distvers($author);
        my @distributions;

        for my $distribution (sort keys %$distributions) {
            my $next = $dbh->iterator(
                            'hash',
                            "SELECT id,state,perl,osname,osvers,platform FROM cpanstats WHERE dist=? AND version=? AND state!='cpan' ORDER BY id",
                            $distribution, $distributions->{$distribution} );

            my (@reports,$summary);
            while ( my $row = $next->() ) {
                my $oscode = lc $row->{osname};
                $oscode =~ s/[^\w]+//g;

                my $report = {
                    id           => $row->{id},
                    distribution => $distribution,
                    status       => uc $row->{state},
                    version      => $distributions->{$distribution},
                    perl         => $row->{perl},
                    osname       => ($OSNAMES{$oscode} || uc($row->{osname})),
                    osvers       => $row->{osvers},
                    archname     => $row->{platform},
                    url          => "http://nntp.x.perl.org/group/perl.cpan.testers/$row->{id}",
                    csspatch     => $row->{perl} =~ /patch/       ? 'pat' : 'unp',
                    cssperl      => $row->{perl} =~ /^5.(7|9|11)/ ? 'dev' : 'rel',
                };
                push @reports, $report;

                $summary->{ $report->{status} }++;
                $summary->{ 'ALL' }++;
            }

            push @distributions,
                {
                distribution => $distribution,
                version      => $distributions->{$distribution},
                reports      => \@reports,
                summary      => $summary,
                csscurrent   => $self->_check_oncpan($distribution,$distributions->{$distribution}) ? 'cpan' : 'back',
                cssrelease   => $distributions->{$distribution} =~ /_/ ? 'rel' : 'off',
                };
        }

        my $parms = {
            author          => $author,
            distributions   => \@distributions,
            now             => $now,
            testersversion  => $VERSION,
            perlvers        => $self->_mklist_perls,
            osnames         => $self->_mklist_osnames,
        };

        my $destfile = file( $directory, 'author', $author . ".html" );
        print "Writing $destfile\n";
        $tt->process( 'author', $parms, $destfile->stringify )
            || die $tt->error;

        my $output;
        $destfile = file( $directory, 'author', $author . ".js" );
        print "Writing $destfile\n";
        $ttjs->process( 'author.js', $parms, \$output )
            || die $tt->error;
        overwrite_file( $destfile->stringify, \$output);

        my @reports;
        for my $distribution (@distributions) {
            push @reports, @{ $distribution->{reports} };
        }
        @reports = sort { $b->{id} <=> $a->{id} } @reports;
        $destfile = file( $directory, 'author', $author . ".yaml" );
        print "Writing $destfile\n";
        overwrite_file( $destfile->stringify,
            _make_yaml_distribution( $author, \@reports ) );

        splice(@reports,RSS_LIMIT_AUTHOR) if scalar(@reports) > RSS_LIMIT_AUTHOR;
        $destfile = file( $directory, 'author', $author . ".rss" );
        print "Writing $destfile\n";
        overwrite_file( $destfile->stringify,
            _make_rss_author( $author, \@reports ) );

        $destfile = file( $directory, 'author', $author . "-nopass.rss" );
        print "Writing $destfile\n";
        overwrite_file( $destfile->stringify,
            _make_rss_author_nopass( $author, \@reports ) );
    }
}


sub _write_distributions {
    my $self      = shift;
    my $dbh       = $self->{CPANSTATS};
    my $dbx       = $self->{UPLOADS};
    my $directory = $self->directory;
    my $last_id   = $self->_last_id;
    my $now       = DateTime->now;
    my $tt        = $self->tt;
    my $ttjs      = $self->ttjs;

    # we only want to update distributions that have had changes from our
    # last update
    my @distributions;

    if(@_) {
        @distributions = @_;
    } else {
        my $next = $dbh->iterator('array',"SELECT DISTINCT(dist) FROM cpanstats WHERE id > $last_id");
        while ( my $row = $next->() ) { push @distributions, $row->[0]; }
    }

    print "Updating ".(scalar(@distributions))." distributions\n";

    # process distribution pages
    for my $distribution (sort @distributions) {
        next unless($distribution =~ /^[A-Za-z0-9][A-Za-z0-9\-_]*$/
                    || $distribution =~ /$EXCEPTIONS/);
        print "Processing $distribution\n";

        #print STDERR "DEBUG:dist=[$distribution]\n";

        my $next = $dbh->iterator(
            'hash',
            "SELECT id, state, version, perl, osname, osvers, platform FROM cpanstats WHERE dist = ? AND state != 'cpan' ORDER BY version, id",
            $distribution );

        my @reports;
        while ( my $row = $next->() ) {
            next unless $row->{version};
            $row->{perl} = "5.004_05" if $row->{perl} eq "5.4.4"; # RT 15162
            my $oscode = lc $row->{osname};
            $oscode =~ s/[^\w]+//g;

            my $report = {
                id           => $row->{id},
                distribution => $distribution,
                status       => uc $row->{state},
                version      => $row->{version},
                perl         => $row->{perl},
                osname       => ($OSNAMES{$oscode} || uc($row->{osname})),
                osvers       => $row->{osvers},
                archname     => $row->{platform},
                url          => "http://nntp.x.perl.org/group/perl.cpan.testers/$row->{id}",
                csspatch     => $row->{perl} =~ /patch/       ? 'pat' : 'unp',
                cssperl      => $row->{perl} =~ /^5.(7|9|11)/ ? 'dev' : 'rel',
            };
            push @reports, $report;
        }

        #print STDERR "DEBUG:count:".(scalar(@reports))."\n";

        my ( $summary, $byversion );
        for my $report (@reports) {
            $summary->{ $report->{version} }->{ $report->{status} }++;
            $summary->{ $report->{version} }->{ 'ALL' }++;
            push @{ $byversion->{ $report->{version} } }, $report;
        }

        for my $version ( keys %$byversion ) {
            my @reports = @{ $byversion->{$version} };
            $byversion->{$version}
                = [ sort { $b->{id} <=> $a->{id} } @reports ];
        }

        # ensure we cover all known versions
        my @rows = $dbx->get_query(
                        'array',
                        "SELECT DISTINCT(version) FROM uploads WHERE dist = ? ORDER BY released DESC",
                        $distribution );
        my @versions;
        for(@rows) { push @versions, $_->[0]; }
        my %versions = map {my $v = $_; $v =~ s/[^\w\.\-]/X/g; $_ => $v} @versions;

        my %release;
        for my $version ( keys %versions ) {
            $release{$version}->{csscurrent} = $self->_check_oncpan($distribution,$version) ? 'cpan' : 'back';
            $release{$version}->{cssrelease} = $version =~ /_/ ? 'dev' : 'off';
        }

        my ($stats,$oses);
        @rows = $dbh->get_query(
            'hash',
            "SELECT perl, osname, count(*) AS count FROM cpanstats WHERE dist = ? AND state = 'pass' GROUP BY perl, osname",
            $distribution );

        for(@rows) {
            my $oscode = lc $_->{osname};
            $oscode =~ s/[^\w]+//g;
            $stats->{$_->{perl}}->{$oscode} = $_->{count};
            $oses->{$oscode} = ($OSNAMES{$oscode} || uc($_->{osname}));
        }

        my @stats_oses = sort keys %$oses;
        my @stats_perl = sort {versioncmp($b,$a)} keys %$stats;

        my $parms = {
            versions        => \@versions,
            versions_tag    => \%versions,
            summary         => $summary,
            release         => \%release,
            byversion       => $byversion,
            distribution    => $distribution,
            now             => $now,
            testersversion  => $VERSION,
            stats_code      => $oses,
            stats_oses      => \@stats_oses,
            stats_perl      => \@stats_perl,
            stats           => $stats,
            perlvers        => $self->_mklist_perls,
            osnames         => $self->_mklist_osnames,
        };
        my $destfile = file( $directory, 'show', $distribution . ".html" );
        print "Writing $destfile\n";
        $tt->process( 'dist', $parms, $destfile->stringify )
            || die $tt->error;

        my $output;
        $destfile = file( $directory, 'show', $distribution . ".js" );
        print "Writing $destfile\n";
        $ttjs->process( 'dist.js', $parms, \$output )
            || die $tt->error;
        overwrite_file( $destfile->stringify, \$output);

        $destfile = file( $directory, 'show', $distribution . ".yaml" );
        print "Writing $destfile\n";
        overwrite_file( $destfile->stringify,
            _make_yaml_distribution( $distribution, \@reports ) );

        splice(@reports,RSS_LIMIT_AUTHOR) if scalar(@reports) > RSS_LIMIT_AUTHOR;
        $destfile = file( $directory, 'show', $distribution . ".rss" );
        print "Writing $destfile\n";
        overwrite_file( $destfile->stringify,
            _make_rss_distribution( $distribution, \@reports ) );
        $destfile = file( $directory, 'show', $distribution . ".json" );
        print "Writing $destfile\n";
        overwrite_file( $destfile->stringify,
            _make_json_distribution( $distribution, \@reports ) );

        # distribution PASS stats
        @rows = $dbh->get_query(
            'hash',
            "SELECT perl, osname, version FROM cpanstats WHERE dist = ? AND state='pass'",
            $distribution );
        for(@rows) {
            $stats->{$_->{perl}}->{$_->{osname}} = $_->{version}
                if(!$stats->{$_->{perl}}->{$_->{osname}} || versioncmp($_->{version},$stats->{$_->{perl}}->{$_->{osname}}));
        }
        $destfile = file( $directory, 'stats', 'dist', $distribution . ".html" );
        print "Writing $destfile\n";
        $tt->process( 'stats-dist', $parms, $destfile->stringify )
            || die $tt->error;
    }
}

sub _write_stats {
    my $self      = shift;
    my $dbh       = $self->{CPANSTATS};
    my $directory = $self->directory;
    my $tt        = $self->tt;
    my $now       = DateTime->now;

    print "Processing stats pages\n";

    my $dir = dir( $directory, 'stats' );
    mkpath("$dir");
    die $!  unless(-d "$dir");

    my (%data,%perldata,%perls,%all_osnames,%dists,%perlos);

    my @rows = $dbh->get_query(
        'hash',
        "SELECT dist, version, perl, osname FROM cpanstats WHERE state = 'pass'");

    no warnings( 'uninitialized', 'numeric' );
    for my $row (@rows) {
        next if not $row->{perl};
        next if $row->{perl} =~ / /;
        next if $row->{perl} =~ /^5\.(7|9|11)/; # ignore dev versions

        next if $row->{version} =~ /[^\d.]/;
        $row->{perl} = "5.004_05" if $row->{perl} eq "5.4.4"; # RT 15162

        my $oscode = lc $row->{osname};
        $oscode =~ s/[^\w]+//g;
        $row->{osname} = $oscode;

        #print Dumper("BEFORE: row=$row->{osname}, oscode=$oscode, osname=$OSNAMES{$oscode}");
        #$row->{osname} = ($OSNAMES{$oscode} || uc($row->{osname}));
        #print Dumper("AFTER:  row=$row->{osname}");

        $perldata{$row->{perl}}{$row->{dist}} = $row->{version}
            if $perldata{$row->{perl}}{$row->{dist}} < $row->{version};
        $data{$row->{dist}}{$row->{perl}}{$row->{osname}} = $row->{version}
            if $data{$row->{dist}}{$row->{perl}}{$row->{osname}} < $row->{version};
        $perls{$row->{perl}}{reports}++;
        $perls{$row->{perl}}{distros}{$row->{dist}}++;
        $perlos{$row->{perl}}{$row->{osname}}++;
        $all_osnames{$row->{osname}}++;
    }

    my @versions = sort {versioncmp($b,$a)} keys %perls;

    # page perl perl version cross referenced with platforms
    my %perl_osname_all;
    for my $perl ( @versions ) {
        my @data;
        my %oscounter;
        my %dist_for_perl;
        for my $dist ( sort keys %{ $perldata{$perl} } ) {
            my @osversion;
            for my $os ( sort keys %{ $perlos{$perl} } ) {
                my $oscode = lc $os;
                $oscode =~ s/[^\w+]//g;
                if ( defined $data{$dist}{$perl}{$oscode} ) {
                    push @osversion, { ver => $data{$dist}{$perl}{$oscode} };
                    $oscounter{$oscode}++;
                    $dist_for_perl{$dist}++;
                } else {
                    push @osversion, { ver => undef };
                }
            }
            push @data,
                {
                dist      => $dist,
                osversion => \@osversion,
                };
        }

        my @perl_osnames;
        for my $os ( sort keys %{ $perlos{$perl} } ) {
            my $oscode = lc $os;
            $oscode =~ s/[^\w+]//g;
            if ( $oscounter{$oscode} ) {
                push @perl_osnames, { oscode => $oscode, osname => $OSNAMES{$oscode} || uc $os, cnt => $oscounter{$oscode} };
                $perl_osname_all{$oscode}{$perl} = $oscounter{$oscode};
            }
        }

        my $destfile
            = file( $directory, 'stats', "perl_${perl}_platforms.html" );
        my $parms = {
            now         => $now,
            osnames     => \@perl_osnames,
            dists       => \@data,
            perl        => $perl,
            cnt_modules => scalar keys %dist_for_perl,
        };
        print "Writing $destfile\n";
        $tt->process( "stats-perl-platform", $parms, $destfile->stringify )
            || die $tt->error;
    }

    # how many test reports per platform per perl version?
    {
        my (@data,@perl_osnames);
        for(keys %perl_osname_all) {
            my $oscode = lc $_;
            $oscode =~ s/[^\w]+//g;
            push @perl_osnames, {oscode => $oscode, osname => $OSNAMES{$oscode} || uc $_}
        }

        for my $perl ( @versions ) {
            my @count;
            for my $os (keys %perl_osname_all) {
                my $oscode = lc $os;
                $oscode =~ s/[^\w+]//g;
                push @count, { oscode => $oscode, osname => $OSNAMES{$oscode} || uc $os, count => $perl_osname_all{$os}{$perl} };
            }
            push @data, {
                perl => $perl,
                count => \@count,
            }
        }

        my $destfile
            = file( $directory, 'stats', "perl_platforms.html" );
        my $parms = {
            now         => $now,
            osnames     => \@perl_osnames,
            perlv       => \@data,
        };
        print "Writing $destfile\n";
        $tt->process( "stats-perl-platform-count", $parms, $destfile->stringify )
            || die $tt->error;
    }

    # page per perl version
    for my $perl ( @versions ) {
        my @data;
        my $cnt;
        for my $dist ( sort keys %{ $perldata{$perl} } ) {
            $cnt++;
            push @data,
                {
                    dist    => $dist,
                    version => $perldata{$perl}{$dist},
                };
        }

        my $destfile = file( $directory, 'stats', "perl_${perl}.html" );
        my $parms = {
            now         => $now,
            data        => \@data,
            perl        => $perl,
            cnt_modules => $cnt,
        };
        print "Writing $destfile\n";
        $tt->process( "stats-perl-version", $parms, $destfile->stringify )
            || die $tt->error;
    }

    # generate index.html
    my @perls;
    for my $p ( @versions ) {
        push @perls,
            {
            perl         => $p,
            report_count => $perls{$p}{reports},
            distro_count => scalar( keys %{ $perls{$p}{distros} } ),
            };
    }
    my $destfile = file( $directory, 'stats', "index.html" );
    my $parms = {
        now   => $now,
        perls => \@perls,
    };
        print "Writing $destfile\n";
    $tt->process( "stats-index", $parms, $destfile->stringify )
        || die $tt->error;

    # create symbolic links
    for my $link ('headings', 'background.png', 'style.css', 'cpan-testers.css') {
        my $source = file( $directory, $link );
        my $target = file( $directory, 'stats', $link );
        next    if(!-e $source);
        next    if( -e $target);

        eval {symlink($source,$target) ; 1};
    }
}

sub _write_recent {
    my $self      = shift;
    my $dbh       = $self->{CPANSTATS};
    my $directory = $self->directory;
    my $now       = DateTime->now;
    my $tt        = $self->tt;

    print "Processing recent page\n";

    # Recent reports
    my $next = $dbh->iterator(
        'hash',
        "SELECT id, state, dist, version, perl, osname, osvers, platform FROM cpanstats WHERE state != 'cpan' ORDER BY id DESC");

    my @recent;
    my $count = RSS_LIMIT_RECENT;
    while ( my $row = $next->() ) {
        next unless $row->{version};
        my $oscode = lc $row->{osname};
        $oscode =~ s/[^\w]+//g;

        my $report = {
            id           => $row->{id},
            distribution => $row->{distribution},
            status       => uc $row->{state},
            version      => $row->{version},
            perl         => $row->{perl},
            osname       => ($OSNAMES{$oscode} || uc($row->{osname})),
            osvers       => $row->{osvers},
            archname     => $row->{platform},
            url => "http://nntp.x.perl.org/group/perl.cpan.testers/$row->{id}",
        };
        push @recent, $report;
        last    if(--$count < 1);
    }

    print "rows = ".(scalar(@recent))."\n";

    my $destfile = file( $directory, "recent.html" );
    print "Writing $destfile\n";
    my $parms = {
        now    => $now,
        recent => \@recent,
    };
    $tt->process( "recent", $parms, $destfile->stringify ) || die $tt->error;
    $destfile = file( $directory, "recent.rss" );
    overwrite_file( $destfile->stringify, _make_rss_recent( \@recent ) );
}

sub _write_index {
    my $self      = shift;
    my $dbh       = $self->{CPANSTATS};
    my $directory = $self->directory;
    my $now       = DateTime->now;
    my $tt        = $self->tt;

    print "Processing index pages\n";

    # Finally, the front page
    my @rows = $dbh->get_query('array',"SELECT count(*) FROM cpanstats WHERE state in ('pass','fail','na','unknown')");
    my $total_reports = @rows ? $rows[0]->[0] : 0;

    my $db = $self->database;

    my $destfile = file( $directory, "index.html" );
    print "Writing $destfile\n";
    my $parms = {
        now           => $now,
        letters       => [ 'A' .. 'Z' ],
        total_reports => $total_reports,
        dbsize        => int((-s $db     )/1024/1024),
        dbzipsize     => int((-s "$db.gz")/1024/1024),
    };

    $tt->process( "index", $parms, $destfile->stringify ) || die $tt->error;

    # now add all the redirects
    for my $dir (qw(author letter lettera show)) {
        my $src  = "src/index.html";
        my $dest = "$directory/$dir/index.html";
        print "Writing $dest\n";
        copy( $src, $dest );
    }

    # now add extra pages
    for my $file (qw(prefs help)) {
        my $dest = "$directory/$file.html";
        print "Writing $dest\n";
        $tt->process( $file, $parms, $dest ) || die $tt->error;
    }

    # Save the max id we got at the start
    $self->_last_id($MAX_ID)    if($UPDATE_ID);

    print "dbsize=[$parms->{dbsize}], dbzipsize=[$parms->{dbzipsize}], db=[$db]\n";
}

sub _write_osnames {
    my $self    = shift;
    my $osnames = $self->_mklist_osnames;

    for(sort keys %$osnames) {
        my $oscode = lc $_;
        $oscode =~ s/[^\w]+//g;
        next    if($OSNAMES{$oscode});
        $OSNAMES{$oscode} = uc $_;
    }

    my $fh      = IO::File->new('osnames.txt','w+') || die "Cannot write file [osnames.txt]: $!\n";
    print $fh "$_,$OSNAMES{$_}\n"    for(sort keys %OSNAMES);
    $fh->close;
}

sub _make_yaml_distribution {
    my ( $dist, $data ) = @_;

    my @yaml;

    for my $test (@$data) {
        my $entry = dclone($test);
        $entry->{platform} = $entry->{archname};
        $entry->{action}   = $entry->{status};
        $entry->{distversion}
            = $entry->{distribution} . '-' . $entry->{version};
        push @yaml, $entry;
    }
    return Dump( \@yaml );
}

sub _make_json_distribution {
    my ( $dist, $data ) = @_;

    my @data;

    for my $test (@$data) {
        my $entry = dclone($test);
        $entry->{platform} = $entry->{archname};
        $entry->{action}   = $entry->{status};
        $entry->{distversion}
            = $entry->{distribution} . '-' . $entry->{version};
        push @data, $entry;
    }
    return JSON::Syck::Dump( \@data );
}

sub _make_rss_distribution {
    my ( $dist, $data ) = @_;
    my $rss = XML::RSS->new( version => '1.0' );

    $rss->channel(
        title       => "$dist CPAN Testers Reports",
        link        => "http://www.cpantesters.org/show/$dist.html",
        description => "Automated test results for the $dist distribution",
        syn         => {
            updatePeriod    => "daily",
            updateFrequency => "1",
            updateBase      => "1901-01-01T00:00+00:00",
        },
    );

    for my $test (@$data) {
        $rss->add_item(
            title => sprintf(
                "%s %s-%s %s on %s %s (%s)",
                @{$test}{
                    qw( status distribution version perl osname osvers archname )
                    }
            ),
            link =>
                "http://nntp.x.perl.org/group/perl.cpan.testers/$test->{id}",
        );
    }

    return $rss->as_string;
}

sub _make_rss_recent {
    my ($data) = @_;
    my $rss = XML::RSS->new( version => '1.0' );

    $rss->channel(
        title       => "Recent CPAN Testers Reports",
        link        => "http://www.cpantesters.org/recent.html",
        description => "Recent CPAN Testers reports",
        syn         => {
            updatePeriod    => "daily",
            updateFrequency => "1",
            updateBase      => "1901-01-01T00:00+00:00",
        },
    );

    for my $test (@$data) {
        $rss->add_item(
            title => sprintf(
                "%s %s-%s %s on %s %s (%s)",
                @{$test}{
                    qw( status distribution version perl osname osvers archname )
                }
            ),
            link =>
                "http://nntp.x.perl.org/group/perl.cpan.testers/$test->{id}",
        );
    }

    return $rss->as_string;
}

sub _make_rss_author {
    my ( $author, $reports, $prefix ) = @_;
    my $rss = XML::RSS->new( version => '1.0' );
    $prefix ||= '';

    $rss->channel(
        title       => "${prefix}Reports for distributions by $author",
        link        => "http://www.cpantesters.org/author/$author.html",
        description => "Reports for distributions by $author",
        syn         => {
            updatePeriod    => "daily",
            updateFrequency => "1",
            updateBase      => "1901-01-01T00:00+00:00",
        },
    );

    for my $report (@$reports) {
        $rss->add_item(
            title => sprintf(
                "%s %s-%s %s on %s %s (%s)",
                @{$report}{
                    qw( status distribution version perl osname osvers archname )
                }
            ),
            link =>
                "http://nntp.x.perl.org/group/perl.cpan.testers/$report->{id}",
        );
    }

    return $rss->as_string;
}

sub _make_rss_author_nopass {
    my ( $author, $reports ) = @_;
    my @nopass = grep { $_->{status} ne 'PASS' } @$reports;
    _make_rss_author( $author, \@nopass, 'Failing ' );
}

sub _get_distvers {
    my $self      = shift;
    my $author    = shift;
    my $dbx       = $self->{UPLOADS};
    my ($dist,@dists,%dists);

    # What distributions have been released by this author?
    my @rows = $dbx->get_query( 'array', "SELECT DISTINCT(dist) FROM uploads WHERE author = ?", $author );
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

sub _author_of {
    my ($self,$dist,$vers) = @_;

    my @rows = $self->{UPLOADS}->get_query(
        'array',
        "SELECT DISTINCT(author) FROM uploads WHERE dist=? AND version=?",
        $dist,$vers);

    return $rows[0]->[0]    if(@rows);
    return;
}

sub _check_oncpan {
    my ($self,$dist,$vers) = @_;

    my @rows = $self->{UPLOADS}->get_query(
        'array',
        "SELECT DISTINCT(type) FROM uploads WHERE dist=? AND version=?",
        $dist,$vers);

    my $type = @rows ? $rows[0]->[0] : undef;

    return 1    unless($type);          # assume it's a new release
    return 0    if($type eq 'backpan'); # on backpan only
    return 1;                           # on cpan or new upload
}

sub _mklist_authors {
    my $self = shift;
    my @authors;
    my $authors = $self->authors;
    return $authors  if($authors);

    my $next = $self->{UPLOADS}->iterator(
        'array',
        "SELECT DISTINCT(author) FROM uploads ORDER BY author ASC");

    while(my $row = $next->()) { push @authors, $row->[0]; }
    $self->authors(\@authors);
    return \@authors;
}

sub _mklist_osnames {
    my $self = shift;
    my %osnames;
    my $osnames = $self->osnames;
    return $osnames  if($osnames);

    my $next = $self->{CPANSTATS}->iterator(
        'array',
        "SELECT DISTINCT(osname) FROM cpanstats WHERE state IN ('pass','fail','na','unknown') ORDER BY osname ASC");

    while(my $row = $next->()) {
        my $oscode = lc $row->[0];
        $oscode =~ s/[^\w]+//g;
        $osnames{$oscode} = ($OSNAMES{$oscode} || uc($row->[0]))  if($oscode);
    }

    $self->osnames(\%osnames);
    return \%osnames;
}

sub _mklist_perls {
    my $self = shift;
    my @perls;
    my $perls = $self->perls;
    return $perls  if($perls);

    my $next = $self->{CPANSTATS}->iterator(
        'array',
        "SELECT DISTINCT(perl) FROM cpanstats WHERE state IN ('pass','fail','na','unknown')");

    while(my $row = $next->()) {
        push @perls, $row->[0] if($row->[0] && $row->[0] !~ /patch|RC/i);
    }

    @perls = sort { versioncmp($b,$a) } @perls;
    $self->perls(\@perls);
    return \@perls;
}


q("QA Automation, so much to answer for!");

__END__

=head1 NAME

CPAN::WWW::Testers - Present CPAN Testers data

=head1 SYNOPSIS

  my $t = CPAN::WWW::Testers->new();
  $t->directory($directory);
  if($update) { $t->update($update); }
  $t->config($config);
  $t->generate;

=head1 DESCRIPTION

This distribution generates the CPAN Testers Reports website.

=head1 CPAN TESTERS

cpan-testers is a group, that was originaly setup by Graham Barr and Chris
Nandor.

The objective of the group is to test as many of the distributions available on
CPAN as possible, on as many platforms as possible, with a variety of perl
interpreters. The ultimate goal is to improve the portability of the
distributions on CPAN, and provide good feedback to the authors.

CPAN Testers began as a mailing list with a web interface (see the NNTP
website - http://nntp.x.perl.org/group/perl.cpan.testers/). Leon Brocard began
working on extracting metadata for use with the CPANTS, and ended up creating
the Reports website. This code now allows you to create and host your very own
CPAN Testers website, should you so choose.

Unpack the distribution and look at examples/generate.pl, to understand how
the site is generated. If you would like to send patches or report bugs,
please use the RT system.

=head1 INTERFACE

=head2 The Constructor

=over

=item * new

Instatiates the object CPAN::WWW::Testers.

=back

=head2 Methods

=over

=item

=item * directory

Accessor to set/get the directory where the webpages are to be created.

=item * database

Accessor to set/get the local path to the SQLite database.

=item * download

Downloads a remote copy of the SQLite database containing the latest article
updates from the NNTP server for the cpan-testers newgroup. The path to the
local copy of the database is then provided to the database accessor.

=item * generate

Reads the local copy of the SQLite database, and creates the alphabetic index,
distribution and main index web pages, together with the YAML and RSS pages
for each distribution.

=item * update

Given an updates file (pass via the constructor hash), will read through the
file and update the requested distritbutions and authors only. This is to
enable the update of specific pages, which may have got accidentally missed
during a regular generate() call. See the 'bin/cpanreps-verify' program for
further details.

=back

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
F<http://stats.cpantesters.org/>,
F<http://wiki.cpantesters.org/>

=head1 AUTHOR

  Original author:    Leon Brocard <acme@astray.com>   200?-2008
  Current maintainer: Barbie       <barbie@cpan.org>   2008-present

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2002-2008 Leon Brocard <acme@astray.com>
  Copyright (C) 2008      Barbie <barbie@cpan.org>

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

