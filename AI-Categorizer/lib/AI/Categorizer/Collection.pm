package AI::Categorizer::Collection;
use strict;

use Params::Validate qw(:types);
use Class::Container;
use base qw(Class::Container);
__PACKAGE__->valid_params
  (
   verbose => {type => SCALAR, default => 0},
   category_hash => { type => HASHREF, default => {} },
   category_file => { type => SCALAR, optional => 1 },
  );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  if ($self->{category_file}) {
    local *FH;
    open FH, $self->{category_file} or die "Can't open $self->{category_file}: $!";
    while (<FH>) {
      my ($doc, @cats) = split;
      $self->{category_hash}{$doc} = \@cats;
    }
    close FH;
  }

  return $self;
}

# Abstract methods
sub next;

1;
