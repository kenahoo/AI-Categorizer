package AI::Categorizer::Learner::NaiveBayes;

use strict;
use AI::Categorizer::Learner;
use base qw(AI::Categorizer::Learner);
use Params::Validate qw(:types);
use AI::Categorizer::Util qw(max average);

__PACKAGE__->valid_params
  (
   threshold => {type => SCALAR, default => 0.3},
  );

sub create_model {
  my $self = shift;
  my $m = $self->{model} = {};

  my $totaldocs = $self->knowledge_set->documents;
  $m->{features} = $self->knowledge_set->features;
  $m->{vocab_size} = $self->knowledge_set->features->length;
  $m->{total_tokens} = $self->knowledge_set->features->sum;

  # Calculate the probabilities for each category
  foreach my $cat ($self->knowledge_set->categories) {
    $m->{cat_prob}{$cat->name} = log($cat->documents / $totaldocs);

    # Count the number of tokens in this cat
    $m->{cat_tokens}{$cat->name} = $cat->features->sum;

    my $denominator = log($m->{cat_tokens}{$cat->name} + $m->{vocab_size});

    my $features = $cat->features->as_hash;
    while (my ($feature, $count) = each %$features) {
      $m->{probs}{$cat->name}{$feature} = log($count + 1) - $denominator;
    }
  }
  $self->{model} = $m;
}

# Counts:
# Total number of words (types)  in all docs: (V)        $self->knowledge_set->features->length or $m->{vocab_size}
# Total number of words (tokens) in all docs:            $self->knowledge_set->features->sum or $m->{total_tokens}
# Total number of words (types)  in category $c:         $c->features->length
# Total number of words (tokens) in category $c:(N)      $c->features->sum or $m->{cat_tokens}{$c->name}

# Logprobs:
# P($cat) = $m->{cat_prob}{$cat->name}
# P($feature|$cat) = $m->{probs}{$cat->name}{$feature}

sub get_scores {
  my ($self, $newdoc) = @_;
  my $m = $self->{model};  # For convenience
  my $all_features = $m->{features};
  
  # Note that we're using the log(prob) here.  That's why we add instead of multiply.

  my %scores;
  while (my ($cat, $cat_features) = each %{$m->{probs}}) {
    my $fake_prob = -log($m->{cat_tokens}{$cat} + $m->{vocab_size}); # Like a very infrequent word

    $scores{$cat} = $m->{cat_prob}{$cat}; # P($cat)
    
    my $doc_hash = $newdoc->features->as_hash;
    while (my ($feature, $value) = each %$doc_hash) {
      next unless $all_features->includes($feature);
      $scores{$cat} += ($cat_features->{$feature} || $fake_prob)*$value;   # P($feature|$cat)**$value
    }
  }
  
  # Scale everything back to a reasonable area in logspace (near zero), un-loggify, and normalize
  my $total = 0;
  my $max = max(values %scores);
  foreach (keys %scores) {
    $scores{$_} = exp($scores{$_} - $max);
    $total += $scores{$_}**2;
  }
  $total = sqrt($total);
  foreach (keys %scores) {
    $scores{$_} /= $total;
  }
  
  return \%scores;
}

sub threshold {
  my $self = shift;
  $self->{threshold} = shift if @_;
  return $self->{threshold};
}

sub categorize {
  my ($self, $doc) = @_;

  my $scores = $self->get_scores($doc);
  
  if ($self->verbose > 1) {
    warn "scores: @{[ %$scores ]}" if $self->verbose > 2;

    foreach my $key (sort {$scores->{$b} <=> $scores->{$a}} keys %$scores) {
      print "$key: $scores->{$key}\n";
    }
  }

  return $self->create_delayed_object('hypothesis',
				      scores => $scores,
				      threshold => $self->{threshold},
				      document_name => $doc->name,
				     );
}

sub save_state {
  my $self = shift;
  local $self->{knowledge_set};  # Don't need the knowledge_set to categorize
  $self->SUPER::save_state(@_);
}

1;

__END__

=head1 NAME

AI::Categorizer::Learner::NaiveBayes - Naive Bayes Algorithm For AI::Categorizer

=head1 SYNOPSIS

  use AI::Categorizer::Learner::NaiveBayes;
  
  # Here $k is an AI::Categorizer::KnowledgeSet object
  
  my $nb = new AI::Categorizer::Learner::NaiveBayes(...parameters...);
  $nb->train(knowledge_set => $k);
  $nb->save_state('filename');
  
  ... time passes ...
  
  $nb = AI::Categorizer::Learner::NaiveBayes->restore_state('filename');
  my $c = new AI::Categorizer::Collection::Files( path => ... );
  while (my $document = $c->next) {
    my $hypothesis = $nb->categorize($document);
    print "Best assigned category: ", $hypothesis->best_category, "\n";
    print "All assigned categories: ", join(', ', $hypothesis->categories), "\n";
  }

=head1 DESCRIPTION

This is an implementation of the Naive Bayes decision-making
algorithm, applied to the task of document categorization (as defined
by the AI::Categorizer module).  See L<AI::Categorizer> for a complete
description of the interface.

=head1 METHODS

This class inherits from the C<AI::Categorizer::Learner> class, so all
of its methods are available unless explicitly mentioned here.

=head2 new()

Creates a new Naive Bayes Learner and returns it.  In addition to the
parameters accepted by the C<AI::Categorizer::Learner> class, the
Naive Bayes subclass accepts the following parameters:

=over 4

=item * threshold

Sets the score threshold for category membership.  The default is
currently 0.3.  Set the threshold lower to assign more categories per
document, set it higher to assign fewer.  This can be an effective way
to trade of between precision and recall.

=back

=head2 threshold()

Returns the current threshold value.  With an optional numeric
argument, you may set the threshold.

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

=head1 THEORY

Bayes' Theorem is a way of inverting a conditional probability. It
states:

                P(y|x) P(x)
      P(x|y) = -------------
                   P(y)

The notation C<P(x|y)> means "the probability of C<x> given C<y>."  See also
L<"http://forum.swarthmore.edu/dr.math/problems/battisfore.03.22.99.html">
for a simple but complete example of Bayes' Theorem.

In this case, we want to know the probability of a given category given a
certain string of words in a document, so we have:

                    P(words | cat) P(cat)
  P(cat | words) = --------------------
                           P(words)

We have applied Bayes' Theorem because C<P(cat | words)> is a difficult
quantity to compute directly, but C<P(words | cat)> and C<P(cat)> are accessible
(see below).

The greater the expression above, the greater the probability that the given
document belongs to the given category.  So we want to find the maximum
value.  We write this as

                                 P(words | cat) P(cat)
  Best category =   ArgMax      -----------------------
                   cat in cats          P(words)


Since C<P(words)> doesn't change over the range of categories, we can get rid
of it.  That's good, because we didn't want to have to compute these values
anyway.  So our new formula is:

  Best category =   ArgMax      P(words | cat) P(cat)
                   cat in cats

Finally, we note that if C<w1, w2, ... wn> are the words in the document,
then this expression is equivalent to:

  Best category =   ArgMax      P(w1|cat)*P(w2|cat)*...*P(wn|cat)*P(cat)
                   cat in cats

That's the formula I use in my document categorization code.  The last
step is the only non-rigorous one in the derivation, and this is the
"naive" part of the Naive Bayes technique.  It assumes that the
probability of each word appearing in a document is unaffected by the
presence or absence of each other word in the document.  We assume
this even though we know this isn't true: for example, the word
"iodized" is far more likely to appear in a document that contains the
word "salt" than it is to appear in a document that contains the word
"subroutine".  Luckily, as it turns out, making this assumption even
when it isn't true may have little effect on our results, as the
following paper by Pedro Domingos argues:
L<"http://www.cs.washington.edu/homes/pedrod/mlj97.ps.gz">

=head1 CALCULATIONS

The various probabilities used in the above calculations are found
directly from the training documents.  For instance, if there are 5000
total tokens (words) in the "sports" training documents and 200 of
them are the word "curling", then C<P(curling|sports) = 200/5000 =
0.04> .  If there are 10,000 total tokens in the training corpus and
5,000 of them are in documents belonging to the category "sports",
then C<P(sports)> = 5,000/10,000 = 0.5> .

Because the probabilities involved are often very small and we
multiply many of them together, the result is often a tiny tiny
number.  This could pose problems of floating-point underflow, so
instead of working with the actual probabilities we work with the
logarithms of the probabilities.  This also speeds up various
calculations in the C<categorize()> method.

=head1 TO DO

More work on the confidence scores - right now the winning category
tends to dominate the scores overwhelmingly, when the scores should
probably be more evenly distributed.

=head1 AUTHOR

Ken Williams, ken@forum.swarthmore.edu

=head1 COPYRIGHT

Copyright 2000-2001 Ken Williams.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

AI::Categorize(3)

"A re-examination of text categorization methods" by Yiming Yang
L<http://www.cs.cmu.edu/~yiming/publications.html>

"On the Optimality of the Simple Bayesian Classifier under Zero-One
Loss" by Pedro Domingos
L<"http://www.cs.washington.edu/homes/pedrod/mlj97.ps.gz">

A simple but complete example of Bayes' Theorem from Dr. Math
L<"http://www.mathforum.com/dr.math/problems/battisfore.03.22.99.html">

=cut
