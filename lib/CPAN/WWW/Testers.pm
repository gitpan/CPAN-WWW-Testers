package CPAN::WWW::Testers;
use DateTime;
use DB_File;
use DBI;
use Email::Simple;
use File::stat;
use File::Spec::Functions;
use Net::NNTP;
use Sort::Versions;
use Template;
use strict;
use vars qw($VERSION);
$VERSION = "0.10";

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
}

sub directory {
  my($self, $dir) = @_;
  if (defined $dir) {
    $self->{DIR} = $dir;
  } else {
    return $self->{DIR};
  }
}

sub generate {
  my $self = shift;

  my $stat = stat("testers.db");
  if ((not $stat) || time - $stat->mtime > 60*60) {
    print "More than an hour old, syncing testers data...\n";
    $self->download;
    $self->insert;
  }
  $self->write;
}

sub download {
  my $self = shift;

  my $t = tie my %testers,  'DB_File', "testers.db";

  my $nntp = Net::NNTP->new("nntp.perl.org") || die;
  my($num, $first, $last) = $nntp->group("perl.cpan.testers");

  my $count;
  foreach my $id ($first .. $last) {
    next if exists $testers{$id};
    print "[$id .. $last]\n";
    my $article = join "", @{$nntp->article($id) || []};
    $testers{$id} = $article;
    if (($count++ % 100) == 0) {
      print "[syncing]\n";
      $t->sync;
    }
  }
}


sub insert {
  my $self = shift;
  tie my %testers,  'DB_File', "testers.db" || die;

  my $db_exists = -f 'testers.sqldb';
  my $dbh = DBI->connect("dbi:SQLite:dbname=testers.sqldb","","", { RaiseError => 1});

  unless ($db_exists) {
    $dbh->do("
CREATE TABLE reports (
 id INTEGER, action, distversion, dist, version, platform,
 unique(id)
)");
    $dbh->do("CREATE INDEX action_idx on reports (action)");
    $dbh->do("CREATE INDEX dist_idx on reports (dist)");
    $dbh->do("CREATE INDEX version_idx on reports (version)");
    $dbh->do("CREATE INDEX distversion_idx on reports (version)");
    $dbh->do("CREATE INDEX platform_idx on reports (platform)");
  }

  $dbh->do("BEGIN TRANSACTION");
  my $sth = $dbh->prepare("REPLACE INTO reports VALUES (?, ?, ?, ?, ?, ?)");

  my $count = 0;
  while (my($id, $content) = each %testers) {
    print "$count...\n" if ($count++ % 1000) == 0;

    my $mail = Email::Simple->new($content);
    my $subject = $mail->header("Subject");
    next unless $subject;
    next if $subject =~ /::/; # it's supposed to be distribution
    my($action, $distversion, $platform) = split /\s/, $subject;
    next unless defined $action;
    next unless $action =~ /^PASS|FAIL|UNKNOWN|NA$/;
    my ($dist, $version) = $self->extract_name_version($distversion);
    next unless $version;
    $sth->execute($id, $action, $distversion, $dist, $version, $platform);
  }
  $dbh->do("COMMIT");
}

# from TUCS, coded by gbarr
sub extract_name_version {
  my($self, $file) = @_;

  my ($dist, $version) = $file =~ /^
    ((?:[-+.]*(?:[A-Za-z0-9]+|(?<=\D)_|_(?=\D))*
      (?:
   [A-Za-z](?=[^A-Za-z]|$)
   |
   \d(?=-)
     )(?<![._-][vV])
    )+)(.*)
  $/xs or return ($file);

  $version = $1
    if !length $version and $dist =~ s/-(\d+\w)$//;

  $version = $1 . $version
    if $version =~ /^\d+$/ and $dist =~ s/-(\w+)$//;

     if ($version =~ /\d\.\d/) {
    $version =~ s/^[-_.]+//;
  }
  else {
    $version =~ s/^[-_]+//;
  }
  return ($dist, $version);
}

sub write {
  my $self = shift;
  my $directory = $self->directory;
  my $now = DateTime->now;

  my $dbh = DBI->connect("dbi:SQLite:dbname=testers.sqldb","","", { RaiseError => 1});
  tie my %testers,  'DB_File', "testers.db" || die;

  my $tt = Template->new({
#    POST_CHOMP => 1,
#    PRE_CHOMP => 1,
#    TRIM => 1,
    EVAL_PERL => 1 ,
    INCLUDE_PATH => ['.', 'lib', 'src'],
    PROCESS => 'layout',
  });

  mkdir catfile($directory, 'report') || die $!;
  
  while (my($id, $content) = each %testers) {
    my $destfile = catfile($directory, 'report', $id . ".html");
    next if -f $destfile;
    my $mail = Email::Simple->new($content);
    my $parms = {
      id => $id,
      mail => $mail,
      now => $now,
    };
    print "Writing $destfile\n";
    $tt->process("report", $parms, $destfile) || die $tt->error;
  }

  mkdir catfile($directory, 'letter') || die $!;

  foreach my $letter ('A'..'Z') {
    my $dist;
    my $sth = $dbh->prepare("SELECT DISTINCT(dist) FROM reports where dist like ?");
    $sth->execute("$letter%");
    $sth->bind_columns(\$dist);
    my @dists;
    while ($sth->fetch) {
      push @dists, $dist;
    }
    my $parms = {
      letter => $letter,
      dists  => \@dists,
      now => $now,
    };
    my $destfile = catfile($directory, 'letter', $letter . ".html");
    print "Writing $destfile\n";
    $tt->process("letter", $parms, $destfile) || die $tt->error;
  }

  my $dist_sth = $dbh->prepare("SELECT DISTINCT(dist) FROM reports order by dist");
  my $dist;
  $dist_sth->execute;
  $dist_sth->bind_columns(\$dist);
  while ($dist_sth->fetch) {
    next unless $dist =~ /^[A-Za-z0-9][A-Za-z0-9-]+$/;
#next unless $dist =~ /^DBI/;

    my $action_sth = $dbh->prepare("SELECT id, action, version, distversion, platform FROM reports WHERE dist = ? order by id");
    $action_sth->execute($dist);
    my($id, $action, $version, $distversion, $platform);
    $action_sth->bind_columns(\$id, \$action, \$version, \$distversion, \$platform);
    my $data;
    while ($action_sth->fetch) {
      next unless $version;
      push @{$data->{$version}}, {
        id => $id,
        action => $action,
        version => $version,
        distversion => $distversion,
        platform => $platform,
      };
    }
    my $versions = [sort {versioncmp($b->[0]->{version}, $a->[0]->{version})} values %$data];
    my $parms = {
      versions => $versions,
      dist  => $dist,
      now => $now,
    };
    my $destfile = catfile($directory, 'show', $dist . ".html");
    print "Writing $destfile\n";
    $tt->process("dist", $parms, $destfile) || die $tt->error;
#use YAML; print Dump($versions); exit;
  }

  # Finally, the front page
  my $destfile = catfile($directory, "index.html");
  print "Writing $destfile\n";
  my $parms = {
    now => $now,
    letters => ['A' .. 'Z'],
  };
  $tt->process("index", $parms, $destfile) || die $tt->error;
}

1;

__END__

=head1 NAME

CPAN::WWW::Testers - Download and present CPAN Testers data

=head1 DESCRIPTION

The distribution can download and present CPAN Testers data.
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

=head1 AUTHOR

Leon Brocard <leon@astray.com>

=head1 LICENSE

This code is distributed under the same license as Perl.

