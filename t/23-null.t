#! perl

use Test::More tests => 2;
use Data::Properties;

my $cfg = Data::Properties->new;

$cfg->parse_lines( [ split( /[\r\n]+/, <<'EOD' ) ] );
a = null
x =
c = a: ${a?|${a|value|empty}|undef}
d = x: ${x?|${x|value|empty}|undef}
EOD

is( $cfg->dump, <<EOD );
# @ = a x c d
x = ''
c = 'a: undef'
d = 'x: empty'
EOD

is_deeply( $cfg->{_props},
	   { '@' => [ qw( a x c d )],
	     a => undef,
	     c => 'a: undef',
	     d => 'x: empty',
	     x => '',
	   } );
