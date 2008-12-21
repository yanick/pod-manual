use strict;
use warnings;

BEGIN {
    eval q{ 
        use Test::Class::Load 't/lib';  
        exit;
    };
}

eval q{ use Test::More skip_all => 'Test::Class::Load required to run test' };


