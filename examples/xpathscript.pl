#!/usr/bin/perl 

use strict;
use warnings;

use Pod::Manual;

my $manual = Pod::Manual->new({ title => 'XPathScript' });

$manual->add_chapters( qw/  
    XML::XPathScript
    XML::XPathScript::Stylesheet
    XML::XPathScript::Template
    XML::XPathScript::Template::Tag
    XML::XPathScript::Processor
    xpathscript
                            / );

my $pdf_file = 'xpathscript_manual.pdf';
$manual->save_as_pdf( $pdf_file );

print "pdf document '$pdf_file' created\n";

