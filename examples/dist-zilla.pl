#!/usr/bin/perl 

package Dist::Zilla::Plugins::PodManual;

use strict;
use warnings;

use Moose;

extends 'Pod::Manual';

use Module::Pluggable search_path => ['Dist::Zilla::Plugin'];


my $manual = __PACKAGE__->master;

$manual->title( 'Dist::Zilla Plugins' );

$manual->ignore([ 'VERSION' ]);

$manual->move_one_to_appendix([ 'COPYRIGHT AND LICENSE' ]);

$manual->add_module( [ $manual->plugins ] );

$manual;

print $manual->as_docbook( css => '+/prince.css' );

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
