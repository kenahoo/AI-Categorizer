package AI::Categorizer::Document;

use strict;
use Class::Container;
use base qw(Class::Container);
use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   name => {type => SCALAR, public => 0},
   body => {type => SCALAR, public => 0},
   categories => {
		  type => ARRAYREF,
		  default => [],
		  callbacks => { 'all are Category objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Categorizer::Category'), @{$_[0]} },
			       },
		  public => 0,
		 },
   stopwords => {type => ARRAYREF|HASHREF, default => []},
  );

__PACKAGE__->contained_objects
  (
   feature_vector => { delayed => 1,
		       class => 'AI::Categorizer::FeatureVector' },
  );

### Constructors

sub new {
  my $self = shift()->SUPER::new(@_);

  # Get efficient internal data structures
  $self->{categories} = new Set::Object( @{$self->{categories}} );
  $self->{stopwords} = { map {($_ => 1)} @{ $self->{stopwords} } }
    if UNIVERSAL::isa($self->{stopwords}, 'ARRAY');
  return $self;
}

sub new_from_string {
  my ($class, %args) = @_;
  $args{categories} ||= [];
  my @cats = map { UNIVERSAL::isa($_, 'AI::Categorizer::Category') 
                   ? $_ 
		   : $args{knowledge}->category_by_name($_) } @{$args{categories}};
  
  return $class->new( name => $args{name},
		      body => $args{string},
		      categories => \@cats );
}

sub new_from_xml;
sub new_from_textfile;

### Accessors

sub name { $_[0]->{name} }

sub features {
  my $self = shift;
  return $self->{feature_vector} if exists $self->{feature_vector};

  $self->tokenize;  # Creates $self->{tokens}
  $self->vectorize; # Creates $self->{feature_vector}
  return $self->{feature_vector};
}

sub categories {
  my $c = $_[0]->{categories};
  return wantarray ? $c->members : $c->size;
}


### Workers

sub is_in_category {
  return $_[0]->{categories}->includes( $_[1] );
}

sub tokenize {
  my $self = shift;
  while ($self->{body} =~ /([-\w]+)/g) {
    push @{$self->{tokens}}, lc $1;
  }
}

# Need to implement stemming options
sub stem_words {}

sub vectorize {
  my $self = shift;
  my %counts;
  foreach my $feature (@{$self->{tokens}}) {
    next if exists $self->{stopwords}{$feature};
    $counts{$feature}++;
  }
  $self->{feature_vector} = $self->create_delayed_object('feature_vector', features => \%counts);
}

1;
