package AI::Categorizer::Category;

use strict;
use AI::Categorizer::ObjectSet;
use Class::Container;
use base qw(Class::Container);

use Params::Validate qw(:types);
use AI::Categorizer::FeatureVector;

__PACKAGE__->valid_params
  (
   name => {type => SCALAR, public => 0},
   documents  => {
		  type => ARRAYREF,
		  default => [],
		  callbacks => { 'all are Document objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Categorizer::Document'), @_ },
			       },
		  public => 0,
		 },
  );

__PACKAGE__->contained_objects
  (
   features => {
		class => 'AI::Categorizer::FeatureVector',
		delayed => 1,
	       },
  );

my %REGISTRY = ();

sub new {
  my $self = shift()->SUPER::new(@_);
  $self->{documents} = new AI::Categorizer::ObjectSet( @{$self->{documents}} );
  $REGISTRY{$self->{name}} = $self;
  return $self;
}

sub by_name {
  my ($class, %args) = @_;
  return $REGISTRY{$args{name}} if exists $REGISTRY{$args{name}};
  return $class->new(%args);
}

sub name { $_[0]->{name} }

sub documents {
  my $d = $_[0]->{documents};
  return wantarray ? $d->members : $d->size;
}

sub contains_document {
  return $_[0]->{documents}->includes( $_[1] );
}

sub add_document {
  my $self = shift;
  $self->{documents}->insert( $_[0] );
  delete $self->{features};  # Could be more efficient?
}

sub features {
  my $self = shift;
  return $self->{features} if exists $self->{features};

  my @docs = $self->documents
    or return $self->{features} = $self->create_delayed_object('features', features => {});

  my $sum = (shift @docs)->features->clone;
  while (@docs) {
    $sum->add((shift @docs)->features);
  }

  return $self->{features} = $sum;
}

1;
