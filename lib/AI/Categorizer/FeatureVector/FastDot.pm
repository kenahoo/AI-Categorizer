use strict;

package AI::Categorizer::FeatureVector::FastDot;

use AI::Categorizer::FeatureVector;
use vars qw($VERSION @ISA);
use DynaLoader ();

@ISA = qw(DynaLoader AI::Categorizer::FeatureVector);
bootstrap AI::Categorizer::FeatureVector::FastDot $VERSION;


my %all_features;

sub all_features {
  my $pkg = shift;
  if (@_) {
    die "all_features() already set" if keys %all_features;
    my $i = 0;
    %all_features = map {$_, $i++} @{$_[0]};
  }
  return \%all_features;
}

sub dot {
  my ($self, $other) = @_;
  return $self->SUPER::dot($other) unless UNIVERSAL::isa($other, __PACKAGE__) && keys %all_features;
  $self->_make_sparse_vec unless $self->{c_array};
  $other->_make_sparse_vec unless $other->{c_array};
  return _dot($self->{c_array}, $other->{c_array});
}

sub _make_sparse_vec {
  my $self = shift;
  my @names = sort {$all_features{$a} <=> $all_features{$b}} $self->names;
  my @indices = @all_features{ @names };
  my @values = $self->values( @names );
  $self->{c_array} = _make_array(\@indices, \@values);
}

1;
__END__

=head1 NAME

AI::Categorizer::FeatureVector - Features vs. Values

=head1 SYNOPSIS

  my $f1 = new AI::Categorizer::FeatureVector
    (features => {howdy => 2, doody => 3});
  my $f2 = new AI::Categorizer::FeatureVector
    (features => {doody => 1, whopper => 2});
   
  @names = $f1->names;
  $x = $f1->length;
  $x = $f1->sum;
  $x = $f1->includes('howdy');
  $x = $f1->value('howdy');
  $x = $f1->dot($f2);
  
  $f3 = $f1->clone;
  $f3 = $f1->intersection($f2);
  $f3 = $f1->add($f2);
  
  $h = $f1->as_hash;
  $h = $f1->as_boolean_hash;
  
  $f1->normalize;

=head1 DESCRIPTION

This class implements a "feature vector", which is a flat data
structure indicating the values associated with a set of features.  At
its base level, a FeatureVector usually represents the set of words in
a document, with the value for each feature indicating the number of
times each word appears in the document.  However, the values are
arbitrary so they can represent other quantities as well, and
FeatureVectors may also be combined to represent the features of
multiple documents.

=head1 METHODS

=over 4

=item ...

=back

=head1 AUTHOR

Ken Williams, ken@mathforum.org

=head1 COPYRIGHT

Copyright 2000-2003 Ken Williams.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

AI::Categorizer(3), Storable(3)

=cut
