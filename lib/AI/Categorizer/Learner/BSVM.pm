use strict;

package AI::Categorizer::Learner::BSVM;

use AI::Categorizer::Learner::Boolean;
use base qw(AI::Categorizer::Learner::Boolean);
use Params::Validate qw(:types);
use File::Spec;
use File::Copy;
use File::Path ();
use File::Temp ();

__PACKAGE__->valid_params
  (
   bsvm_train_path   => {type => SCALAR, default => 'bsvm-train'},
   bsvm_predict_path => {type => SCALAR, default => 'bsvm-predict'},
   tmpdir => {type => SCALAR, default => File::Spec->tmpdir},
  );

__PACKAGE__->contained_objects
  (
   features => {class => 'AI::Categorizer::FeatureVector', delayed => 1},
  );

sub create_model {
  my ($self) = shift;
  my $m = $self->{model} ||= {};
  $m->{all_features} = [ $self->knowledge_set->features->names ];
  $m->{rev_features} = { map {( $m->{all_features}[$_] => $_ )} 0..$#{$m->{all_features}} };
  $m->{_in_dir} = File::Temp::tempdir( DIR => $self->{tmpdir} );

  $self->SUPER::create_model(@_);
}

# bsvm-train -t 2 -c 1000  vehicle.scale vehicle_model

sub create_boolean_model {
  my ($self, $pos, $neg, $cat) = @_;

  # Create the training file
  my ($train_fh, $train_file) = $self->new_data_file($cat->name . '_train');
warn "Creating training file '$train_file'" if $self->{verbose};
  foreach my $doc (@$pos) {
    print $train_fh $self->data_file_line($doc->features, 1);
  }
  foreach my $doc (@$neg) {
    print $train_fh $self->data_file_line($doc->features, 0);
  }
  close $train_fh;
  
  my %info = (machine_file => $cat->name . '_model');
  my $outfile = File::Spec->catfile($self->{model}{_in_dir}, $info{machine_file});
  
  my @args = ($self->{bsvm_train_path},
	      '-t', 2,
	      '-c', 1000,
	      $train_file,
	      $outfile,
	     );
  
  $self->do_cmd(@args);
#  unlink $train_file or warn "Couldn't remove $train_file: $!";

  return \%info;
}

# bsvm-predict vehicle.scale vehicle_model classified_result

sub get_boolean_score {
  my ($self, $doc, $info) = @_;
  
  # Create document file
  my $doc_file = $self->create_data_file('doc', [[$doc->features, 0]], $self->{tmpdir});
  my $machine_file = File::Spec->catfile($self->{model}{_in_dir}, $info->{machine_file});
  my $outfile = File::Temp::tmpnam($self->{tmpdir});

  my @args = ($self->{bsvm_predict_path},
	      $doc_file,
	      $machine_file,
	      $outfile);
  $self->do_cmd(@args);

  open my($fh), '<', $outfile or die "Can't read result file '$outfile': $!";
  my $result;
  while (<$fh>) {
    $result = $1, last if /(\d+)/;
  }
  unlink $outfile or warn "Couldn't clean up '$outfile': $!";
  
  return $result;
}

sub categorize_collection {
  my ($self, %args) = @_;
  my $c = $args{collection} or die "No collection provided";

  # Create the data file
  my ($doc_fh, $doc_file) = $self->new_data_file("docs");
  while (my $d = $c->next) {
    print $doc_fh $self->data_file_line($d->features, 0);
  }
  close $doc_fh;

  my $outfile = File::Temp::tmpnam($self->{tmpdir});
  
  my @assigned;
  my $l = $self->{model}{learners};
  foreach my $cat (keys %$l) {
    my $machine_file = File::Spec->catfile($self->{model}{_in_dir}, "${cat}_model");
    my @args = ($self->{bsvm_predict_path},
		$doc_file,
		$machine_file,
		$outfile);
    $self->do_cmd(@args);
    
    open my($fh), '<', $outfile or die "Can't read result file '$outfile': $!";
    my $index = 0;
    while (<$fh>) {
      next unless /^\d+$/;
      $assigned[$index]{$cat} = 1 if /1/;
      $index++;
    }
  }
  unlink $outfile or warn "Couldn't clean up '$outfile': $!";

  # Sum up the results in an Experiment object
  my $experiment = $self->create_delayed_object('experiment', categories => [map $_->name, $self->categories]);
  
  my $i = 0;
  $c->rewind;
  while (my $d = $c->next) {
    $experiment->add_result([keys %{$assigned[$i]}], [map $_->name, $d->categories], $d->name);
    $i++;
  }

  return $experiment;
}


sub do_cmd {
  my ($self, @cmd) = @_;
  print STDERR " % @cmd\n" if $self->verbose;
  system @cmd;
}

sub new_data_file {
  my ($self, $name, $dir) = @_;
  $dir = $self->{model}{_in_dir} unless defined $dir;

  my ($fh, $filename) = File::Temp::tempfile(
					     $name . "_XXXX",  # Template
					     DIR    => $dir,
					     SUFFIX => '.scale',
					    );
  return ($fh, $filename);
}

sub data_file_line {
  my ($self, $features, $cat) = @_;
  my $f = $features->normalize->as_hash;
  return "$cat " . join(' ', map "$self->{model}{rev_features}{$_}:$f->{$_}", keys %$f) . "\n";
}

sub create_data_file {
  my ($self, $name, $docs, $dir) = @_;
  my $feature_indices = $self->{model}{rev_features};

  my ($fh, $filename) = $self->new_data_file($name, $dir);
  
  foreach my $doc (@$docs) {
    print $fh $self->data_file_line(@$doc);
  }
  
  return $filename;
}

sub save_state {
  my ($self, $path) = @_;

  {
    local $self->{knowledge_set};
    $self->SUPER::save_state($path);
  }
  return unless $self->{model};

  my $model_dir = File::Spec->catdir($path, 'models');
  mkdir($model_dir, 0777) or die "Couldn't create $model_dir: $!";
  while (my ($name, $learner) = each %{$self->{model}{learners}}) {
    my $oldpath = File::Spec->catdir($self->{model}{_in_dir}, $learner->{machine_file});
    my $newpath = File::Spec->catfile($model_dir, "${name}_model");
    File::Copy::copy($oldpath, $newpath);
  }
  $self->{model}{_in_dir} = $model_dir;
}

sub restore_state {
  my ($pkg, $path) = @_;
  
  my $self = $pkg->SUPER::restore_state($path);

  my $model_dir = File::Spec->catdir($path, 'models');
  return $self unless -e $model_dir;
  $self->{model}{_in_dir} = $model_dir;
  
  return $self;
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
C<Inline::Java> wrapper for better performance (faster running
times).  However, if you're looking for really great performance,
you're probably looking in the wrong place - this Weka wrapper is
intended more as a way to try lots of different machine learning
methods.

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

=item java_args

Specifies a list of any additional arguments to give to the java
process.  Commonly it's necessary to allocate more memory than the
default, using an argument like C<-Xmx130MB>.

=item weka_path

Specifies the path to the C<weka.jar> file containing the Weka
bytecode.  If Weka has been installed somewhere in your java
C<CLASSPATH>, you needn't specify a C<weka_path>.

=item weka_classifier

Specifies the Weka class to use for a categorizer.  The default is
C<weka.classifiers.NaiveBayes>.  Consult your Weka documentation for a
list of other classifiers available.

=item weka_args

Specifies a list of any additional arguments to pass to the Weka
classifier class when building the categorizer.

=item tmpdir

A directory in which temporary files will be written when training the
categorizer and categorizing new documents.  The default is given by
C<< File::Spec->tmpdir >>.

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

=head1 SEE ALSO

AI::Categorizer(3)

=cut
