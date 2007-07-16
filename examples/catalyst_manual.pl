#!/usr/bin/perl 

use strict;
use warnings;

use Pod::Manual;

my $manual = Pod::Manual->new({ title => 'Catalyst' });

$manual->add_chapter( $_ ) for qw/  
                            Catalyst::Manual::About 
                            Catalyst::Manual::Actions
                            Catalyst::Manual::Cookbook
                            Catalyst::Manual::DevelopmentProcess
                            Catalyst::Manual::Internals
                            Catalyst::Manual::Intro
                            Catalyst::Manual::Plugins
                            Catalyst::Manual::Tutorial
                            Catalyst::Manual::Tutorial::Intro
                            Catalyst::Manual::Tutorial::CatalystBasics
                            Catalyst::Manual::Tutorial::BasicCRUD
                            Catalyst::Manual::Tutorial::Authentication
                            Catalyst::Manual::Tutorial::Authorization
                            Catalyst::Manual::Tutorial::Debugging
                            Catalyst::Manual::Tutorial::Testing
                            Catalyst::Manual::Tutorial::AdvancedCRUD
                            Catalyst::Manual::Tutorial::Appendices
                            Catalyst::Manual::WritingPlugins /;

#print $manual->as_docbook; exit;
$manual->save_as_pdf( 'catalyst_manual.pdf' );

