package Pod::Manual;

use Object::InsideOut;

use warnings;
no warnings qw/ uninitialized /;
use strict;
use Carp;

use Cwd;
use XML::LibXML;
use Pod::XML;
use Pod::2::DocBook;
use Pod::Find qw/ pod_where /;
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use List::MoreUtils qw/ any /;
use Params::Validate;

our $VERSION = '0.08_01';

my @parser_of        :Field;
my @dom_of           :Field;
my @appendix_of      :Field;
my @root_of          :Field;
my @ignore_sections  :Field
                     :Set(set_ignore)
                     :Arg(Name => 'ignore_sections', Type => 'array')
                     ;
my @appendix_sections :Field
                      :Args(Name => 'appendix_sections', Type => 'array')
                      :Set(set_appendix_sections)
                      ;
my @title            :Field
                     :Arg(title)
                     :Get(get_title);
my @unique_id        :Field;
my @pdf_generator    :Field 
                     :Arg(Name => 'pdf_generator', Default => 'latex', Pre => sub { lc $_[4] if $_[4]} )
                     :Std(Name => 'pdf_generator', Pre => sub { lc $_[4] } )
                     :Type(sub { grep { $_[0] eq $_ } qw/ prince latex / } )
                     ;
my @prince_css       :Field
                     :Arg('prince_css')
                     :Set(set_prince_css)
                     ;


### Special accessors ##########################################

sub get_appendix_sections {
    my $self = shift;
    return $appendix_sections[ $$self ] ? @{ $appendix_sections[ $$self ] }
                                       : ()
                                       ;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub get_ignore_sections {
    my $self = shift;

    return unless $ignore_sections[ $$self ];

    return @{ $ignore_sections[ $$self ] };
}

sub get_prince_css {
    my $self = shift;

    unless ( $prince_css[$$self] ) {

        # try to find the stylesheet
                                                    #<<< perltidy off
        my ($css) = grep { -f $_ }
                    map  { $_ . '/lib/prince/style/docbook.css' } 
                         qw# /usr /usr/local #;
                                                    #>>>

        $self->set_prince_css($css) if $css;
    }

    return $prince_css[$$self];
}

sub unique_id {
    return ++$unique_id[ ${$_[0]} ];
}

sub _init :Init {
    my $self = shift;
    my $args_ref = shift;

    my $parser = $parser_of[ $$self ] = XML::LibXML->new;

    $dom_of[ $$self ] = $parser->parse_string(
        '<book><bookinfo><title>' 
            . $self->get_title 
            . '</title></bookinfo></book>' 
    );

    $dom_of[ $$self ]->setEncoding( 'iso-8859-1' );

    $root_of[ $$self ] = $dom_of[ $$self ]->documentElement;

    $appendix_of[ $$self ] = undef;

}

sub set_title {
    my( $self, $title ) = @_;

    $title[ $$self ] = $title;

    return unless $dom_of[ $$self ];

    my $title_node = $dom_of[ $$self ]->findnodes( '/book/bookinfo/title')
                                      ->[0];
    # remove any possible title already there
    $title_node->removeChild( $_ ) for $title_node->childNodes;

    $title_node->appendText( $title );

    return;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub _find_module_pod {
    my $self = shift;
    my $module = shift;

    my $file_location = pod_where( { -inc => 1 }, $module )
        or die "couldn't find pod for module $module\n";

    local $/ = undef;
    open my $pod_fh, '<', $file_location 
        or die "can't open pod file $file_location: $!";

    return <$pod_fh>;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub _convert_pod_to_xml {
    my $self = shift;
    my $pod = shift;

    my $parser = Pod::2::DocBook->new ( doctype => 'chapter',);

    my $podxml;
    local *STDOUT;
    open STDOUT, '>', \$podxml;
    open my $input_fh, '<', \$pod;
    $parser->parse_from_filehandle( $input_fh );

    my $dom = eval { 
        $parser_of[ $$self ]->parse_string( $podxml ) 
    } or die "error while converting raw pod to xml for '$pod': $@";

    return $dom;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

    my $dom = eval { 
        $parser_of[ $$self ]->parse_string( $podxml ) 
    } or die "error while converting raw pod to xml for '$pod': $@";

    return $dom;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub add_chapters { 
    my $self = shift;
    my $options = 'HASH' eq ref $_[-1] ?   pop @_ : { };

    $self->add_chapter( $_ => $options ) for @_;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


sub add_chapter {
    my $self = shift;
    my $chapter = shift;

    my %option = validate( @_, {
            ignore_sections   => { default => [ $self->get_ignore_sections ] },
            appendix_sections => { default => [ $self->get_appendix_sections ] },
            set_title => 0,
        } );

    # simplify things later
    for my $i ( qw/ ignore_sections appendix_sections / ) {
        unless ( ref $option{ $i } ) {
            $option{$i} = [ $option{$i} ];
        }
    }

    my $podxml;
   
    # the chapter can be passed as various things
    if ( $chapter =~ /\n/ ) {   # it's pure pod
        $podxml = $self->_convert_pod_to_xml( $chapter );
    }
    elsif ( -f $chapter ) {     # it's a file
        local $/ = undef;
        open my $pod_fh, '<', $chapter 
            or die "can't open pod file $chapter: $!";
        $podxml = $self->_convert_pod_to_xml( <$pod_fh> );
    }
    else {                     # it's a module name
        $podxml = $self->_convert_pod_to_xml( 
                        $self->_find_module_pod( $chapter ) 
        );
    }

    my $dom = $dom_of[ $$self ];

    my $subdoc = $podxml->documentElement;
    #my $docbook = XML::XPathScript->new->transform( $podxml, 
    #        $Pod::Manual::PodXML2Docbook::stylesheet );

    #my $subdoc = eval { 
    #    XML::LibXML->new->parse_string( $docbook )->documentElement;
    #};

    if ( $@ ) {
        croak "chapter couldn't be converted to docbook: $@";
    }

    # give the chapter an id if there isn't
    unless ( $subdoc->getAttribute( 'id' ) ) {
        $subdoc->setAttribute( 'id' => 'chapter-'.$self->unique_id );
    }

    # fudge the id of the sections as well
    for my $s ( $subdoc->findnodes( '//section' ) ) {
        $s->setAttribute( id => 'section-'.$self->unique_id );
    }

    # fix the title
    if ( my ( $node ) = $subdoc->findnodes( 'section[title/text()="NAME"]' ) ) {
        my $title = $node->findvalue( 'para/text()' );
        my ( $title_node ) = $subdoc->findnodes( 'title' );
        $title_node->appendText( $title );
        if ( $title =~ /-/ ) {
            my ( $short ) = split /\s*-\s*/, $title;

            my $abbrev = $title_node->ownerDocument->createElement( 'titleabbrev' );
            $abbrev->appendText( $short );

            $title_node->appendChild( $abbrev );
        }
        $node->unbindNode;
    }

    # trash sections we don't want to see
    for my $section ( $subdoc->findnodes( 'section' ) ) {
        my $title = $section->findvalue( 'title/text()' );
        if ( any { $_ eq $title } @{ $option{ignore_sections} } ) {
            $section->unbindNode;
        }
    }

    # give abbreviations to all section titles
    for my $title ( $subdoc->findnodes( 'section/title' ) ) {
        next if $title->findnodes( 'titleabbrev' );  #already there
        my $abbrev = $title->ownerDocument->createElement( 'titleabbrev' );
        my $text = $title->toString;
        $title->appendChild( $abbrev );
        # FIXME
        $text =~ s/^<.*?>//;
        $text =~ s#</.*?>$##;
        if ( length( $text ) > 20 ) {
            # heuristics... *cross fingers*
            $text =~ s/\s+-.*$//;  # something - like this
            $text =~ s/\(.*?\)/( ... )/;
        }
        $abbrev->appendText( $text );
    }
    

    # use the title of that section if the 'doc_title' option is
    # used, or if there are no title given yet
    if ( $option{set_title} or not defined $self->get_title ) {
        my $title = $subdoc->findvalue( '/chapter/title/text()' );
        $title =~ s/\s*-.*//;  # remove desc after the '-'
        $self->set_title( $title ) if $title;
    }


    $dom->adoptNode( $subdoc );

    # if there is no appendix, it adds the chapter
    # at the end of the document
    $root_of[ $$self ]->insertBefore( $subdoc, $appendix_of[ $$self ] );

    for my $section_title ( @{ $option{appendix_sections} } ) {
        $self->_add_to_appendix( 
            grep { $_->findvalue( 'title/text()' ) eq $section_title }
                    $subdoc->findnodes( 'section' )
        );
    }

    return $self;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub as_dom {
    my $self = shift;
    return $dom_of[ $$self ];
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub as_docbook {
    my $self = shift;
    my %option = ref $_[0] eq 'HASH' ? %{ $_[0] } : () ;

    # generate the toc
    $self->generate_toc;

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

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub generate_toc {
    my $self = shift;
    my $dom = $dom_of[ $$self ];

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

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub tag_content {
    my $node;
    my $text;
    $text .= $_->toString for $node->childNodes;
    return $text;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub add_entry_to_toc {
    my ( $self, $level, $toc, $chapter ) = @_;

    my $tocchap = $chapter->ownerDocument->createElement( 
        $level == 0 ? 'tocchap' : 'toclevel'.$level 
    );
    $toc->addChild( $tocchap );

    my $title = $chapter->findvalue( 'title/titleabbrev/text()' ) 
              || $chapter->findvalue( 'title/text()' );

    my $tocentry = $chapter->ownerDocument->createElement( 'tocentry' );
    $tocchap->addChild( $tocentry );
    $tocentry->setAttribute( href => '#'.$chapter->getAttribute( 'id' ) );
    $tocentry->appendText( $title );

    for my $child ( $chapter->findnodes( 'section' ) ) {
        $self->add_entry_to_toc( $level + 1, $tocchap, $child );
    }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub as_latex {
    my $self = shift;

    eval {
        require XML::XPathScript;
        require Pod::Manual::Docbook2LaTeX;
    };

    croak 'as_latex() requires module XML::XPathScript to be installed'
        if $@;

    my $xps = XML::XPathScript->new;

    my $docbook = eval { $xps->transform( 
         $self->as_docbook => $Pod::Manual::Docbook2LaTeX::stylesheet
    ) } ;

    croak "couldn't convert to docbook: $@" if $@;

    return $docbook;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub generate_pdf_using_prince {
    my ( $self, $filename ) = @_;

    # if no css, we must create our own

    my $docbook = $self->as_docbook({ css =>  
            $self->local_prince_css( '.' ) });

    open my $db_fh, '>', 'manual.docbook'
        or croak "can't open file 'manual.docbook' for writing: $!";

    print $db_fh $docbook;
    close $db_fh;

    system 'prince', 'manual.docbook', '-o', 'manual.pdf';
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub generate_pdf_using_latex {
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

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub save_as_pdf {
    # TODO: add -force argument
    my $self = shift;

    my %option;

    if ( ref $_[-1] eq 'HASH' ) {
        my @a = %{$_[-1]};
        %option = validate( @a, { force => 0 } );
    }

    my $filename = shift 
        or croak 'save_as_pdf: requires a filename as an argument';

    $filename =~ s/\.pdf$// 
        or croak "save_as_pdf: filename '$filename'"
                ."must have suffix '.pdf'";

    if ( -f $filename.'.pdf' ) {
        if ( $option{force} ) {
            unlink $filename.'.pdf' 
                or die "can't remove file $filename.pdf: $!\n";
        }
        else {
            croak "file $filename.pdf already exist";
        }
    }

    my $original_dir = cwd();    # let's remember where we are

    my $tmpdir = tempdir( 'podmanualXXXX', CLEANUP => 1 );

    chdir $tmpdir or die "can't switch to dir $tmpdir: $!\n";

    #if ( $filename =~ s#^(.*)/## ) {
    #    chdir $1 or croak "can't chdir to $1: $!";
    #}

    if ( $self->get_pdf_generator eq 'latex' ) {
        $self->generate_pdf_using_latex( $filename, $original_dir );
    }
    elsif( $self->get_pdf_generator eq 'prince' ) {
        $self->generate_pdf_using_prince( $filename, $original_dir );
    }


    chdir $original_dir;

    copy( $tmpdir.'/manual.pdf' => $filename.'.pdf' ) or die $!;

    return 1;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub create_appendix {
    my $self = shift;

    return $appendix_of[ $$self ] if $appendix_of[ $$self ];

    my $appendix = $root_of[ $$self ]->new( 'appendix' );
    $appendix->setAttribute(  id => 'appendix-'.$self->unique_id );
    
    $root_of[ $$self ]->appendChild( $appendix );

    my $label = $appendix->new( 'title' );
    $label->appendText( 'Appendix' );
    $appendix->appendChild( $label );
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub get_appendix {
    my ( $self, $create_if_missing ) = @_;

    return $create_if_missing ? $self->create_appendix : $appendix_of[ $$self ];
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub _add_to_appendix {
    my ( $self, @nodes ) = @_;

    my $appendix = $self->get_appendix(1);

    $appendix->appendChild( $_ ) for @nodes;

    return $self;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub local_prince_css {
    my $self = shift;
    my $tempdir = shift;

    my $css;

    if ( my $prince = $self->get_prince_css ) {
        $css = qq{\@import '$prince';\n};
    }

    $css .= <<'END_CSS';
bookinfo title {
    font-size: 24pt;
    text-align: center;
}

tocentry { display: block;  }
tocentry::after { content: leader(".") target-counter(attr(href), page); }

toclevel1, toclevel2, toclevel3,
toclevel4, toclevel5, toclevel6 { 
    display: block;
    position: inherit; 
    padding-left: 20px; 
}

bookinfo > title {
    string-set: doctitle content();
}


title {
    string-set: currentSection content();
}

section > title {
    margin-top: 5px;
    font: 14pt;
}

chapter > section > title > titleabbrev,
appendix > section > title > titleabbrev
{ 
    display: block; 
    font: 10pt;
    flow: static(currentSection);
}

chapter > title > titleabbrev,
appendix > title > titleabbrev { 
    display: block; 
    font: 10pt;
    text-align: left;
    flow: static(currentChapter);
}

chapter > title > titleabbrev,
appendix > title > titleabbrev {
    string-set: currentChapter content();
}

@page:first { 
    @top-left { content: normal }
    @top-right { content: normal }
    @bottom-left { content: normal }
    @bottom-right { content: normal }
}

chapter > title::before {
    display: none;
}

chapter > title,
appendix > title {
    text-align: left;
}



emphasis[role="italic"] {
    font-style: italic;
}


@page { 
    @bottom-left {
        content: string(doctitle)
    }
    @bottom-right { 
        content: counter(page);
        font-style: italic
    }
    @top-right {
        content: flow(currentSection);
    }
    @top-left {
        content: flow(currentChapter);
    }
}

appendix {
    page-break-before: always;
    display: block;
}

appendix > title {
    font-size: 24pt;
    font-weight: bold;
}
END_CSS

    open my $css_fh, '>', 'docbook.css' 
        or croak "can't open file docbook.css for writing: $!";
    print $css_fh $css;

    return 'docbook.css';
}

'end of Pod::Manual'; # Magic true value required at end of module

__END__

=head1 NAME

Pod::Manual - Aggregates several PODs into a single manual

=head1 VERSION

This document describes Pod::Manual version 0.08

This module is still in early development and must be 
considered as alpha quality. Use with caution.


=head1 SYNOPSIS

    use Pod::Manual;

    my $manual = Pod::Manual->new( title => 'My Manual' );

    $manual->add_chapter( 'Some::Module' );
    $manual->add_chapter( 'Some::Other::Module' );

    $manual->save_as_pdf( 'manual.pdf' );


=head1 DESCRIPTION

The goal of B<Pod::Manual> is to gather the pod of several 
modules into a comprehensive manual.  Its primary objective
is to generate a document that can be printed, but it also
allow to output the document into other formats 
(e.g., docbook).

=head1 METHODS

=head2 new( I< %options > )

Creates a new manual. Several options can be passed to the 
constructor:

=over

=item title => $title

Sets the title of the manual to I<$title>.

=item ignore_sections => $section_name

=item ignore_sections => \@sections_name

When importing pods, discards any section having its title set as
I<$section_name> or listed
in I<@section_names>.

=item pdf_generator => $generator

Sets the pdf generation engine to be used.  Can be C<latex> 
(the default) or C<prince>.

=back

=head2 add_chapter( I<$module>, \%options )

    $manual->add_chapter( 'Pod::Manual', { set_title => 1 } );

Adds the pod of I<$module> to the manual.

=over

=item set_title

If true, uses the shortened title of the chapter as the title
of the manual. 

=back

=head2 add_chapters( I<@modules>, \%options )

    $manual->add_chapters( 'Some::Module', 'Some::Other::Module' )

Adds the pod of several modules to the manual.

=head2 as_docbook( { css => $filename } )

    print $manual->as_docbook({ css => 'stylesheet.css' });

Returns the manual in a docbook format. If the option I<css> 
is given, a 'xml-stylesheet' PI pointing to I<$filename> will
be added to the document. 

=head2 as_latex

    print $manual->as_latex;

Returns the manual in a LaTeX format.

=head2 save_as_pdf( $filename )

    $manual->save_as_pdf( '/path/to/document.pdf' );

Saves the manual as a pdf file. Several temporary
files will be created (and later on 
cleaned up) in the same directory. If any of those files
already exist, the method will abort.

Returns 1 if the pdf has been created, 0 otherwise.

B<NOTE>: this function requires to have 
TeTeX installed and I<pdflatex> accessible
via the I<$PATH>.

=head2 set_pdf_generator( $generator )

Sets the pdf generation engine to be used.  Can be C<latex> 
(the default) or C<prince>.

=head2 get_pdf_generator

Returns the pdf generation engine used by the object.


=head1 BUGS AND LIMITATIONS

As this is a preliminary release, a lot of both.

Please report any bugs or feature requests to
C<bug-pod-manual@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 REPOSITORY

Pod::Manual's development git repository can be accessed at
git://github.com/yanick/pod-manual.git

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
