package AI::Categorizer;
$VERSION = '0.01';

use strict;
use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Categorizer;


# Preloaded methods go here.

1;
__END__

=head1 NAME

AI::Categorizer - Automatic Text Categorization

=head1 SYNOPSIS

 # An example...
 
 use AI::Categorizer;
 use AI::Categorizer::Categorizer::NaiveBayes;
  
 # Read a collection of categorized documents
 my $k = new AI::Categorizer::KnowledgeSet
   (
    document_class   => 'AI::Categorizer::Document::Text',
    collection_class => 'AI::Categorizer::Collection::Files',
    stopwords => [ ... ],
    features_kept => 500,
    load => { path => '/path/to/data', scan_features => 1 },
   );
 
 # Train a categorizer
 my $c = new AI::Categorizer::Categorizer::NaiveBayes;
 $c->train($k);
 $c->save_state('filename');
 
 # ... Time passes ...
 
 # Read an uncategorized document
 use AI::Categorizer::Document::Text;
 my $doc = AI::Categorizer::Document::Text->read( path => '/path/to/doc' );
 
 # Categorize it
 $c = AI::Categorizer::Categorizer::NaiveBayes->restore_state('filename');
 my $result = $c->categorize($doc);
 
 # Check the result
 if ($result->is_in_category('sports')) { ... }
 my $best_cat = $result->best_category;
 my @categories = $result->categories;
 my @scores = $result->scores(@categories);

=head1 DESCRIPTION

C<AI::Categorizer> is a framework for automatic text categorization.
It consists of a collection of Perl modules that implement common
categorization tasks.  The various details are flexible - for example,
you can choose what categorization algorithm to use, what features
(words or otherwise) of the documents should be used (or how to
automatically choose these features), what format the documents are
in, and so on.

The basic process of using this module will typically involve
obtaining a collection of B<pre-categorized> documents, creating a
knowledge set representation of those documents, training a
categorizer on that knowledge set, and saving the trained categorizer
for later use.

For the usage details, please see the documentation of each individual
module.

=head1 HISTORY

This module is a revised and redesigned version of the previous
C<AI::Categorize> module by the same author.  Note the added 'r' in
the new name.  The older module has a different interface, and no
attempt at backward compatibility has been made - that's why I changed
the name.

You can have both C<AI::Categorize> and C<AI::Categorizer> installed
at the same time on the same machine, if you want.

=head1 AUTHOR

Ken Williams <kenw@ee.usyd.edu.au>

=head1 COPYRIGHT

This distribution is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.  These terms apply to
every file in the distribution - if you have questions, please contact
the author.

=cut
