use strict;
use warnings;

use Test::More tests => 3;                      # last test to print

like run_podmanual( 'Pod::Manual' ),
    qr/<\?xml/,
    'podmanual finds modules';

like run_podmanual( './script/podmanual' ),
    qr/<\?xml/,
    'podmanual finds files';

like run_podmanual( '-title' => 'Foo', 'Pod::Manual' ),
    qr/<title>Foo/,
    'option -title';

# run_podmanual( '-pdf' => 'test.pdf', 'Pod::Manual' );
# ok -f 'test.pdf', 'can create pdfs';


### utility functions ######################################

sub run_podmanual {
    my $args = join ' ', @_;
    return `$^X ./script/podmanual $args`;
}

