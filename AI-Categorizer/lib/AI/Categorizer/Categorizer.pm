package AI::Categorizer::Categorizer;

use strict;
use Class::Container;
use base qw(Class::Container);
use Params::Validate qw(:types);
use Set::Object;

__PACKAGE__->valid_params
  (
   knowledge  => { isa => 'AI::Categorizer::KnowledgeSet' },
   features_kept => { type => SCALAR, default => 0.2 },
  );

sub train {
  my ($self, %args) = @_;
  $self->{knowledge} = $args{knowledge} if $args{knowledge};
  die "No knowledge provided" unless $self->{knowledge};

  $self->select_features; # May replace $self->{knowledge}
  $self->create_model;    # Creates $self->{model}
}

# sub categorize
# sub create_model

sub select_features {
  # This just uses a simple document-frequency criterion, controlled
  # by 'features_kept'.  Other algorithms may follow later, controlled
  # by other parameters.

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

  print "Finished trimming features - words = " . $k->features->length . "\n" if $self->{verbose};
}




1;
