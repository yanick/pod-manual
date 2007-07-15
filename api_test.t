use Pod::Manual;

my $manual = Pod::Manual->new(
    title => 'XPathScript',
    extract_authors_from_chapters => 1,
    ignore_sections => [ qw/ COPYRIGHT  / ],
);

#print Pod::Manual::_get_podxml( 'XML::XPathScript::Stylesheet' ); exit;
#print Pod::Manual::_get_podxml( 'Catalyst::Manual::About' );

$manual->add_chapter( 'XML::XPathScript', ); # { move_to_appendix => [ qw/ SYNOPSIS / ] } );
$manual->add_chapter( 'XML::XPathScript::Stylesheet', );

#print $manual->as_dom;
# print $manual->as_latex;
#print $manual->as_docbook( { css => 'docbook-css-0.4/driver.css' } );
$manual->save_as_pdf( 'xpathscript.pdf' );


