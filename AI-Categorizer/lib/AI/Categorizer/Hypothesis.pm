package AI::Categorizer::Hypothesis;

use AI::Categorizer::Util;

sub new {
  my $package = shift;
  my $self = bless {@_}, $package;
  return $self;
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
