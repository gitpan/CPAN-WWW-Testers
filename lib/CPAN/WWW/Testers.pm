package CPAN::WWW::Testers;
use DateTime;
use DBI;
use File::Copy;
use File::stat;
use File::Slurp;
use LWP::Simple;
use Parse::BACKPAN::Packages;
use Path::Class;
use Template;
use Storable qw(dclone);
use XML::RSS;
use YAML;
use strict;
use vars qw($VERSION);
use version;
use base qw(Class::Accessor::Chained::Fast);
__PACKAGE__->mk_accessors(qw(directory database dbh tt last_id backpan));
$VERSION = "0.28";

sub generate {
  my $self = shift;

  $self->download;
  $self->write;
}

sub _last_id {
  my ($self, $id) = @_;
  my $filename = file($self->directory, "last_id.txt")->stringify;

  overwrite_file($filename, 0) unless -f $filename;

  if ($id) {
    overwrite_file($filename, $id);
  } else {
    my $id = read_file($filename);
    return $id;
  }
}

sub download {
  my $self = shift;

  my $url = "http://testers.astray.com/testers.db";
  my $file = file($self->directory, "testers.db");
  mirror($url, $file);
  $self->database($self->directory);
}

sub write {
  my $self = shift;

  my $db = file($self->database, "testers.db");
  my $dbh = DBI->connect("dbi:SQLite:dbname=$db", '', '', { RaiseError => 1 });
  $self->dbh($dbh);

  my $backpan   = Parse::BACKPAN::Packages->new();
  $self->backpan($backpan);

  my $directory = $self->directory;

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

  $self->_write_alphabetic;
  $self->_write_distributions;
  
  $self->_write_authors_alphabetic;
  $self->_write_authors;

  $self->_write_recent;
  $self->_write_index;
}

sub _write_alphabetic {
  my $self      = shift;
  my $dbh       = $self->dbh;
  my $directory = $self->directory;
  my $now       = DateTime->now;
  my $tt        = $self->tt;

  my $stylesrc = file('src', 'style.css');
  my $styledest = file($directory, 'style.css');
  copy($stylesrc, $styledest);

  mkdir dir($directory, 'letter') || die $!;

  foreach my $letter ('A' .. 'Z') {
    my $dist;
    my $sth =
      $dbh->prepare(
      "SELECT DISTINCT(distribution) FROM reports where distribution like ?");
    $sth->execute("$letter%");
    $sth->bind_columns(\$dist);
    my @dists;
    while ($sth->fetch) {
      next unless $dist =~ /^[A-Za-z0-9][A-Za-z0-9-_]+$/;
      push @dists, $dist;
    }
    my $parms = {
      letter         => $letter,
      dists          => \@dists,
      now            => $now,
      testersversion => $VERSION,
    };
    my $destfile = file($directory, 'letter', $letter . ".html");
    print "Writing $destfile\n";
    $tt->process('letter', $parms, $destfile->stringify) || die $tt->error;
  }
}

sub _write_authors_alphabetic {
  my $self      = shift;
  my $directory = $self->directory;
  my $backpan   = $self->backpan;
  my $now       = DateTime->now;
  my $tt        = $self->tt;

  mkdir dir($directory, 'lettera') || die $!;

  my @all_authors = $backpan->authors;

  foreach my $letter ('A' .. 'Z') {
    my @authors = grep { /^$letter/ } @all_authors;
    my $parms = {
      letter         => $letter,
      authors          => \@authors,
      now            => $now,
      testersversion => $VERSION,
    };
    my $destfile = file($directory, 'lettera', $letter . ".html");
    print "Writing $destfile\n";
    $tt->process('lettera', $parms, $destfile->stringify) || die $tt->error;
  }
}

sub _write_authors {
  my $self      = shift;
  my $dbh       = $self->dbh;
  my $directory = $self->directory;
  my $last_id   = $self->_last_id;
  my $backpan   = $self->backpan;
  my $now       = DateTime->now;
  my $tt        = $self->tt;

  mkdir dir($directory, 'letter') || die $!;

  # we only want to update authors that have had changes from our
  # last update
  my $dist_sth =
    $dbh->prepare(
    "SELECT DISTINCT(distribution) FROM reports WHERE id > $last_id");
  my $distribution;
  $dist_sth->execute;
  $dist_sth->bind_columns(\$distribution);
  
  my $author_of;
  foreach my $author ($backpan->authors) {
    foreach my $distribution ($backpan->distributions_by($author)) {
      $author_of->{$distribution} = $author;
    }
  }
 
  my %authors;
  while ($dist_sth->fetch) {
    my $author = $author_of->{$distribution};
    next unless $author;
    $authors{$author}++;
  }
  my @authors = sort keys %authors;

  foreach my $author (@authors) {
    my @distributions;
    foreach my $distribution ($backpan->distributions_by($author)) {
      next unless $distribution =~ /^[A-Za-z0-9][A-Za-z0-9-_]+$/;

      my $latest_version;
      my $latest_sth = $dbh->prepare("select version from reports where distribution = '$distribution' order by id desc limit 1");
      $latest_sth->execute;
      $latest_sth->bind_columns(\$latest_version);
      $latest_sth->fetch;
  
      my $sth = $dbh->prepare("
SELECT id, status, perl, osname, osvers, archname FROM reports 
WHERE distribution = ? and version = ? order by id
");
      $sth->execute($distribution, $latest_version);
      my ($id, $status, $perl, $osname, $osvers, $archname);
      $sth->bind_columns(\$id, \$status, \$perl, \$osname, \$osvers,
        \$archname);
      my @reports;
      while ($sth->fetch) {
        my $report = {
          id           => $id,
          distribution => $distribution,
          status       => $status,
          version      => $latest_version,
          perl         => $perl,
          osname       => $osname,
          osvers       => $osvers,
          archname     => $archname,
          url          => "http://nntp.x.perl.org/group/perl.cpan.testers/$id",
        };
        push @reports, $report;
      }

      my ($summary);
      foreach my $report (@reports) {
        $summary->{ $report->{status} }++;
      }

      push @distributions,
        {
        distribution => $distribution,
        version      => $latest_version,
        reports      => \@reports,
        summary      => $summary,
        };
    }

    my $parms = {
      author         => $author,
      distributions  => \@distributions,
      now            => $now,
      testersversion => $VERSION,
    };

    my $destfile = file($directory, 'author', $author . ".html");
    print "Writing $destfile\n";
    $tt->process('author', $parms, $destfile->stringify) || die $tt->error;

    my @reports;
	  foreach my $distribution (@distributions) {
	    push @reports, @{$distribution->{reports}};
	  }
	  @reports = sort { $b->{id} <=> $a->{id} } @reports;

    $destfile = file($directory, 'author', $author . ".rss");
    print "Writing $destfile\n";
    overwrite_file($destfile->stringify, _make_rss_author($author, \@reports));
  }
}

sub _write_distributions {
  my $self      = shift;
  my $dbh       = $self->dbh;
  my $directory = $self->directory;
  my $last_id   = $self->_last_id;
  my $backpan   = $self->backpan;
  my $now       = DateTime->now;
  my $tt        = $self->tt;

  # we only want to update distributions that have had changes from our
  # last update
  my @distributions;
  my $dist_sth =
    $dbh->prepare(
    "SELECT DISTINCT(distribution) FROM reports WHERE id > $last_id");
  my $distribution;
  $dist_sth->execute;
  $dist_sth->bind_columns(\$distribution);
  while ($dist_sth->fetch) {
    push @distributions, $distribution;
  }
  @distributions = sort @distributions;

  # process distribution pages
  foreach my $distribution (@distributions) {
    next unless $distribution =~ /^[A-Za-z0-9][A-Za-z0-9-_]+$/;

    my $action_sth = $dbh->prepare("
SELECT id, status, version, perl, osname, osvers, archname FROM reports 
WHERE distribution = ? order by id
");
    $action_sth->execute($distribution);
    my ($id, $status, $version, $perl, $osname, $osvers, $archname);
    $action_sth->bind_columns(\$id, \$status, \$version, \$perl, \$osname,
      \$osvers, \$archname);
    my @reports;
    while ($action_sth->fetch) {
      next unless $version;
      my $report = {
        id           => $id,
        distribution => $distribution,
        status       => $status,
        version      => $version,
        perl         => $perl,
        osname       => $osname,
        osvers       => $osvers,
        archname     => $archname,
        url          => "http://nntp.x.perl.org/group/perl.cpan.testers/$id",
      };
      push @reports, $report;
    }

    my ($summary, $byversion);
    foreach my $report (@reports) {
      $summary->{ $report->{version} }->{ $report->{status} }++;
      push @{ $byversion->{ $report->{version} } }, $report;
    }

    foreach my $version (keys %$byversion) {
      my @reports = @{ $byversion->{$version} };
      $byversion->{$version} = [ sort { $b->{id} <=> $a->{id} } @reports ];
    }

    my @versions = map { $_->version } $backpan->distributions($distribution);

    my $parms = {
      versions       => \@versions,
      summary        => $summary,
      byversion      => $byversion,
      distribution   => $distribution,
      now            => $now,
      testersversion => $VERSION,
    };
    my $destfile = file($directory, 'show', $distribution . ".html");
    print "Writing $destfile\n";
    $tt->process('dist', $parms, $destfile->stringify) || die $tt->error;
    $destfile = file($directory, 'show', $distribution . ".yaml");
    print "Writing $destfile\n";
    overwrite_file($destfile->stringify, _make_yaml_distribution($distribution, \@reports));
    $destfile = file($directory, 'show', $distribution . ".rss");
    print "Writing $destfile\n";
    overwrite_file($destfile->stringify, _make_rss_distribution($distribution, \@reports));
  }
}

sub _write_recent {
  my $self      = shift;
  my $dbh       = $self->dbh;
  my $directory = $self->directory;
  my $now       = DateTime->now;
  my $tt        = $self->tt;

  # Get the last id
  my $last_id;
  my $last_sth = $dbh->prepare("SELECT max(id) FROM reports");
  $last_sth->execute;
  $last_sth->bind_columns(\$last_id);
  $last_sth->fetch;

  # Recent reports
  my $recent_id = $last_id - 200;
  my @recent;
  my $recent_sth = $dbh->prepare("
SELECT id, status, distribution, version, perl, osname, osvers, archname FROM reports 
WHERE id > $recent_id order by id desc
");
  $recent_sth->execute();
  my ($id, $status, $distribution, $version, $perl, $osname, $osvers,
    $archname);
  $recent_sth->bind_columns(\$id, \$status, \$distribution, \$version, \$perl,
    \$osname, \$osvers, \$archname);
  my @reports;
  while ($recent_sth->fetch) {
    next unless $version;
    my $report = {
      id           => $id,
      distribution => $distribution,
      status       => $status,
      version      => $version,
      perl         => $perl,
      osname       => $osname,
      osvers       => $osvers,
      archname     => $archname,
      url          => "http://nntp.x.perl.org/group/perl.cpan.testers/$id",
    };
    push @recent, $report;
  }

  my $destfile = file($directory, "recent.html");
  print "Writing $destfile\n";
  my $parms = {
    now    => $now,
    recent => \@recent,
  };
  $tt->process("recent", $parms, $destfile->stringify) || die $tt->error;
  $destfile = file($directory, "recent.rss");
  overwrite_file($destfile->stringify, _make_rss_recent(\@recent));

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
  my $sth = $dbh->prepare("SELECT count(*) from reports");
  $sth->execute;
  $sth->bind_columns(\$total_reports);
  $sth->fetch;

  my $destfile = file($directory, "index.html");
  print "Writing $destfile\n";
  my $parms = {
    now           => $now,
    letters       => [ 'A' .. 'Z' ],
    total_reports => $total_reports,
  };
  $tt->process("index", $parms, $destfile->stringify) || die $tt->error;
}

sub _make_yaml_distribution {
  my ($dist, $data) = @_;

  my @yaml;

  foreach my $test (@$data) {
    my $entry = dclone($test);
    $entry->{platform}    = $entry->{archname};
    $entry->{action}      = $entry->{status};
    $entry->{distversion} = $entry->{distribution} . '-' . $entry->{version};
    push @yaml, $entry;
  }
  return Dump(\@yaml);
}

sub _make_rss_distribution {
  my ($dist, $data) = @_;
  my $rss = XML::RSS->new(version => '1.0');

  $rss->channel(
    title       => "$dist CPAN Testers reports",
    link        => "http://testers.cpan.org/show/$dist.html",
    description => "Automated test results for the $dist distribution",
    syn         => {
      updatePeriod    => "daily",
      updateFrequency => "1",
      updateBase      => "1901-01-01T00:00+00:00",
    },
  );

  foreach my $test (@$data) {
    $rss->add_item(
      title => sprintf("%s %s-%s %s on %s %s (%s)",
        @{$test}
          {qw( status distribution version perl osname osvers archname )}),
      link => "http://nntp.x.perl.org/group/perl.cpan.testers/$test->{id}",
    );
  }

  return $rss->as_string;
}

sub _make_rss_recent {
  my ($data) = @_;
  my $rss = XML::RSS->new(version => '1.0');

  $rss->channel(
    title       => "Recent CPAN Testers reports",
    link        => "http://testers.cpan.org/recent.html",
    description => "Recent CPAN Testers reports",
    syn         => {
      updatePeriod    => "daily",
      updateFrequency => "1",
      updateBase      => "1901-01-01T00:00+00:00",
    },
  );

  foreach my $test (@$data) {
    $rss->add_item(
      title => sprintf("%s %s-%s %s on %s %s (%s)",
        @{$test}
          {qw( status distribution version perl osname osvers archname )}),
      link => "http://nntp.x.perl.org/group/perl.cpan.testers/$test->{id}",
    );
  }

  return $rss->as_string;
}

sub _make_rss_author {
  my ($author, $reports) = @_;
  my $rss = XML::RSS->new(version => '1.0');

  $rss->channel(
    title       => "Reports for distributions by $author",
    link        => "http://testers.cpan.org/author/$author.html",
    description => "Reports for distributions by $author",
    syn         => {
      updatePeriod    => "daily",
      updateFrequency => "1",
      updateBase      => "1901-01-01T00:00+00:00",
    },
  );

  foreach my $report (@$reports) {
    $rss->add_item(
      title => sprintf("%s %s-%s %s on %s %s (%s)",
        @{$report}
          {qw( status distribution version perl osname osvers archname )}),
      link => "http://nntp.x.perl.org/group/perl.cpan.testers/$report->{id}",
    );
  }

  return $rss->as_string;
}

1;

__END__

=head1 NAME

CPAN::WWW::Testers - Present CPAN Testers data

=head1 SYNOPSIS

  my $t = CPAN::WWW::Testers->new();
  $t->directory($directory);
  $t->generate;

=head1 DESCRIPTION

The distribution can present CPAN Testers data.
cpan-testers is a group which was initially setup by Graham Barr and
Chris Nandor. The objective of the group is to test as many of the
distributions on CPAN as possible, on as many platforms as possible.
The ultimate goal is to improve the portability of the distributions
on CPAN, and provide good feedback to the authors.

CPAN Testers is really a mailing list with a web interface,
testers.cpan.org. testers.cpan.org was painfully slow. I happened to
be doing metadata stuff for Module::CPANTS. This is the result. It's
alpha code, but using it anyone can host their CPAN Testers website.

Unpack the distribution and look at examples/generate.pl. Wait
patiently. Send patches and better design.

At the moment I am running the output of this at
http://testers.astray.com/

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
Note this also where the local copy of testers.db will reside.

=item * generate

Initiates the $obj->download and $obj->write method calls.

=item * download

Downloads the latest article updates from the NNTP server for the
cpan-testers newgroup. Articles are then stored in the news.db
SQLite database.

=item * database

Path to the SQLite database.

=item * write

Reads the local copy of the testers.db, and creates the alphabetic 
index, distribution and main index web pages, together with the
YAML and RSS pages for each distribution.

=back

=head1 SEE ALSO

CPAN::WWW::Testers::Generator

=head1 AUTHOR

Leon Brocard <leon@astray.com>

=head1 LICENSE

This code is distributed under the same license as Perl.

