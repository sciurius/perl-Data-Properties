#! perl

use Test::More tests => 2;
use Data::Properties;

my $cfg = Data::Properties->new;

$cfg->parse_lines( [ split( /[\r\n]+/, <<EOD ) ] );
version = 1
config.version = 2
nested {
  version = 3
  something = 4
}
EOD

is( $cfg->dump, <<EOD );
# @ = version config nested
version = '1'
config.version = '2'
# nested.@ = version something
nested.version = '3'
nested.something = '4'
EOD

is_deeply( $cfg->{_props},
	   { '@' => [
		     'version',
		     'config',
		     'nested',
		    ],
	     'config.@' => [
			    'version',
			   ],
	     'config.version' => 2,
	     'nested.@' => [
			    'version',
			    'something',
			   ],
	     'nested.something' => 4,
	     'nested.version' => 3,
	     version => 1,
	   } );

