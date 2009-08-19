use strict;
use warnings;

use Test::More;                      # last test to print
use Pod::Manual;

plan tests => 4;

eval {
    Pod::Manual->new( pdf_generator => 'foo' ) 
};

#isa_ok $@ => 'OIO::Args', 'invalid pdf_generator';

isa_ok( Pod::Manual->new( pdf_generator => $_ ), 'Pod::Manual',
    $_ ) for qw/ prince latex PRINCE LATEX /;




