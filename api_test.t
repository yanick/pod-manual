use Pod::Manual;

my $manual = Pod::Manual->new({
    title => 'XPathScript',
    extract_authors_from_chapters => 1,
    ignore_sections => [ qw/ COPYRIGHT  / ],
});

#print Pod::Manual::_get_podxml( 'XML::XPathScript::Stylesheet' ); exit;
#print Pod::Manual::_get_podxml( 'Catalyst::Manual::About' );

$manual->add_chapter( 'XML::XPathScript', { move_to_appendix => [ qw/ COPYRIGHT / ] } );
$manual->add_chapter( 'XML::XPathScript::Stylesheet', );

#print $manual->as_dom;
#print $manual->as_docbook;
$manual->as_pdf( 'xpathscript' );


