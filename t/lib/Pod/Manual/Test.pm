package Pod::Manual::Test;
 
use strict;
use warnings;

use base 'Test::Class';

INIT { Test::Class->runtests }

1;
