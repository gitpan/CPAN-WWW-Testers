#!perl

use strict;
use warnings;
$|=1;

use Test::More tests => 12;
use lib 't';
use CWT_Testing;

ok( my $obj = CWT_Testing::getObj(), "got object" );

my $href;

$href = $obj->_get_distvers('MrFoo');
is_deeply( $href, {}, "[MrFoo] distvers" );

$href = $obj->_get_distvers('INGY');
is_deeply( $href, { 'Acme' => '1.11111' }, "[INGY] distvers" );

$href = $obj->_get_distvers('JBRYAN');
is_deeply( $href, {
          'AI-NeuralNet-BackProp' => '0.89',
          'AI-NeuralNet-Mesh' => '0.44'
}, "[JBRYAN] distvers" );


foreach my $row (
	# dist, ver, author, type
	[ 'Foo-Bar DNE', '1.23', undef, 1 ],
	[ 'Acme', '1.11', 'INGY', 0 ],
	[' Acme-Buffy', '1.5', undef, 1 ],
    ){
  my ($dist, $ver, $expectedAuthor, $expectedType) = @$row;
  my $s;
  my @pkg = ($dist, $ver);
  my $diz = sprintf '[%s-%s]', $dist, $ver;

  $s = $obj->_author_of(@pkg);
  is( $s, $expectedAuthor, "$diz author" );

  $s = $obj->_check_oncpan(@pkg);
  is( $s, $expectedType, "$diz type" );
}

my $aref = $obj->_mklist_authors;
ok( $aref, 'got authors' );
is_deeply( $aref, [
          'ADRIANWIT',
          'DRRHO',
          'GARU',
          'INGY',
          'ISHIGAKI',
          'JALDHAR',
          'JBRYAN',
          'JESSE',
          'JETEVE',
          'JHARDING',
          'JJORE',
          'LBROCARD',
          'SAPER',
          'VOISCHEV',
          'ZOFFIX',
],  "authors match" );


