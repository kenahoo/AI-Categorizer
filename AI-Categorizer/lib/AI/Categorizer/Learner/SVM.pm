package AI::Categorizer::Learner::SVM;
$VERSION = '0.01';

use strict;
use AI::Categorizer::Learner::Boolean;
use base qw(AI::Categorizer::Learner::Boolean);
use Algorithm::SVM;
use Algorithm::SVM::DataSet;
use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   svm_kernel => {type => SCALAR, default => 'linear'},
  );

sub create_model {
  my $self = shift;
  my $f = $self->knowledge_set->features->as_hash;
  my $rmap = [ keys %$f ];
  $self->{model}{feature_map} = { map { $rmap->[$_], $_ } 0..$#$rmap };
  $self->{model}{feature_map_reverse} = $rmap;
  $self->SUPER::create_model(@_);
}

sub _doc_2_dataset {
  my ($self, $doc, $label, $fm) = @_;

  my $ds = new Algorithm::SVM::DataSet(Label => $label);
  my $f = $doc->features->as_hash;
  while (my ($k, $v) = each %$f) {
    next unless exists $fm->{$k};
    $ds->attribute( $fm->{$k}, $v );
  }
  return $ds;
}

sub create_boolean_model {
  my ($self, $positives, $negatives, $cat) = @_;
  warn "Creating model for category ", $cat->name, "\n" if $self->verbose;
  
  my $svm = new Algorithm::SVM(Kernel => $self->{svm_kernel});
  
  my (@pos, @neg);
  foreach my $doc (@$positives) {
    push @pos, $self->_doc_2_dataset($doc, 1, $self->{model}{feature_map});
  }
  foreach my $doc (@$negatives) {
    push @neg, $self->_doc_2_dataset($doc, 0, $self->{model}{feature_map});
  }

  warn "Training...", $cat->name, "\n" if $self->verbose;
  $svm->train(@pos, @neg);

  return $svm;
}

sub get_boolean_score {
  my ($self, $doc, $svm) = @_;
  my $ds = $self->_doc_2_dataset($doc, -1, $self->{model}{feature_map});
  my $result = $svm->predict($ds);
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
