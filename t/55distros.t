#!perl

use strict;
use warnings;
$|=1;

use Test::More tests => 37;
use CPAN::WWW::Testers;
use JSON::Syck;
use XML::RSS;
use YAML;

my $s;
my $diz;
my @data = (
  { id=>'10', status=>'s1', distribution=>'d1', version=>'v1', perl=>'p1', osname=>'os1', osvers=>'ver1', archname=>'arch1' },
  { id=>'20', status=>'s2', distribution=>'d2', version=>'v2', perl=>'p2', osname=>'os2', osvers=>'ver2', archname=>'arch2' },
  { id=>'30', status=>'s3', distribution=>'d3', version=>'v3', perl=>'p3', osname=>'os3', osvers=>'ver3', archname=>'arch3' },
  { id=>'40', status=>'s4', distribution=>'d4', version=>'v4', perl=>'p4', osname=>'os4', osvers=>'ver4', archname=>'arch4' },
);
my $rss = XML::RSS->new();

$diz = '[distro]';
$s = CPAN::WWW::Testers::_make_rss_distribution('foo', \@data);
ok( $s, "$diz got rss" );
ok( $rss->parse($s), "$diz parsed rss" );
is( scalar(@{$rss->{items}}), 4, "$diz got items" );
is( $rss->{num_items}, 4, "$diz got items" );
is( $rss->{version}, '1.0', "$diz got version" );
is( $rss->{channel}->{title}, 'foo CPAN Testers Reports', "$diz got title" );
is( $rss->{channel}->{link}, 'http://www.cpantesters.org/show/foo.html', "$diz got link" );
is( $rss->{channel}->{description}, 'Automated test results for the foo distribution', "$diz got description" );

$diz = '[recent]';
$s = CPAN::WWW::Testers::_make_rss_recent( \@data );
ok( $s, "$diz got rss" );
ok( $rss->parse($s), "$diz parsed rss" );
is( scalar(@{$rss->{items}}), 4, "$diz got items" );
is( $rss->{num_items}, 4, "$diz got items" );
is( $rss->{version}, '1.0', "$diz got version" );
is( $rss->{channel}->{title}, 'Recent CPAN Testers Reports', "$diz got title" );
is( $rss->{channel}->{link}, 'http://www.cpantesters.org/recent.html', "$diz got link" );
is( $rss->{channel}->{description}, 'Recent CPAN Testers reports', "$diz got description" );

$diz = '[author]';
$s = CPAN::WWW::Testers::_make_rss_author( 'MrFoo', \@data, 'MyPrefix' );
ok( $s, "$diz got rss" );
ok( $rss->parse($s), "$diz parsed rss" );
is( scalar(@{$rss->{items}}), 4, "$diz got items" );
is( $rss->{num_items}, 4, "$diz got items" );
is( $rss->{version}, '1.0', "$diz got version" );
is( $rss->{channel}->{title}, 'MyPrefixReports for distributions by MrFoo', "$diz got title" );
is( $rss->{channel}->{link}, 'http://www.cpantesters.org/author/MrFoo.html', "$diz got link" );
is( $rss->{channel}->{description}, 'Reports for distributions by MrFoo', "$diz got description" );

$diz = '[nopass]';
$s = CPAN::WWW::Testers::_make_rss_author_nopass( 'MrFoo', \@data );
ok( $s, "$diz got rss" );
ok( $rss->parse($s), "$diz parsed rss" );
is( scalar(@{$rss->{items}}), 4, "$diz got items" );
is( $rss->{num_items}, 4, "$diz got items" );
is( $rss->{version}, '1.0', "$diz got version" );
is( $rss->{channel}->{title}, 'Failing Reports for distributions by MrFoo', "$diz got title" );
is( $rss->{channel}->{link}, 'http://www.cpantesters.org/author/MrFoo.html', "$diz got link" );
is( $rss->{channel}->{description}, 'Reports for distributions by MrFoo', "$diz got description" );

$diz = '[yaml]';
$s = CPAN::WWW::Testers::_make_yaml_distribution( 'MrFoo', \@data );
ok( $s, "$diz got yaml" );
my ($yaml, undef, undef) = Load($s);

$diz = '[json]';
$s = CPAN::WWW::Testers::_make_json_distribution( 'MrFoo', \@data );
ok( $s, "$diz got json" );
my $json = JSON::Syck::Load($s);

$diz= '[json+yaml]';
is_deeply( $yaml, $json, "$diz yaml=json" );
foreach my $row ( @data ){
        $row->{platform} = $row->{archname};
        $row->{action}   = $row->{status};
        $row->{distversion} = $row->{distribution} . '-' . $row->{version};
}
is_deeply( $yaml, \@data, "$diz yaml=data" );
is_deeply( $json, \@data, "$diz json=data" );

