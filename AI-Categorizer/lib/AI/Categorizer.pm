package AI::Categorizer;
$VERSION = '0.02';

use strict;
use Class::Container 0.02;
use base qw(Class::Container);
use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   save_progress => { type => SCALAR, default => 'save' },
   knowledge_set => { isa => 'AI::Categorizer::KnowledgeSet' },
   learner       => { isa => 'AI::Categorizer::Learner' },
   verbose       => { type => BOOLEAN, default => 0 },
   training_set  => { type => SCALAR, optional => 1 },
   test_set      => { type => SCALAR, optional => 1 },
   data_root     => { type => SCALAR, optional => 1 },
  );

__PACKAGE__->contained_objects
  (
   knowledge_set => { class => 'AI::Categorizer::KnowledgeSet' },
   learner       => { class => 'AI::Categorizer::Learner::NaiveBayes' },
   experiment    => { class => 'AI::Categorizer::Experiment',
		      delayed => 1 },
   collection    => { class => 'AI::Categorizer::Collection::Files',
		      delayed => 1 },
  );

sub new {
  my $package = shift;
  my %args = @_;
  my %defaults;
  if (exists $args{data_root}) {
    $defaults{training_set} = "$args{data_root}/training";
    $defaults{test_set} = "$args{data_root}/test";
    $defaults{category_file} = "$args{data_root}/cats.txt";
    delete $args{data_root};
  }

  return $package->SUPER::new(%defaults, %args);
}

sub knowledge_set { shift->{knowledge_set} }
sub learner       { shift->{learner} }

# Combines several methods in one sub
sub run_experiment {
  my $self = shift;
  $self->scan_features;
  $self->read_training_set;
  $self->train;
  $self->evaluate_test_set;
  print $self->stats_table;
}

sub scan_features {
  my $self = shift;
  $self->knowledge_set->scan_features( path => $self->{training_set} );
  $self->_save_progress( '01', 'knowledge_set' );
}

sub read_training_set {
  my $self = shift;
  $self->_load_progress( '01', 'knowledge_set' );
  $self->knowledge_set->read( path => $self->{training_set} );
  $self->_save_progress( '02', 'knowledge_set' );
}

sub train {
  my $self = shift;
  $self->_load_progress( '02', 'knowledge_set' );
  $self->learner->train( knowledge_set => $self->{knowledge_set} );
  $self->_save_progress( '03', 'learner' );
}

sub evaluate_test_set {
  my $self = shift;
  $self->_load_progress( '03', 'learner' );
  my $c = $self->create_delayed_object('collection', path => $self->{test_set} );
  my @all_cats = map $_->name, $self->knowledge_set->categories;
  $self->{experiment} = $self->create_delayed_object('experiment', categories => \@all_cats);
  while (my $d = $c->next) {
    my $h = $self->learner->categorize($d);
    $self->{experiment}->add_result([$h->categories], [map $_->name, $d->categories], $d->name);
  }
  $self->_save_progress( '04', 'experiment' );
}

sub stats_table {
  my $self = shift;
  $self->_load_progress( '04', 'experiment' );
  return $self->{experiment}->stats_table;
}

sub _save_progress {
  my ($self, $stage, $node) = @_;
  return unless $self->{save_progress};
  my $file = "$self->{save_progress}-$stage-$node";
  warn "Saving to $file\n" if $self->{verbose};
  $self->{$node}->save_state($file);
}

sub _load_progress {
  my ($self, $stage, $node) = @_;
  return unless $self->{save_progress};
  my $file = "$self->{save_progress}-$stage-$node";
  warn "Loading $file\n" if $self->{verbose};
  $self->{$node} = $self->contained_class($node)->restore_state($file);
}

1;
__END__

=head1 NAME

AI::Categorizer - Automatic Text Categorization

=head1 SYNOPSIS

 use AI::Categorizer;
 my $c = new AI::Categorizer(...parameters...);
 
 # Run a complete experiment - training on a corpus, testing on a test
 # set, printing a summary of results to STDOUT
 $c->run_experiment;
 
 # Run the parts of $c->run_experiment separately
 $c->scan_features;
 $c->read_training_set;
 $c->train;
 $c->evaluate_test_set;
 print $c->stats_table;
 
 # After training, use the Learner for categorization
 my $l = $c->learner;
 while (...) {
   my $d = ...create a document...
   my $hypothesis = $l->categorize($d);  # An AI::Categorizer::Hypothesis object
 }
 
=head1 DESCRIPTION

C<AI::Categorizer> is a framework for automatic text categorization.
It consists of a collection of Perl modules that implement common
categorization tasks, and a set of defined relationships among those
modules.  The various details are flexible - for example, you can
choose what categorization algorithm to use, what features (words or
otherwise) of the documents should be used (or how to automatically
choose these features), what format the documents are in, and so on.

The basic process of using this module will typically involve
obtaining a collection of B<pre-categorized> documents, creating a
knowledge set representation of those documents, training a
categorizer on that knowledge set, and saving the trained categorizer
for later use.  There are several ways to achieve this process.  The
top-level C<AI::Categorizer> module provides an umbrella class for
high-level operations, or you may use the interfaces of the individual
classes in the framework.

Disclaimer: the results of any of the machine learning algorithms are
far from infallible (close to fallible?).  Categorization of documents
is often a difficult task even for humans well-trained in the
particular domain of knowledge, and there are many things a human
would consider that none of these algorithms consider.  These are only
statistical tests - at best they are neat tricks or helpful
assistants, and at worst they are totally unreliable.  If you plan to
use this module for anything important, human supervision is
essential, both of the categorization process and the final results.

For the usage details, please see the documentation of each individual
module.

=head1 Framework Components

This section explains the major pieces of the C<AI::Categorizer>
object framework.  This section gives a conceptual overview, but does
not get into any of the details about interfaces or usage.  See the
documentation for the individual classes for more details.

=head2 Knowledge Sets

A "knowledge set" is defined as a collection of documents, stored in a
particular format, together with some information on the categories
each document belongs to.  Note that this term is somewhat unique to
this project - other sources may call it a "training corpus", or
"prior knowledge".

A knowledge set is encapsulated by the
C<AI::Categorizer::KnowledgeSet> class.  Before you can start playing
with categorizers, you will have to start playing with knowledge sets,
so that the categorizers have some data to train on.  See the
documentation for the C<AI::Categorizer::KnowledgeSet> module for
information on its interface.

=head2 Categorization Algorithms

Currently two different algorithms are implemented in this bundle,
with more to come:

  AI::Categorizer::Learner::NaiveBayes
  AI::Categorizer::Learner::NNetTC

These are subclasses of C<AI::Categorizer::Learner>.  The NNetTC
module is currently just a wrapper around a proprietary Neural Net
implementation.  A separate NNet categorizer is planned, and when it
is implemented we will drop the NNetTC package from the distribution
(since nobody else has the libraries it depends on, and for licensing
reasons they couldn't use them even if they had them).

Several other Learner classes are planned, including a
k-Nearest-Neighbor class, a Decision Tree class, a Mixture of Experts
meta-class, and the NNet class mentioned above.  No timetable for
their creation has yet been set.

Please see the documentation of these individual modules for more
details on their guts and quirks.  See the C<AI::Categorizer::Learner>
documentation for a description of the general categorizer interface.

=head2 Feature Vectors

Most categorization algorithms don't deal directly with a document's
data, they instead deal with a I<vector representation> of a
document's I<features>.  The features may be any properties of the
document that seem indicative of its category, but they are usually
some version of the "most important" words in the document.  A list of
features and their weights in each document is encapsulated by the
C<AI::Categorizer::FeatureVector> class.  You may think of this class
as roughly analogous to a Perl hash, where the keys are the names of
features and the values are their weights.

=head2 Feature Selection

Deciding which features are the most important is a very large part of
the categorization task - you cannot simply consider all the words in
all the documents when training, and all the words in the document
being categorized.  There are two main reasons for this - first, it
would mean that your training and categorizing processes would take
forever and use tons of memory, and second, the significant bits of
the documents would get lost in the "noise" of the insignificant bits.

The process of selecting the most important features in the training
set is called "feature selection".  It is managed by the
C<AI::Categorizer::KnowledgeSet> class, and you will find the details
of feature selection processes in that class's documentation.

=head2 Hypotheses

The result of asking a categorizer to categorize a previously unseen
document is called a hypothesis, because it is some kind of
"statistical guess" of what categories this document should be
assigned to.  Since you may be interested in any of several pieces of
information about the hypothesis (for instance, which categories were
assigned, which category was the single most likely category, the
scores assigned to each category, etc.), the hypothesis is returned as
an object of the C<AI::Categorizer::Hypothesis> class, and you can use
its object methods to get information about the hypothesis.  See its
class documentation for the details.

=head2 Experiments

The C<AI::Categorizer::Experiment> class helps you organize the
results of categorization experiments.  As you get lots of
categorization results (Hypotheses) back from the Learner, you can
feed these results to the Experiment class, along with the correct
answers.  When all results have been collected, you can get a report
on accuracy, precision, recall, F1, and so on, with both
micro-averaging and macro-averaging over categories.  See the docs for
C<AI::Categorizer::Experiment> for more details.

=head1 HISTORY

This module is a revised and redesigned version of the previous
C<AI::Categorize> module by the same author.  Note the added 'r' in
the new name.  The older module has a different interface, and no
attempt at backward compatibility has been made - that's why I changed
the name.

You can have both C<AI::Categorize> and C<AI::Categorizer> installed
at the same time on the same machine, if you want.  They don't know
about each other or use conflicting namespaces.

=head1 AUTHOR

Ken Williams <kenw@ee.usyd.edu.au>

=head1 REFERENCES

http://www.d.umn.edu/~tpederse/nsp.html (could be used later for
feature selection)

=head1 COPYRIGHT

This distribution is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.  These terms apply to
every file in the distribution - if you have questions, please contact
the author.

=cut
