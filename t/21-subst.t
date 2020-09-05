#! perl

use Test::More tests => 1;
use Data::Properties;

my $cfg = Data::Properties->new;

$ENV{XXDATAPROPERTIESXX} = "env";

$cfg->parse_lines( [ split( /[\r\n]+/, <<'EOD' ) ] );
version = 1
nested {
  nothing = ${.version||xxx}
  version = 3
  # version at this level
  something = ${.version}
  # version at global level
  else = ${version}
}
XXDATAPROPERTIESXX = "local"
# This should be overridden by the env. var.
test1 = ${XXDATAPROPERTIESXX}
# But env var names are not case insensitive
test2 = ${xxdatapropertiesxx}
EOD

is( $cfg->dump, <<EOD );
# @ = version nested XXDATAPROPERTIESXX test1 test2
version = '1'
# nested.@ = nothing version something else
nested.nothing = 'xxx'
nested.version = '3'
nested.something = '3'
nested.else = '1'
XXDATAPROPERTIESXX = 'local'
test1 = 'env'
test2 = 'local'
EOD
