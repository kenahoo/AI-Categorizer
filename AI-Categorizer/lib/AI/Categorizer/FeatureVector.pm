package AI::Categorizer::FeatureVector;

sub new {
  my ($package, %args) = @_;
  $args{features} ||= {};
  return bless {features => $args{features}}, $package;
}

sub names {
  my $self = shift;
  return keys %{$self->{features}};
}

sub set {
  my $self = shift;
  $self->{features} = (ref $_[0] ? $_[0] : {@_});
}

sub as_hash {
  my $self = shift;
  return $self->{features};
}

sub normalize {
  my $self = shift;
  my $total = 0;
  local $_;
  while ( (undef, $_) = each %{ $self->{features} } ) {
    $total += $_**2;
  }
  $total = sqrt($total);
  foreach ( %{ $self->{features} } ) {
    $_ /= $total;
  }
  return $self;
}

sub as_boolean_hash {
  my $self = shift;
  return { map {($_ => 1)} keys %{$self->{features}} };
}

sub length {
  my $self = shift;
  return scalar keys %{$self->{features}};
}

sub clone {
  my $self = shift;
  return ref($self)->new( features => { %{$self->{features}} } );
}

sub intersection {
  my ($self, $other) = @_;
  $other = $other->as_hash if UNIVERSAL::isa($other, __PACKAGE__);

  my $common;
  if (UNIVERSAL::isa($other, 'ARRAY')) {
    $common = {map {exists $self->{features}{$_} ? ($_ => $self->{features}{$_}) : ()} @$other};
  } elsif (UNIVERSAL::isa($other, 'HASH')) {
    $common = {map {exists $self->{features}{$_} ? ($_ => $self->{features}{$_}) : ()} keys %$other};
  }
  return ref($self)->new( features => $common );
}

sub add {
  my ($self, $other) = @_;

  $other = $other->as_hash;
  while (my ($k,$v) = each %$other) {
    $self->{features}{$k} += $v;
  }
}

sub sum {
  my ($self) = @_;

  # Return total of values in this vector
  my $total = 0;
  while ( (undef, my $v) = each %{ $self->{features} } ) {
    $total += $v;
  }
  return $total;
}

sub includes {
  return exists $_[0]->{features}{$_[1]};
}

1;
