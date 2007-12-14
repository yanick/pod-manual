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

$manual->add_chapters( @ARGV ? @ARGV : <> );

if ( $pdf_file ) {
    $manual->save_as_pdf( $pdf_file );
    print "pdf document '$pdf_file' created\n";
}
else {
    print $manual->as_docbook;
}





