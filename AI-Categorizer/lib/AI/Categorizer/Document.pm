package AI::Categorizer::Document;

use strict;
use Class::Container;
use base qw(Class::Container);

use Params::Validate qw(:types);
use AI::Categorizer::ObjectSet;
use AI::Categorizer::FeatureVector;

__PACKAGE__->valid_params
  (
   name       => {
		  type => SCALAR, 
		 },
   categories => {
		  type => ARRAYREF,
		  default => [],
		  callbacks => { 'all are Category objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Categorizer::Category'), @{$_[0]} },
			       },
		  public => 0,
		 },
   stopwords => {
		 type => ARRAYREF|HASHREF,
		 default => []
		},
   content   => {
		 type => HASHREF|SCALAR,
		},
   content_weights => {
		       type => HASHREF,
		       default => {},
		      },
   use_features => {
		    type => HASHREF|UNDEF,
		    default => undef,
		   },
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
  $self->{categories} = new AI::Categorizer::ObjectSet( @{$self->{categories}} );
  $self->{stopwords} = { map {($_ => 1)} @{ $self->{stopwords} } }
    if UNIVERSAL::isa($self->{stopwords}, 'ARRAY');

  # Allow a simple string as the content
  $self->{content} = { body => $self->{content} } unless ref($self->{content});

  $self->create_feature_vector; # Deletes 'content' and 'content_weights'

  return $self;
}

sub new_from_string {
  my ($class, %args) = @_;
  $args{categories} ||= [];
  my @cats = map $args{knowledge}->category_by_name($_), @{$args{categories}};
  
  return $class->new( name => $args{name},
		      content => $args{string},
		      categories => \@cats );
}

sub new_from_xml;
sub new_from_textfile;

### Accessors

sub name { $_[0]->{name} }

sub features {
  my $self = shift;
  if (@_) {
    $self->{feature_vector} = shift;
  }
  return $self->{feature_vector};
}

sub categories {
  my $c = $_[0]->{categories};
  return wantarray ? $c->members : $c->size;
}


### Workers

sub create_feature_vector {
  my $self = shift;
  my $content = $self->{content};
  my $weights = $self->{content_weights};
  delete @{$self}{'content', 'content_weights'};

  my %features;
  while (my ($name, $data) = each %$content) {
    my $t = $self->tokenize($data);
    $self->stem_words($t);
    my $h = $self->vectorize(tokens => $t, weight => exists($weights->{$name}) ? $weights->{name} : 1 );
    @features{keys %$h} = values %$h;
  }
  $self->{feature_vector} = $self->create_delayed_object('feature_vector', features => \%features);

  undef $self->{content};
  undef $self->{content_weights};
  #undef %features;
}

sub is_in_category {
  return $_[0]->{categories}->includes( $_[1] );
}

sub tokenize {
  my $self = shift;
  my @tokens = [];
  while ($_[0] =~ /([-\w]+)/g) {
    push @tokens, lc $1;
  }
  return \@tokens;
}

# Need to implement stemming options
sub stem_words {}

sub vectorize {
  my ($self, %args) = @_;
  my %counts;
  foreach my $feature (@{$args{tokens}}) {
    if ($self->{use_features}) {
      next unless exists $self->{use_features}{$feature};
    } elsif (exists $self->{stopwords}{$feature}) {
      next;
    }
    $counts{$feature} += $args{weight};
  }
  return \%counts;
}

1;
