package AI::Categorizer::Experiment;

use strict;
use Class::Container;
use base qw(Class::Container);

#              Correct=Y   Correct=N
#            +-----------+-----------+
# Assigned=Y |     a     |     b     |
#            +-----------+-----------+
# Assigned=N |     c     |     d     |
#            +-----------+-----------+

# accuracy = (a+d)/(a+b+c+d)
# precision = a/(a+b)
# recall = a/(a+c)
# F1 = 

# Edge cases:
#  precision(a,0,c,d) = 1
#  precision(0,+,c,d) = 0
#     recall(a,b,0,d) = 1
#     recall(0,b,+,d) = 0
#         F1(a,0,0,d) = 1
#         F1(0,+++,d) = 0

use Params::Validate qw(:types);
__PACKAGE__->valid_params
  (
  );

sub new {
  my $package = shift;
  my $self = $package->SUPER::new(@_);
  $self->{$_} = 0 foreach qw(a b c d);
  return $self;
}

sub add_hypothesis {
  my ($self, $hypothesis, $correct) = @_;
  my %assigned = map {($_, 1)} $hypothesis->categories;

  unless ($self->{categories}) {
    my @all_cats = $hypothesis->all_categories;
    $self->{categories} = { map {$_, {a=>0, b=>0, c=>0, d=>0}} @all_cats };
  }
  my $cats_table = $self->{categories};

  # Hashify
  if (!ref($correct)) {
    $correct = [$correct];  # $correct is a string
  } elsif (UNIVERSAL::isa($correct, 'ARRAY')) {
    $correct = { map {(ref($_) ? $_->name : $_) => 1} @$correct };
  } elsif (UNIVERSAL::isa($correct, 'HASH')) {
    # Leave it alone
  } else {
    die "Unknown type '$correct' for correct categories";
  }

  # Add to the macro/micro tables
  foreach my $cat (keys %$cats_table) {
    $cats_table->{$cat}{a}++, $self->{a}++ if  $assigned{$cat} and  $correct->{$cat};
    $cats_table->{$cat}{b}++, $self->{b}++ if  $assigned{$cat} and !$correct->{$cat};
    $cats_table->{$cat}{c}++, $self->{c}++ if !$assigned{$cat} and  $correct->{$cat};
    $cats_table->{$cat}{d}++, $self->{d}++ if !$assigned{$cat} and !$correct->{$cat};
  }

  $self->{hypotheses}++;
}

sub _invert {
  my ($self, $x, $y) = @_;
  return 1 unless $y;
  return 0 unless $x;
  return 1 / (1 + $y/$x);
}

sub _accuracy {
  my $h = $_[1];
  return +($h->{a} + $h->{d}) / ($h->{a} + $h->{b} + $h->{c} + $h->{d});
}

sub _error {
  my $h = $_[1];
  return +($h->{b} + $h->{c}) / ($h->{a} + $h->{b} + $h->{c} + $h->{d});
}

sub _precision {
  my ($self, $h) = @_;
  return $self->_invert($h->{a}, $h->{b});
}
  
sub _recall {
  my ($self, $h) = @_;
  return $self->_invert($h->{a}, $h->{c});
}
  
sub _F1 {
  my ($self, $h) = @_;
  return $self->_invert(2 * $h->{a}, $h->{b} + $h->{c});
}

# Fills in precision, recall, etc. for each category, and computes their averages
sub _micro_stats {
  my $self = shift;
  return $self->{micro} if $self->{micro};
  
  my @metrics = qw(precision recall F1 accuracy error);

  my $cats = $self->{categories};
  my %results;
  while (my ($cat, $scores) = each %$cats) {
    foreach my $metric (@metrics) {
      my $method = "_$metric";
      $results{$metric} += ($scores->{$metric} = $self->$method($scores));
    }
  }
  foreach (@metrics) {
    $results{$_} /= keys %$cats;
  }
  $self->{micro} = \%results;
}

sub macro_accuracy  { $_[0]->_accuracy( $_[0]) }
sub macro_error     { $_[0]->_error(    $_[0]) }
sub macro_precision { $_[0]->_precision($_[0]) }
sub macro_recall    { $_[0]->_recall(   $_[0]) }
sub macro_F1        { $_[0]->_F1(       $_[0]) }

sub micro_accuracy  { shift()->_micro_stats->{accuracy} }
sub micro_error     { shift()->_micro_stats->{error} }
sub micro_precision { shift()->_micro_stats->{precision} }
sub micro_recall    { shift()->_micro_stats->{recall} }
sub micro_F1        { shift()->_micro_stats->{F1} }

sub category_stats {
  my $self = shift;
  $self->_micro_stats;

  return $self->{categories};
}

sub stats_table {
  my $self = shift;
  
  my $out = "+---------------------------------------------------------+\n";
  $out   .= "|   miR    miP   miF1    miE     maR    maP   maF1    maE |\n";
  $out   .= "| %.3f  %.3f  %.3f  %.3f   %.3f  %.3f  %.3f  %.3f |\n";
  $out   .= "+---------------------------------------------------------+\n";

  return sprintf($out,
		 $self->micro_recall,
		 $self->micro_precision,
		 $self->micro_F1,
		 $self->micro_error,
		 $self->macro_recall,
		 $self->macro_precision,
		 $self->macro_F1,
		 $self->macro_error,
		);
}


1;

__END__

=head1 NAME

AI::Categorizer::Experiment - Coordinate experimental results

=head1 SYNOPSIS

 use AI::Categorizer::Experiment;
 my $e = new AI::Categorizer::Experiment;
 my $l = AI::Categorizer::Learner->restore_state(...path...);
 
 while (...) {
   my $d = ... get document ...
   my $h = $l->categorize($d);
   $e->add_hypothesis($h, [$d->categories]);
 }
 
 print "Macro F1: ", $e->macro_F1, "\n"; # Access a single statistic
 print $e->stats_table; # Show several stats in table form

=head1 DESCRIPTION

The C<AI::Categorizer::Experiment> class helps you organize the
results of categorization experiments.  As you get lots of
categorization results (Hypotheses) back from the Learner, you can
feed these results to the Experiment class, along with the correct
answers.  When all results have been collected, you can get a report
on accuracy, precision, recall, F1, and so on, with both
micro-averaging and macro-averaging over categories.

=head2 Micro vs. Macro Statistics

All of the statistics offered by this module can be calculated for
each category and then averaged, or can be calculated over all
decisions and then averaged.  The former is called micro-averaging,
and the latter is called macro-averaging.  They bias the results
differently - macro-averaging tends to over-emphasize the performance
on the largest categories, while micro-averaging over-emphasizes the
performance on the smallest.  It's usually best to look at both
of them to get a better idea of how your categorizer is performing.

=head2 Statistics available

All of the statistics are calculated based on a so-called "contingency
table", which looks like this:

              Correct=Y   Correct=N
            +-----------+-----------+
 Assigned=Y |     a     |     b     |
            +-----------+-----------+
 Assigned=N |     c     |     d     |
            +-----------+-----------+

a, b, c, and d are counts that reflect how the assigned categories
matched the correct categories.  Depending on whether a
micro-statistic or a macro-statistic is being calculated, these
numbers will be tallied per-category or for the entire result set.

The following statistics are available:

=over 4

=item * accuracy

This measures the portion of all decisions that were correct
decisions.  It is defined as C<(a+d)/(a+b+c+d)>.  It falls in the
range from 0 to 1, with 1 being the best score.

=item * error

This measures the portion of all decisions that were incorrect
decisions.  It is defined as C<(b+c)/(a+b+c+d)>.  It falls in the
range from 0 to 1, with 0 being the best score.

=item * precision

This measures the portion of the assigned categories that were
correct.  It is defined as C<a/(a+b)>.  It falls in the range from 0
to 1, with 1 being the best score.

=item * recall

This measures the portion of the correct categories that were
assigned.  It is defined as C<a/(a+c)>.  It falls in the range from 0
to 1, with 1 being the best score.

=item * F1

This measures an even combination of precision and recall.  It is
defined as C<2*p*r/(p+r)>.  In terms of a, b, and c, it may be
expressed as C<2a/(2a+b+c)>.  It falls in the range from 0 to 1, with
1 being the best score.

=back

The F1 measure is probably the only simple measure that is worth
trying to maximize on its own - consider the fact that you can get a
perfect precision score by always assigning zero categories, or a
perfect recall score by always assigning every category.  A truly
smart system will assign the correct categories and only the correct
categories, maximizing precision and recall at the same time, and
therefore maximizing the F1 score.

Sometimes it's worth trying to maximize the accuracy score, but
accuracy (and its counterpart error) are considered fairly crude
scores that don't give much information about the performance of a
categorizer.

=head1 METHODS

The general execution flow when using this class is to create an
Experiment object, add a bunch of Hypotheses to it, and then report on
the results.

=over 4

=item * $e = AI::Categorizer::Experiment->new()

Returns a new Experiment object.  No parameters are accepted at the moment.

=item * $e->add_hypothesis($hypothesis, \@correct_categories)

Adds a new hypothesis to the Experiment.  The hypothesis should be an
object of type C<AI::Categorizer::Hypothesis> (or one of its
subclasses), as returned by the C<categorize()> method of a Learner.
The list of correct categories can be given as an array of category
names (strings), an array of Category objects, a hash whose keys are
the category names (this is the fastest), or as a single string if
there is only one category.

As of the current implementation, the Hypothesis itself is not stored,
it is only used to generate the counts for the contingency table.

=item * $e->macro_accuracy

Returns the macro-averaged accuracy for the Experiment.

=item * $e->macro_error

Returns the macro-averaged error for the Experiment.

=item * $e->macro_precision

Returns the macro-averaged precision for the Experiment.

=item * $e->macro_recall

Returns the macro-averaged recall for the Experiment.

=item * $e->macro_F1

Returns the macro-averaged F1 for the Experiment.

=item * $e->micro_accuracy

Returns the micro-averaged accuracy for the Experiment.

=item * $e->micro_error

Returns the micro-averaged error for the Experiment.

=item * $e->micro_precision

Returns the micro-averaged precision for the Experiment.

=item * $e->micro_recall

Returns the micro-averaged recall for the Experiment.

=item * $e->micro_F1

Returns the micro-averaged F1 for the Experiment.

=item * $e->stats_table

Returns a string combining several statistics in one graphic.  Since
accuracy is 1 minus error, we only report error since it takes less
space to print.

=item * $e->category_stats

Returns a hash reference whose keys are the names of each category.
The values are hash references whose keys are the names of various
statistics (accuracy, error, precision, recall, or F1) and whose
values are the measures themselves.  For example:

 print $e->category_stats->{sports}{recall}, "\n";
 
 my $stats = $e->category_stats;
 while (my ($cat, $value) = each %$stats) {
   print "Category '$cat': \n";
   print "  Accuracy: $value->{accuracy}\n";
   print "  Precision: $value->{precision}\n";
   print "  F1: $value->{F1}\n";
 }

=back

=head1 AUTHOR

Ken Williams <kenw@ee.usyd.edu.au>

=head1 COPYRIGHT

This distribution is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.  These terms apply to
every file in the distribution - if you have questions, please contact
the author.

=cut
