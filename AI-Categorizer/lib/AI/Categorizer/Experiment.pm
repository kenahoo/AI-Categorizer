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

use AI::Categorizer::Util qw(intersection);

sub new {
  my $package = shift;
  my $self = $package->SUPER::new(@_);
  $self->{$_} = 0 foreach qw(a b c d);
  $self->{categories} = {};
  return $self;
}

sub add_hypothesis {
  my ($self, $hypothesis, $correct) = @_;
  my %assigned = map {($_, 1)} $hypothesis->categories;
  
  my %this;
  $this{a} = intersection(\%assigned, $correct);
  $this{b} = keys(%assigned) - $this{a};
  $this{c} = @$correct - $this{a};

  # Add to the macro tables
  foreach (qw(a b c)) {
    $self->{$_} += $this{$_};
  }

  # Now this is the tricky part - add to the micro tables
  foreach my $cat (@$correct) {
#    if ($assigned{$cat}) {
#      $self->{categories}{$cat}{a}++;
#    } else {
#      $self->{categories}{$cat}{c}++;
#    }
  }
}

sub _compute {
  my ($self, $x, $y) = @_;
  return 1 unless $y;
  return 0 unless $x;
  return 1 / (1 + $y/$x);
}

sub macro_precision {
  my ($self) = @_;
  return $self->_compute($self->{a}, $self->{b});
}

sub macro_recall {
  my $self = shift;
  return $self->_compute($self->{a}, $self->{c});
}

sub macro_F1 {
  my $self = shift;
  return $self->_compute(2 * $self->{a}, $self->{b} + $self->{c});
}

sub micro_precision {
  my $self = shift;
  my $cats = $self->{categories};
  my $result;
  while (my ($cat, $scores) = each %$cats) {
    $result += $self->_compute($scores->{a}, $scores->{b});
  }
  return $result / keys %$cats;
}

sub micro_recall {
  my $self = shift;
  my $cats = $self->{categories};
  my $result;
  while (my ($cat, $scores) = each %$cats) {
    $result += $self->_compute($scores->{a}, $scores->{c});
  }
  return $result / keys %$cats;
}

sub micro_F1 {
  my $self = shift;
  my $cats = $self->{categories};
  my $result;
  while (my ($cat, $scores) = each %$cats) {
    $result += $self->_compute(2 * $scores->{a}, $scores->{b} + $scores->{c});
  }
  return $result / keys %$cats;
}

1;
