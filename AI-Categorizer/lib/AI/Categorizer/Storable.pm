package AI::Categorizer::Storable;

use strict;
use Storable;

sub save_state {
  my ($self, $file) = @_;
  Storable::store($self, $file);
}

sub restore_state {
  my ($package, $file) = @_;
  return Storable::retrieve($file);
}

1;
