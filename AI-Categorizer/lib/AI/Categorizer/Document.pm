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
   front_bias => {
		  type => SCALAR,
		  default => 0,
		  },
   term_weighting  => {
		       type => SCALAR,
		       default => 'natural',
		      },
   use_features => {
		    type => HASHREF|UNDEF,
		    default => undef,
		   },
   stemming => {
		type => SCALAR|UNDEF,
		optional => 1,
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
    my $word = lc $1;
    next unless $word =~ /[a-z]/;
    $word =~ s/^[^a-z]+//;  # Trim leading non-alpha characters (helps with ordinals)
    push @tokens, $word;
  }
  return \@tokens;
}

sub stem_words {
  my ($self, $tokens) = @_;
  return unless $self->{stemming};
  return if $self->{stemming} eq 'none';
  die "Unknown stemming option '$self->{stemming}' - options are 'porter' or 'none'"
    unless $self->{stemming} eq 'porter';
  
  eval {require Lingua::Stem; 1}
    or die "Porter stemming requires the Lingua::Stem module, available from CPAN.\n";

  @$tokens = @{ Lingua::Stem::stem(@$tokens) };
}

sub _filter_tokens {
  my ($self, $tokens_in) = @_;

  if ($self->{use_features}) {
    my $f = $self->{use_features}->as_hash;
    return [ grep  exists($f->{$_}), @$tokens_in ];
  } elsif ($self->{stopwords}) {
    my $s = $self->{stopwords};
    return [ grep !exists($s->{$_}), @$tokens_in ];
  }
  return $tokens_in;
}

sub _weigh_tokens {
  my ($self, $tokens, $weight) = @_;

  my %counts;
  if (my $b = 0+$self->{front_bias}) {
    die "'front_bias' value must be between -1 and 1"
      unless -1 < $b and $b < 1;
    
    my $n = @$tokens;
    my $r = ($b-1)**2 / ($b+1);
    my $mult = $weight * log($r)/($r-1);
    
    my $i = 0;
    foreach my $feature (@$tokens) {
      $counts{$feature} += $mult * $r**($i/$n);
      $i++;
    }
    
  } else {
    foreach my $feature (@$tokens) {
      $counts{$feature} += $weight;
    }
  }

  return \%counts;
}

sub vectorize {
  my ($self, %args) = @_;
  my $tokens = $self->_filter_tokens($args{tokens});

  return { map {( $_ => $args{weight})} @$tokens }
    if $self->{term_weighting} eq 'boolean';

  my $counts = $self->_weigh_tokens($tokens, $args{weight});

  if ($self->{term_weighting} eq 'natural') {
    # Nothing to do
  } elsif ($self->{term_weighting} eq 'log') {
    $_ = 1 + log($_) foreach values %$counts;
  } else {
    die "term_weighting must be one of 'natural', 'log', or 'boolean'";
  }
  
  return $counts;
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
