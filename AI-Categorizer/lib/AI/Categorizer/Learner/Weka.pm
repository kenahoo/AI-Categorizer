package AI::Categorizer::Learner::Weka;

use strict;
use AI::Categorizer::Learner;
use base qw(AI::Categorizer::Learner);
use Params::Validate qw(:types);
use File::Spec;
use File::Copy;
use File::Path ();


__PACKAGE__->valid_params
  (
   java_path => {type => SCALAR, default => 'java'},
   java_args => {type => SCALAR|ARRAYREF, optional => 1},
   weka_path => {type => SCALAR, optional => 1},
   weka_classifier => {type => SCALAR, default => 'weka.classifiers.NaiveBayes'},
   weka_args => {type => SCALAR|ARRAYREF, optional => 1},
   tmpdir => {type => SCALAR, default => '/tmp'},
  );

__PACKAGE__->contained_objects
  (
   features => {class => 'AI::Categorizer::FeatureVector', delayed => 1},
  );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  for ('java_args', 'weka_args') {
    $self->{$_} = [] unless defined $self->{$_};
    $self->{$_} = [$self->{$_}] unless UNIVERSAL::isa($self->{$_}, 'ARRAY');
  }
  
  if (defined $self->{weka_path}) {
    push @{$self->{java_args}}, '-classpath', $self->{weka_path};
    delete $self->{weka_path};
  }
  return $self;
}

# java -classpath /Applications/Science/weka-3-2-3/weka.jar weka.classifiers.NaiveBayes -t /tmp/train_file.arff -d /tmp/weka-machine

sub create_model {
  my $self = shift;
  my $m = $self->{model} = {};
  
  $m->{categories} = [ $self->knowledge_set->categories ];
  $m->{all_features} = [ $self->knowledge_set->features->names ];
  
  # Create data file $train_file in ARFF format
  my $train_file = File::Spec->catfile($self->{tmpdir}, 'train_file.arff');

  my @docs = map { [$_->features, $_->categories ? ($_->categories)[0]->name : 'unknown'] } $self->knowledge_set->documents;

  $self->create_arff_file($train_file, \@docs);
  
  # Create a dummy test file $dummy_file in ARFF format (a kludgey WEKA requirement)
  my $dummy_file = File::Spec->catfile($self->{tmpdir}, 'dummy.arff');
  my $dummy_features = $self->create_delayed_object('features');
  $self->create_arff_file($dummy_file, [[$dummy_features, 'unknown']]);

  my $outfile = File::Spec->catfile($self->{tmpdir}, 'weka-machine');

  my @args = ($self->{java_path},
	      @{$self->{java_args}},
	      $self->{weka_classifier}, 
	      @{$self->{weka_args}},
	      '-t', $train_file,
	      '-T', $dummy_file,
	      '-d', $outfile,
	      '-v',
	      '-p', '0',
	     );
  $self->do_cmd(@args);
  
  $m->{machine_file} = $outfile;
  return $m;
}

# java -classpath /Applications/Science/weka-3-2-3/weka.jar weka.classifiers.NaiveBayes -l out -T test.arff -p 0

sub get_scores {
  my ($self, $doc) = @_;

  # XXX Create document file
  my $doc_file = File::Spec->catfile( $self->{tmpdir}, "doc_$$" );
  my $cat = $doc->categories ? ($doc->categories)[0]->name : 'unknown';
  $self->create_arff_file($doc_file, [[$doc->features, $cat]]);

  my @args = ($self->{java_path},
	      @{$self->{java_args}},
	      $self->{weka_classifier},
	      '-l', $self->{model}{machine_file},
	      '-T', $doc_file,
	      '-p', 0,
	     );

  my @output = $self->do_cmd(@args);

  my $scores = { map {$_->name,0} @{ $self->{model}{categories} } };
  foreach (@output) {
    # 0 large.elem 0.4515551620220952 numberth.high
    next unless my ($index, $predicted, $score) = /^([\d.]+)\s+(\S+)\s+([\d.]+)/;
    $scores->{$predicted} = 1;
  }

  return ($scores, 0.5);
}

sub categorize_collection {
  my ($self, %args) = @_;
  my $c = $args{collection} or die "No collection provided";
  
  my $doc_file = File::Spec->catfile( $self->{tmpdir}, "doc_$$" );
  my @docs;
  while (my $d = $c->next) {
    push @docs, [$d->features, $d->categories ? ($d->categories)[0]->name : 'unknown'];
  }
  $self->create_arff_file($doc_file, \@docs);
  
  my $experiment = $self->create_delayed_object('experiment', categories => [map $_->name, $self->categories]);
  
  my @args = ($self->{java_path},
              @{$self->{java_args}},
              $self->{weka_classifier},
              '-l', $self->{model}{machine_file},
              '-T', $doc_file,
              '-p', 0,
             );
  
  my @output = $self->do_cmd(@args);
  foreach my $line (@output) {
    # 0 large.elem 0.4515551620220952 numberth.high
    unless ( $line =~ /^([\d.]+)\s+(\S+)\s+([\d.]+)\s+(\S+)/ ) {
      warn "Can't parse line $line";
      next;
    }
    my ($index, $predicted, $score, $real) = ($1, $2, $3, $4);
    $experiment->add_result($predicted, $real, $index);

    if ($self->verbose) {
      print STDERR "$index: assigned=($predicted) correct=($real)\n";
    }
  }

  return $experiment;
}


sub do_cmd {
  my ($self, @cmd) = @_;
  print STDERR " % @cmd\n" if $self->verbose;
  
  my @output;
  local *KID_TO_READ;
  my $pid = open(KID_TO_READ, "-|");
  
  if ($pid) {   # parent
    @output = <KID_TO_READ>;
    close(KID_TO_READ) or warn "@cmd exited $?";
    
  } else {      # child
    exec(@cmd) or die "Can't exec @cmd: $!";
  }
  
  return @output;
}


sub create_arff_file {
  my ($self, $file, $docs) = @_;
  
  open my $fh, "> $file" or die "Can't create $file: $!";
  print $fh "\@RELATION foo\n\n";
  
  my $feature_names = $self->{model}{all_features};
  foreach my $name (@$feature_names) {
    print $fh "\@ATTRIBUTE feature-$name REAL\n";
  }
  print $fh "\@ATTRIBUTE category {", join(',', map($_->name, $self->categories), 'unknown'), "}\n\n";
  
  my %feature_indices = map {$feature_names->[$_], $_} 0..$#{$feature_names};
  my $last_index = keys %feature_indices;
  
  # We use the 'sparse' format, see http://www.cs.waikato.ac.nz/~ml/weka/arff.html
  
  print $fh "\@DATA\n";
  foreach my $doc (@$docs) {
    my ($features, $cat) = @$doc;
    my $f = $features->as_hash;
    my @ordered_keys = (sort {$feature_indices{$a} <=> $feature_indices{$b}} 
			grep {exists $feature_indices{$_}}
			keys %$f);

    print $fh ("{",
	       join(', ', map("$feature_indices{$_} $f->{$_}", @ordered_keys), "$last_index '$cat'"),
	       "}\n"
	      );
  }
}

sub save_state {
  my ($self, $path) = @_;
  local $self->{knowledge_set};  # Don't need the knowledge_set to categorize

  if (-e $path) {
    File::Path::rmtree($path, 1, 0);
    die "Couldn't remove existing $path" if -e $path;
  }

  mkdir $path or die "Couldn't create dir $path: $!";
  $self->SUPER::save_state(File::Spec->catfile($path, 'self'));
  File::Copy::copy($self->{model}{machine_file}, File::Spec->catfile($path, 'weka-machine'));
}

sub restore_state {
  my ($pkg, $path) = @_;
  
  my $self = $pkg->SUPER::restore_state( File::Spec->catfile($path, 'self') );
  $self->{model}{machine_file} = File::Spec->catfile($path, 'weka-machine');
  
  return $self;
}

sub categories {
  my $self = shift;
  return @{ $self->{model}{categories} };
}

1;

__END__

=head1 NAME

AI::Categorizer::Learner::Weka - Pass-through wrapper to Weka system

=head1 SYNOPSIS

  use AI::Categorizer::Learner::Weka;
  
  # Here $k is an AI::Categorizer::KnowledgeSet object
  
  my $nb = new AI::Categorizer::Learner::Weka(...parameters...);
  $nb->train(knowledge_set => $k);
  $nb->save_state('filename');
  
  ... time passes ...
  
  $nb = AI::Categorizer::Learner->restore_state('filename');
  my $c = new AI::Categorizer::Collection::Files( path => ... );
  while (my $document = $c->next) {
    my $hypothesis = $nb->categorize($document);
    print "Best assigned category: ", $hypothesis->best_category, "\n";
  }

=head1 DESCRIPTION

This class doesn't implement any machine learners of its own, it
merely passes the data through to the Weka machine learning system
(http://www.cs.waikato.ac.nz/~ml/weka/).  This can give you access to
a collection of machine learning algorithms not otherwise implemented
in C<AI::Categorizer>.

Currently this is a simple command-line wrapper that calls C<java>
subprocesses.  In the future this may be converted to an
C<Inline::Java> wrapper for better performance (shorter running
times).  However, if you're looking for really great performance,
you're probably looking in the wrong place - this Weka wrapper is
intended more as a way to try lots of different machine learning
methods.

One important caveat: at the moment, this learner can only handle one
category per document, in both training and runtime assignment.  This
is because it's difficult to get Weka to do otherwise.  Also, some
classifiers (like SMO, the Support Vector Machine implementation) can
only handle a single I<binary> classification, so you might want to
check out Weka's MultipleClassClassifier to help with this situation.

=head1 METHODS

This class inherits from the C<AI::Categorizer::Learner> class, so all
of its methods are available unless explicitly mentioned here.

=head2 new()

Creates a new Weka Learner and returns it.  In addition to the
parameters accepted by the C<AI::Categorizer::Learner> class, the
Weka subclass accepts the following parameters:

=over 4

=item java_path

Specifies where the C<java> executable can be found on this system.
The default is simply C<java>, meaning that it will search your
C<PATH> to find java.

=item weka_path

Specifies the path to the C<weka.jar> file containing the Weka
bytecode.  If Weka has been installed somewhere in your java
C<CLASSPATH>, you needn't specify a C<weka_path>.

=item java_args

Specifies a list of any additional arguments to give to the java
process.  Commonly it's necessary to allocate more memory than the
default, using an argument like C<-Xmx130MB>.

=item weka_args

Specifies a list of any additional arguments to pass to the Weka
classifier class when building the categorizer.

=item weka_classifier

Specifies the Weka class to use for a categorizer.  The default is
C<weka.classifiers.NaiveBayes>.  Consult your Weka documentation for a
list of other classifiers available.

=item tmpdir

A directory in which temporary files will be written when training the
categorizer and categorizing new documents.  The default is C</tmp>.

=back

=head2 train(knowledge_set => $k)

Trains the categorizer.  This prepares it for later use in
categorizing documents.  The C<knowledge_set> parameter must provide
an object of the class C<AI::Categorizer::KnowledgeSet> (or a subclass
thereof), populated with lots of documents and categories.  See
L<AI::Categorizer::KnowledgeSet> for the details of how to create such
an object.

=head2 categorize($document)

Returns an C<AI::Categorizer::Hypothesis> object representing the
categorizer's "best guess" about which categories the given document
should be assigned to.  See L<AI::Categorizer::Hypothesis> for more
details on how to use this object.

=head2 save_state($path)

Saves the categorizer for later use.  This method is inherited from
C<AI::Categorizer::Storable>.

=head1 AUTHOR

Ken Williams, ken@forum.swarthmore.edu

=head1 COPYRIGHT

Copyright 2000-2002 Ken Williams.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

AI::Categorize(3)

=cut
