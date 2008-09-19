package CPAN::WWW::Testers;

use strict;
use vars qw($VERSION);

$VERSION = "0.34";

#----------------------------------------------------------------------------
# Library Modules

use Archive::Extract;
use DateTime;
use DBI;
use File::Copy;
use File::Path;
use File::stat;
use File::Slurp;
use JSON::Syck;
use LWP::Simple;
use Parse::BACKPAN::Packages;
use Parse::CPAN::Distributions;
use Path::Class;
use Template;
use Sort::Versions;
use Storable qw(dclone);
use XML::RSS;
use YAML;

use base qw(Class::Accessor::Chained::Fast);

#----------------------------------------------------------------------------
# Variables

my $DEFAULT_URL = 'http://devel.cpantesters.org/cpanstats.db.gz';
my $DEFAULT_DB  = './cpanstats.db';

use constant RSS_LIMIT_RECENT => 200;
use constant RSS_LIMIT_AUTHOR => 100;

#----------------------------------------------------------------------------
# The Application Programming Interface

__PACKAGE__->mk_accessors(qw(directory database dbh tt last_id backpan oncpan updates list));

sub download {
    my $self    = shift;
    my $source  = shift || $DEFAULT_URL;
    my $file  = basename($source);

    my $target = file( $self->directory, $file );
    mirror( $source, $target );

    #system("bunzip -kf $target");
    my $ae = Archive::Extract->new( archive => $target );
    unless($ae->extract( to => $self->directory )) {
        die 'Failed to extract the archive [$target]';
    }

    my @files = $ae->files();
    $self->database( $self->directory, $files[0] );
}

sub generate {
    my $self = shift;

    # ensure we have a database
    my $db = $self->database;
    $db = $DEFAULT_DB           unless($db && -f $db);
    die 'No database found!\n'  unless($db && -f $db);

    my $dbh = DBI->connect( "dbi:SQLite:dbname=$db", '', '',
        { RaiseError => 1 } );
    $self->dbh($dbh);

    my $backpan = Parse::BACKPAN::Packages->new();
    $self->backpan($backpan);
    my $oncpan = Parse::CPAN::Distributions->new(file => $self->list);
    $self->oncpan($oncpan);

    my $directory = $self->directory;

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

    # generate pages
    $self->_copy_files;
    $self->_write_distributions_alphabetic;
    $self->_write_distributions;
    $self->_write_authors_alphabetic;
    $self->_write_authors;
    $self->_write_recent;
    $self->_write_stats;
    $self->_write_index;
}

sub update {
    my $self = shift;

    # ensure we have a database
    my $db = $self->database;
    $db = $DEFAULT_DB           unless($db && -f $db);
    die 'No database found!\n'  unless($db && -f $db);

    my $dbh = DBI->connect( "dbi:SQLite:dbname=$db", '', '',
        { RaiseError => 1 } );
    $self->dbh($dbh);

    my $backpan = Parse::BACKPAN::Packages->new();
    $self->backpan($backpan);
    my $oncpan = Parse::CPAN::Distributions->new(file => $self->list);
    $self->oncpan($oncpan);

    my $directory = $self->directory;

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
}

sub _last_id {
    my ( $self, $id ) = @_;
    my $filename = file( $self->directory, "last_id.txt" )->stringify;

    overwrite_file( $filename, 0 ) unless -f $filename;

    if ($id) {
        overwrite_file( $filename, $id );
    } else {
        $id = read_file($filename);
    }

    return $id;
}

sub _copy_files {
    my $self      = shift;
    my $dbh       = $self->dbh;
    my $directory = $self->directory;

    foreach my $filename (
        'style.css',
        'cssrules.js',
        'red.png', 'yellow.png', 'green.png', 'background.png'
        )
    {
        my $src  = "src/$filename";
        my $dest = "$directory/$filename";
        copy( $src, $dest );
    }

    my $dir = dir( $directory, 'stats', 'dist' );
    mkpath("$dir");
    die $!  unless(-d "$dir");
}

sub _write_distributions_alphabetic {
    my $self      = shift;
    my $dbh       = $self->dbh;
    my $directory = $self->directory;
    my $now       = DateTime->now;
    my $tt        = $self->tt;

    my $dir = dir( $directory, 'letter' );
    mkpath("$dir");
    die $!  unless(-d "$dir");

    foreach my $letter ( 'A' .. 'Z' ) {
        my $dist;
        my $sth = $dbh->prepare(
            "SELECT DISTINCT(dist) FROM cpanstats WHERE dist LIKE ?"
        );
        $sth->execute("$letter%");
        $sth->bind_columns( \$dist );
        my @dists;
        while ( $sth->fetch ) {
            next unless $dist =~ /^[A-Za-z0-9][A-Za-z0-9-_]+$/;
            push @dists, $dist;
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
    my $backpan   = $self->backpan;
    my $now       = DateTime->now;
    my $tt        = $self->tt;

    my $dir = dir( $directory, 'lettera' );
    mkpath("$dir");
    die $!  unless(-d "$dir");

    my @all_authors = $backpan->authors;

    foreach my $letter ( 'A' .. 'Z' ) {
        my @authors = grep {/^$letter/} @all_authors;
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
    my $dbh       = $self->dbh;
    my $directory = $self->directory;
    my $last_id   = $self->_last_id;
    my $backpan   = $self->backpan;
    my $oncpan    = $self->oncpan;
    my $now       = DateTime->now;
    my $tt        = $self->tt;
    my $count     = 0;

    my $dir = dir( $directory, 'letter' );
    mkpath("$dir");
    die $!  unless(-d "$dir");

    my @authors;
    if(@_) {
        @authors = @_;

    } else {
        my $sth = $dbh->prepare(
            "SELECT count(id) FROM cpanstats WHERE id > $last_id");
        $sth->execute;
        $sth->bind_columns( \$count );
        $sth->fetch;
        if($count > 100000) {
            # rebuild for all authors if we're looking at a large number
            # of reports, as checking backpan for distributions is EXTREMELY
            # time consuming! There are less than 4000 authors in total anyway.
            @authors = $backpan->authors;
        } else {
            # if only updating for a smaller selection of reports, only update
            # for those authors that have had reports since our last update
            my $sth = $dbh->prepare(
                "SELECT dist,version FROM cpanstats WHERE id > $last_id GROUP BY dist,version");
            my ($distribution,$version);
            $sth->execute;
            $sth->bind_columns( \$distribution, \$version );

            my %authors;
            while ( $sth->fetch ) {
                #print "... checking distro=$distribution-$version\n";
                my $author = $oncpan->author_of($distribution,$version);
                if($author) {
                    $authors{$author}++;
                } else {
                    foreach my $dist ( $backpan->distributions($distribution) ) {
                    #print "... version=".$dist->{version}." [$version]\n";
                    #print "... author=".$dist->{cpanid}."\n";
                        if($dist->{version} eq $version) {
                            $authors{$dist->{cpanid}}++;
                            last;
                        }
                    }
                }
            }
            @authors = keys %authors;
        }
    }

    print "Updating ".(scalar(@authors))." authors, from $count entries\n";

    foreach my $author (sort @authors) {
        print "Processing $author\n";
        my (%distributions,@distributions);

        # if an author has no entries in BACKPAN, the next line can blow up!
        eval{ %distributions = map {$_ => 1} $backpan->distributions_by($author), $oncpan->distributions_by($author); };
        eval{ %distributions = map {$_ => 1} $oncpan->distributions_by($author); }  if($@);

        foreach my $distribution (sort keys %distributions ) {
            next unless $distribution =~ /^[A-Za-z0-9][A-Za-z0-9-_]+$/;
            #print "... dist $distribution\n";

            # Note that we assume CPAN holds the latest version. It's possible
            # that this is not the case, but hopefully that is a short term
            # anomaly
            my $latest_version = $oncpan->latest_version($distribution,$author);

            # If no version found on CPAN, check BACKPAN
            unless($latest_version) {
                foreach my $dist ( sort {versioncmp($b->{version},$a->{version})} $backpan->distributions($distribution) ) {
                    if($dist->{cpanid} eq $author) {
                        $latest_version = $dist->{version};
                        last;
                    }
                }
            }

            my $sth = $dbh->prepare(
                "SELECT id, state, perl, osname, osvers, platform FROM cpanstats WHERE dist = ? AND version = ? AND state != 'cpan' ORDER BY id" );
            $sth->execute( $distribution, $latest_version );
            my ( $id, $status, $perl, $osname, $osvers, $archname );
            $sth->bind_columns( \$id, \$status, \$perl, \$osname, \$osvers,
                \$archname );
            my (@reports,$summary);
            while ( $sth->fetch ) {
                my $report = {
                    id           => $id,
                    distribution => $distribution,
                    status       => uc $status,
                    version      => $latest_version,
                    perl         => $perl,
                    osname       => $osname,
                    osvers       => $osvers,
                    archname     => $archname,
                    url          => "http://nntp.x.perl.org/group/perl.cpan.testers/$id",
                    csspatch     => $perl =~ /patch/ ? 'patch' : 'regular',
                    cssperl      => $perl =~ /^5.(7|9|11)/ ? 'perldev' : 'perlfull',
                };
                push @reports, $report;

                $summary->{ $report->{status} }++;
                $summary->{ 'ALL' }++;
            }

            push @distributions,
                {
                distribution => $distribution,
                version      => $latest_version,
                reports      => \@reports,
                summary      => $summary,
                csscurrent   => $self->oncpan->listed($distribution,$latest_version) ? 'oncpan' : 'backpan',
                cssrelease   => $latest_version =~ /_/ ? 'develrel' : 'official',
                };
        }

        my $parms = {
            author         => $author,
            distributions  => \@distributions,
            now            => $now,
            testersversion => $VERSION,
        };

        my $destfile = file( $directory, 'author', $author . ".html" );
        print "Writing $destfile\n";
        $tt->process( 'author', $parms, $destfile->stringify )
            || die $tt->error;

        my @reports;
        foreach my $distribution (@distributions) {
            push @reports, @{ $distribution->{reports} };
        }
        @reports = sort { $b->{id} <=> $a->{id} } @reports;
        splice(@reports,RSS_LIMIT_AUTHOR);

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
    my $dbh       = $self->dbh;
    my $directory = $self->directory;
    my $last_id   = $self->_last_id;
    my $backpan   = $self->backpan;
    my $oncpan    = $self->oncpan;
    my $now       = DateTime->now;
    my $tt        = $self->tt;

    # we only want to update distributions that have had changes from our
    # last update
    my @distributions;

    if(@_) {
        @distributions = @_;
    } else {
        my $sth = $dbh->prepare(
            "SELECT DISTINCT(dist) FROM cpanstats WHERE id > $last_id");
        my $distribution;
        $sth->execute;
        $sth->bind_columns( \$distribution );
        while ( $sth->fetch ) {
            push @distributions, $distribution;
        }
    }

    print "Updating ".(scalar(@distributions))." distributions\n";

    # process distribution pages
    foreach my $distribution (sort @distributions) {
        next unless $distribution =~ /^[A-Za-z0-9][A-Za-z0-9-_]+$/;
        print "Processing $distribution\n";

        #print STDERR "DEBUG:dist=[$distribution]\n";

        my $action_sth = $dbh->prepare(
            "SELECT id, state, version, perl, osname, osvers, platform FROM cpanstats WHERE dist = ? AND state != 'cpan' ORDER BY version, id" );
        $action_sth->execute($distribution);
        my ( $id, $status, $version, $perl, $osname, $osvers, $archname );
        $action_sth->bind_columns(
            \$id,     \$status, \$version, \$perl,
            \$osname, \$osvers, \$archname
        );
        my @reports;
        while ( $action_sth->fetch ) {
            #print STDERR "DEBUG:report:id=[$id],status=[$status],version=[$version]\n";
            next unless $version;
            $perl = "5.004_05" if $perl eq "5.4.4"; # RT 15162
            my $report = {
                id           => $id,
                distribution => $distribution,
                status       => uc $status,
                version      => $version,
                perl         => $perl,
                osname       => $osname,
                osvers       => $osvers,
                archname     => $archname,
                url          => "http://nntp.x.perl.org/group/perl.cpan.testers/$id",
                csspatch     => $perl =~ /patch/ ? 'patch' : 'regular',
                cssperl      => $perl =~ /^5.(7|9|11)/ ? 'perldev' : 'perlfull',
            };
            push @reports, $report;
        }

        #print STDERR "DEBUG:count:".(scalar(@reports))."\n";

        my ( $summary, $byversion );
        foreach my $report (@reports) {
            $summary->{ $report->{version} }->{ $report->{status} }++;
            $summary->{ $report->{version} }->{ 'ALL' }++;
            push @{ $byversion->{ $report->{version} } }, $report;
        }

        foreach my $version ( keys %$byversion ) {
            my @reports = @{ $byversion->{$version} };
            $byversion->{$version}
                = [ sort { $b->{id} <=> $a->{id} } @reports ];
        }

        #print STDERR "BY  :versions:".(join(",",(keys %$byversion)))."\n";
        #print STDERR "CPAN:versions:".(join(",",($oncpan->versions($distribution))))."\n";
        #print STDERR "BACK:versions:".(join(",",(map {$_->version} $backpan->distributions($distribution))))."\n";

        # ensure we cover all known versions
        my %versions = map {$_ => 1}
                            keys %$byversion,
                            $oncpan->versions($distribution),
                            map {$_->version} $backpan->distributions($distribution);

        my @versions = sort {versioncmp($b,$a)} keys %versions;

        my %release;
        foreach my $version ( keys %versions ) {
            $release{$version}->{csscurrent} = $oncpan->listed($distribution,$version) ? 'oncpan' : 'backpan';
            $release{$version}->{cssrelease} = $version =~ /_/ ? 'develrel' : 'official';
        }

        #print STDERR "DEBUG:backpan:".(scalar(keys %versions))."\n";
        #print STDERR "DEBUG:versions:".(join(",",(@versions)))."\n";

        my ($stats,$oses);
        my $sth = $dbh->prepare(
            "SELECT perl, osname, count(*) FROM cpanstats WHERE dist = ? GROUP BY perl, osname" );
        $sth->execute($distribution);
        while ( my ( $perl, $osname, $count ) = $sth->fetchrow_array ) {
            # warn "$perl $osname $count\n";
            $stats->{$perl}->{$osname} = $count;
            $oses->{$osname} = 1;
        }

        my @stats_oses = sort keys %$oses;
        my @stats_perl = sort {versioncmp($a,$b)} keys %$stats;

        my $parms = {
            versions       => \@versions,
            summary        => $summary,
            release        => \%release,
            byversion      => $byversion,
            distribution   => $distribution,
            now            => $now,
            testersversion => $VERSION,
            stats_oses     => \@stats_oses,
            stats_perl     => \@stats_perl,
            stats          => $stats,
        };
        my $destfile = file( $directory, 'show', $distribution . ".html" );
        print "Writing $destfile\n";
        $tt->process( 'dist', $parms, $destfile->stringify )
            || die $tt->error;
        $destfile = file( $directory, 'show', $distribution . ".yaml" );
        print "Writing $destfile\n";
        overwrite_file( $destfile->stringify,
            _make_yaml_distribution( $distribution, \@reports ) );

        splice(@reports,RSS_LIMIT_AUTHOR);
        $destfile = file( $directory, 'show', $distribution . ".rss" );
        print "Writing $destfile\n";
        overwrite_file( $destfile->stringify,
            _make_rss_distribution( $distribution, \@reports ) );
        $destfile = file( $directory, 'show', $distribution . ".json" );
        print "Writing $destfile\n";
        overwrite_file( $destfile->stringify,
            _make_json_distribution( $distribution, \@reports ) );

        # distribution PASS stats
        $sth = $dbh->prepare(
            "SELECT perl, osname, version FROM cpanstats WHERE dist = ? AND state='pass'" );
        $sth->execute($distribution);
        while ( my ( $perl, $osname, $version ) = $sth->fetchrow_array ) {
            # warn "$perl $osname $version\n";
            $stats->{$perl}->{$osname} = $version   if(!$stats->{$perl}->{$osname} || versioncmp($version,$stats->{$perl}->{$osname}));
        }
        $destfile = file( $directory, 'stats', 'dist', $distribution . ".html" );
        print "Writing $destfile\n";
        $tt->process( 'stats-dist', $parms, $destfile->stringify )
            || die $tt->error;
    }
}

sub _write_stats {
    my $self      = shift;
    my $dbh       = $self->dbh;
    my $directory = $self->directory;
    my $tt        = $self->tt;
    my $now       = DateTime->now;

    my $dir = dir( $directory, 'stats' );
    mkpath("$dir");
    die $!  unless(-d "$dir");

    my $limit;    # set to a small number for debugging only
    my (%data,%perldata,%perls,%all_osnames,%dists,%perlos);

    my $sth = $dbh->prepare(
        "SELECT dist, version, perl, osname FROM cpanstats WHERE state = 'pass'");
    $sth->execute;
    no warnings( 'uninitialized', 'numeric' );
    my $cnt;
    while ( my ( $dist, $version, $perl, $osname ) = $sth->fetchrow_array() )
    {
        next if not $perl;
        next if $perl =~ / /;
        next if $perl =~ /^5\.7/;
        #next if $perl =~ /^5\.9/;

        next if $version =~ /[^\d.]/;
        $perl = "5.004_05" if $perl eq "5.4.4"; # RT 15162

        last if $limit and $cnt++ > $limit;
        $perldata{$perl}{$dist} = $version
            if $perldata{$perl}{$dist} < $version;
        $data{$dist}{$perl}{$osname} = $version
            if $data{$dist}{$perl}{$osname} < $version;
        $perls{$perl}{reports}++;
        $perls{$perl}{distros}{$dist}++;
        $perlos{$perl}{$osname}++;
        $all_osnames{$osname}++;
    }
    $sth->finish;

    my @versions = sort {versioncmp($b,$a)} keys %perls;
#        map {$_->{external}}
#        sort {$b->{internal} <=> $a->{internal}}
#        map {my $v = version->new($_); {internal => $v->numify, external => $_}} keys %perls;

    # page perl perl version cross referenced with platforms
    my %perl_osname_all;
    foreach my $perl ( @versions ) {
        my @data;
        my %oscounter;
        my %dist_for_perl;
        foreach my $dist ( sort keys %{ $perldata{$perl} } ) {
            my @osversion;
            foreach my $os ( sort keys %{ $perlos{$perl} } ) {
                if ( defined $data{$dist}{$perl}{$os} ) {
                    push @osversion, { ver => $data{$dist}{$perl}{$os} };
                    $oscounter{$os}++;
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
        foreach my $os ( sort keys %{ $perlos{$perl} } ) {
            if ( $oscounter{$os} ) {
                push @perl_osnames, { os => $os, cnt => $oscounter{$os} };
                $perl_osname_all{$os}{$perl} = $oscounter{$os};
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
        my @data;
        my @perl_osnames = map {{os => $_}} keys %perl_osname_all;

        foreach my $perl ( @versions ) {
            my @count;
            foreach my $os (keys %perl_osname_all) {
                push @count, { os => $os, count => $perl_osname_all{$os}{$perl} };
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
    foreach my $perl ( @versions ) {
        my @data;
        my $cnt;
        foreach my $dist ( sort keys %{ $perldata{$perl} } ) {
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
    foreach my $p ( @versions ) {
        unshift @perls,
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
}

sub _write_recent {
    my $self      = shift;
    my $dbh       = $self->dbh;
    my $directory = $self->directory;
    my $now       = DateTime->now;
    my $tt        = $self->tt;

    # Get the last id
    my $last_id;
    my $last_sth = $dbh->prepare("SELECT max(id) FROM cpanstats");
    $last_sth->execute;
    $last_sth->bind_columns( \$last_id );
    $last_sth->fetch;

    # Recent reports
    my $recent_id = $last_id - RSS_LIMIT_RECENT;
    my @recent;
    my $recent_sth = $dbh->prepare(
        "SELECT id, state, dist, version, perl, osname, osvers, platform FROM cpanstats WHERE id > $recent_id AND state != 'cpan' ORDER BY id desc" );
    $recent_sth->execute();
    my ( $id, $status, $distribution, $version, $perl, $osname, $osvers,
        $archname );
    $recent_sth->bind_columns( \$id, \$status, \$distribution, \$version,
        \$perl, \$osname, \$osvers, \$archname );
    my @reports;
    while ( $recent_sth->fetch ) {
        next unless $version;
        my $report = {
            id           => $id,
            distribution => $distribution,
            status       => uc $status,
            version      => $version,
            perl         => $perl,
            osname       => $osname,
            osvers       => $osvers,
            archname     => $archname,
            url => "http://nntp.x.perl.org/group/perl.cpan.testers/$id",
        };
        push @recent, $report;
    }

    my $destfile = file( $directory, "recent.html" );
    print "Writing $destfile\n";
    my $parms = {
        now    => $now,
        recent => \@recent,
    };
    $tt->process( "recent", $parms, $destfile->stringify ) || die $tt->error;
    $destfile = file( $directory, "recent.rss" );
    overwrite_file( $destfile->stringify, _make_rss_recent( \@recent ) );

    # Save the last id
    $self->_last_id($last_id);
}

sub _write_index {
    my $self      = shift;
    my $dbh       = $self->dbh;
    my $directory = $self->directory;
    my $now       = DateTime->now;
    my $tt        = $self->tt;

    # Finally, the front page
    my $total_reports;
    my $sth = $dbh->prepare("SELECT count(*) FROM cpanstats WHERE state in ('pass','fail','na','unknown')");
    $sth->execute;
    $sth->bind_columns( \$total_reports );
    $sth->fetch;

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

    print STDERR "dbsize=[$parms->{dbsize}], dbzipsize=[$parms->{dbzipsize}], db=[$db]\n";

    $tt->process( "index", $parms, $destfile->stringify ) || die $tt->error;

    # now add all the redirects
    for my $dir (qw(author letter lettera show)) {
        my $src  = "src/index.html";
        my $dest = "$directory/$dir/index.html";
        copy( $src, $dest );
    }
}

sub _make_yaml_distribution {
    my ( $dist, $data ) = @_;

    my @yaml;

    foreach my $test (@$data) {
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

    foreach my $test (@$data) {
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

    foreach my $test (@$data) {
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
        title       => "Recent CPAN Testers reports",
        link        => "http://www.cpantesters.org/recent.html",
        description => "Recent CPAN Testers reports",
        syn         => {
            updatePeriod    => "daily",
            updateFrequency => "1",
            updateBase      => "1901-01-01T00:00+00:00",
        },
    );

    foreach my $test (@$data) {
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

    foreach my $report (@$reports) {
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

q("QA Automation, so much to answer for!");

__END__

=head1 NAME

CPAN::WWW::Testers - Present CPAN Testers data

=head1 SYNOPSIS

  my $t = CPAN::WWW::Testers->new();
  $t->directory($directory);
  if($download) { $t->download($download); }
  else          { $t->database($database); }
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

