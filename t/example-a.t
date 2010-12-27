use strict;
use warnings;

use Test::More;

use lib 't/lib';

use Pod::Manual;

my $manual = Pod::Manual->new;

$manual->title( 'An example' );
$manual->move_one_to_appendix( 'COPYRIGHT' );

$manual->ignore( 'IGNORE ME' );

$manual->add_module( 'A' );

my $docbook = $manual->as_docbook;

unlike $docbook => qr/IGNORE ME/, 'ignore()';

diag $docbook;

done_testing;
