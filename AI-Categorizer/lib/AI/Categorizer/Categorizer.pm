package AI::Categorizer::Categorizer;

use strict;
use Class::Container;
use AI::Categorizer::Storable;
use base qw(Class::Container AI::Categorizer::Storable);

use Params::Validate qw(:types);
use AI::Categorizer::ObjectSet;

__PACKAGE__->valid_params
  (
   knowledge  => { isa => 'AI::Categorizer::KnowledgeSet', optional => 1 },
   features_kept => { type => SCALAR, default => 0.2 },
   verbose => {type => SCALAR, default => 0},
  );

__PACKAGE__->contained_objects
  (
   hypothesis => {
		  class => 'AI::Categorizer::Hypothesis',
		  delayed => 1,
		 },
  );

# Subclasses must override these virtual methods:
sub categorize;
sub create_model;

sub knowledge {
  my $self = shift;
  if (@_) {
    $self->{knowledge} = shift;
  }
  return $self->{knowledge};
}

sub train {
  my ($self, %args) = @_;
  $self->{knowledge} = $args{knowledge} if $args{knowledge};
  die "No knowledge provided" unless $self->{knowledge};

  $self->create_model;    # Creates $self->{model}
}

1;
