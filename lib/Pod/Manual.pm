package Pod::Manual;

use Object::InsideOut;

use warnings;
no warnings qw/ uninitialized /;
use strict;
use Carp;

use XML::LibXML;
use Pod::DocBook;
use Pod::XML;
use Pod::Find qw/ pod_where /;
use XML::XPathScript;
use Pod::Manual::PodXML2Docbook;
use Pod::Manual::Docbook2LaTeX;

use version; our $VERSION = qv('0.01');

my @parser_of   :Field;
my @dom_of      :Field;
my @appendix_of :Field;
my @root_of     :Field;

sub _init :Init {
    my $self = shift;
    my $args_ref = shift;

    my $parser = $parser_of[ $$self ] = XML::LibXML->new;

    $dom_of[ $$self ] = $parser->parse_string(
        '<book><bookinfo><title/></bookinfo></book>' 
    );

    $dom_of[ $$self ]->setEncoding( 'iso-8859-1' );

    $root_of[ $$self ] = $dom_of[ $$self ]->documentElement;

    $appendix_of[ $$self ] = undef;

    if ( my $title = $args_ref->{ title } ) {
        my( $node ) = $dom_of[ $$self ]->findnodes( '/book/bookinfo/title' );
        $node->appendText( $title );
    }

}

sub _get_podxml {
    my $self = shift;
    my $pod = shift;

    my $pod_location = pod_where( { -inc => 1 }, $pod );

    my $parser = Pod::XML->new;

    my $podxml;
    local *STDOUT;
    open STDOUT, '>', \$podxml;
    $parser->parse_from_file( $pod_location );
    close STDOUT;

    $podxml =~ s/xmlns=".*?"//;
    $podxml =~ s#]]></verbatim>\n<verbatim><!\[CDATA\[##g;

    my $dom = eval { $parser_of[ $$self ]->parse_string( $podxml ) 
    } or die "error while converting raw pod to xml: $@";

    return $dom;
}

sub add_chapters { 
    my $self = shift;
    my $options = 'HASH' eq ref $_[-1] ?  %{ pop @_ } : { };

    $self->add_chapter( $_ => $options ) for @_;
}

sub add_chapter {
    my $self = shift;
    my $chapter = shift;

    my $options = 'HASH' eq ref $_[-1] ? pop @_ : { };

    my $dom = $dom_of[ $$self ];

    my $podxml = $self->_get_podxml( $chapter ) 
        or croak "couldn't find pod for $chapter";

    my $docbook = XML::XPathScript->new->transform( $podxml, 
            $Pod::Manual::PodXML2Docbook::stylesheet );

    my $subdoc = eval { 
        XML::LibXML->new->parse_string( $docbook )->documentElement;
    };

    if ( $@ ) {
        croak "chapter couldn't be converted to docbook: $@";
    }

    $dom->adoptNode( $subdoc );

    # if there is no appendix, it adds the chapter
    # at the end of the document
    $root_of[ $$self ]->insertBefore( $subdoc, $appendix_of[ $$self ] );

    if ( my $list = $options->{move_to_appendix} ) {
        for my $section_title ( ref $list ? @{ $list  } : $list ) {
            $self->_add_to_appendix( 
                grep { $_->findvalue( 'title/text()' ) eq $section_title }
                     $subdoc->findnodes( 'section' )
            );
        }
    }

    return $self;
}

sub as_dom {
    my $self = shift;
    return $dom_of[ $$self ];
}

sub as_docbook {
    my $self = shift;
    my %option = ref $_[0] eq 'HASH' ? %{ $_[0] } : () ;

    my $dom = $dom_of[ $$self ];

    if ( my $css = $option{ css } ) {
        # make a copy of the dom so that we're not stuck with the PI
        $dom = $parser_of[ $$self ]->parse_string( $dom->toString );

        my $pi = $dom->createPI( 'xml-stylesheet' 
                                    => qq{href="$css" type="text/css"} );
        $dom->insertBefore( $pi, $dom->firstChild );
    }

    return $dom->toString;
}

sub as_pdf {
    my $self = shift;
    my $filename = shift or die;
    $filename .= '.tex';
    my $docbook = $self->as_docbook;
    my $xps = XML::XPathScript->new;

    my $latex = eval { $xps->transform( 
         $docbook => $Pod::Manual::Docbook2LaTeX::stylesheet
    ) } ;

   die $@ if $@;

   open my $latex_fh, '>', $filename or die $!;
   print {$latex_fh} $latex;
   close $latex_fh;

   for ( 1..2 ) {
    system 'pdflatex', $filename and die $!;
    }

}

sub _add_to_appendix {
    my ( $self, @nodes ) = @_;

    unless ( $appendix_of[ $$self ] ) {
        # create appendix
        $root_of[ $$self ]->appendChild( 
            $appendix_of[ $$self ] = $root_of[ $$self ]->new( 'appendix' )
        );
        my $label = $appendix_of[ $$self ]->new( 'label' );
        $label->appendText( 'Appendix' );
        $appendix_of[ $$self ]->appendChild( $label );
    }

    $appendix_of[ $$self ]->appendChild( $_ ) for @nodes;

    return $self;
}

1; # Magic true value required at end of module

__END__

=head1 NAME

Pod::Manual - Aggregates several PODs into a single manual


=head1 VERSION

This document describes Pod::Manual version 0.1

As you can guess from the very low version number, this release
is alpha quality. Use with caution.


=head1 SYNOPSIS

    use Pod::Manual;

    my $manual = Pod::Manual->new({ title => 'Pod::Manual' });

    $manual->add_chapter( 'Pod::Manual' );

    my $docbook = $manual->as_docbook;


=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Pod::Manual requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-pod-manual@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Yanick Champoux  C<< <yanick@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Yanick Champoux C<< <yanick@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
