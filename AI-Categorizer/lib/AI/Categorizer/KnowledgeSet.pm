package AI::Categorizer::KnowledgeSet;

use strict;
use Class::Container;
use AI::Categorizer::Storable;
use base qw(Class::Container AI::Categorizer::Storable);

use Params::Validate qw(:types);
use AI::Categorizer::ObjectSet;
use AI::Categorizer::Document;
use AI::Categorizer::Category;
use AI::Categorizer::FeatureVector;

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

  # Convert to AI::Categorizer::ObjectSet sets
  $self->{categories} = new AI::Categorizer::ObjectSet( @{$self->{categories}} );
  $self->{documents}  = new AI::Categorizer::ObjectSet( @{$self->{documents}}  );
  $self->{category_names} = { map {($_->name => $_)} $self->{categories}->members };
  return $self;
}

sub features {
  my $self = shift;

  if (@_) {
    $self->{features} = shift;
    $self->trim_doc_features if $self->{features};
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

sub trim_doc_features {
  my ($self) = @_;
  
  foreach my $doc ($self->documents) {
    $doc->features( $doc->features->intersection($self->features) );
  }
}

sub select_features {
  # This just uses a simple document-frequency criterion, controlled
  # by 'features_kept'.  Other algorithms may follow later, controlled
  # by other parameters.

# XXX this is doing word-frequency right now, not document-frequency

  my ($self, %args) = @_;
  my $kept = exists($args{features_kept}) ? $args{features_kept} : $self->{features_kept};
  return unless $kept;
  
  my $f = $self->features;

  my $num_features = $f->length;
  print "Trimming features - # features = $num_features\n" if $self->{verbose};
  
  # This is algorithmic overkill, but the sort seems fast enough.  Will revisit later.
  my $features = $f->as_hash;
  my @new_features = (sort {$features->{$b} <=> $features->{$a}} keys %$features)
                      [0 .. $kept * $num_features];
  my $new_features = $f->intersection( \@new_features );
  $self->features( $new_features );

  print "Finished trimming features - # features = " . $self->features->length . "\n" if $self->{verbose};
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

sub category_by_name {
  my ($self, $cat) = @_;
  return $cat if ref $cat;
  return $self->{category_names}{$cat} if exists $self->{category_names}{$cat};
  return $self->{category_names}{$cat} = $self->create_delayed_object('category', name => $cat);
}

#  sub save_state {
#    my $self = shift;
  
#    # With large corpora it's infeasible to save the whole knowledge
#    # base.  We'll just save feature vectors & relationships.

#    local $self->{documents_save} = {};
#    foreach my $doc ($self->documents) {
#      $self->
#    }

#    return $self->SUPER::save_state(@_);
#  }

1;
