package Pod::Manual::Formatter::LaTeX;

use strict;
use warnings;

use Moose::Role;

use Carp;
use XML::XPathScript;
use Pod::Manual::Docbook2LaTeX;

sub as_latex {
    my $self = shift;

    my $xps = XML::XPathScript->new;

    my $docbook = eval { $xps->transform( 
         $self->as_docbook => $Pod::Manual::Docbook2LaTeX::stylesheet
    ) } ;

    croak "couldn't convert to docbook: $@" if $@;

    return $docbook;
}

1;



