#! perl

use Test::More tests => 3;
use Data::Properties;

my $cfg = Data::Properties->new;

$cfg->set_property( "version", 1 );
$cfg->parse_lines( [ 'vv = ${version:2}' ] );
is( $cfg->get_property("vv"), 1, "v1" );
$cfg->parse_lines( [ 'vv = ${vercsion:2}' ] );
is( $cfg->get_property("vv"), 2, "v2" );
$cfg->parse_lines( [ 'vv = ${vercsion:2:3}' ] );
is( $cfg->get_property("vv"), '2:3', "v3" );
