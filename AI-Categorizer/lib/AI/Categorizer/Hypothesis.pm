package AI::Categorizer::Hypothesis;

use strict;
use AI::Categorizer::Util;

use Class::Container;
use base qw(Class::Container);
use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   all_categories => {type => ARRAYREF},
   scores => {type => HASHREF},
   threshold => {type => SCALAR},
  );

sub all_categories {
  my $self = shift;
  return @{$self->{all_categories}};
}

sub best_category {
  my ($self) = @_;
  my $sc = $self->{scores};
  return unless %$sc;

  my ($best_cat, $best_score) = each %$sc;
  while (my ($key, $val) = each %$sc) {
    $best_cat = $key if $val > $best_score;
  }
  return $best_cat;
}

sub in_category {
  my ($self, $cat) = @_;
  return unless exists $self->{scores}{$cat};
  return $self->{scores}{$cat} > $self->{threshold};
}

sub categories {
  my $self = shift;
  return @{$self->{cats}} if $self->{cats};
  $self->{cats} = [sort {$self->{scores}{$b} <=> $self->{scores}{$a}}
                   grep {$self->{scores}{$_} > $self->{threshold}}
                   keys %{$self->{scores}}];
  return @{$self->{cats}};
}

sub scores {
  my $self = shift;
  return @{$self->{scores}}{@_};
}

sub precision {
  my ($self, $correct) = @_;
  return AI::Categorizer::Util::precision([$self->categories], $correct);
}

sub recall {
  my ($self, $correct) = @_;
  return AI::Categorizer::Util::recall([$self->categories], $correct);
}

sub F1 {
  my ($self, $correct) = @_;
  return AI::Categorizer::Util::F1([$self->categories], $correct);
}


1;
