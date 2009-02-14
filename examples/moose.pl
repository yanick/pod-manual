#!/usr/bin/perl 

use strict;
use warnings;

use Pod::Manual;

use Moose 0.69;

my $manual = Pod::Manual->new(
    title         => 'Moose',
    pdf_generator => 'latex'
);

$manual->add_chapters(
    qw/
      Moose::Manual::Concepts
      Moose::Manual::Classes
      Moose::Manual::Attributes
      Moose::Manual::Delegation
      Moose::Manual::Construction
      Moose::Manual::MethodModifiers
      Moose::Manual::Roles
      Moose::Manual::Types
      Moose::Manual::MOP
      Moose::Manual::MooseX
      Moose::Manual::BestPractices
      /
);

my $pdf_file = 'moose.pdf';
$manual->save_as_pdf($pdf_file);

print "pdf document '$pdf_file' created\n";
