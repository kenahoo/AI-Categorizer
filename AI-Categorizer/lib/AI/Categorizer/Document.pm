package AI::Classifier::Document;

use strict;
use Class::Container;
use base qw(Class::Container);
use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   name => {type => SCALAR},
   body => {type => SCALAR},
   categories => {
		  type => ARRAYREF,
		  callbacks => { 'all are Category objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Classifier::Category'), @_ },
			       },
		 },
  );

__PACKAGE__->contained_objects
  (
   feature_vector => { delayed => 1,
		       class => 'AI::Classifier::FeatureVector' },
  );

__PACKAGE__->make_accessors(':all');

sub new {
  my $self = shift()->SUPER::new(@_);
  $self->{category_hash} = map {$_->name => 1} @{$self->categories};
  return $self;
}

sub features {
  my $self = shift;
  return $self->{feature_vector} if exists $self->{feature_vector};

  $self->tokenize;  # Creates $self->{tokens}
  $self->vectorize; # Creates $self->{feature_vector}
  return $self->{feature_vector};
}

sub is_in_category {
  return $_[0]->{category_hash}{ $_[1]->name };
}

sub tokenize {
  my $self = shift;
  while ($self->{body} =~ /([-\w]+)/g) {
    push @{$self->{tokens}}, $1;
  }
}

sub vectorize {
  my $self = shift;
  my %counts;
  foreach my $feature (@{$self->{tokens}}) {
    $counts{$feature}++;
  }
  $self->{feature_vector} = $self->create_delayed_object('feature_vector', features => \%counts);
}

1;
