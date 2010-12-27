package Pod::Manual::Formatter::PDFLaTeX;

use strict;
use warnings;

use Moose::Role;
use Carp;

sub generate_pdf {
    my ( $self ) = @_;

   my $latex = $self->as_latex;

   open my $latex_fh, '>', 'manual.tex' 
       or croak "can't write to 'manual.tex': $!";
   print {$latex_fh} $latex;
   close $latex_fh;

    for ( 1..2 ) {       # two times to populate the toc
        system "pdflatex -interaction=batchmode manual.tex > /dev/null";
           # and croak "problem running pdflatex: $!";
    }

}

1;
