#!/usr/bin/perl 

package Moose::PodManual;

use strict;
use warnings;

use Moose;
use Pod::Manual;

extends 'Pod::Manual';

my $manual = __PACKAGE__->master;

$manual->title( 'Moose' );

$manual->ignore([ 'FOO' ]);

$manual->move_one_to_appendix([ 'COPYRIGHT AND LICENSE' ]);

$manual->add_module([qw/
      Moose::Intro
      Moose::Manual
      Moose::Manual::Concepts
      Moose::Manual::Classes
      Moose::Manual::Attributes
      Moose::Manual::Delegation
      Moose::Manual::Construction
      Moose::Manual::MethodModifiers
      Moose::Manual::Roles
      Moose::Manual::Types
      Moose::Manual::MOP
      Moose::Manual::MooseX
      Moose::Manual::BestPractices
      /]);

$manual;

__END__

=pod

=cut

#print $manual->as_docbook( directory => 'moose', file => 'moose.docbook', css => 'default' );

#use Pod::Manual::Formatter::PDFLaTeX;
use Pod::Manual::Formatter::PDFPrince;
#use Pod::Manual::Formatter::LaTeX;

Pod::Manual::Formatter::PDFPrince->meta->apply( $manual );
#Pod::Manual::Formatter::LaTeX->meta->apply( $manual );

print $manual->as_docbook;


#print $manual->save_as_pdf( 'moose.pdf' );

#podmanual --formatter=PDFPrince --as=pdf --output=foo.pdf
