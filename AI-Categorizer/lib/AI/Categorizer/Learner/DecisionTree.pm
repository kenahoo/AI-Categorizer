package AI::Categorizer::Learner::DecisionTree;
$VERSION = '0.01';

use strict;
use AI::DecisionTree;
use AI::Categorizer::Learner::Boolean;
use base qw(AI::Categorizer::Learner::Boolean);

sub create_model {
  my $self = shift;
  $self->SUPER::create_model;
  $self->{model}{first_tree}->do_purge;
  delete $self->{model}{first_tree};
}

sub create_boolean_model {
  my ($self, $positives, $negatives, $cat) = @_;
  
  my $t = new AI::DecisionTree(noise_mode => 'pick_best', 
			       verbose => $self->verbose);

  my %results;
  for ($positives, $negatives) {
    foreach my $doc (@$_) {
      $results{$doc->name} = $_ eq $positives ? 1 : 0;
    }
  }

  if ($self->{model}{first_tree}) {
    $t->copy_instances(from => $self->{model}{first_tree});
    $t->set_results(\%results);

  } else {
    for ($positives, $negatives) {
      foreach my $doc (@$_) {
	$t->add_instance( attributes => $doc->features->as_boolean_hash,
			  result => $results{$doc->name},
			  name => $doc->name,
			);
      }
    }
    $t->purge(0);
    $self->{model}{first_tree} = $t;
  }

  print STDERR "\nBuilding tree for category '", $cat->name, "'" if $self->verbose;
  $t->train;
  return $t;
}

sub get_boolean_score {
  my ($self, $doc, $t) = @_;
  my $result = $t->get_result( attributes => $doc->features->as_boolean_hash ) || 0;
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
