package AI::Categorizer::Learner::DecisionTree;
$VERSION = '0.01';

use strict;
use AI::DecisionTree;
use AI::Categorizer::Learner::Boolean;
use base qw(AI::Categorizer::Learner::Boolean);

sub create_boolean_model {
  my ($self, $positives, $negatives, $cat) = @_;
  
  my $t = new AI::DecisionTree(noise_mode => 'pick_best');
  for ($positives, $negatives) {
    foreach my $doc (@$_) {
      $t->add_instance( attributes => $doc->features->as_boolean_hash,
			result => $_ eq $positives );
    }
  }

  $t->train;
  return $t;
}

sub get_boolean_score {
  my ($self, $doc, $t) = @_;
  my $result = $t->get_result( attributes => $doc->features->as_boolean_hash );
  return $result;
}

1;
__END__

=head1 NAME

AI::Categorizer::Learner::DecisionTree - Perl extension for blah blah blah

=head1 SYNOPSIS

  use AI::Categorizer::Learner::DecisionTree;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for AI::Categorizer::Learner::DecisionTree, created
by h2xs. It looks like the author of the extension was negligent
enough to leave the stub unedited.

Blah blah blah.

=head1 AUTHOR

Ken Williams, <ken@mathforum.org>

=head1 SEE ALSO

AI::Categorizer, AI::DecisionTree

=cut
