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
#   categories => {type => ARRAYREF},
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

sub macro_accuracy {
  my $self = shift;
  return +($self->{a} + $self->{d}) / ($self->{a} + $self->{b} + $self->{c} + $self->{d});
}

sub macro_error {
  my $self = shift;
  return +($self->{b} + $self->{c}) / ($self->{a} + $self->{b} + $self->{c} + $self->{d});
}

sub macro_precision {
  my ($self) = @_;
  return $self->_invert($self->{a}, $self->{b});
}

sub macro_recall {
  my $self = shift;
  return $self->_invert($self->{a}, $self->{c});
}

sub macro_F1 {
  my $self = shift;
  return $self->_invert(2 * $self->{a}, $self->{b} + $self->{c});
}

sub micro_precision {
  my $self = shift;
  my $cats = $self->{categories};
  my $result;
  while (my ($cat, $scores) = each %$cats) {
    $result += $self->_invert($scores->{a}, $scores->{b});
  }
  return $result / keys %$cats;
}

sub micro_recall {
  my $self = shift;
  my $cats = $self->{categories};
  my $result;
  while (my ($cat, $scores) = each %$cats) {
    $result += $self->_invert($scores->{a}, $scores->{c});
  }
  return $result / keys %$cats;
}

sub micro_F1 {
  my $self = shift;
  my $cats = $self->{categories};
  my $result;
  while (my ($cat, $scores) = each %$cats) {
    $result += $self->_invert(2 * $scores->{a}, $scores->{b} + $scores->{c});
  }
  return $result / keys %$cats;
}

sub micro_accuracy {
  my $self = shift;
  my $cats = $self->{categories};
  my $result;
  while (my ($cat, $scores) = each %$cats) {
    $result += ($scores->{a} + $scores->{d}) / $self->{hypotheses};
  }
  return $result / keys %$cats;
}

sub micro_error {
  my $self = shift;
  my $cats = $self->{categories};
  my $result;
  while (my ($cat, $scores) = each %$cats) {
    $result += ($scores->{b} + $scores->{c}) / $self->{hypotheses};
  }
  return $result / keys %$cats;
}

sub display_stats {
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
