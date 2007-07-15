use strict;
use warnings;

use Test::More tests => 7;

BEGIN { use_ok( 'Pod::Manual' ); }


diag( "Testing Pod::Manual $Pod::Manual::VERSION" );

# first let's test that the methods are there
can_ok 'Pod::Manual' => qw/ new add_chapter save_as_pdf as_docbook /;

my $manual = Pod::Manual->new({ title => 'The Manual Title',
                                ignore_sections => 'BUGS AND LIMITATIONS' });

$manual->add_chapter( 'Pod::Manual' );

my $pdf_file = 't/manual.pdf';

SKIP: {
    skip 'requires "pdflatex"', 2 if system 'pdflatex -h';

    ok $manual->save_as_pdf( $pdf_file ), 'save_as_pdf()';
    ok -e $pdf_file, 'pdf file exists';
    unlink $pdf_file;
}

my $docbook = $manual->as_docbook;

like $docbook => qr/The Manual Title/, 'new({ title => ... })';
unlike $docbook => qr/BUGS AND LIMITATIONS/, 'new({ ignore_sections => ... })';

unlike $docbook => qr/xml-stylesheet.*<docbook>/, 'as_docbook() without css';


