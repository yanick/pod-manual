package Pod::Manual::Formatter::PDFPrince;

use strict;
use warnings;

use Carp;
use File::ShareDir qw/ dist_file /;

use Moose::Role;

sub generate_pdf {
    my ( $self, $filename ) = @_;

    my $docbook = $self->as_docbook( css =>  
            dist_file( 'Pod-Manual', 'docbook.css' )
        );

    open my $db_fh, '>', 'manual.docbook'
        or croak "can't open file 'manual.docbook' for writing: $!";

    print $db_fh $docbook;
    close $db_fh;

    system 'prince', 'manual.docbook', '-o', 'manual.pdf';
}


1;
