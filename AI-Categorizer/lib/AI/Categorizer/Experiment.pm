package AI::Categorizer::Experiment;

use strict;
use Class::Container;
use AI::Categorizer::Storable;
use Statistics::Contingency;

use base qw(Class::Container AI::Categorizer::Storable Statistics::Contingency);

use Params::Validate qw(:types);
__PACKAGE__->valid_params
  (
   categories => { type => ARRAYREF|HASHREF },
  );

sub new {
  my $package = shift;
  my $self = $package->Class::Container::new(@_);
  
  $self->{$_} = 0 foreach qw(a b c d);
  my $c = delete $self->{categories};
  $self->{categories} = { map {($_ => {a=>0, b=>0, c=>0, d=>0})} 
			  UNIVERSAL::isa($c, 'HASH') ? keys(%$c) : @$c
			};
  return $self;
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
 
 print "Micro F1: ", $e->micro_F1, "\n"; # Access a single statistic
 print $e->stats_table; # Show several stats in table form

=head1 DESCRIPTION

The C<AI::Categorizer::Experiment> class helps you organize the
results of categorization experiments.  As you get lots of
categorization results (Hypotheses) back from the Learner, you can
feed these results to the Experiment class, along with the correct
answers.  When all results have been collected, you can get a report
on accuracy, precision, recall, F1, and so on, with both
macro-averaging and micro-averaging over categories.

=head2 Macro vs. Micro Statistics

All of the statistics offered by this module can be calculated for
each category and then averaged, or can be calculated over all
decisions and then averaged.  The former is called macro-averaging,
and the latter is called micro-averaging.  They bias the results
differently - micro-averaging tends to over-emphasize the performance
on the largest categories, while macro-averaging over-emphasizes the
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
macro-statistic or a micro-statistic is being calculated, these
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

=item * $e->add_result($assigned_categories, $correct_categories, $name)

Adds a new result to the experiment.  The lists of assigned and
correct categories can be given as an array of category names
(strings), as a hash whose keys are the category names and whose
values are anything logically true, or as a single string if there is
only one category.

If you've already got the lists in hash form, this will be the fastest
way to pass them.  Otherwise, the current implementation will convert
them to hash form internally.

The C<$name> parameter is a name for this result, it will only be used
in error messages or debugging/progress output.

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

=item * $e->stats_table

Returns a string combining several statistics in one graphic table.
Since accuracy is 1 minus error, we only report error since it takes
less space to print.

=item * $e->category_stats

Returns a hash reference whose keys are the names of each category.
The values are hash references whose keys are the names of various
statistics (accuracy, error, precision, recall, or F1) and whose
values are the measures themselves.  For example, to print a single
statistic:

 print $e->category_stats->{sports}{recall}, "\n";

Or to print certain statistics for all categtories:
 
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
