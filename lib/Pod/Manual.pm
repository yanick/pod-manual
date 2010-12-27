package Pod::Manual;

use Moose;

use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
use MooseX::AttributeHelpers;

use Pod::Manual::Types qw/ ChapterType /;

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
use File::chdir;
use List::MoreUtils qw/ any /;
use Params::Validate;
use File::ShareDir ':ALL';

with 'Pod::Manual::Formatter::DocBook';

our $VERSION = '0.08_04';
#$File::Temp::KEEP_ALL = 1;  #save temp files while debugging.

has parser => ( is => 'ro', default => sub { XML::LibXML->new( expand_entities
=> 0 )} );
has dom => ( is => 'ro', 
    lazy => 1,
    default => sub {
       my $self = shift; 
        my $dom = $self->parser->parse_string(
        '<book><bookinfo><title>' 
            . $self->title 
            . '</title></bookinfo></book>' 
    );

        $dom->setEncoding( 'UTF-8' );
        $dom;
    });
has root => ( is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        $self->dom->documentElement;
    });
has title => ( 
    is => 'rw' ,
    isa => 'Str',
    trigger => sub {
        my( $self, $title ) = @_;

    my $title_node = $self->dom->findnodes( '/book/bookinfo/title')
                                      ->[0];
    # remove any possible title already there
    $title_node->removeChild( $_ ) for $title_node->childNodes;

    $title_node->appendText( $title );
    },
);
has unique_id => ( 
    is => 'ro',
    isa => 'Num',
    default => 1,
    );



after unique_id => sub {
        my $self = shift;
        $self->{unique_id}++;
};

has css => (
    is => 'rw',
    default =>  dist_file( 'Pod-Manual', 'docbook.css' ),
);

subtype 'ArrayRefOfStrs'
    => as 'ArrayRef[Str]';

coerce 'ArrayRefOfStrs'
    => from 'Str'
    => via { [ $_ ] };

has ignore => (
    is => 'rw',
    metaclass => 'Collection::Array',
    isa => 'ArrayRefOfStrs',
    coerce => 1,
    auto_deref => 1,
    default => sub { [] },
    provides => {
        find => '_find_ignore',    
    },
);

sub is_ignored {
    my $self = shift;
    my $section = shift;
    return $self->_find_ignore( sub { $section eq $_[0] } );
}

has move_one_to_appendix => (
    is => 'rw',
    metaclass => 'Collection::Array',
    isa => 'ArrayRefOfStrs',
    coerce => 1,
    auto_deref => 1,
    default => sub { [] },
    provides => {
        find => '_is_in_move_one_in_appendix',    
    },
);

sub is_in_move_one_in_appendix {
    my $self = shift;
    my $section = shift;
    return $self->_is_in_move_one_in_appendix( sub { $section eq $_[0] } )
}

#has appendix_sections => (
#    metaclass => 'Collection::Array',
#    is => 'rw',
#    isa => 'ArrayRef[Str]',
#    default => {[]},
#    provides => {
#        elements => 'appendix_sections',
#        },
#);

has pdf_generator => (
    is => 'rw',
    isa => 'Str',
    default => 'latex',
);


sub appendix {
    my $self = shift;

    # blerk, rework
    my @app = $self->dom->findnodes( '/book/appendix' );

    return @app ? $app[0] : undef;

}

sub create_appendix {
    my $self = shift;
    my $root = $self->root;

    my $appendix = $self->appendix;

    return $appendix if $appendix;

    $appendix = $root->new( 'appendix' );

    $appendix->setAttribute(  id => 'appendix-'.$self->unique_id );
    
    $self->root->appendChild( $appendix );

    my $label = $appendix->new( 'title' );
    $label->appendText( 'Appendix' );
    $appendix->appendChild( $label );

    return $appendix;
}

sub add_to_appendix {
    my $self = shift;
    $self->create_appendix->appendChild( shift );
}

sub appendix_section_titles {
    my $self = shift;
    return map { $_->findvalue( 'text()' ) }
        $self->dom->findnodes( '/book/appendix/section/title' );
}
                      
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

    use HTML::Entities ();
    use utf8;
    
    my %e2c = %HTML::Entities::entity2char;
    delete @e2c{qw/ amp lt quot apos/}; # 'gt' makes Perl crash? wtf?

    HTML::Entities::_decode_entities( $podxml, \%e2c );

    utf8::encode( $podxml );

    my $dom = eval { 
        $self->parser->parse_string( $podxml ) 
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
        $self->parser->parse_string( $podxml ) 
    } or die "error while converting raw pod to xml for '$pod': $@";

    return $dom;
}


sub add_module {
    my $self = shift;
    my $module = shift;
    my $arg = shift;

    if ( ref $module eq 'ARRAY' ) {
        $self->add_module( $_, $arg ) for @$module;
        return;
    }

    my $podxml = $self->_convert_pod_to_xml( $self->_find_module_pod( $module ) );

    my $dom = $self->dom;

    my $subdoc = $podxml->documentElement;

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

        $section->unbindNode if $self->is_ignored( $title );
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

    # move sections to appendix
    for my $section ( $subdoc->findnodes( 'section' ) ) {
        my $title = $section->findvalue( 'title/text()' );

        if ( $self->is_in_move_one_in_appendix( $title ) 
        ) {
            $DB::single = 1;
            if( grep { $title eq $_ } $self->appendix_section_titles ) {
                $section->unbindNode;
            }
            else {
                $self->create_appendix->appendChild( $section );
            }
        }
    }
    

    # use the title of that section if the 'doc_title' option is
    # used, or if there are no title given yet
#    if ( $option{set_title} or not defined $self->title ) {
#        my $title = $subdoc->findvalue( '/chapter/title/text()' );
#        $title =~ s/\s*-.*//;  # remove desc after the '-'
#        $self->set_title( $title ) if $title;
#    }


    $dom->adoptNode( $subdoc );

    # if there is no appendix, it adds the chapter
    # at the end of the document
    $self->root->insertBefore( $subdoc, $self->appendix );

}

method add_chapter ( ChapterType $type!, Str $chapter!, $attr? ) {

    my %option;
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

    my $dom = $self->dom;

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
    if ( $option{set_title} or not defined $self->title ) {
        my $title = $subdoc->findvalue( '/chapter/title/text()' );
        $title =~ s/\s*-.*//;  # remove desc after the '-'
        $self->set_title( $title ) if $title;
    }


    $dom->adoptNode( $subdoc );

    # if there is no appendix, it adds the chapter
    # at the end of the document
    $self->root->insertBefore( $subdoc, undef );

    #   for my $section_title ( @{ $option{appendix_sections} } ) {
    #    $self->_add_to_appendix( 
    #        grep { $_->findvalue( 'title/text()' ) eq $section_title }
    #                $subdoc->findnodes( 'section' )
    #    );
    #}

    return $self;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub as_dom {
    my $self = shift;
    return $self->dom;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

    $self->generate_pdf( $filename, $original_dir );

    chdir $original_dir;

    copy( $tmpdir.'/manual.pdf' => $filename.'.pdf' ) or die $!;

    return 1;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#sub _add_to_appendix {
#    my ( $self, @nodes ) = @_;
#
#    my $appendix = $self->appendix(1);
#
#    $appendix->appendChild( $_ ) for @nodes;
#
#    return $self;
#}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub master {
    my $class = shift;
    $class = ref $class if ref $class;

       my $var = '$'.$class.'::master';

    my $master = eval $var;

    unless ( $master ) {
        $master = $class->new;

        eval "$var = \$master";
    }

    return $master;
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
