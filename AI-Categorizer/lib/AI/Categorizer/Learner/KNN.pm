package AI::Categorizer::Learner::KNN;

use strict;
use AI::Categorizer::Learner;
use base qw(AI::Categorizer::Learner);
use Params::Validate qw(:types);
use AI::Categorizer::Util qw(max average binary_search);

__PACKAGE__->valid_params
  (
   threshold => {type => SCALAR, default => 0.1},
   k_value => {type => SCALAR, default => 5},
  );

sub create_model {
  my $self = shift;
  foreach my $doc ($self->knowledge_set->documents) {
    $doc->features->normalize;
  }
}

sub threshold {
  my $self = shift;
  $self->{threshold} = shift if @_;
  return $self->{threshold};
}

#--- returns scores of this document with k closest neighbours
sub subIn{
    my($value, $arr)=@_;
    return -1 if $arr->[0] > $value;

    my $i = binary_search($arr, $value);
    splice @$arr, $i, 0, $value;
    pop @$arr;
    return $i;
}

sub get_scores {
  my ($self, $newdoc) = @_;
  my @docs = $self->knowledge_set->documents;

  my $currentDocName = $newdoc->name;
  #print "classifying $currentDocName\n";

  my $features = $newdoc->features->normalize;
  my (%scores, @dscores, @kdocs);
  my $k = $self->{k_value};

  @dscores = (0) x $k;
  @kdocs = (undef) x $k;
  
  foreach my $doc (@docs) { # each doc in corpus 
    my $score = $doc->features->dot( $features );
    warn "Score for ", $doc->name, " (", ($doc->categories)[0]->name, "): $score" if $self->verbose > 1;
    
    local $^W; # @dscores may have lots of undef's in it - needs to be fixed
    my $index = subIn($score, \@dscores);
    if($index>-1){
      splice @kdocs, $index, 0, $doc;
      pop @kdocs;
    }
  }
  
  my $no_of_cats =0;
  foreach my $e (0..$k) {
    next unless defined $kdocs[$e];
    
    if($dscores[$e]){
      foreach my $cat($kdocs[$e]->categories){
	$no_of_cats++;
	$scores{$cat->name}++; #increment cat score
      }
    }
  } 
  
  foreach my $key (keys %scores) {
    $scores{$key} /= $no_of_cats;
  }
  
  return (\%scores, $self->{threshold});
}

1;

__END__

=head1 NAME

AI::Categorizer::Learner::KNN - K Nearest Neighbour Algorithm For AI::Categorizer

=head1 SYNOPSIS

  use AI::Categorizer::Learner::KNN;
  
  # Here $k is an AI::Categorizer::KnowledgeSet object
  
  my $nb = new AI::Categorizer::Learner::KNN(...parameters...);
  $nb->train(knowledge_set => $k);
  $nb->save_state('filename');
  
  ... time passes ...
  
  $l = AI::Categorizer::Learner->restore_state('filename');
  my $c = new AI::Categorizer::Collection::Files( path => ... );
  while (my $document = $c->next) {
    my $hypothesis = $l->categorize($document);
    print "Best assigned category: ", $hypothesis->best_category, "\n";
    print "All assigned categories: ", join(', ', $hypothesis->categories), "\n";
  }

=head1 DESCRIPTION

This is an implementation of the k-Nearest-Neighbor decision-making
algorithm, applied to the task of document categorization (as defined
by the AI::Categorizer module).  See L<AI::Categorizer> for a complete
description of the interface.

=head1 METHODS

This class inherits from the C<AI::Categorizer::Learner> class, so all
of its methods are available unless explicitly mentioned here.

=head2 new()

Creates a new KNN Learner and returns it.  In addition to the
parameters accepted by the C<AI::Categorizer::Learner> class, the
KNN subclass accepts the following parameters:

=over 4

=item threshold

Sets the score threshold for category membership.  The default is
currently 0.1.  Set the threshold lower to assign more categories per
document, set it higher to assign fewer.  This can be an effective way
to trade of between precision and recall.

=item k_value

Sets the C<k> value (as in k-Nearest-Neighbor) to the given integer.
This indicates how many of each document's nearest neighbors should be
considered when assigning categories.  The default is 5.

=back

=head2 threshold()

Returns the current threshold value.  With an optional numeric
argument, you may set the threshold.

=head2 train(knowledge_set => $k)

Trains the categorizer.  This prepares it for later use in
categorizing documents.  The C<knowledge_set> parameter must provide
an object of the class C<AI::Categorizer::KnowledgeSet> (or a subclass
thereof), populated with lots of documents and categories.  See
L<AI::Categorizer::KnowledgeSet> for the details of how to create such
an object.

=head2 categorize($document)

Returns an C<AI::Categorizer::Hypothesis> object representing the
categorizer's "best guess" about which categories the given document
should be assigned to.  See L<AI::Categorizer::Hypothesis> for more
details on how to use this object.

=head2 save_state($path)

Saves the categorizer for later use.  This method is inherited from
C<AI::Categorizer::Storable>.

=head1 AUTHOR

Originally written by David Bell (C<< <dave@student.usyd.edu.au> >>),
October 2002.

Added to AI::Categorizer November 2002, modified, and maintained by
Ken Williams (C<< <ken@mathforum.org> >>).

=head1 COPYRIGHT

Copyright 2000-2002 Ken Williams.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

AI::Categorizer(3)

"A re-examination of text categorization methods" by Yiming Yang
L<http://www.cs.cmu.edu/~yiming/publications.html>

=cut
