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
  $correct = UNIVERSAL::isa($correct, 'HASH') ? $correct : { map {($_ => 1)} @$correct };

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

sub macro_accuracy  { $_[0]->_accuracy( $_[0]) }
sub macro_error     { $_[0]->_error(    $_[0]) }
sub macro_precision { $_[0]->_precision($_[0]) }
sub macro_recall    { $_[0]->_recall(   $_[0]) }
sub macro_F1        { $_[0]->_F1(       $_[0]) }

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

sub micro_precision {
  return shift()->_micro_stats->{precision};
}

sub micro_recall {
  return shift()->_micro_stats->{recall};
}

sub micro_F1 {
  return shift()->_micro_stats->{F1};
}

sub micro_accuracy {
  return shift()->_micro_stats->{accuracy};
}

sub micro_error {
  return shift()->_micro_stats->{error};
}

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
