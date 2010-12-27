package Pod::Manual::Types;

use 5.10.0;

use strict;
use warnings;


use MooseX::Types -declare => [ qw/
    ChapterType
/ ];

use MooseX::Types::Moose qw/Str/;


subtype ChapterType,
    as Str,
    where { $_ ~~ [ qw/ pod file module / ] },
    message { "type was '$_' and must be 'pod', 'file' or 'module'" };

#enum 'ChapterType' => [ qw/ pod file module / ];

1;
