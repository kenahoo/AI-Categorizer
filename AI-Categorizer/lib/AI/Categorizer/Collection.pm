package AI::Categorizer::Collection;
use strict;

use Params::Validate qw(:types);
use Class::Container;
use base qw(Class::Container);
__PACKAGE__->valid_params
  ( verbose => {TYPE => SCALAR, default => 0} );

# Abstract methods
sub next;
sub count_documents;

1;
