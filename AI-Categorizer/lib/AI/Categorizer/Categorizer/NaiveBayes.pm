package AI::Categorizer::Categorizer::NaiveBayes;

use strict;
use AI::Categorizer::Categorizer;
use base qw(AI::Categorizer::Categorizer);

__PACKAGE__->valid_params
  (
   bayes_threshold => {type => SCALAR, default => 0.3},
  );

sub create_model {
  my $self = shift;
  my $m = $self->{model} = {};

  my $vocab_size = $self->knowledge->features->size;
  my $totaldocs = $self->knowledge->documents;
  $m->{total_tokens} = $self->knowledge->features->sum;

  # Calculate the probabilities for each category
  foreach my $cat ($self->knowledge->categories) {
    $m->{cat_prob}{$cat->name} = log($cat->documents / $totaldocs);

    # Count the number of tokens in this cat
    $m->{cat_tokens}{$cat->name} = $cat->features->sum;

    my $denominator = log($m->{cat_tokens}{$cat->name} + $vocab_size);

    my $features = $cat->features->as_hash;
    while (my ($feature, $count) = each %$features) {
      $m->{probs}{$cat->name}{$feature} = log($count + 1) - $denominator;
    }
  }
}

# Total number of words (types)  in all docs: (V)        $self->knowledge->features->size
# Total number of words (tokens) in all docs:            $self->knowledge->features->sum or $m->{total_tokens}
# Total number of words (types)  in category $c:         $c->features->size
# Total number of words (tokens) in category $c:(N)      $c->features->sum or $m->{cat_tokens}{$c->name}

# Logprobs:
# P($cat) = $m->{cat_prob}{$cat->name}
# P($feature|$cat) = $m->{probs}{$cat->name}{$feature}

sub get_scores {
  my ($self, $newdoc) = @_;
  
  # Note that we're using the log(prob) here.  That's why we add instead of multiply.

  my %scores;
  while (my ($cat,$words) = each %{$self->{probs}}) {
    my $fake_prob = -log($self->{tokens}{$cat} + $self->total_types); # Like a very infrequent word

    $scores{$cat} = $self->{catprob}{$cat}; # P($cat)
    
    while (my ($word, $count) = each %$newdoc) {
      next unless exists $self->{docword}{$word};
      $scores{$cat} += ($words->{$word} || $fake_prob)*$count;   # P($word|$cat)**$count
    }
  }
  
  # Scale everything back to a reasonable area in logspace (near zero)
  my $min = 0;
  foreach (values %scores) {$min = $_ if $_ < $min}
  foreach (keys %scores) {$scores{$_} = exp($scores{$_} - $min)}
  
  $self->normalize(\%scores);
  return \%scores;
}

sub categorize {
  my ($self, $doc) = @_;

  my $scores = $self->get_scores($doc);
  
#    if ($self->{verbose}) {
#      foreach my $key (sort {$scores{$b} <=> $scores{$a}} keys %scores) {
#        print "$key: $scores{$key}\n";
#      }
#    }

  return $self->create_delayed_object('hypothesis',
				      scores => $scores,
				      threshold => $self->{threshold},
				     );
}

1;

__END__

sub add_document {
  my ($self, $document, $cats, $content) = @_;
  # In the future, $content may be allowed to be a filehandle

  # Record the category information
  $cats = [$cats] unless ref $cats;
  $self->cat_map->add_document($document, $cats);
  
  my $words = $self->extract_words($content);
  
  foreach my $cat (@$cats) {
    while (my ($word, $count) = each %$words) {
      $self->{count}{$cat}{$word} += $count;
      $self->{docword}{$word}++;
    }
  }
}

# Number of times word $w appears with category $c:(Nk)  $self->{count}{$c}{$w}  (until crunch())

sub crunch {
  my ($self) = @_;

  $self->trim_features($self->{features_kept}) if $self->{features_kept};
  
  my $vocabulary = $self->total_types;
  my $totaldocs = $self->cat_map->documents;

  # Calculate the probabilities for each category
  foreach my $cat (keys %{$self->{count}}) {
    $self->{catprob}{$cat} = log($self->cat_map->documents_of($cat) / $totaldocs);

    # Count the number of tokens in this cat
    $self->{tokens}{$cat} = $self->cat_tokens($cat);

    my $denominator = log($self->{tokens}{$cat} + $vocabulary);
    while (my ($word, $count) = each %{$self->{count}{$cat}}) {
      $self->{total_tokens} += $count;
      $self->{probs}{$cat}{$word} = log($count + 1) - $denominator;
    }
  }
}

sub threshold {
  my $self = shift;
  $self->{threshold} = shift if @_;
  return $self->{threshold};
}

sub total_types { keys %{shift->{docword}} }

sub cat_tokens {
  my ($self, $cat) = @_;
  my $total = 0;
  $total += $_ for values %{$self->{count}{$cat}};
  return $total;
}

# Total number of words (types)  in all docs: (V)        keys %{$self->{docword}} or $self->total_types
# Total number of words (tokens) in all docs:            $self->{total_tokens} or sum values $self->{docword}
# Total number of words (types)  in category $c:         keys %{$self->{count}{$cat}}
# Total number of words (tokens) in category $c:(N)      $self->{tokens}{$c}

# Logprobs:
# P($cat) = $self->{catprob}{$cat}
# P($word|$cat) = $self->{probs}{$cat}{$word}

sub categorize {
  my $self = shift;
  my $newdoc = $self->extract_words(shift);
  my $scores = $self->get_scores($newdoc);
  
#    if ($self->{verbose}) {
#      foreach my $key (sort {$scores{$b} <=> $scores{$a}} keys %scores) {
#        print "$key: $scores{$key}\n";
#      }
#    }

  return $self->{results_class}->new(scores => $scores,
				     threshold => $self->{threshold},
				    );
}

sub get_scores {
  my ($self, $newdoc) = @_;
  
  # Note that we're using the log(prob) here.  That's why we add instead of multiply.

  my %scores;
  while (my ($cat,$words) = each %{$self->{probs}}) {
    my $fake_prob = -log($self->{tokens}{$cat} + $self->total_types); # Like a very infrequent word

    $scores{$cat} = $self->{catprob}{$cat}; # P($cat)
    
    while (my ($word, $count) = each %$newdoc) {
      next unless exists $self->{docword}{$word};
      $scores{$cat} += ($words->{$word} || $fake_prob)*$count;   # P($word|$cat)**$count
    }
  }
  
  # Scale everything back to a reasonable area in logspace (near zero)
  my $min = 0;
  foreach (values %scores) {$min = $_ if $_ < $min}
  foreach (keys %scores) {$scores{$_} = exp($scores{$_} - $min)}
  
  $self->normalize(\%scores);
  return \%scores;
}

sub trim_features {
  # Trims $self->{count} and $self->{docword}
  
  my ($self, $target) = @_;
  my $dw = $self->{docword};
  my $num_words = keys %$dw;
  print "Trimming features - total types = $num_words\n" if $self->{verbose};
  
  # Find the most-frequently-used words.
  # This is algorithmic overkill, but the sort seems fast enough.
  my @new_docword = (sort {$dw->{$b} <=> $dw->{$a}} keys %$dw)[0 .. $target*$num_words];
  %$dw = map {$_,$dw->{$_}} @new_docword;

  # Go through the corpus data, excise words that aren't in our reduced set.
  while (my ($cat,$wordlist) = each %{$self->{count}}) {
    my %newlist = map { $dw->{$_} ? ($_, $wordlist->{$_}) : () } keys %$wordlist;
    $self->{count}{$cat} = {%newlist};
  }

  warn "Finished trimming features - types = " . @new_docword . "\n" if $self->{verbose};
}

sub normalize {
  # An arbitrary normalization - make sure they add up to 1, as if
  # they were probabilities filling the entire probability space without overlap.
  my ($self, $scores) = @_;
  my $total = 0;
  while (my ($key) = each %$scores) {
    $total += $scores->{$key};
  }
  return unless $total;
  while (my ($key) = each %$scores) {
    $scores->{$key} /= $total;
  }
}


1;

__END__

=head1 NAME

AI::Categorize::NaiveBayes - Naive Bayes Algorithm For AI::Categorize

=head1 SYNOPSIS

  use AI::Categorize::NaiveBayes;
  my $c = AI::Categorize::NaiveBayes->new;
  my $c = AI::Categorize::NaiveBayes->new(load_data => 'filename');
  
  # See AI::Categorize for more details

=head1 DESCRIPTION

This is an implementation of the Naive Bayes decision-making
algorithm, applied to the task of document categorization (as defined
by the AI::Categorize module).  See L<AI::Categorize> for a complete
description of the interface.

=head1 METHODS

This class inherits from the C<AI::Categorize> class, so all of its
methods are available unless explicitly mentioned here.

=head2 new()

The C<new()> method accepts several parameters that help determine the
behavior of the categorizer.

=over 4

=item * features_kept

This parameter determines what portion of the features (words) from
the training documents will be kept and what features will be
discarded.  The parameter is a number between 0 and 1.  The default is
0.2, indicating that 20% of the features will be kept.  To determine
which features should be kept, we use the document-frequency
criterion, in which we keep the features that appear in the greatest
number of training documents.  This algorithm is simple to implement
and reasonably effective.

To keep all features, pass a C<features_kept> parameter of 0.

=item * threshold

Sets the score threshold for category membership.  The default is
currently 0.3.  Set the threshold lower to assign more categories per
document, set it higher to assign fewer.

=back

=head2 threshold()

Returns the current threshold value.  With an optional numeric
argument, you may set the threshold.


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
