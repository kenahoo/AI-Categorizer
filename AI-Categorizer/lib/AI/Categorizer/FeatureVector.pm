package AI::Classifier::FeatureVector;

sub new {
  my ($package, %args) = @_;
  $args{features} ||= {};
  return bless {features => $args{features}}, $package;
}

sub set {
  my $self = shift;
  $self->{features} = (ref $_[0] ? $_[0] : {@_});
}

sub as_hash {
  my $self = shift;
  return $self->{features};
}

1;
