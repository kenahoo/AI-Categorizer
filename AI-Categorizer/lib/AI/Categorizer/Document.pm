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
   term_weighting  => {
		       type => SCALAR,
		       default => 'natural',
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

  $self->create_feature_vector;

  # Now we're done with all the content stuff
  delete @{$self}{'content', 'content_weights', 'stopwords', 'term_weighting', 'use_features'};
  
  return $self;
}

# Parse a document format - a virtual method
sub parse;


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

  my %features;
  while (my ($name, $data) = each %$content) {
    my $t = $self->tokenize($data);
    $self->stem_words($t);
    my $h = $self->vectorize(tokens => $t, weight => exists($weights->{$name}) ? $weights->{$name} : 1 );
    @features{keys %$h} = values %$h;
  }
  $self->{feature_vector} = $self->create_delayed_object('feature_vector', features => \%features);
}

sub is_in_category {
  return $_[0]->{categories}->includes( $_[1] );
}

sub tokenize {
  my $self = shift;
  my @tokens;
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

  # Do this separately for a speedup
  if ($self->{use_features}) {
    #warn "Using features: $self->{use_features} (@{[ $self->{use_features}->length ]})\n";
    foreach my $feature (@{$args{tokens}}) {
      $counts{$feature} += $args{weight} if $self->{use_features}->includes($feature);
    }
  } else {
    foreach my $feature (@{$args{tokens}}) {
      $counts{$feature} += $args{weight} unless exists $self->{stopwords}{$feature};
    }
  }

  if ($self->{term_weighting} eq 'natural') {
    return \%counts;
  } elsif ($self->{term_weighting} eq 'boolean') {
    return { map {( $_ => $args{weight})} keys %counts };
  } elsif ($self->{term_weighting} eq 'log') {
    return { map {( $_ => 1 + log($counts{$_}))} keys %counts };
  } else {
    die "term_weighting can only be 'natural', 'log', or 'boolean' (so far)";
  }
  return \%counts;
}

sub read {
  my ($class, %args) = @_;
  my $path = delete $args{path} or die "Must specify 'path' argument to read()";
  $args{name} ||= $path;

  local *FH;
  open FH, "< $path" or die "$path: $!";
  my $body = do {local $/; <FH>};
  close FH;

  my $doc = $class->parse(content => $body);
  return $class->new(%args, content => $doc);
}

1;
