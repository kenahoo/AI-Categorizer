package AI::Categorizer::KnowledgeSet;

use strict;
use Class::Container;
use AI::Categorizer::Storable;
use base qw(Class::Container AI::Categorizer::Storable);
use Params::Validate qw(:types);
use Set::Object;

__PACKAGE__->valid_params
  (
   categories => {
		  type => ARRAYREF,
		  default => [],
		  callbacks => { 'all are Category objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Categorizer::Category'), @_ },
			       },
		 },
   documents  => {
		  type => ARRAYREF,
		  default => [],
		  callbacks => { 'all are Document objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Categorizer::Document'), @_ },
			       },
		 },
  );

__PACKAGE__->contained_objects
  (
   document => { delayed => 1,
		 class => 'AI::Categorizer::Document' },
   category => { delayed => 1,
		 class => 'AI::Categorizer::Category' },
  );

sub new {
  my $self = shift()->SUPER::new(@_);

  # Convert to Set::Object sets
  $self->{categories} = new Set::Object( @{$self->{categories}} );
  $self->{documents}  = new Set::Object( @{$self->{documents}}  );
  return $self;
}

sub features {
  my $self = shift;
  if (@_) {
    $self->{features} = shift;
  }
  return $self->{features} if $self->{features};
  
  # Create a feature vector encompassing the whole set of documents
  my $v;
  foreach my $document ($self->documents) {
    $v ||= ref($document->features)->new( features => {} );
    $v->add( $document->features );
  }
  return $self->{features} = $v;
}

sub categories {
  my $c = $_[0]->{categories};
  return wantarray ? $c->members : $c->size;
}

sub documents {
  my $d = $_[0]->{documents};
  return wantarray ? $d->members : $d->size;
}

sub partition {
  my ($self, @sizes) = @_;
  my $num_docs = my @docs = $self->documents;
  my @groups;

  while (@sizes > 1) {
    my $size = int ($num_docs * shift @sizes);
    push @groups, [];
    for (0..$size) {
      push @{ $groups[-1] }, splice @docs, rand(@docs), 1;
    }
  }
  push @groups, \@docs;

  return map { ref($self)->new( documents => $_ ) } @groups;
}

sub make_document {
  my ($self, %args) = @_;
  my $cats = delete $args{categories};
  my @cats = map { $self->category_by_name($_) } @$cats;
  my $d = $self->create_delayed_object('document', %args, categories => \@cats);
  $self->add_document($d);
}

sub add_document {
  my ($self, $doc) = @_;

  foreach ($doc->categories) {
    $_->add_document($doc);
  }
  $self->{documents}->insert($doc);
  $self->{categories}->insert($doc->categories);
}

# Not very efficient yet - need a lookup table
sub category_by_name {
  my ($self, $name) = @_;
  foreach my $cat ($self->categories) {
    return $cat if $cat->name eq $name;
  }
  return $self->create_delayed_object('category', name => $name);
}

1;
