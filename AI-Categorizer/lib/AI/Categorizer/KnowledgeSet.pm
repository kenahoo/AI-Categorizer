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
use AI::Categorizer::Util;
use Carp qw(croak);

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
   features_kept => {
		     type => SCALAR,
		     default => 0.2,
		    },
   feature_selection => {
			 type => SCALAR,
			 default => 'document_frequency',
			},
   tfidf_weighting  => {
			type => SCALAR,
			optional => 1,
		       },
   term_weighting  => {
		       type => SCALAR,
		       default => 'x',
		      },
   collection_weighting => {
			    type => SCALAR,
			    default => 'x',
			   },
   normalize_weighting => {
			   type => SCALAR,
			   default => 'x',
			  },
   verbose => {
	       type => SCALAR,
	       default => 0,
	      },
  );

__PACKAGE__->contained_objects
  (
   document => { delayed => 1,
		 class => 'AI::Categorizer::Document' },
   category => { delayed => 1,
		 class => 'AI::Categorizer::Category' },
   collection => { delayed => 1,
		   class => 'AI::Categorizer::Collection::Files' },
   features => { delayed => 1,
		 class => 'AI::Categorizer::FeatureVector' },
  );

sub new {
  my ($pkg, %args) = @_;
  
  # Shortcuts
  if ($args{tfidf_weighting}) {
    @args{'term_weighting', 'collection_weighting', 'normalize_weighting'} = split '', $args{tfidf_weighting};
    delete $args{tfidf_weighting};
  }

  my $self = $pkg->SUPER::new(%args);

  # Convert to AI::Categorizer::ObjectSet sets
  $self->{categories} = new AI::Categorizer::ObjectSet( @{$self->{categories}} );
  $self->{documents}  = new AI::Categorizer::ObjectSet( @{$self->{documents}}  );

  if ($self->{load}) {
    my $args = ref($self->{load}) ? $self->{load} : { path => $self->{load} };
    $self->load(%$args);
    delete $self->{load};
  }
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
  my $v = $self->create_delayed_object('features', features => {});
  foreach my $document ($self->documents) {
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

sub document {
  my ($self, $name) = @_;
  return $self->{documents}->retrieve($name);
}

sub verbose {
  my $self = shift;
  $self->{verbose} = shift if @_;
  return $self->{verbose};
}

sub trim_doc_features {
  my ($self) = @_;
  
  foreach my $doc ($self->documents) {
    $doc->features( $doc->features->intersection($self->features) );
  }
}


sub prog_bar {
  my ($self, $collection) = @_;

  return sub {} unless $self->verbose;
  return sub { print STDERR '.' } unless eval "use Time::Progress; 1";

  my $count = $collection->can('count_documents') ? $collection->count_documents : 0;

  my $pb = 'Time::Progress'->new;
  $pb->attr(max => $count);
  my $i = 0;
  return sub {
    $i++;
    return if $i % 25;
    print STDERR $pb->report("%50b %p ($i/$count)\r", $i);
  };
}

sub scan_stats {
  # Should determine:
  #  - number of documents
  #  - number of categories
  #  - avg. number of categories per document (whole corpus)
  #  - avg. number of tokens per document (whole corpus)
  #  - avg. number of types per document (whole corpus)
  #  - number of documents, tokens, & types for each category
  #  - "category skew index" (% variance?) by num. documents, tokens, and types

  my ($self, %args) = @_;
  my $collection = $self->create_delayed_object('collection', %args);
  my $pb = $self->prog_bar($collection);

  my %stats;


  while (my $doc = $collection->next) {
    $pb->();
    $stats{category_count_with_duplicates} += $doc->categories;

    my ($sum, $length) = ($doc->features->sum, $doc->features->length);
    $stats{document_count}++;
    $stats{token_count} += $sum;
    $stats{type_count}  += $length;
    
    foreach my $cat ($doc->categories) {
#warn $doc->name, ": ", $cat->name, "\n";
      $stats{categories}{$cat->name}{document_count}++;
      $stats{categories}{$cat->name}{token_count} += $sum;
      $stats{categories}{$cat->name}{type_count}  += $length;
    }
  }
  print "\n" if $self->verbose;

  my @cats = keys %{ $stats{categories} };

  $stats{category_count}          = @cats;
  $stats{categories_per_document} = $stats{category_count_with_duplicates} / $stats{document_count};
  $stats{tokens_per_document}     = $stats{token_count} / $stats{document_count};
  $stats{types_per_document}      = $stats{type_count}  / $stats{document_count};

  foreach my $thing ('type', 'token', 'document') {
    $stats{"${thing}s_per_category"} = AI::Categorizer::Util::average
      ( map { $stats{categories}{$_}{"${thing}_count"} } @cats );

    next unless @cats;

    # Compute the skews
    my $ssum;
    foreach my $cat (@cats) {
      $ssum += ($stats{categories}{$cat}{"${thing}_count"} - $stats{"${thing}s_per_category"}) ** 2;
    }
    $stats{"${thing}_skew_by_category"} = sqrt($ssum/@cats) / $stats{"${thing}s_per_category"};
  }

  return \%stats;
}

sub load {
  my ($self, %args) = @_;
  
  if ($args{scan_features}) {
    # Figure out the feature set first, then read data in
    $self->scan_features( path => $args{path} );
    $self->read( path => $args{path} );

  } elsif (my $fk = exists($args{features_kept}) ? $args{features_kept} : $self->{features_kept}) {
    # Read the whole thing in, then reduce
    $self->read( path => $args{path} );
    $self->select_features( features_kept => $fk );

  } else {
    # Don't do any feature reduction, just read the data
    $self->read( path => $args{path} );
  }
}

sub read {
  my ($self, %args) = @_;
  my $collection = $self->create_delayed_object('collection', %args);
  my $pb = $self->prog_bar($collection);

  while (my $doc = $collection->next) {
    $pb->();
    $self->add_document($doc);
  }
  print "\n" if $self->verbose;
}

sub finish {
  # This could be made more efficient by figuring out an execution
  # plan in advance

  my $self = shift;
  return if $self->{finished}++;
  
  if ( $self->{term_weighting} =~ /^(t|x)$/ ) {
    # Nothing to do
  } elsif ( $self->{term_weighting} eq 'l' ) {
    foreach my $doc ($self->documents) {
      my $f = $doc->features->as_hash;
      $_ = 1 + log($_) foreach values %$f;
    }
  } elsif ( $self->{term_weighting} eq 'n' ) {
    foreach my $doc ($self->documents) {
      my $f = $doc->features->as_hash;
      my $max_tf = AI::Categorizer::Util::max values %$f;
      $_ = 0.5 + 0.5 * $_ / $max_tf foreach values %$f;
    }
  } elsif ( $self->{term_weighting} eq 'b' ) {
    foreach my $doc ($self->documents) {
      my $f = $doc->features->as_hash;
      $_ = $_ ? 1 : 0 foreach values %$f;
    }
  } else {
    die "term_weighting must be one of 'x', 't', 'l', 'b', or 'n'";
  }
  
  if ($self->{collection_weighting} eq 'x') {
    # Nothing to do
  } elsif ($self->{collection_weighting} =~ /^(f|p)$/) {
    my $subtrahend = ($1 eq 'f' ? 0 : 1);
    my $num_docs = $self->documents;
    $self->document_frequency('foo');  # Initialize
    foreach my $doc ($self->documents) {
      my $f = $doc->features->as_hash;
      $f->{$_} *= log($num_docs / $self->{doc_freq_vector}{$_} - $subtrahend) foreach keys %$f;
    }
  } else {
    die "collection_weighting must be one of 'x', 'f', or 'p'";
  }

  if ( $self->{normalize_weighting} eq 'x' ) {
    # Nothing to do
  } elsif ( $self->{normalize_weighting} eq 'c' ) {
    $_->features->normalize foreach $self->documents;
  } else {
    die "normalize_weighting must be one of 'x' or 'c'";
  }
}

sub document_frequency {
  my ($self, $term) = @_;
  
  unless (exists $self->{doc_freq_vector}) {
    die "No corpus has been scanned for features" unless $self->documents;

    my $doc_freq = $self->create_delayed_object('features', features => {});
    foreach my $doc ($self->documents) {
      $doc_freq->add( $doc->features->as_boolean_hash );
    }
    $self->{doc_freq_vector} = $doc_freq->as_hash;
  }
  
  return exists $self->{doc_freq_vector}{$term} ? $self->{doc_freq_vector}{$term} : 0;
}

sub scan_features {
  my ($self, %args) = @_;

  my $ranked_features;

  if ($self->{feature_selection} eq 'document_frequency') {
    my $doc_freq   = $self->create_delayed_object('features', features => {});
    my $collection = $self->create_delayed_object('collection', %args);
    my $pb = $self->prog_bar($collection);
    
    while (my $doc = $collection->next) {
      $pb->();
      $doc_freq->add( $doc->features->as_boolean_hash );
    }
    print "\n" if $self->verbose;
    
    $ranked_features = $self->_reduce_features($doc_freq);
    $self->{doc_freq_vector} = $ranked_features->as_hash;
  } else {
    die "Unknown feature_selection type '$self->{feature_selection}'";
  }
  
  $self->delayed_object_params('document', use_features => $ranked_features);
  $self->delayed_object_params('collection', use_features => $ranked_features);
}

sub _reduce_features {
  # Takes a feature vector whose weights are "feature scores", and
  # chops to the highest n features.  n is specified by the
  # 'features_kept' parameter.  If it's zero, all features are kept.
  # If it's between 0 and 1, we multiply by the present number of
  # features.  If it's greater than 1, we treat it as the number of
  # features to use.

  my ($self, $f, $kept) = @_;
  $kept ||= $self->{features_kept};
  return $f unless $kept;

  my $num_kept = ($kept < 1 ? 
		  $f->length * $kept :
		  $kept);

  print "Trimming features - # features = " . $f->length . "\n" if $self->{verbose};
  
  # This is algorithmic overkill, but the sort seems fast enough.  Will revisit later.
  my $features = $f->as_hash;
  my @new_features = (sort {$features->{$b} <=> $features->{$a}} keys %$features)
                      [0 .. $num_kept-1];

  my $result = $f->intersection( \@new_features );
  print "Finished trimming features - # features = " . $result->length . "\n" if $self->{verbose};
  return $result;
}


sub select_features {
  # This just uses a simple document-frequency criterion, controlled
  # by 'features_kept'.  Other algorithms may follow later, controlled
  # by other parameters.

# XXX this is doing word-frequency right now, not document-frequency

  my ($self, %args) = @_;
  
  my $f = $self->_reduce_features($self->features, $args{features_kept});
  $self->features($f);
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
  my @cats = map { $self->call_method('category', 'by_name', name => $_) } @$cats;
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

sub save_features {
  my ($self, $file) = @_;
  
  my $f = ($self->{features} || { $self->delayed_object_params('document') }->{use_features})
    or croak "No features to save";
  
  open my($fh), "> $file" or croak "Can't create $file: $!";
  my $h = $f->as_hash;
  print $fh "# Total: ", $f->length, "\n";
  
  foreach my $k (sort {$h->{$b} <=> $h->{$a}} keys %$h) {
    print $fh "$k\t$h->{$k}\n";
  }
  close $fh;
}

sub restore_features {
  my ($self, $file, $n) = @_;
  
  open my($fh), "< $file" or croak "Can't open $file: $!";

  my %hash;
  while (<$fh>) {
    next if /^#/;
    /^(.*)\t([\d.]+)$/ or croak "Malformed line: $_";
    $hash{$1} = $2;
    last if defined $n and $. >= $n;
  }
  my $features = $self->create_delayed_object('features', features => \%hash);
  
  $self->delayed_object_params('document',   use_features => $features);
  $self->delayed_object_params('collection', use_features => $features);
}

1;

__END__

=item term_weighting

Specifies how word counts should be converted to feature vector
values.  If C<term_weighting> is set to C<natural>, the word counts
themselves will be used as the values.  C<boolean> indicates that each
positive word count will be converted to 1 (or whatever the
C<content_weight> for this section is).  C<log> indicates that the
values will be set to C<1+log(count)>.

