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
   experiment => {
		  class => 'AI::Categorizer::Experiment',
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
  $self->delayed_object_params('hypothesis',
			       all_categories => [keys %{$self->{model}{cat_prob}}]
			      );
}

sub prog_bar {
  my ($self, $count) = @_;
  
  return sub { print STDERR '.' } unless eval "use Time::Progress; 1";
  
  my $pb = 'Time::Progress'->new;
  $pb->attr(max => $count);
  my $i = 0;
  return sub {
    $i++;
    return if $i % 25;
    my $string = '';
    if (@_) {
      my $e = shift;
      $string = sprintf " (miF1=%.03f, maF1=%.03f)", $e->micro_F1, $e->macro_F1;
    }
    print STDERR $pb->report("%50b %p ($i/$count)$string\r", $i);
    return $i;
  };
}

sub categorize_collection {
  my ($self, %args) = @_;
  my $c = $args{collection} or die "No collection provided";
  
  my @all_cats = map $_->name, $self->categories;
  my $experiment = $self->create_delayed_object('experiment', categories => \@all_cats);
  my $pb = $self->verbose ? $self->prog_bar($c->count_documents) : sub {};
  while (my $d = $c->next) {
    my $h = $self->categorize($d);
    $experiment->add_result([$h->categories], [map $_->name, $d->categories], $d->name);
    $pb->($experiment);
  }
  print STDERR "\n" if $self->verbose;

  return $experiment;
}

1;
