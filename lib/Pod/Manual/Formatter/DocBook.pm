package Pod::Manual::Formatter::DocBook;

use Moose::Role;

use strict;
use warnings;

use autodie;

use File::ShareDir qw/ dist_dir /;

sub as_docbook {
    my $self = shift;
    my %arg = @_;

    $self->generate_toc;

    # make a copy of the dom so that we're not stuck with the PI
    my $dom = $self->parser->parse_string( $self->dom->toString );

    if ( my $css = $arg{css} ) {

        $css =~ s/^\+/ dist_dir( 'Pod-Manual' ) /e;

        my $pi = $dom->createPI( 'xml-stylesheet' 
                                    => qq{href="$css" type="text/css"} );
        $dom->insertBefore( $pi, $dom->firstChild );
    }

    return $dom->toString;
}

sub save_as_docbook {
    my $self = shift;
    my %arg = @_;

    $arg{file} or die;

    open my $fh, '>', $arg{file};

    print {$fh} $self->as_docbook;
}

sub generate_toc {
    my $self = shift;
    my $dom = $self->dom;

    # if there's already a toc, nuke it
    for ( $dom->findnodes( 'toc' ) ) {
        $_->unbindNode;
    }

    my $toc = $dom->createElement( 'toc' );
    my ( $bookinfo ) = $dom->findnodes( '/book/bookinfo' );
    $bookinfo->parentNode->insertAfter( $toc, $bookinfo );

    for my $chapter ( $dom->findnodes( '/book/chapter' ),
                      $dom->findnodes( '/book/appendix' ) ) {
        $self->add_entry_to_toc( 0, $toc, $chapter );
    }
}

1;

