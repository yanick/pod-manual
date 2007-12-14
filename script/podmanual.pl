#!/usr/bin/perl 

use strict;
use warnings;

use Pod::Manual;
use Getopt::Long;

my $title;
my $pdf_file;

GetOptions( 'title=s' => \$title,
            'pdf=s'   => \$pdf_file );

my $manual = Pod::Manual->new({ title => $title });

# the chapters are either passed as arguments,
# or taken from STDIN
$manual->add_chapters( @ARGV ? @ARGV : split /\r?\n/, join '', <> );

if ( $pdf_file ) {
    $manual->save_as_pdf( $pdf_file );
    print "pdf document '$pdf_file' created\n";
}
else {
    print $manual->as_docbook;
}

__END__

=head1 NAME

podmanual - converts pods into docbook or pdf manual

=head1 SYNOPSIS

podmanual [ OPTIONS ] [ module names | pod files ] 
	
=head1 DESCRIPTION

Take the pods given as arguments and generate
a manual out of them. 

The pods can be given as module names or file names. If no
pods are passed as arguments, C<podmanual> will read them from
STDIN, assuming a format of one module name per line.

=head2 OPTIONS

=over

=item -pdf I<filename>

The manual is saved as the pdf file I<filename>.

=item -title I<manual title>

Set the manual title.  If the option is not invoked, 
the name of the first module will be used as the title of
the manual.

=back

=head1 SEE ALSO

L<Pod::Manual>

=head1 BUGS

Please send bug reports to <bug-pod-manual@rt.cpan.org>,
or via the web interface at 
http://rt.cpan.org/Public/Dist/Display.html?Name=Pod-Manual.

=head1 AUTHOR

Yanick Champoux, <yanick@cpan.org>

=cut

