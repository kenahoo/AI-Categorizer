package AI::Categorizer::Learner::Boolean;

use strict;
use AI::DecisionTree;
use AI::Categorizer::Learner;
use base qw(AI::Categorizer::Learner);

sub create_model {
  my $self = shift;
  my $m = $self->{model} = {};

  foreach my $cat ($self->knowledge_set->categories) {
    my (@p, @n);
    foreach my $doc ($self->knowledge_set->documents) {
      push( ($doc->is_in_category($cat) ? @p : @n), $doc );
    }
    $m->{learners}{ $cat->name } = $self->create_boolean_model(\@p, \@n, $cat);
  }
}

sub get_scores {
  my ($self, $doc) = @_;
  my $m = $self->{model};
  my %scores;
  foreach my $cat (keys %{$m->{learners}}) {
    $scores{$cat} = $self->get_boolean_score($doc, $m->{learners}{$cat});
  }
  return (\%scores, 0.5);
}

1;
__END__

=head1 NAME

AI::Categorizer::Learner::Boolean - Abstract class for boolean categorizers

=head1 SYNOPSIS

 use AI::Categorizer::Learner::Boolean;
 
 sub create_boolean_model {
   my ($self, $positives, $negatives, $category) = @_;
   ...
   return $something_helpful;
 }
 
 sub get_boolean_score {
   my ($self, $document, $something_helpful) = @_;
   ...
   return $score;
 }

=head1 DESCRIPTION

This class isn't useful as a categorizer on its own, but it provides a
framework for turning boolean categorizers (categorizers based on
algorithms that can just provide yes/no categorization decisions) into
multi-valued categorizers.  For instance, the decision tree
categorizer C<AI::Categorizer::Learner::DecisionTree> maintains a
decision tree for each category, then makes a separate decision for
each category.

Any class that inherits from this class should implement the following
methods:

=head2 create_boolean_model()

Used during training to create a category-specific model.  The type of
model you create is up to you - it should be returned as a scalar.
Whatever you return will be available to you in the
C<get_boolean_score()> method, so put any information you'll need
during categorization in this scalar.

In addition to C<$self>, this method will be passed three arguments.
The first argument is a reference to an array of B<positive> examples,
i.e. documents that belong to the given category.  The next argument
is a reference to an array of B<negative> examples, i.e. documents
that do I<not> belong to the given category.  The final argument is
the Category object for the given category.

=head2 get_boolean_score()

Used during categorization to assign a score for a single document
relative to a single category.  The score should be between 0 and 1,
with a score greater than 0.5 indicating membership in the category.

In addition to C<$self>, this method will be passed two arguments.
The first argument is the document to be categorized.  The second
argument is the value returned by C<create_boolean_model()> for this
category.

=head1 AUTHOR

Ken Williams, <ken@mathforum.org>

=head1 SEE ALSO

AI::Categorizer

=cut
