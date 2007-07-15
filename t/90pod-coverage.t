use strict;
use warnings;

use Test::More;

$ENV{ TEST_AUTHOR } and eval q{
    use Test::Pod::Coverage;
    goto RUN_TESTS;
};

plan skip_all => $@
       ? 'Test::Pod::Coverage not installed; skipping pod coverage testing'
       : 'Set TEST_AUTHOR in your environment to enable these tests';

RUN_TESTS: 

all_pod_coverage_ok();
