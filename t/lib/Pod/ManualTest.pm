package Pod::ManualTest;

use strict;
use warnings;

use base 'Pod::Manual::Test';

use Test::More;
use Pod::Manual;

sub object_creation :Test {
    my $manual = Pod::Manual->new;

    isa_ok $manual, 'Pod::Manual';
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub ignore_sections_scalar :Test {
    my $manual = Pod::Manual->new( ignore_sections => 'BUGS' );

    $manual->add_chapter( sample_pod() );

    # BUGS are gone!
    
    unlike $manual->as_docbook => qr/BUGS/;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub ignore_sections_array :Tests(2) {
    my $manual = Pod::Manual->new( ignore_sections => [ 'BUGS', 'SEE ALSO' ] );

    $manual->add_chapter( sample_pod() );

    # BUGS and SEE ALSO are gone
    
    unlike $manual->as_docbook => qr/BUGS/;
    unlike $manual->as_docbook => qr/SEE ALSO/;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub sample_pod {
    return <<'END_POD';
=head1 NAME

foo - yadah yadah

=head1 DESCRIPTION

blah blah blah

=head1 BUGS

etc etc etc 

=head1 SEE ALSO 

meh
END_POD

}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1;

