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
__PACKAGE__->mk_accessors(qw(directory database last_id));
$VERSION = "0.26";

sub generate {
  my $self = shift;

  $self->download;
  $self->write;
}

sub _last_id {
  my($self, $id) = @_;
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
  my $self      = shift;
  my $directory = $self->directory;
  my $now       = DateTime->now;

  my $last_id = $self->_last_id;

  my $backpan = Parse::BACKPAN::Packages->new();

  my $db = file($self->database, "testers.db");
  my $dbh = DBI->connect("dbi:SQLite:dbname=$db", '', '', { RaiseError => 1 });

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

  my $stylesrc = file('src', 'style.css');
  my $styledest = file($directory, 'style.css');
  copy($stylesrc, $styledest);

  ## process alphabetic pages

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
    #   last;
  }

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

    #next unless $distribution =~ /^Acme-Colour$/;

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
    overwrite_file($destfile->stringify, make_yaml($distribution, \@reports));
    $destfile = file($directory, 'show', $distribution . ".rss");
    print "Writing $destfile\n";
    overwrite_file($destfile->stringify, make_rss($distribution, \@reports));
  }

  # Save the last id
  my $last_sth = $dbh->prepare("SELECT max(id) FROM reports");
  $last_sth->execute;
  $last_sth->bind_columns(\$last_id);
  $last_sth->fetch;
  $self->_last_id($last_id);

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

sub make_yaml {
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

sub make_rss {
  my ($dist, $data) = @_;
  my $rss = XML::RSS->new(version => '1.0');

  $rss->channel(
    title       => "Smoking for $dist",
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

1;

__END__

=head1 NAME

CPAN::WWW::Testers - Present CPAN Testers data

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

=item * make_rss

Creates the RSS file for use by RSS readers.

=item * make_yaml

Creates the YAML file for use by CPANPLUS.

=back

=head1 Rewrite magic

If you want to remain compatible with the URL scheme used on the old
search.cpan.org, you can use the following mod_rewrite magic with
Apache 1 or 2:

  # Try and keep the same URL scheme as search.cpan.org:
  # This rewrites
  # /search?request=dist&dist=Cache-Mmap
  # to
  # /show/Cache-Mmap.html
  RewriteEngine On
  ReWriteRule ^/search$  /search_%{QUERY_STRING}
  RewriteRule   ^/search_request=dist&dist=(.*)$  /show/$1.html

=head1 SEE ALSO

CPAN::WWW::Testers::Generator

=head1 AUTHOR

Leon Brocard <leon@astray.com>

=head1 LICENSE

This code is distributed under the same license as Perl.

