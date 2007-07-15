use Test::More;

$ENV{ TEST_AUTHOR } and eval q{
    use Test::Pod;
    goto RUN_TESTS;
};

plan skip_all => $@
       ? 'Test::Pod not installed; skipping pod testing'
       : 'Set TEST_AUTHOR in your environment to enable these tests';

RUN_TESTS: 

all_pod_files_ok();
