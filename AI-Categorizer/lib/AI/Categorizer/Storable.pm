package AI::Categorizer::Storable;

use strict;
use Storable;
use File::Spec ();
use File::Path ();

sub save_state {
  my ($self, $path) = @_;
  if (-e $path) {
    File::Path::rmtree($path) or die "Couldn't overwrite $path: $!";
  }
  mkdir($path, 0777) or die "Can't create $path: $!";
  Storable::nstore($self, File::Spec->catfile($path, 'self'));
}

sub restore_state {
  my ($package, $path) = @_;
  return Storable::retrieve(File::Spec->catfile($path, 'self'));
}

1;
