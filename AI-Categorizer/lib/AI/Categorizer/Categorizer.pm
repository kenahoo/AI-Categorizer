package AI::Categorizer::Categorizer;

use strict;
use Class::Container;
use AI::Categorizer::Storable;
use base qw(Class::Container AI::Categorizer::Storable);

use Params::Validate qw(:types);
use Set::Object;

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

  $self->select_features; # May replace $self->{knowledge}
  $self->create_model;    # Creates $self->{model}
}

sub select_features {
  # This just uses a simple document-frequency criterion, controlled
  # by 'features_kept'.  Other algorithms may follow later, controlled
  # by other parameters.

# XXX this is doing word-frequency right now, not document-frequency

  my $self = shift;
  return unless $self->{features_kept};

  my $k = $self->{knowledge}; # For convenience
  
  my $num_features = $k->features->length;
  print "Trimming features - # features = $num_features\n" if $self->{verbose};
  
  # This is algorithmic overkill, but the sort seems fast enough.  Will revisit later.
  my $features = $k->features->as_hash;
  my @new_features = (sort {$features->{$b} <=> $features->{$a}} keys %$features)
                      [0 .. $self->{features_kept} * $num_features];
  my $new_features = $k->features->intersection( \@new_features );
  $k->features( $new_features );

  print "Finished trimming features - # features = " . $k->features->length . "\n" if $self->{verbose};
}




1;
