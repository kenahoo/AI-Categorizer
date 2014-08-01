use strict;

package AI::Categorizer::Learner::NaiveBayesBoolean;

use AI::Categorizer::Learner::Boolean;
use base qw(AI::Categorizer::Learner::Boolean);
use Params::Validate qw(:types);
use AI::Categorizer::Util qw(max average);

sub create_model {
  my $self = shift;
  my $m = $self->{model} = {};

  $m->{totaldocs} = $self->knowledge_set->documents;
  $m->{features} = $self->knowledge_set->features->as_hash;
  $m->{vocab_size} = $self->knowledge_set->features->length;
  $m->{total_tokens} = $self->knowledge_set->features->sum;

  $self->SUPER::create_model(@_);
}

sub _compute_probs {
  my ($self, $docs) = @_;
  return {} unless @$docs;
  
  my $features;
  foreach my $doc (@$docs) {
    if (!$features) {
      $features = $doc->features;
      next;
    }
    $features->add($doc->features);
  }
  my $f = $features->as_hash;
  my $denominator = log($features->sum + $self->{model}{vocab_size});
  
  my %out;
  while (my ($feature, $count) = each %$f) {
    $out{$feature} = log($count + 1) - $denominator;
  }
  $out{''} = -$denominator;
  
  return \%out;
}

sub create_boolean_model {
  my ($self, $positives, $negatives, $cat) = @_;

  # Calculate the probabilities for pos/neg
  my %info = (
	      pos => {
		      prior  => @$positives / $self->{model}{totaldocs},
		      probs  => $self->_compute_probs($positives),
		     },
	      neg => {
		      prior  => @$negatives / $self->{model}{totaldocs},
		      probs  => $self->_compute_probs($negatives),
		     },
	     );
  
  return \%info;
}

# Counts:
# Total number of words (types)  in all docs: (V)        $self->knowledge_set->features->length or $m->{vocab_size}
# Total number of words (tokens) in all docs:            $self->knowledge_set->features->sum or $m->{total_tokens}
# Total number of words (types)  in category $c:         $c->features->length
# Total number of words (tokens) in category $c:(N)      $c->features->sum or $m->{cat_tokens}{$c->name}

# Logprobs:
# P($cat) = $info->{$cat}{prior}
# P($feature|$cat) = $info->{$cat}{probs}{$feature}

sub get_boolean_score {
  my ($self, $newdoc, $info) = @_;

  return 0 if $info->{pos}{prior} == 0;
  return 1 if $info->{pos}{prior} == 1;
  
  # Note that we're using the log(prob) here.  That's why we add instead of multiply.
  
  my %scores;
  foreach my $cat ('pos', 'neg') {
    $scores{$cat} = log $info->{$cat}{prior}; # P($cat)
    my $cat_features = $info->{$cat}{probs};
    
    my $doc_hash = $newdoc->features->as_hash;
    while (my ($feature, $value) = each %$doc_hash) {
      next unless exists $self->{model}{features}{$feature};
      $scores{$cat} += ($cat_features->{$feature} || $cat_features->{''})*$value;   # P($feature|$cat)**$value
    }
  }
  
  $self->_rescale(\%scores);
#warn $newdoc->name, ": pos => $scores{pos}, neg => $scores{neg}\n";
  return $scores{pos};
}

sub _rescale {
  my ($self, $scores) = @_;

  # Scale everything back to a reasonable area in logspace (near zero), un-loggify, and normalize
  my $total = 0;
  my $max = max(values %$scores);
  foreach (keys %$scores) {
    $scores->{$_} = exp($scores->{$_} - $max);
    $total += $scores->{$_};
  }
  foreach (keys %$scores) {
    $scores->{$_} /= $total;
  }
}

sub save_state {
  my $self = shift;
  local $self->{knowledge_set};  # Don't need the knowledge_set to categorize
  $self->SUPER::save_state(@_);
}

1;

__END__
