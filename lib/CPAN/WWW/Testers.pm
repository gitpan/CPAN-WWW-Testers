package CPAN::WWW::Testers;
use DateTime;
use DBI;
use File::Copy;
use File::stat;
use File::Spec::Functions;
use File::Slurp;
use LWP::Simple;
use Template;
use YAML;
use strict;
use vars qw($VERSION);
use version;
$VERSION = "0.21";

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

  $self->download;
  $self->write;
}

sub download {
  my $self = shift;
  
  my $url = "http://testers.astray.com/testers.db";
  my $file = catdir($self->directory, "testers.db");
  mirror($url, $file);
}

sub write {
  my $self = shift;
  my $directory = $self->directory;
  my $now = DateTime->now;

  my $db = catfile($self->directory, "testers.db");
  my $dbh = DBI->connect("dbi:SQLite:dbname=$db","","", { RaiseError => 1});

  my $tt = Template->new({
#    POST_CHOMP => 1,
#    PRE_CHOMP => 1,
#    TRIM => 1,
    EVAL_PERL => 1 ,
    INCLUDE_PATH => ['.', 'lib', 'src'],
    PROCESS => 'layout',
    FILTERS => {
      'striphtml' => sub {
         my $text = shift;
         $text =~ s/<.+?>//g;
         return $text;
      },
    },
  });

  my $stylesrc = catfile('src', 'style.css');
  my $styledest = catfile($directory, 'style.css');
  copy($stylesrc, $styledest);

  mkdir catfile($directory, 'letter') || die $!;

  foreach my $letter ('A'..'Z') {
    my $dist;
    my $sth = $dbh->prepare("SELECT DISTINCT(dist) FROM reports where dist like ?");
    $sth->execute("$letter%");
    $sth->bind_columns(\$dist);
    my @dists;
    while ($sth->fetch) {
      next unless $dist =~ /^[A-Za-z0-9][A-Za-z0-9-_]+$/;
      push @dists, $dist;
    }
    my $parms = {
      letter => $letter,
      dists  => \@dists,
      now => $now,
      testersversion => $VERSION,
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
    next unless $dist =~ /^[A-Za-z0-9][A-Za-z0-9-_]+$/;
#next unless $dist =~ /^Acme-Colour$/;

    my $action_sth = $dbh->prepare("SELECT id, action, version, distversion, platform FROM reports WHERE dist = ? order by id");
    $action_sth->execute($dist);
    my($id, $action, $version, $distversion, $platform);
    $action_sth->bind_columns(\$id, \$action, \$version, \$distversion, \$platform);
    my($data, @yaml);
    while ($action_sth->fetch) {
      next unless $version;
      my $thing = {
        id => $id,
        action => $action,
        version => $version,
        distversion => $distversion,
        platform => $platform,
      };
      push @{$data->{$version}}, $thing;
      push @yaml, $thing;
    }
    my $versions = [sort {
      my($versiona, $versionb) = (0, 0);
      eval {
	$versiona = version->new($a->[0]->{version});
	$versionb = version->new($b->[0]->{version});
      };
      $versionb <=> $versiona;
      } values %$data];
    my $parms = {
      versions => $versions,
      dist  => $dist,
      now => $now,
      testersversion => $VERSION,
    };
    my $destfile = catfile($directory, 'show', $dist . ".html");
    print "Writing $destfile\n";
    $tt->process("dist", $parms, $destfile) || die $tt->error;
    $destfile = catfile($directory, 'show', $dist . ".yaml");
    print "Writing $destfile\n";
    overwrite_file($destfile, Dump(\@yaml));
  }

  # Finally, the front page

  my $total_reports;
  my $sth = $dbh->prepare("SELECT count(*) from reports");
  $sth->execute;
  $sth->bind_columns(\$total_reports);
  $sth->fetch;

  my $destfile = catfile($directory, "index.html");
  print "Writing $destfile\n";
  my $parms = {
    now => $now,
    letters => ['A' .. 'Z'],
    total_reports => $total_reports,
  };
  $tt->process("index", $parms, $destfile) || die $tt->error;
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

=head1 Rewrite magic

If you want to remain compatible with the URL scheme used on
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

