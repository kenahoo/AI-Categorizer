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

# This should usually be replaced with a faster version that doesn't
# need to create actual documents each time through
sub count_documents {
  my $self = shift;
  return $self->{document_count} if exists $self->{document_count};

  $self->rewind;
  my $count = 0;
  $count++ while $self->next;
  $self->rewind;

  return $self->{document_count} = $count;
}

# Abstract methods
sub next;

1;
