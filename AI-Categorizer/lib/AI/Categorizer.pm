package AI::Categorizer;
$VERSION = '0.01';

use strict;
use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Learner;
use AI::Categorizer::Document;
use AI::Categorizer::Collection;


# Preloaded methods go here.

1;
__END__

=head1 NAME

AI::Categorizer - Automatic Text Categorization

=head1 SYNOPSIS

 # An example...
 
 use AI::Categorizer;
 use AI::Categorizer::Learner::NaiveBayes;
  
 # Read a collection of categorized documents
 my $k = new AI::Categorizer::KnowledgeSet
   (
    document_class   => 'AI::Categorizer::Document::Text',
    collection_class => 'AI::Categorizer::Collection::Files',
    stopwords => [ ... ],
    features_kept => 500,
    load => { path => '/path/to/data', scan_features => 1 },
   );
 
 # Train a categorizer
 my $c = new AI::Categorizer::Learner::NaiveBayes;
 $c->train($k);
 $c->save_state('filename');
 
 # ... Time passes ...
 
 # Read an uncategorized document
 use AI::Categorizer::Document::Text;
 my $doc = AI::Categorizer::Document::Text->read( path => '/path/to/doc' );
 
 # Categorize it
 $c = AI::Categorizer::Learner::NaiveBayes->restore_state('filename');
 my $result = $c->categorize($doc);
 
 # Check the result
 if ($result->is_in_category('sports')) { ... }
 my $best_cat = $result->best_category;
 my @categories = $result->categories;
 my @scores = $result->scores(@categories);

=head1 DESCRIPTION

C<AI::Categorizer> is a framework for automatic text categorization.
It consists of a collection of Perl modules that implement common
categorization tasks.  The various details are flexible - for example,
you can choose what categorization algorithm to use, what features
(words or otherwise) of the documents should be used (or how to
automatically choose these features), what format the documents are
in, and so on.

The basic process of using this module will typically involve
obtaining a collection of B<pre-categorized> documents, creating a
knowledge set representation of those documents, training a
categorizer on that knowledge set, and saving the trained categorizer
for later use.

Disclaimer: the results of any of these algorithms are far from
infallible (close to fallible?).  Categorization of documents is often
a difficult task even for humans well-trained in the particular domain
of knowledge, and there are many things a human would consider that
none of these algorithms consider.  These are only statistical tests -
at best they are neat tricks or helpful assistants, and at worst they
are totally unreliable.  If you plan to use this module for anything
important, human supervision is essential.

For the usage details, please see the documentation of each individual
module.

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

Please see the documentation of these individual modules for more
details on their guts and quirks.  See the C<AI::Categorizer::Learner>
documentation for a description of the general categorizer interface.

=head2 Feature Vectors

Most categorization algorithms don't deal directly with a document's
data, they instead deal with a I<vector representation> of a
document's I<features>.  The features may be any property of the
document that seems indicative of its category, but they are usually
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

=head1 COPYRIGHT

This distribution is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.  These terms apply to
every file in the distribution - if you have questions, please contact
the author.

=cut
