package AI::Categorizer::Util;

use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(intersection average F1 recall precision accuracy error max min);

use strict;

# It's possible that this can be a class - something like 
# 
# $e = Evaluate->new(); $e->correct([...]); $e->assigned([...]); print $e->precision;

sub max {
  return undef unless @_;
  my $max = shift;
  foreach (@_) {
    $max = $_ if $_ > $max;
  }
  return $max;
}

sub min {
  return undef unless @_;
  my $min = shift;
  foreach (@_) {
    $min = $_ if $_ > $min;
  }
  return $min;
}

sub average {
  return undef unless @_;
  my $total;
  $total += $_ foreach @_;
  return $total/@_;
}

sub F1 { # F1 = 2I/(A+C), I=Intersection, A=Assigned, C=Correct
  my ($assigned, $correct) = @_;
  return 1 unless @$assigned or @$correct;  # score 1 for correctly assigning zero categories
  return 2 * intersection($assigned, $correct) / (@$assigned + @$correct);
}

sub recall {
  my ($assigned, $correct) = @_;
  return 1 if !@$assigned and !@$correct;
  return 0 if  @$assigned and !@$correct; # Don't divide by zero
  
  return intersection($assigned, $correct) / @$correct;
}

sub precision {
  my ($assigned, $correct) = @_;
  return 1 if !@$assigned and !@$correct;
  return 0 if !@$assigned and  @$correct; # Don't divide by zero
  
  return intersection($assigned, $correct) / @$assigned;
}

sub accuracy {
  # accuracy = 1-error, and error is easier to compute.
  return 1 - error(@_);
}

# Returns the error rate among all binary decisions made over all categories.
sub error {
  my ($assigned, $correct, $all) = @_;
  $correct  = _hashify($correct);
  $assigned = _hashify($assigned);

  my $symmetric_diff = 0;
  foreach (@$assigned) {
    $symmetric_diff++ unless exists $correct->{$_};
  }
  foreach (@$correct ) {
    $symmetric_diff++ unless exists $assigned->{$_};
  }
  return $symmetric_diff / @$all;
}

sub intersection {
  my ($one, $two) = @_;
  $two = _hashify($two);

  return UNIVERSAL::isa($one, 'HASH') ?	# Accept hash or array for $one
    grep {exists $two->{$_}} keys %$one :
    grep {exists $two->{$_}} @$one;
}

sub _hashify {
  return $_[0] if UNIVERSAL::isa($_[0], 'HASH');
  return {map {$_=>1} @{$_[0]}};
}

1;
