package AI::Categorizer::Learner;

use strict;
use Class::Container;
use AI::Categorizer::Storable;
use base qw(Class::Container AI::Categorizer::Storable);

use Params::Validate qw(:types);
use AI::Categorizer::ObjectSet;

__PACKAGE__->valid_params
  (
   knowledge_set  => { isa => 'AI::Categorizer::KnowledgeSet', optional => 1 },
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

sub verbose {
  my $self = shift;
  if (@_) {
    $self->{verbose} = shift;
  }
  return $self->{verbose};
}

sub knowledge_set {
  my $self = shift;
  if (@_) {
    $self->{knowledge_set} = shift;
  }
  return $self->{knowledge_set};
}

sub train {
  my ($self, %args) = @_;
  $self->{knowledge_set} = $args{knowledge_set} if $args{knowledge_set};
  die "No knowledge_set provided" unless $self->{knowledge_set};

  $self->create_model;    # Creates $self->{model}
}

1;
