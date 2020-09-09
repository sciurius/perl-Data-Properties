#! perl

use Test::More tests => 2;
use Data::Properties;

my $cfg = Data::Properties->new;

$cfg->parse_lines( [ split( /[\r\n]+/, <<'EOD' ) ], '', 'base' );
a = 1
b = 2
nested {
  0 {
      c = 3
    }
  1 = 5
  2 = 6
}
EOD

is_deeply( $cfg->data,
	   { base => {
		     a => 1,
		     b => 2,
		     nested => [
				{
				 c => 3,
				},
				5,
				6,
			       ],
		    },
	   }
);

$cfg = Data::Properties->new;

$cfg->parse_lines( [ split( /[\r\n]+/, <<'EOD' ) ], '<data>', 'base' );
a = 1
b = 2
nested [
  {
      c = 3
  }
  5
  6
]
EOD

is_deeply( $cfg->data,
	   { base => {
		     a => 1,
		     b => 2,
		     nested => [
				{
				 c => 3,
				},
				5,
				6,
			       ],
		    },
	   }
);
