use strict;
use warnings;

use Test::More;                      # last test to print
use Pod::Manual;
use Test::Exception;

plan tests => 5;


throws_ok { Pod::Manual->new( pdf_generator => 'foo' ) }
    'OIO::Args', 'invalid pdf_generator';

isa_ok( Pod::Manual->new( pdf_generator => $_ ), 'Pod::Manual',
    $_ ) for qw/ prince latex PRINCE LATEX /;




